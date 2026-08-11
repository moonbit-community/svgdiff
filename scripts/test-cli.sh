#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/svgdiff-cli-$$
wasi_tmp=_build/svgdiff-wasm-cli-$$
mkdir -p "$tmp"
mkdir -p "$wasi_tmp"
trap 'rm -rf "$tmp" "$wasi_tmp"' EXIT

assert_status() {
  expected=$1
  shift
  set +e
  "$@"
  actual=$?
  set -e
  if [ "$actual" -ne "$expected" ]; then
    echo "Expected exit status $expected, got $actual: $*" >&2
    exit 1
  fi
}

cd "$root"

moon run --target native modules/svgdiff/cmd/svgdiff -- \
  testdata/before.svg testdata/after.svg \
  >"$tmp/report.json" 2>"$tmp/report.err"
test ! -s "$tmp/report.err"
jq -e '
  .schema_version == "2.0" and
  .analysis_status == "complete" and
  .comparison == {"viewport":{"width":16,"height":16}} and
  .canvas.status == "computed" and
  .canvas.changed_pixels > 0 and
  ([.difference_groups[].items[]] | length) == 1 and
  .difference_groups[0].category == "paint" and
  .difference_groups[0].items[0].effective.relation == "different" and
  .events[0].difference_ids == [.difference_groups[0].items[0].id] and
  .events[0].regions[0].kind == "conservative" and
  .limitations == [] and
  (has("profile") | not) and
  (has("coverage_matrix") | not) and
  (has("impact_assessment") | not) and
  (has("atomic_differences") | not)
' "$tmp/report.json" >/dev/null

moon run --target native modules/svgdiff/cmd/svgdiff -- \
  testdata/before.svg testdata/after.svg --agent-json \
  >"$tmp/agent.json" 2>"$tmp/agent.err"
test ! -s "$tmp/agent.err"
test "$(wc -l <"$tmp/agent.json" | tr -d ' ')" -eq 1
test "$(wc -c <"$tmp/agent.json")" -lt "$(wc -c <"$tmp/report.json")"
test "$(jq -S -c . "$tmp/agent.json")" = "$(jq -S -c . "$tmp/report.json")"

moon run --target native modules/svgdiff/cmd/svgdiff -- \
  testdata/before.svg testdata/after.svg \
  --perceptual-background '#336699' \
  >"$tmp/background.json" 2>"$tmp/background.err"
test ! -s "$tmp/background.err"
jq -e '
  .comparison.perceptual_background == {"red":51,"green":102,"blue":153} and
  .events[0].outcome.perceptual_color.sample_count > 0 and
  .events[0].outcome.perceptual_color.mean_delta_e_ok > 0 and
  (.events[0].outcome | has("perceptual_difference") | not)
' "$tmp/background.json" >/dev/null

moon run --target native modules/svgdiff/cmd/svgdiff -- \
  testdata/before.svg testdata/after.svg \
  --perceptual-background '#336699' \
  --flip-pixels-per-degree 20 --flip-error-threshold 0.05 \
  >"$tmp/flip.json" 2>"$tmp/flip.err"
test ! -s "$tmp/flip.err"
jq -e '
  .comparison.flip_pixels_per_degree == 20 and
  .comparison.flip_error_threshold == 0.05 and
  .canvas.perceptual_difference > 0 and
  .events[0].outcome.perceptual_difference.canvas_mean > 0 and
  .events[0].outcome.perceptual_difference.area_above_threshold.threshold == 0.05 and
  (.events[0].outcome.perceptual_difference | has("values_base64") | not)
' "$tmp/flip.json" >/dev/null

moon run --target native modules/svgdiff/cmd/svgdiff -- \
  testdata/before.svg testdata/after.svg --width 32 --height 24 \
  --output "$tmp/output.json" --html "$tmp/report.html" \
  --summary "$tmp/summary.md" >"$tmp/output.stdout" 2>"$tmp/output.err"
test ! -s "$tmp/output.stdout"
test ! -s "$tmp/output.err"
jq -e '
  .comparison.viewport == {"width":32,"height":24} and
  .events[0].outcome.linear_rgba_rmse > 0
' "$tmp/output.json" >/dev/null
grep -q '<!doctype html>' "$tmp/report.html"
grep -q 'sandbox=""' "$tmp/report.html"
grep -q 'id="report-data"' "$tmp/report.html"
grep -q '&quot;difference_groups&quot;' "$tmp/report.html"
! grep -q '&quot;coverage_matrix&quot;' "$tmp/report.html"
grep -q '^# SVG Diff Summary$' "$tmp/summary.md"
diff_id=$(jq -r '.difference_groups[0].items[0].id' "$tmp/output.json")
grep -F "$diff_id" "$tmp/summary.md" >/dev/null

cat testdata/before.svg | moon run --target native modules/svgdiff/cmd/svgdiff -- \
  - testdata/after.svg >"$tmp/stdin-before.json"
jq -e '.schema_version == "2.0" and .analysis_status == "complete"' \
  "$tmp/stdin-before.json" >/dev/null

printf '%s\n' \
  "<svg width='16' height='16'><rect id='box' width='8' height='8' fill='red' stroke='red' style='fill:blue;stroke:blue;unknown:value'/></svg>" \
  >"$tmp/limited.svg"
moon run --target native modules/svgdiff/cmd/svgdiff -- \
  "$tmp/limited.svg" "$tmp/limited.svg" --agent-json \
  >"$tmp/limited.json"
jq -e '
  .analysis_status == "partial" and
  any(.limitations[]; .code == "renderer_style_precedence_unresolved")
' "$tmp/limited.json" >/dev/null

