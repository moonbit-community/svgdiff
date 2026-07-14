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

printf 'Benchmark command: reproducible artifacts: ok, thresholds: pass/fail verified\n'
