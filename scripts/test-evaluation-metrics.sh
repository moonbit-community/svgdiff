#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
manifest="$root/evaluation/corpus/manifest.json"
tmp=${TMPDIR:-/tmp}/svgdiff-evaluation-metrics-$$
reports="$tmp/reports"
tasks="$tmp/tasks.jsonl"
evidence_answers="$tmp/evidence-answers.jsonl"
empty_answers="$tmp/empty-answers.jsonl"
wrong_magnitude_answers="$tmp/wrong-magnitude-answers.jsonl"
evidence_metrics="$tmp/evidence-metrics.json"
empty_metrics="$tmp/empty-metrics.json"
wrong_magnitude_metrics="$tmp/wrong-magnitude-metrics.json"
wrong_magnitude_gate="$tmp/wrong-magnitude-gate.json"
wrong_magnitude_failures="$tmp/wrong-magnitude-failures.json"
mkdir -p "$reports"
trap 'rm -rf "$tmp"' EXIT

cd "$root"
jq -c '.cases[]' "$manifest" | while IFS= read -r case_json; do
  id=$(printf '%s' "$case_json" | jq -r '.id')
  before=$(printf '%s' "$case_json" | jq -r '.before')
  after=$(printf '%s' "$case_json" | jq -r '.after')
  width=$(printf '%s' "$case_json" | jq -r '.viewport.width')
  height=$(printf '%s' "$case_json" | jq -r '.viewport.height')
  moon run --target native modules/svgdiff/cmd/svgdiff -- \
    "$root/evaluation/corpus/$before" \
    "$root/evaluation/corpus/$after" \
    --width "$width" --height "$height" >"$reports/$id.json"
done

python3 evaluation/harness/harness.py prepare --reports "$reports" --output "$tasks"
python3 evaluation/harness/harness.py run \
  --tasks "$tasks" \
  --output "$evidence_answers" \
  --agent "python3 evaluation/harness/evidence_test_agent.py"
python3 evaluation/harness/harness.py run \
  --tasks "$tasks" \
  --output "$empty_answers" \
  --agent "python3 evaluation/harness/report_only_test_agent.py"

jq -s -e '
  any(.[] | select(.case_id == "subtle-geometry-shift");
    any(.differences[].magnitude_claims[];
      .field == "magnitude.parameter_abs_css_px" and
      .status == "measured" and
      .unit == "css_px")) and
  any(.[] | select(.case_id == "structural-rect-insertion");
    any(.differences[].magnitude_claims[];
      .field == "magnitude.presence.affected_entity_count" and
      .status == "measured" and
      .value == 1 and
      .unit == "entities")) and
  any(.[] | select(.case_id == "group-transform-change");
    any(.differences[].magnitude_claims[];
      .field == "magnitude.transform.norm_css_px" and
      .status == "measured" and
      .value == 4 and
      .unit == "css_px")) and
  any(.[] | select(.case_id == "embedded-raster-change");
    any(.differences[].magnitude_claims[];
      .field == "magnitude.intrinsic_raster.changed_fraction" and
      .status == "measured" and
      .value == 1 and
      .unit == "pixel_fraction"))
' "$evidence_answers" >/dev/null

jq -c '
  if .case_id == "subtle-geometry-shift" then
    .differences[0].magnitude_claims[0].value = 123456
  else
    .
  end
' "$evidence_answers" >"$wrong_magnitude_answers"

python3 evaluation/harness/score.py \
  --tasks "$tasks" --answers "$evidence_answers" --output "$evidence_metrics"
python3 evaluation/harness/score.py \
  --tasks "$tasks" --answers "$empty_answers" --output "$empty_metrics"
python3 evaluation/harness/score.py \
  --tasks "$tasks" \
  --answers "$wrong_magnitude_answers" \
  --output "$wrong_magnitude_metrics"

