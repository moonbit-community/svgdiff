#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/svgdiff-renderer-conformance-$$
oracle="$tmp/oracle"
adapter="$root/_build/native/release/build/Milky2018/svgdiff/evaluation/renderer_adapter/renderer_adapter.exe"
trap 'rm -rf "$tmp"' EXIT

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 OUTPUT_JSON" >&2
  exit 2
fi

mkdir -p "$oracle"
cd "$root"
sh scripts/run-browser-oracle.sh "$oracle"
moon build --target native --release evaluation/renderer_adapter
python3 evaluation/renderer-conformance/compare.py \
  --oracle "$oracle" \
  --adapter "$adapter" \
  --output "$1"
