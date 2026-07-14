#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output=

while [ "$#" -gt 0 ]; do
  case "$1" in
    --output)
      [ "$#" -ge 2 ] || { printf 'Missing value for --output\n' >&2; exit 2; }
      output=$2
      shift 2
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

[ -n "$output" ] || { printf 'Usage: sh scripts/run-stage-benchmarks.sh --output FILE\n' >&2; exit 2; }

case "$output" in
  /*) ;;
  *) output="$root/$output" ;;
esac

tmp=${TMPDIR:-/tmp}/svgdiff-stage-benchmarks-$$
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

cd "$root"
moon test --target native --release --include-skipped \
  --filter 'pipeline stage machine artifact' \
  engine/pipeline_benchmark_wbtest.mbt >"$tmp/raw.txt"

sed -n 's/^SVGDIFF_STAGE_BENCHMARK_JSON=//p' "$tmp/raw.txt" >"$tmp/result.json"
test "$(wc -l <"$tmp/result.json" | tr -d ' ')" -eq 1
python3 evaluation/performance/validate.py --input "$tmp/result.json"

mkdir -p "$(dirname -- "$output")"
mv "$tmp/result.json" "$output"
printf 'Pipeline stage benchmark artifact: %s\n' "$output"
