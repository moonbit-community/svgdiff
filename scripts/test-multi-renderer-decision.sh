#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/svgdiff-multi-renderer-decision-$$
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

cd "$root"
python3 evaluation/multi-renderer-decision/validate.py >"$tmp/first.txt"
python3 evaluation/multi-renderer-decision/validate.py >"$tmp/second.txt"
cmp "$tmp/first.txt" "$tmp/second.txt"
grep -Fx 'Multi-renderer decision: profile sensitivity and renderer conformance typed separately; matrices preserve edges, diagonals confounded, no majority truth' "$tmp/first.txt" >/dev/null
cat "$tmp/first.txt"
