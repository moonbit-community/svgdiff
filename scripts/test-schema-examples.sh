#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

moon build --target native --release cmd/svgdiff >/dev/null
cli="$root/_build/native/release/build/Milky2018/svgdiff/cmd/svgdiff/svgdiff.exe"
test -x "$cli"
python3 evaluation/schema-examples/validate.py --cli "$cli"
python3 evaluation/schema-examples/validate.py --cli "$cli"
printf 'Schema examples: deterministic production regeneration: ok\n'
