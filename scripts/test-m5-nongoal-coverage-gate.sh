#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/svgdiff-m5-nongoal-gate.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
manifest=evaluation/m5-nongoal-coverage-gate/manifest.v1.json

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

run_unsupported_self_comparison() {
  name=$1
  expected_diagnostic=$2
  svg=$tmp/$name.svg
  report=$tmp/$name.json
  tee "$svg" >/dev/null
  assert_status 0 "$cli" "$svg" "$svg" --width 16 --height 16 >"$report"
  python3 - "$report" "$expected_diagnostic" <<'PY'
import json
from pathlib import Path
import sys

report = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
expected_diagnostic = sys.argv[2]
codes = {limitation["code"] for limitation in report["limitations"]}
if report["analysis_status"] != "partial":
    raise SystemExit("unsupported self-comparison did not remain partial")
if expected_diagnostic not in codes:
    raise SystemExit(f"missing expected diagnostic: {expected_diagnostic}")
if not report["limitations"]:
    raise SystemExit("unsupported self-comparison has no limitation")
if any(group["items"] for group in report["difference_groups"]):
    raise SystemExit("self-comparison unexpectedly produced Atomic Differences")
PY
}

cd "$root"
python3 evaluation/m5-nongoal-coverage-gate/validate.py "$manifest"
python3 -m json.tool "$manifest" >/dev/null

jq 'del(.capabilities[0])' "$manifest" >"$tmp/missing-capability.json"
assert_status 1 python3 evaluation/m5-nongoal-coverage-gate/validate.py \
  "$tmp/missing-capability.json" >/dev/null 2>&1
for field in disposition authority document decision_artifact validation_command product_guards future_identities; do
  jq --arg field "$field" 'del(.capabilities[0][$field])' "$manifest" \
    >"$tmp/missing-$field.json"
  assert_status 1 python3 evaluation/m5-nongoal-coverage-gate/validate.py \
    "$tmp/missing-$field.json" >/dev/null 2>&1
done
jq '.capabilities[0].adopted = true' "$manifest" >"$tmp/adopted.json"
assert_status 1 python3 evaluation/m5-nongoal-coverage-gate/validate.py \
  "$tmp/adopted.json" >/dev/null 2>&1
jq '.capabilities[0].future_identities = []' "$manifest" >"$tmp/no-future-identity.json"
assert_status 1 python3 evaluation/m5-nongoal-coverage-gate/validate.py \
  "$tmp/no-future-identity.json" >/dev/null 2>&1
jq '.capabilities[3].outside_input_reason = ""' "$manifest" >"$tmp/no-outside-reason.json"
assert_status 1 python3 evaluation/m5-nongoal-coverage-gate/validate.py \
  "$tmp/no-outside-reason.json" >/dev/null 2>&1

for command in \
  scripts/test-font-runtime-selection.sh \
  scripts/test-platform-font-modes.sh \
  scripts/test-color-profile-decision.sh \
  scripts/test-multi-renderer-decision.sh \
  scripts/test-script-runtime-decision.sh \
  scripts/test-interaction-state-decision.sh \
  scripts/test-animation-timeline-decision.sh \
  scripts/test-foreign-content-decision.sh \
  scripts/test-resource-snapshot-decision.sh
do
  sh "$command"
done

moon build --target native --release modules/svgdiff/cmd/svgdiff >/dev/null
cli=$root/_build/native/release/build/Milky2018/svgdiff/cmd/svgdiff/svgdiff.exe

run_unsupported_self_comparison font analysis_coverage_unproven <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg"><text x="0" y="10">Hello</text></svg>
SVG
run_unsupported_self_comparison color color_profile_unsupported <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg"><rect width="10" height="10" fill="color(display-p3 1 0 0)"/></svg>
SVG
run_unsupported_self_comparison interaction css_cascade_unsupported <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg"><style>rect:hover{fill:red}</style><rect width="10" height="10"/></svg>
SVG
run_unsupported_self_comparison script unsupported_visual_subject <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg"><script>document.documentElement.setAttribute("fill","red")</script><rect width="10" height="10"/></svg>
SVG
run_unsupported_self_comparison animation unsupported_visual_subject <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg"><rect width="10" height="10"><animate attributeName="x" from="0" to="10" dur="1s"/></rect></svg>
SVG
run_unsupported_self_comparison foreign-object unsupported_visual_subject <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg"><foreignObject width="10" height="10"><div xmlns="http://www.w3.org/1999/xhtml">Hello</div></foreignObject></svg>
SVG
run_unsupported_self_comparison external-resource use_external_reference_unsupported <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg"><use href="https://example.invalid/a.svg#x"/></svg>
SVG

sh scripts/test-m2-renderer-coverage-gate.sh
moon test --target native \
  modules/svgdiff/engine/structured_report_test.mbt \
  modules/svgdiff/engine/internal/diff/embedded_image_diff_wbtest.mbt \
  modules/svgdiff/engine/internal/diff/resource_bundle_wbtest.mbt \
  modules/svgdiff/engine/internal/diff/resource_outcome_policy_wbtest.mbt \
  modules/svgdiff/engine/unsupported_input_property_test.mbt

printf 'M5 explicit non-goal coverage gate: passed\n'
