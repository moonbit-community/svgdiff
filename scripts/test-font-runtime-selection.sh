#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/svgdiff-font-runtime-selection-$$
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

cd "$root"
python3 evaluation/font-runtime-selection/validate.py >"$tmp/first.txt"
python3 evaluation/font-runtime-selection/validate.py >"$tmp/second.txt"
cmp "$tmp/first.txt" "$tmp/second.txt"
grep -Fx 'Font runtime selection: HarfBuzz 14.2.1 + FreeType 2.14.3 static MoonBit FFI feasible; product runtime and conformance remain unimplemented' "$tmp/first.txt" >/dev/null
cat "$tmp/first.txt"