jq -e '
  .metrics_version == "svgdiff-evaluation-metrics/1" and
  .case_count == 13 and
  .aggregate.agent_coverage_status_accuracy_macro == 1 and
  .aggregate.agent_equality_conclusion_accuracy_macro == 1 and
  .aggregate.agent_required_diagnostic_recall_macro == 1 and
  .aggregate.agent_hard_safety_failure_count == 0 and
  .aggregate.agent_atomic_difference_recall_macro == 1 and
  .aggregate.agent_magnitude_claim_recall_macro == 1 and
  .aggregate.agent_main_difference_mrr == 1 and
  .aggregate.report_region_overlap_macro == 1 and
  .aggregate.agent_region_overlap_macro == 1 and
  .aggregate.report_cause_envelope_recall_macro == 1 and
  .aggregate.agent_possible_cause_recall_macro == 1 and
  .aggregate.report_cause_candidate_count_total == 12 and
  .aggregate.report_cause_candidate_occurrence_count_total == 15 and
  .aggregate.report_cause_region_count_total == 8 and
  .aggregate.report_cause_candidates_per_region_macro == 1.7142857142857142 and
  .aggregate.report_cause_false_positive_count == 2 and
  .aggregate.report_cause_false_positive_fraction_macro == 0.16666666666666666 and
  .aggregate.agent_cause_false_positive_count == 2 and
  .aggregate.invalid_magnitude_claim_count == 0 and
  .aggregate.invalid_evidence_reference_count == 0
' "$evidence_metrics" >/dev/null

jq -e '
  .aggregate.agent_hard_safety_failure_count == 0 and
  .aggregate.agent_atomic_difference_recall_macro < 1 and
  .aggregate.agent_magnitude_claim_recall_macro < 1 and
  .aggregate.agent_main_difference_mrr == 0 and
  .aggregate.agent_region_overlap_macro == 0 and
  .aggregate.agent_possible_cause_recall_macro == 0 and
  .aggregate.report_cause_envelope_recall_macro == 1 and
  .aggregate.report_cause_candidate_count_total == 12 and
  .aggregate.report_cause_candidate_occurrence_count_total == 15 and
  .aggregate.report_cause_region_count_total == 8 and
  .aggregate.report_cause_false_positive_fraction_macro == 0.16666666666666666
' "$empty_metrics" >/dev/null

jq -e --slurpfile evidence "$evidence_metrics" '
  .aggregate.agent_atomic_difference_recall_macro == 1 and
  .aggregate.agent_magnitude_claim_recall_macro < 1 and
  .aggregate.invalid_magnitude_claim_count == 1 and
  .aggregate.report_region_overlap_macro ==
    $evidence[0].aggregate.report_region_overlap_macro and
  .aggregate.report_cause_envelope_recall_macro ==
    $evidence[0].aggregate.report_cause_envelope_recall_macro
' "$wrong_magnitude_metrics" >/dev/null

if python3 evaluation/harness/check_thresholds.py \
  --metrics "$wrong_magnitude_metrics" \
  --thresholds evaluation/benchmark-thresholds.v1.json \
  --output "$wrong_magnitude_gate" >/dev/null 2>&1; then
  printf 'Benchmark unexpectedly accepted an altered magnitude claim\n' >&2
  exit 1
fi
python3 evaluation/harness/classify_failures.py \
  --tasks "$tasks" \
  --gate "$wrong_magnitude_gate" \
  --output "$wrong_magnitude_failures"
jq -e '
  .gate_passed == false and
  .summary.threshold_failures_by_domain.agent_interpretation == 2 and
  .summary.threshold_failures_by_domain.report_model == 0 and
  .summary.has_unclassified == false and
  any(.threshold_failures[];
    .metric == "agent_magnitude_claim_recall_macro") and
  any(.threshold_failures[];
    .metric == "invalid_magnitude_claim_count")
' "$wrong_magnitude_failures" >/dev/null

printf 'Evaluation metrics: four answer dimensions scored, altered magnitude rejected\n'
