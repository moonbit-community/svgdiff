#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/svgdiff-resource-snapshot-decision-$$
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

cd "$root"
python3 evaluation/resource-snapshot-decision/validate.py >"$tmp/first.txt"
python3 evaluation/resource-snapshot-decision/validate.py >"$tmp/second.txt"
cmp "$tmp/first.txt" "$tmp/second.txt"
grep -Fx 'Resource snapshot decision: side-qualified offline responses preserve URL, content, and provenance distinctions with zero comparison-time I/O' "$tmp/first.txt" >/dev/null
cat "$tmp/first.txt"
