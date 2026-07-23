#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/svgdiff-report-determinism-$$
cli="$root/_build/native/release/build/Milky2018/svgdiff/cmd/svgdiff/svgdiff.exe"
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

cd "$root"
moon build --target native --release modules/svgdiff/cmd/svgdiff >/dev/null
python3 evaluation/determinism/validate.py --cli "$cli" --output "$tmp/first.json"
python3 evaluation/determinism/validate.py --cli "$cli" --output "$tmp/second.json"
cmp "$tmp/first.json" "$tmp/second.json"
jq -e '
  .schema_version == "svgdiff-determinism-results/1" and
  .repetitions_per_mode == 3 and
  (.cases | length) == 8 and
  all(.cases[]; .status == "passed") and
  .negative_controls == [
    "duplicate_report_local_id",
    "dangling_report_local_reference",
    "dangling_possible_cause"
  ]
' "$tmp/first.json" >/dev/null

printf 'Structured Report determinism and local references: ok\n'
