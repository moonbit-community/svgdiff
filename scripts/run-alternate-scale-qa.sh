#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
adapter="$root/_build/native/release/build/Milky2018/svgdiff/evaluation/renderer_adapter/renderer_adapter.exe"

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 OUTPUT_JSON" >&2
  exit 2
fi

cd "$root"
moon build --target native --release modules/svgdiff/evaluation/renderer_adapter
python3 evaluation/alternate-scale/run.py --adapter "$adapter" --output "$1"
