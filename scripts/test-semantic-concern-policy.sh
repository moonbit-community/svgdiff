#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/svgdiff-semantic-concern-$$
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

cd "$root"
moon build --target native --release cmd/svgdiff >/dev/null
cli="$root/_build/native/release/build/Milky2018/svgdiff/cmd/svgdiff/svgdiff.exe"
python3 evaluation/semantic-concern/evaluate.py --cli "$cli" >"$tmp/first.txt"
python3 evaluation/semantic-concern/evaluate.py --cli "$cli" >"$tmp/second.txt"
cmp "$tmp/first.txt" "$tmp/second.txt"
grep -Fx 'Semantic concern policy: dominated 1-pixel target preserved in full and Agent inventories; semantic priority remains query-conditioned' "$tmp/first.txt" >/dev/null

jq -e '
  .schema_version == "svgdiff-semantic-concern-results/1" and
  .report_schema_version == "1.45" and
  .impact_policy_id == "event_rendered_pareto/v1" and
  .analysis_status == "complete" and
  .caller_concern_source == "external_evaluation_query" and
  .engine_inferred_semantic_importance == false and
  .target_measurements.changed_pixels == 1 and
  .target_measurements.changed_pixel_fraction == (1 / 256) and
  .target_frontier_member == false and
  .domination_witness.dominated_event_id == .target_event_id and
  .dominant_event_measurements.changed_pixels == 64 and
  .full_inventory_event_count == 2 and
  .full_inventory_atomic_difference_count == 2 and
  (.target_evidence.atomic_difference_ids | length) == 1 and
  (.target_evidence.changed_fact_ids | length) == 1 and
  .target_evidence.cause_candidate_changed_fact_ids == .target_evidence.changed_fact_ids and
  .agent_transport_preserved_target == true and
  .decision.context_free_main_change_policy == "retained" and
  .decision.query_matching_dominated_event == "must_be_reported" and
  .decision.missing_query_context_semantic_importance == "unknown" and
  .decision.source_derived_semantic_priority == "rejected" and
  .decision.threshold_suppression_of_small_events == "rejected" and
  .decision.production_concern_fields == "not_added"
' evaluation/semantic-concern/results.v1.json >/dev/null

cat "$tmp/first.txt"
