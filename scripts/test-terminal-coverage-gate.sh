#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/svgdiff-terminal-coverage.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
manifest=evaluation/terminal-coverage-gate/manifest.v1.json
validator=evaluation/terminal-coverage-gate/validate.py

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

jq 'del(.obligations[0])' "$manifest" >"$tmp/missing-obligation.json"
assert_status 1 python3 "$validator" "$tmp/missing-obligation.json" >/dev/null 2>&1
for field in claim boundary authorities validation_commands; do
  jq --arg field "$field" 'del(.obligations[0][$field])' "$manifest" \
    >"$tmp/missing-$field.json"
  assert_status 1 python3 "$validator" "$tmp/missing-$field.json" >/dev/null 2>&1
done
jq 'del(.forbidden_inferences[0])' "$manifest" >"$tmp/missing-forbidden.json"
assert_status 1 python3 "$validator" "$tmp/missing-forbidden.json" >/dev/null 2>&1
jq '.claim_scope = "all-svg-every-browser"' "$manifest" >"$tmp/widened-scope.json"
assert_status 1 python3 "$validator" "$tmp/widened-scope.json" >/dev/null 2>&1
jq '.obligations[0].validation_commands[0] = "scripts/not-a-real-gate.sh"' "$manifest" \
  >"$tmp/missing-command.json"
assert_status 1 python3 "$validator" "$tmp/missing-command.json" >/dev/null 2>&1

sh scripts/test-m2-core-static-coverage.sh
sh scripts/test-m2-renderer-coverage-gate.sh
sh scripts/test-m2-soundness-gate.sh
sh scripts/test-m5-nongoal-coverage-gate.sh
sh scripts/test-m5-adopted-profile-gate.sh
sh scripts/test-cli.sh
sh scripts/test-fuzz-smoke.sh
moon test --target native \
  engine/coverage_proof_wbtest.mbt \
  engine/feature_coverage_wbtest.mbt \
  engine/unsupported_input_property_test.mbt \
  engine/resource_limits_wbtest.mbt

moon build --target native --release cmd/svgdiff >/dev/null
cli=$root/_build/native/release/build/Milky2018/svgdiff/cmd/svgdiff/svgdiff.exe
"$cli" testdata/before.svg testdata/before.svg >"$tmp/complete.json"
printf '%s\n' '<svg xmlns="http://www.w3.org/2000/svg"><script/></svg>' >"$tmp/partial.svg"
"$cli" "$tmp/partial.svg" "$tmp/partial.svg" >"$tmp/partial.json"
printf '%s\n' '<svg><rect></svg>' >"$tmp/failed.svg"
assert_status 1 "$cli" "$tmp/failed.svg" testdata/before.svg >"$tmp/failed.json"
python3 - "$tmp/complete.json" "$tmp/partial.json" "$tmp/failed.json" <<'PY'
import json
from pathlib import Path
import sys

reports = [json.loads(Path(path).read_text(encoding="utf-8")) for path in sys.argv[1:]]
expected = ["complete", "partial", "failed"]
if [report["analysis_status"] for report in reports] != expected:
    raise SystemExit("complete/partial/failed production status composition changed")
if reports[1]["atomic_differences"]:
    raise SystemExit("unsupported self-comparison unexpectedly produced differences")
if not reports[1]["diagnostics"] or not reports[2]["diagnostics"]:
    raise SystemExit("partial or failed report lacks Diagnostics")
for report in reports[1:]:
    if not any(
        "limited" in (row["source_semantics"], row["computed_appearance"], row["rendered_evidence"])
        or "failed" in (row["source_semantics"], row["computed_appearance"], row["rendered_evidence"])
        for row in report["coverage_matrix"]
    ):
        raise SystemExit("non-complete report lacks limiting or failed coverage")
PY

printf 'Terminal evidence-or-Diagnostic coverage gate: passed\n'
