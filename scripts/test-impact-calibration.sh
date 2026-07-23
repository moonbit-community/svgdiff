#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/svgdiff-impact-calibration-$$
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

cd "$root"
moon build --target native --release modules/svgdiff/cmd/svgdiff >/dev/null
cli="$root/_build/native/release/build/Milky2018/svgdiff/cmd/svgdiff/svgdiff.exe"
python3 evaluation/impact-calibration/validate.py --cli "$cli" >"$tmp/first.txt"
python3 evaluation/impact-calibration/validate.py --cli "$cli" >"$tmp/second.txt"
cmp "$tmp/first.txt" "$tmp/second.txt"
grep -Fx 'Impact calibration: 13 cases, 12 scorable, 0 multi-event ranked; production calibrated policy rejected' "$tmp/first.txt" >/dev/null
jq -e '
  .schema_version == "svgdiff-impact-calibration-results/1" and
  .decision.production_policy == "rejected" and
  .decision.retained_policy_id == "event_rendered_pareto/v1" and
  .evidence_summary.human_tier_case_counts == {none: 5, low: 1, medium: 4, high: 3} and
  .evidence_summary.human_tier_event_counts == {none: 4, low: 1, medium: 4, high: 3} and
  .evidence_summary.raw_rendered_measurement_case_count == 11 and
  .evidence_summary.flip_measurement_case_count == 11 and
  .evidence_summary.recorded_independent_agreement_comparisons == 0 and
  .evidence_summary.multi_event_scorable_case_count == 0 and
  .evidence_summary.frontier_relation_case_counts == {not_applicable: 1, unique: 12, tied: 0, incomparable: 0, mixed: 0} and
  .evidence_summary.partial_impact_case_count == 1 and
  .evidence_summary.missing_frontier_measurement_case_count == 1 and
  .uncalibrated_frontier_baseline.recall == 1 and
  (.candidates[] | select(.candidate_id == "changed_pixel_fraction_ordinal_cutpoints/v1") |
    .full_fit.measured_accuracy == 1 and
    .measured_tier_counts == {none: 4, low: 1, medium: 4, high: 2} and
    .leave_one_case_out.coverage == (10 / 12) and
    .leave_one_case_out.conditional_accuracy == 0.9 and
    .leave_one_case_out.overall_accuracy == 0.75 and
    .release_gate_results.independent_reviewer_agreement == false and
    .release_gate_results.minimum_measured_cases_per_tier == false and
    .release_gate_results.complete_policy_inputs == false) and
  (.candidates[] | select(.candidate_id == "linear_premultiplied_rgba_rmse_ordinal_cutpoints/v1") |
    .full_fit.status == "not_trainable") and
  (.candidates[] | select(.candidate_id == "flip_canvas_mean_ordinal_cutpoints/v1") |
    .full_fit.status == "not_trainable") and
  (.candidates[] | select(.kind == "total_event_order") |
    .evaluable_multi_event_case_count == 0 and
    .labeled_pair_count == 0 and
    .top_event_accuracy == null) and
  all(.candidates[]; .decision == "rejected")
' evaluation/impact-calibration/results.v1.json >/dev/null
cat "$tmp/first.txt"
