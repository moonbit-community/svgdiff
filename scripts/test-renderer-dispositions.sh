#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cli="$root/_build/native/release/build/cmd/svgdiff/svgdiff.exe"

cd "$root"
moon build --target native --release cmd/svgdiff
python3 evaluation/renderer-conformance/validate_dispositions.py --cli "$cli"
