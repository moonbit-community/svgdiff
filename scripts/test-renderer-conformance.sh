#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/svgdiff-renderer-conformance-test-$$
report="$tmp/report.json"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp"
cd "$root"
sh scripts/run-renderer-conformance.sh "$report"
python3 evaluation/renderer-conformance/validate_baseline.py --report "$report"
