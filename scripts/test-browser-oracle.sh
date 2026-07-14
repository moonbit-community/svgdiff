#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/svgdiff-browser-oracle-test-$$
first="$tmp/first"
second="$tmp/second"
mkdir -p "$first" "$second"
trap 'rm -rf "$tmp"' EXIT

cd "$root"
sh scripts/run-browser-oracle.sh "$first"
sh scripts/run-browser-oracle.sh "$second"
python3 evaluation/browser-oracle/validate.py "$first"
python3 evaluation/browser-oracle/validate.py "$second"

first_hashes=$(find "$first" -name '*.png' -type f -print | sort | while IFS= read -r path; do shasum -a 256 "$path" | awk '{print $1}'; done)
second_hashes=$(find "$second" -name '*.png' -type f -print | sort | while IFS= read -r path; do shasum -a 256 "$path" | awk '{print $1}'; done)
test "$first_hashes" = "$second_hashes"
cmp "$first/oracle-report.json" "$second/oracle-report.json"

printf 'Browser oracle reproducibility: two runs identical\n'
