#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/svgdiff-performance-budget-test-$$
trap 'rm -rf "$tmp"' EXIT

cd "$root"
sh scripts/run-performance-budgets.sh --output "$tmp/results.json" >/dev/null
python3 evaluation/performance/validate_budgets.py \
  --input "$tmp/results.json" \
  --self-test >/dev/null
jq -e '
  .schema_version == "svgdiff-performance-results/1" and
  .budget_version == "svgdiff-performance-budgets/1" and
  .passed == true and
  (.workloads | map(.size)) == ["small", "medium", "large"] and
  all(.workloads[]; .passed and (.samples | length) == 3 and all(.checks[]; .passed))
' "$tmp/results.json" >/dev/null

printf 'Performance budgets: small, medium, large time and peak RSS gates: ok\n'
