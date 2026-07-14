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

[ -n "$output" ] || { printf 'Usage: sh scripts/run-performance-budgets.sh --output FILE\n' >&2; exit 2; }

case "$output" in
  /*) ;;
  *) output="$root/$output" ;;
esac

cd "$root"
moon build --target native --release cmd/svgdiff
python3 evaluation/performance/run_budgets.py \
  --cli _build/native/release/build/cmd/svgdiff/svgdiff.exe \
  --manifest evaluation/performance/budgets.v1.json \
  --output "$output"
python3 evaluation/performance/validate_budgets.py --input "$output"