moon run --target native modules/svgdiff/cmd/svgdiff -- --help >"$tmp/help.txt"
grep -q '^Usage: svgdiff ' "$tmp/help.txt"
grep -q -- '--agent-json' "$tmp/help.txt"
grep -q -- '--summary <summary>' "$tmp/help.txt"

moon run --target native modules/svgdiff/cmd/svgdiff -- --version >"$tmp/version.txt"
grep -q '^svgdiff 0.7.1$' "$tmp/version.txt"
grep -q '^schema: 2.0$' "$tmp/version.txt"

moon runwasm modules/svgdiff/cmd/svgdiff \
  testdata/before.svg testdata/after.svg \
  --output "$wasi_tmp/report.json" \
  --html "$wasi_tmp/report.html" \
  --summary "$wasi_tmp/summary.md"
test "$(jq -S -c . "$wasi_tmp/report.json")" = \
  "$(jq -S -c . "$tmp/report.json")"
grep -q '<!doctype html>' "$wasi_tmp/report.html"
grep -q '^# SVG Diff Summary$' "$wasi_tmp/summary.md"

moon runwasm modules/svgdiff/cmd/svgdiff \
  testdata/before.svg testdata/after.svg \
  --agent-projection --output "$wasi_tmp/report.jsonl"
grep -q 'svgdiff-agent-projection/1' "$wasi_tmp/report.jsonl"

python3 -c \
  'import base64, pathlib, sys; pathlib.Path(sys.argv[1]).write_bytes(base64.b64decode(sys.argv[2]))' \
  "$wasi_tmp/red.png" \
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg=='
printf '%s\n' \
  "<svg width='16' height='16'><image href='asset.png' width='8' height='8'/></svg>" \
  >"$wasi_tmp/resource.svg"
resource_json=$(printf \
  '{"locator":"asset.png","media_type":"image/png","path":"%s"}' \
  "$wasi_tmp/red.png")
moon runwasm modules/svgdiff/cmd/svgdiff \
  "$wasi_tmp/resource.svg" "$wasi_tmp/resource.svg" \
  --before-resource "$resource_json" \
  --after-resource "$resource_json" \
  --agent-json >"$wasi_tmp/resource-report.json"
jq -e '
  all(.limitations[]; .code != "resource_bundle_entry_missing")
' "$wasi_tmp/resource-report.json" >/dev/null

assert_status 1 moon run --target native modules/svgdiff/cmd/svgdiff -- \
  testdata/before.svg testdata/after.svg --max-checkpoints 1 \
  >"$tmp/native-budget.out" 2>"$tmp/native-budget.err"
grep -q 'checkpoint budget 1 exhausted' "$tmp/native-budget.err"

assert_status 1 moon runwasm modules/svgdiff/cmd/svgdiff \
  testdata/before.svg testdata/after.svg --max-checkpoints 1 \
  >"$tmp/wasm-budget.out" 2>"$tmp/wasm-budget.err"
grep -q 'checkpoint budget 1 exhausted' "$tmp/wasm-budget.err"

assert_status 2 moon run --target native modules/svgdiff/cmd/svgdiff -- \
  >"$tmp/missing-args.out" 2>"$tmp/missing-args.err"
test ! -s "$tmp/missing-args.out"
grep -q '^Usage: svgdiff ' "$tmp/missing-args.err"

assert_status 2 moon run --target native modules/svgdiff/cmd/svgdiff -- \
  "$tmp/missing.svg" testdata/after.svg \
  >"$tmp/missing-native.out" 2>"$tmp/missing-native.err"
test ! -s "$tmp/missing-native.out"
grep -q "^Failed to read $tmp/missing.svg:" "$tmp/missing-native.err"

assert_status 2 moon runwasm modules/svgdiff/cmd/svgdiff \
  "$wasi_tmp/missing.svg" testdata/after.svg \
  >"$tmp/missing-wasm.out" 2>"$tmp/missing-wasm.err"
test ! -s "$tmp/missing-wasm.out"
grep -q "^Failed to read $wasi_tmp/missing.svg:" "$tmp/missing-wasm.err"

assert_status 2 moon run --target native modules/svgdiff/cmd/svgdiff -- \
  testdata/before.svg testdata/after.svg \
  --perceptual-background transparent \
  >"$tmp/invalid-background.out" 2>"$tmp/invalid-background.err"
test ! -s "$tmp/invalid-background.out"

assert_status 1 moon run --target native modules/svgdiff/cmd/svgdiff -- \
  testdata/before.svg testdata/after.svg --width 8193 --agent-json \
  >"$tmp/resource-failed.json" 2>"$tmp/resource-failed.err"
test ! -s "$tmp/resource-failed.err"
jq -e '
  .schema_version == "2.0" and
  .analysis_status == "failed" and
  .difference_groups == [] and
  .events == [] and
  .limitations == [{
    "id":"diagnostic:resource-limit-exceeded:raster_dimensions",
    "code":"resource_limit_exceeded",
    "subject":"raster_dimensions",
    "affects":["source_semantics","computed_appearance","rendered_evidence"]
  }]
' "$tmp/resource-failed.json" >/dev/null

printf '%s\n' '<svg><rect></svg>' >"$tmp/malformed.svg"
assert_status 1 moon run --target native modules/svgdiff/cmd/svgdiff -- \
  "$tmp/malformed.svg" testdata/after.svg \
  >"$tmp/failed.json" 2>"$tmp/failed.err"
test ! -s "$tmp/failed.err"
jq -e '
  .analysis_status == "failed" and
  .difference_groups == [] and
  .events == [] and
  .limitations[0].code == "svg_parse_failed"
' "$tmp/failed.json" >/dev/null
