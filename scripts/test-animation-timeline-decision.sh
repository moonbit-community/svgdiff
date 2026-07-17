#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/svgdiff-animation-timeline-decision-$$
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

cd "$root"
python3 evaluation/animation-timeline-decision/validate.py >"$tmp/first.txt"
python3 evaluation/animation-timeline-decision/validate.py >"$tmp/second.txt"
cmp "$tmp/first.txt" "$tmp/second.txt"
grep -Fx 'Animation timeline decision: exact shared document-time checkpoints preserve timing differences; finite samples never prove interval equality' "$tmp/first.txt" >/dev/null
cat "$tmp/first.txt"
