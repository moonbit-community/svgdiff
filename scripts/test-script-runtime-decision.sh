#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/svgdiff-script-runtime-decision-$$
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

cd "$root"
python3 evaluation/script-runtime-decision/validate.py >"$tmp/first.txt"
python3 evaluation/script-runtime-decision/validate.py >"$tmp/second.txt"
cmp "$tmp/first.txt" "$tmp/second.txt"
grep -Fx 'Script runtime decision: canonical secure-static execution remains script-free; sandbox is not determinism; future script output is external observation only' "$tmp/first.txt" >/dev/null
cat "$tmp/first.txt"
