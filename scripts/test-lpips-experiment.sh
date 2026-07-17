#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/svgdiff-lpips-experiment-$$
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

cd "$root"
python3 evaluation/lpips-experiment/evaluate.py >"$tmp/first.txt"
python3 evaluation/lpips-experiment/evaluate.py >"$tmp/second.txt"
cmp "$tmp/first.txt" "$tmp/second.txt"
grep -Fx 'LPIPS experiment: 13 cases x 4 profiles, renderer-gap false identity retained, profile sensitivity measured; production integration rejected' "$tmp/first.txt" >/dev/null

jq -e '
  .schema_version == "svgdiff-lpips-experiment-results/1" and
  .canonical_report_evidence == false and
  .accepted_role == "optional_offline_learned_perceptual_experiment" and
  .production_integration == "rejected" and
  .summary.case_count == 13 and
  .summary.profile_count == 4 and
  .summary.maximum_symmetry_absolute_gap <= 1e-12 and
  .summary.scale_sensitivity.absolute_delta_maximum > 0 and
  .summary.background_sensitivity.absolute_delta_maximum > 0 and
  all(.summary.ordering_by_profile[];
    .inverted_pair_count + .tied_pair_count > 0) and
  all(.summary.human_non_none_zero_distance_case_ids_by_profile[];
    index("embedded-raster-change") != null) and
  (.cases[] | select(.case_id == "equivalent-color-spelling") |
    all(.observations[];
      .displayed_srgb8_equal == true and .forward_distance == 0 and
      .identity_distance == 0 and .repeat_bit_identical == true)) and
  (.cases[] | select(.case_id == "embedded-raster-change") |
    .human_tier == "high" and
    .production_renderer_capability_gaps[0].capability_id ==
      "raster.embedded_images" and
    all(.observations[];
      .raw_rgba8_equal == true and .forward_distance == 0))
' evaluation/lpips-experiment/results.v1.json >/dev/null

if rg -n 'lpips' moon.mod moon.pkg engine schema cmd .github >/dev/null; then
  printf 'LPIPS leaked into the module, product engine, schema, CLI, or default CI\n' >&2
  exit 1
fi

cat "$tmp/first.txt"
