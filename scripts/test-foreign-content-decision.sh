#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/svgdiff-foreign-content-decision-$$
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

cd "$root"
python3 evaluation/foreign-content-decision/validate.py >"$tmp/first.txt"
python3 evaluation/foreign-content-decision/validate.py >"$tmp/second.txt"
cmp "$tmp/first.txt" "$tmp/second.txt"
grep -Fx 'Foreign content decision: general canonical XHTML requires a deterministic host-language engine; closed evaluators remain bounded subsets' "$tmp/first.txt" >/dev/null
cat "$tmp/first.txt"
