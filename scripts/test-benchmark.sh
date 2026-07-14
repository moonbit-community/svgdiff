#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/svgdiff-benchmark-test-$$
trap 'rm -rf "$tmp"' EXIT

cd "$root"
sh scripts/run-agent-benchmark.sh --output "$tmp/evidence" >/dev/null
jq -e '
  .gate_version == "svgdiff-benchmark-gate/1" and
  .passed == true and
  all(.checks[]; .passed == true)
' "$tmp/evidence/gate.json" >/dev/null
jq -e '
  .classification_version == "svgdiff-failure-classification/1" and
  .gate_passed == true and
  .summary.diagnostic_observations_by_domain.feature_coverage == 1 and
  .summary.diagnostic_observations_by_domain.renderer_conformance == 2 and
  .summary.threshold_failures_by_domain.report_model == 0 and
  .summary.threshold_failures_by_domain.agent_interpretation == 0 and
  .summary.has_unclassified == false
' "$tmp/evidence/failures.json" >/dev/null

if sh scripts/run-agent-benchmark.sh \
  --output "$tmp/empty" \
  --agent "python3 evaluation/harness/report_only_test_agent.py" \
  >/dev/null 2>&1; then
  printf 'Benchmark unexpectedly accepted the empty semantic adapter\n' >&2
  exit 1
fi
jq -e '
  .passed == false and
  any(.checks[]; .passed == false)
' "$tmp/empty/gate.json" >/dev/null
jq -e '
  .gate_passed == false and
  .summary.threshold_failures_by_domain.agent_interpretation > 0 and
  .summary.threshold_failures_by_domain.report_model == 0 and
  .summary.has_unclassified == false
' "$tmp/empty/failures.json" >/dev/null

python3 evaluation/harness/test_failure_classification.py >/dev/null

printf 'Benchmark command: reproducible artifacts: ok, thresholds: pass/fail verified\n'
