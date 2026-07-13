#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/svgdiff-cli-$$
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

cd "$root"
moon run --target native cmd/main -- testdata/before.svg testdata/after.svg >"$tmp/report.json"
jq -e '.schema_version == "1.0" and .analysis_status == "complete" and (.atomic_differences | length) == 1' "$tmp/report.json" >/dev/null

moon run --target native cmd/main -- testdata/before.svg testdata/after.svg --width 32 --height 24 --output "$tmp/output.json" --html "$tmp/report.html"
jq -e '.profile.viewport_width == 32 and .profile.viewport_height == 24' "$tmp/output.json" >/dev/null
grep -q '<!doctype html>' "$tmp/report.html"
grep -q 'sandbox=""' "$tmp/report.html"
grep -q 'id="report-data"' "$tmp/report.html"
jq empty schema/svgdiff-report.schema.json

if moon run --target native cmd/main -- >/dev/null 2>&1; then
  echo "CLI unexpectedly accepted missing arguments" >&2
  exit 1
fi

if moon run --target native cmd/main -- "$tmp/missing.svg" testdata/after.svg >/dev/null 2>&1; then
  echo "CLI unexpectedly accepted an unreadable input" >&2
  exit 1
fi

printf '%s\n' '<svg><rect></svg>' >"$tmp/malformed.svg"
if moon run --target native cmd/main -- "$tmp/malformed.svg" testdata/after.svg >"$tmp/failed.json"; then
  echo "CLI unexpectedly returned success for failed analysis" >&2
  exit 1
fi
jq -e '.analysis_status == "failed" and (.diagnostics | length) > 0' "$tmp/failed.json" >/dev/null
