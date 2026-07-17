#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/svgdiff-font-bundle-contract-$$
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

cd "$root"
python3 evaluation/font-bundle-contract/validate.py >"$tmp/first.txt"
python3 evaluation/font-bundle-contract/validate.py >"$tmp/second.txt"
cmp "$tmp/first.txt" "$tmp/second.txt"
grep -Fx 'Font bundle contract: 3 valid identities, 16 invalid manifests rejected; legal metadata separated from rendering identity' "$tmp/first.txt" >/dev/null

if rg -n 'font[_-](bundle|resource)' moon.mod moon.pkg engine schema cmd .github >/dev/null; then
  printf 'The font-bundle decision leaked into product code, report schema, or default CI\n' >&2
  exit 1
fi

cat "$tmp/first.txt"
