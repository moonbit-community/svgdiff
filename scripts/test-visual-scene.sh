#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

moon build --target native --release modules/svgdiff/cmd/svgdiff >/dev/null
cli="$root/_build/native/release/build/Milky2018/svgdiff/cmd/svgdiff/svgdiff.exe"
python3 evaluation/stress/validate_visual_scene.py --cli "$cli"
