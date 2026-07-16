#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/svgdiff-alternate-scale-qa-$$
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

cd "$root"
sh scripts/run-alternate-scale-qa.sh "$tmp/qa.json"
cmp evaluation/alternate-scale/baseline.v1.json "$tmp/qa.json"
jq -e '
  .schema_version == "svgdiff-alternate-scale-renderer-qa/1" and
  .canonical_report_evidence == false and
  (.pairs | length) == 4 and
  (all(.pairs[]; (.measurements | length) == 4))
' "$tmp/qa.json" >/dev/null

moon run --target native cmd/svgdiff -- \
  testdata/before.svg testdata/after.svg --agent-json >"$tmp/report.json"
jq -e '
  .schema_version == "1.32" and
  .profile.comparison_dpr == 1 and
  ([paths | map(tostring) | join(".") | select(contains("alternate_scale"))] |
    length) == 0
' "$tmp/report.json" >/dev/null

printf 'Alternate-scale QA baseline: reproduced; canonical report: unchanged\n'
