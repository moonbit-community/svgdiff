#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
manifest="$root/evaluation/corpus/manifest.json"
tmp=${TMPDIR:-/tmp}/svgdiff-evaluation-metrics-$$
reports="$tmp/reports"
tasks="$tmp/tasks.jsonl"
evidence_answers="$tmp/evidence-answers.jsonl"
empty_answers="$tmp/empty-answers.jsonl"
evidence_metrics="$tmp/evidence-metrics.json"
empty_metrics="$tmp/empty-metrics.json"
mkdir -p "$reports"
trap 'rm -rf "$tmp"' EXIT

cd "$root"
jq -c '.cases[]' "$manifest" | while IFS= read -r case_json; do
  id=$(printf '%s' "$case_json" | jq -r '.id')
  before=$(printf '%s' "$case_json" | jq -r '.before')
  after=$(printf '%s' "$case_json" | jq -r '.after')
  width=$(printf '%s' "$case_json" | jq -r '.viewport.width')
  height=$(printf '%s' "$case_json" | jq -r '.viewport.height')
  moon run --target native cmd/svgdiff -- \
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

python3 evaluation/harness/score.py \
  --tasks "$tasks" --answers "$evidence_answers" --output "$evidence_metrics"
python3 evaluation/harness/score.py \
  --tasks "$tasks" --answers "$empty_answers" --output "$empty_metrics"

jq -e '
  .metrics_version == "svgdiff-evaluation-metrics/1" and
  .case_count == 9 and
  .aggregate.agent_coverage_status_accuracy_macro == 1 and
  .aggregate.agent_equality_conclusion_accuracy_macro == 1 and
  .aggregate.agent_required_diagnostic_recall_macro == 1 and
  .aggregate.agent_hard_safety_failure_count == 0 and
  .aggregate.agent_atomic_difference_recall_macro == 1 and
  .aggregate.agent_main_difference_mrr == 1 and
  .aggregate.report_region_overlap_macro == 1 and
  .aggregate.agent_region_overlap_macro == 1 and
  .aggregate.report_cause_envelope_recall_macro == 1 and
  .aggregate.agent_possible_cause_recall_macro == 1 and
  .aggregate.report_cause_candidate_count_total == 9 and
  .aggregate.report_cause_candidate_occurrence_count_total == 17 and
  .aggregate.report_cause_region_count_total == 12 and
  .aggregate.report_cause_candidates_per_region_macro == 1.2857142857142858 and
  .aggregate.report_cause_false_positive_count == 0 and
  .aggregate.report_cause_false_positive_fraction_macro == 0 and
  .aggregate.agent_cause_false_positive_count == 0 and
  .aggregate.invalid_evidence_reference_count == 0
' "$evidence_metrics" >/dev/null

jq -e '
  .aggregate.agent_hard_safety_failure_count == 0 and
  .aggregate.agent_atomic_difference_recall_macro < 1 and
  .aggregate.agent_main_difference_mrr == 0 and
  .aggregate.agent_region_overlap_macro == 0 and
  .aggregate.agent_possible_cause_recall_macro == 0 and
  .aggregate.report_cause_envelope_recall_macro == 1 and
  .aggregate.report_cause_candidate_count_total == 9 and
  .aggregate.report_cause_candidate_occurrence_count_total == 17 and
  .aggregate.report_cause_region_count_total == 12 and
  .aggregate.report_cause_false_positive_fraction_macro == 0
' "$empty_metrics" >/dev/null

printf 'Evaluation metrics: report and agent layers separated, evidence baseline: ok, empty baseline: lower\n'
