#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/svgdiff-platform-font-modes-$$
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

cd "$root"
python3 evaluation/platform-font-modes/validate.py >"$tmp/first.txt"
python3 evaluation/platform-font-modes/validate.py >"$tmp/second.txt"
cmp "$tmp/first.txt" "$tmp/second.txt"
grep -Fx 'Platform font modes: canonical native execution permanently rejected; closed-bundle observations external, ambient captures exploratory only' "$tmp/first.txt" >/dev/null
cat "$tmp/first.txt"
