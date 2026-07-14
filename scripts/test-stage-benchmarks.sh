#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/svgdiff-stage-benchmark-test-$$
trap 'rm -rf "$tmp"' EXIT

cd "$root"
sh scripts/run-stage-benchmarks.sh --output "$tmp/result.json" >/dev/null
python3 evaluation/performance/validate.py \
  --input "$tmp/result.json" \
  --self-test >/dev/null
jq -e '
  .schema_version == "svgdiff-stage-benchmark-results/1" and
  .suite_version == "svgdiff-stage-benchmark-suite/1" and
  .target == "native" and
  .build_profile == "release" and
  .time_unit == "microseconds" and
  (.stages | map(.name)) == [
    "parse_admission",
    "alignment",
    "rendering",
    "region_extraction",
    "provenance",
    "serialization"
  ] and
  all(.stages[]; .runs > 0 and .batch_size > 0 and .min > 0 and .mean > 0 and .max > 0)
' "$tmp/result.json" >/dev/null

printf 'Pipeline stage benchmarks: six production stages, artifact and negative controls: ok\n'
