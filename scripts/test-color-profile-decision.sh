#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/svgdiff-color-profile-decision-$$
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

cd "$root"
python3 evaluation/color-profile-decision/validate.py >"$tmp/first.txt"
python3 evaluation/color-profile-decision/validate.py >"$tmp/second.txt"
cmp "$tmp/first.txt" "$tmp/second.txt"
grep -Fx 'Color profile decision: current sRGB unchanged; predefined SDR first future candidate, ICC and HDR staged, ambient platform color permanently rejected' "$tmp/first.txt" >/dev/null
cat "$tmp/first.txt"
