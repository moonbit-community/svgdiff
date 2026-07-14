#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/svgdiff-cli-$$
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

cd "$root"
moon run --target native cmd/svgdiff -- testdata/before.svg testdata/after.svg >"$tmp/report.json" 2>"$tmp/report.err"
test ! -s "$tmp/report.err"
jq -e '.schema_version == "1.0" and .analysis_status == "complete" and (.atomic_differences | length) == 1' "$tmp/report.json" >/dev/null

moon run --target native cmd/svgdiff -- testdata/before.svg testdata/after.svg --width 32 --height 24 --output "$tmp/output.json" --html "$tmp/report.html" >"$tmp/output.stdout" 2>"$tmp/output.err"
test ! -s "$tmp/output.stdout"
test ! -s "$tmp/output.err"
jq -e '.profile.viewport_width == 32 and .profile.viewport_height == 24 and .profile.comparison_dpr == 1 and .profile.color_interpretation == "srgb" and .profile.raster_representation == "linear_srgb_premultiplied_rgba_f64" and (.events[0].rendered_outcome.magnitude.linear_premultiplied_rgba_rmse > 0)' "$tmp/output.json" >/dev/null
grep -q '<!doctype html>' "$tmp/report.html"
grep -q 'sandbox=""' "$tmp/report.html"
grep -q 'id="report-data"' "$tmp/report.html"
jq empty schema/svgdiff-report.schema.json

cat testdata/before.svg | moon run --target native cmd/svgdiff -- - testdata/after.svg >"$tmp/stdin-before.json" 2>"$tmp/stdin-before.err"
test ! -s "$tmp/stdin-before.err"
jq -e '.schema_version == "1.0" and .analysis_status == "complete"' "$tmp/stdin-before.json" >/dev/null

cat testdata/after.svg | moon run --target native cmd/svgdiff -- testdata/before.svg - >"$tmp/stdin-after.json" 2>"$tmp/stdin-after.err"
test ! -s "$tmp/stdin-after.err"
jq -e '.schema_version == "1.0" and .analysis_status == "complete"' "$tmp/stdin-after.json" >/dev/null

moon run --target native cmd/svgdiff -- --help >"$tmp/help.txt"
grep -q '^Usage: svgdiff ' "$tmp/help.txt"
grep -q -- '--version' "$tmp/help.txt"
grep -q 'Invalid arguments or file I/O failure' "$tmp/help.txt"

moon run --target native cmd/svgdiff -- --version >"$tmp/version.txt"
grep -q '^svgdiff 0.1.0$' "$tmp/version.txt"
grep -q '^engine: 0.1.0$' "$tmp/version.txt"
grep -q '^schema: 1.0$' "$tmp/version.txt"
grep -q '^renderer: mizchi/svg@0.2.1$' "$tmp/version.txt"
grep -q '^ordering-policy: v1_domain_lexicographic$' "$tmp/version.txt"

if moon run --target native cmd/svgdiff -- >"$tmp/missing-args.out" 2>"$tmp/missing-args.err"; then
  echo "CLI unexpectedly accepted missing arguments" >&2
  exit 1
fi
test ! -s "$tmp/missing-args.out"
grep -q '^Usage: svgdiff ' "$tmp/missing-args.err"

if moon run --target native cmd/svgdiff -- "$tmp/missing.svg" testdata/after.svg >"$tmp/missing-file.out" 2>"$tmp/missing-file.err"; then
  echo "CLI unexpectedly accepted an unreadable input" >&2
  exit 1
fi
test ! -s "$tmp/missing-file.out"
grep -q '^Failed to read ' "$tmp/missing-file.err"

if printf '%s\n' '<svg/>' | moon run --target native cmd/svgdiff -- - - >"$tmp/double-stdin.out" 2>"$tmp/double-stdin.err"; then
  echo "CLI unexpectedly accepted two stdin operands" >&2
  exit 1
fi
test ! -s "$tmp/double-stdin.out"
grep -q '^Only one SVG input may use stdin (-)$' "$tmp/double-stdin.err"

printf '%s\n' '<svg><rect></svg>' >"$tmp/malformed.svg"
if moon run --target native cmd/svgdiff -- "$tmp/malformed.svg" testdata/after.svg >"$tmp/failed.json" 2>"$tmp/failed.err"; then
  echo "CLI unexpectedly returned success for failed analysis" >&2
  exit 1
fi
test ! -s "$tmp/failed.err"
jq -e '.analysis_status == "failed" and (.diagnostics | length) > 0' "$tmp/failed.json" >/dev/null
