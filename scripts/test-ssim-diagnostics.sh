#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/svgdiff-ssim-diagnostics-$$
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

cd "$root"
moon build --target native --release modules/svgdiff/evaluation/ssim_adapter modules/svgdiff/cmd/svgdiff >/dev/null
adapter="$root/_build/native/release/build/Milky2018/svgdiff/evaluation/ssim_adapter/ssim_adapter.exe"
cli="$root/_build/native/release/build/Milky2018/svgdiff/cmd/svgdiff/svgdiff.exe"
python3 evaluation/ssim-diagnostics/evaluate.py \
  --adapter "$adapter" --cli "$cli" >"$tmp/first.txt"
python3 evaluation/ssim-diagnostics/evaluate.py \
  --adapter "$adapter" --cli "$cli" >"$tmp/second.txt"
cmp "$tmp/first.txt" "$tmp/second.txt"
grep -Fx 'SSIM diagnostics: 13 cases, 2 non-none false identity, 1 MS-SSIM unavailable; production integration rejected' "$tmp/first.txt" >/dev/null

jq -e '
  .schema_version == "svgdiff-ssim-diagnostic-results/1" and
  .canonical_report_evidence == false and
  .annotation_review_status == "initial_single_pass" and
  .accepted_role == "qa_only_secondary_structural_observation" and
  .production_integration == "rejected" and
  .summary.case_count == 13 and
  .summary.human_non_none_false_exact_case_ids == ["subtle-geometry-shift", "embedded-raster-change"] and
  .summary.ms_ssim_unavailable_case_ids == ["unsupported-path-change"] and
  .summary.ssim_scale_absolute_delta_maximum > 0.8 and
  .summary.canonical_ssim_ordering.inverted_pair_count > 0 and
  .summary.enlarged_ssim_ordering.inverted_pair_count > 0 and
  .summary.ms_ssim_ordering.inverted_pair_count > 0 and
  (.cases[] | select(.case_id == "equivalent-color-spelling") |
    .canonical_exact_rgba8 == true and .canonical_ssim == 1 and
    .enlarged_exact_rgba8 == true and .ms_ssim == 1) and
  (.cases[] | select(.case_id == "embedded-raster-change") |
    .human_tier == "high" and .canonical_exact_rgba8 == true and
    any(.production_limitations[]; .code == "renderer_embedded_raster_unavailable")) and
  (.cases[] | select(.case_id == "unsupported-path-change") |
    .ms_ssim == null and .ms_ssim_reason_code != null)
' evaluation/ssim-diagnostics/results.v1.json >/dev/null

moon run --target native modules/svgdiff/cmd/svgdiff -- \
  testdata/before.svg testdata/after.svg --agent-json >"$tmp/report.json"
jq -e '
  .schema_version == "2.0" and
  ([paths | map(tostring) | join(".") |
    select(test("(^|\\.)(ssim|ms_ssim)($|\\.)"))] | length) == 0
' "$tmp/report.json" >/dev/null

cat "$tmp/first.txt"
