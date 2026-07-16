#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/svgdiff-impact-assessment-$$
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

cd "$root"
moon build --target native --release cmd/svgdiff >/dev/null
cli="$root/_build/native/release/build/Milky2018/svgdiff/cmd/svgdiff/svgdiff.exe"
python3 evaluation/impact/validate.py --cli "$cli" >"$tmp/first.txt"
python3 evaluation/impact/validate.py --cli "$cli" >"$tmp/second.txt"
cmp "$tmp/first.txt" "$tmp/second.txt"
grep -q '^Impact frontier benchmark: 12 scorable targets covered, 1 not applicable$' "$tmp/first.txt"
cat "$tmp/first.txt"
