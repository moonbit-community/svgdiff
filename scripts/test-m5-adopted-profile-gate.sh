#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/svgdiff-m5-adopted-gate.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
manifest=evaluation/m5-adopted-profile-gate/manifest.v1.json
validator=evaluation/m5-adopted-profile-gate/validate.py

assert_status() {
  expected=$1
  shift
  set +e
  "$@"
  actual=$?
  set -e
  if [ "$actual" -ne "$expected" ]; then
    printf 'Expected exit status %s, got %s: %s\n' "$expected" "$actual" "$*" >&2
    exit 1
  fi
}

cd "$root"
python3 "$validator" "$manifest"
python3 -m json.tool "$manifest" >/dev/null

jq 'del(.capabilities[0])' "$manifest" >"$tmp/missing-capability.json"
assert_status 1 python3 "$validator" "$tmp/missing-capability.json" >/dev/null 2>&1
for field in decision_artifact implementation_flag profile_identity_fields environment_requirement_fields; do
  jq --arg field "$field" 'del(.capabilities[0][$field])' "$manifest" \
    >"$tmp/missing-$field.json"
  assert_status 1 python3 "$validator" "$tmp/missing-$field.json" >/dev/null 2>&1
done
jq '.capabilities[0].profile_identity_fields = []' "$manifest" >"$tmp/no-profile-format.json"
assert_status 1 python3 "$validator" "$tmp/no-profile-format.json" >/dev/null 2>&1
jq '.capabilities[0].environment_requirement_fields = []' "$manifest" \
  >"$tmp/no-environment-contract.json"
assert_status 1 python3 "$validator" "$tmp/no-environment-contract.json" >/dev/null 2>&1
jq '.capabilities[0].adopted_profile_instance = {"fabricated": true}' "$manifest" \
  >"$tmp/fabricated-instance.json"
assert_status 1 python3 "$validator" "$tmp/fabricated-instance.json" >/dev/null 2>&1

jq '.capabilities |= map(if .id == "platform_native_fonts" then .adopted = true else . end)' \
  evaluation/m5-nongoal-coverage-gate/manifest.v1.json >"$tmp/adoption-source.json"
jq '.capabilities[0].adoption_status = "adopted" | .current_adopted_capabilities = ["platform_native_fonts"]' \
  "$manifest" >"$tmp/adopted-without-implementation.json"
assert_status 1 python3 "$validator" "$tmp/adopted-without-implementation.json" \
  --adoption-source "$tmp/adoption-source.json" >"$tmp/no-implementation.txt" 2>&1
grep -F 'product implementation is absent' "$tmp/no-implementation.txt" >/dev/null

jq '.product_backend_implemented = true' evaluation/platform-font-modes/decision.v1.json \
  >"$tmp/platform-decision.json"
jq --arg decision "$tmp/platform-decision.json" \
  '.capabilities[0].decision_artifact = $decision' \
  "$tmp/adopted-without-implementation.json" >"$tmp/adopted-without-profile.json"
assert_status 1 python3 "$validator" "$tmp/adopted-without-profile.json" \
  --adoption-source "$tmp/adoption-source.json" >"$tmp/no-profile.txt" 2>&1
grep -F 'adopted_profile_instance must be an object' "$tmp/no-profile.txt" >/dev/null

jq '.capabilities[0].adopted_profile_instance = {
  "profile_identity": "example-platform-profile/1",
  "profile_manifest_sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "profile_version": "1"
}' "$tmp/adopted-without-profile.json" >"$tmp/adopted-without-environment.json"
assert_status 1 python3 "$validator" "$tmp/adopted-without-environment.json" \
  --adoption-source "$tmp/adoption-source.json" >"$tmp/no-environment.txt" 2>&1
grep -F 'pinned_environment_instance must be an object' "$tmp/no-environment.txt" >/dev/null

jq '.capabilities[0].pinned_environment_instance = {
  "environment_identity": "example-platform-environment/1",
  "implementation_build_ids": ["example-build/1"],
  "limits_profile_identity": "example-limits/1",
  "resource_manifest_sha256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
}' "$tmp/adopted-without-environment.json" >"$tmp/complete-hypothetical-adoption.json"
assert_status 0 python3 "$validator" "$tmp/complete-hypothetical-adoption.json" \
  --adoption-source "$tmp/adoption-source.json" >/dev/null

for command in \
  scripts/test-platform-font-modes.sh \
  scripts/test-color-profile-decision.sh \
  scripts/test-multi-renderer-decision.sh \
  scripts/test-script-runtime-decision.sh \
  scripts/test-interaction-state-decision.sh \
  scripts/test-animation-timeline-decision.sh \
  scripts/test-foreign-content-decision.sh
do
  sh "$command"
done
sh scripts/test-m5-nongoal-coverage-gate.sh

moon build --target native --release modules/svgdiff/cmd/svgdiff >/dev/null
cli=$root/_build/native/release/build/Milky2018/svgdiff/cmd/svgdiff/svgdiff.exe
"$cli" testdata/before.svg testdata/before.svg >"$tmp/current-report.json"
python3 - "$manifest" "$tmp/current-report.json" <<'PY'
import json
from pathlib import Path
import sys

manifest = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
report = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
profile = report["profile"]
if report["analysis_status"] != "complete":
    raise SystemExit("current supported self-comparison is not complete")
if profile["comparison_dpr"] != 1 or profile["color_interpretation"] != "srgb":
    raise SystemExit("current static execution profile changed")
if profile["raster_representation"] != "linear_srgb_premultiplied_rgba_f64":
    raise SystemExit("current raster profile changed")

def strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, list):
        for item in value:
            yield from strings(item)
    elif isinstance(value, dict):
        for item in value.values():
            yield from strings(item)

reserved = set()
root = Path.cwd()
for capability in manifest["capabilities"]:
    artifact = json.loads((root / capability["decision_artifact"]).read_text(encoding="utf-8"))
    for field in capability["profile_identity_fields"]:
        reserved.add(artifact[field])
present = set(strings(report))
unexpected = sorted(reserved & present)
if unexpected:
    raise SystemExit(f"advanced profile identity entered current report: {unexpected}")
PY

printf 'M5 adopted-profile gate: passed with 0 adopted advanced capabilities\n'
