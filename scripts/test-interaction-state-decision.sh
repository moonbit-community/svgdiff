#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/svgdiff-interaction-state-decision-$$
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

cd "$root"
python3 evaluation/interaction-state-decision/validate.py >"$tmp/first.txt"
python3 evaluation/interaction-state-decision/validate.py >"$tmp/second.txt"
cmp "$tmp/first.txt" "$tmp/second.txt"
grep -Fx 'Interaction decision: typed checkpoint seeds derive canonical state; browser actions remain observations and must prove achieved postconditions' "$tmp/first.txt" >/dev/null
cat "$tmp/first.txt"
