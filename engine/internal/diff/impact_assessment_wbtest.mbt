///|
fn impact_test_event(
  id : String,
  difference_ids : Array[String],
  changed_pixel_fraction? : Double,
  linear_rmse? : Double,
) -> VisualEvent {
  let rendered_outcome = match (changed_pixel_fraction, linear_rmse) {
    (Some(changed_pixel_fraction), Some(linear_premultiplied_rgba_rmse)) =>
      computed_rendered_evidence({
        changed_pixels: 1,
        changed_pixel_fraction,
        rgba8_rmse: 0.0,
        linear_premultiplied_rgba_rmse,
      })
    _ => not_computed_rendered_evidence("rendered_evidence_unavailable")
  }
  {
    id,
    primary_subject_id: id,
    atomic_difference_ids: difference_ids,
    rendered_outcome,
    difference_regions: [],
  }
}

///|
test "Impact Assessment handles an empty event inventory explicitly" {
  let assessment = impact_assessment_for_events([])
  assert_eq(assessment.policy_id, "event_rendered_pareto/v1")
  assert_eq(assessment.status, "not_applicable")
  assert_eq(assessment.calibration_status, "not_calibrated")
  assert_eq(assessment.candidate_event_count, 0)
  assert_eq(assessment.frontier_relation, "not_applicable")
  assert_true(assessment.frontier_groups.is_empty())
  assert_true(assessment.domination_witnesses.is_empty())
}

///|
test "Impact Assessment keeps one Pareto winner and one domination witness" {
  let assessment = impact_assessment_for_events([
    impact_test_event(
      "event:small",
      ["diff:small"],
      changed_pixel_fraction=0.25,
      linear_rmse=0.1,
    ),
    impact_test_event(
      "event:large",
      ["diff:large:paint", "diff:large:resource"],
      changed_pixel_fraction=0.5,
      linear_rmse=0.2,
    ),
  ])
  assert_eq(assessment.status, "complete")
  assert_eq(assessment.candidate_event_count, 2)
  assert_eq(assessment.frontier_relation, "unique")
  guard assessment.frontier_groups is [group] else {
    fail("expected one frontier group")
  }
  assert_eq(group.event_ids, ["event:large"])
  assert_eq(group.atomic_difference_ids, [
    "diff:large:paint", "diff:large:resource",
  ])
  guard group.measurements is Some(measurements) else {
    fail("expected measured frontier vector")
  }
  assert_eq(measurements.changed_pixel_fraction, 0.5)
  assert_eq(measurements.linear_premultiplied_rgba_rmse, 0.2)
  guard assessment.domination_witnesses is [witness] else {
    fail("expected one domination witness")
  }
  assert_eq(witness.dominant_event_id, "event:large")
  assert_eq(witness.dominated_event_id, "event:small")
  assert_eq(witness.rule_id, "both_rendered_metrics_no_less_and_one_greater")
}

///|
test "Impact Assessment groups exact measured ties deterministically" {
  let assessment = impact_assessment_for_events([
    impact_test_event(
      "event:z",
      ["diff:z"],
      changed_pixel_fraction=0.5,
      linear_rmse=0.2,
    ),
    impact_test_event(
      "event:a",
      ["diff:a"],
      changed_pixel_fraction=0.5,
      linear_rmse=0.2,
    ),
  ])
  assert_eq(assessment.frontier_relation, "tied")
  guard assessment.frontier_groups is [group] else {
    fail("expected one tied frontier group")
  }
  assert_eq(group.event_ids, ["event:a", "event:z"])
  assert_eq(group.atomic_difference_ids, ["diff:a", "diff:z"])
  assert_true(assessment.domination_witnesses.is_empty())
}

///|
test "Impact Assessment preserves incomparable tradeoffs and mixed ties" {
  let assessment = impact_assessment_for_events([
    impact_test_event(
      "event:extent-a",
      ["diff:extent-a"],
      changed_pixel_fraction=0.6,
      linear_rmse=0.1,
    ),
    impact_test_event(
      "event:extent-b",
      ["diff:extent-b"],
      changed_pixel_fraction=0.6,
      linear_rmse=0.1,
    ),
    impact_test_event(
      "event:intensity",
      ["diff:intensity"],
      changed_pixel_fraction=0.2,
      linear_rmse=0.4,
    ),
  ])
  assert_eq(assessment.frontier_relation, "mixed")
  assert_eq(assessment.frontier_groups.length(), 2)
  assert_eq(assessment.frontier_groups[0].event_ids, [
    "event:extent-a", "event:extent-b",
  ])
  assert_eq(assessment.frontier_groups[1].event_ids, ["event:intensity"])
  assert_true(assessment.domination_witnesses.is_empty())
}

///|
test "Impact Assessment preserves a pure incomparable tradeoff" {
  let assessment = impact_assessment_for_events([
    impact_test_event(
      "event:extent",
      ["diff:extent"],
      changed_pixel_fraction=0.8,
      linear_rmse=0.1,
    ),
    impact_test_event(
      "event:intensity",
      ["diff:intensity"],
      changed_pixel_fraction=0.2,
      linear_rmse=0.5,
    ),
  ])
  assert_eq(assessment.frontier_relation, "incomparable")
  assert_eq(assessment.frontier_groups.length(), 2)
  assert_eq(assessment.frontier_groups[0].event_ids, ["event:extent"])
  assert_eq(assessment.frontier_groups[1].event_ids, ["event:intensity"])
  assert_true(assessment.domination_witnesses.is_empty())
}

///|
test "Impact Assessment selects the first deterministic dominator witness" {
  let assessment = impact_assessment_for_events([
    impact_test_event(
      "event:target",
      ["diff:target"],
      changed_pixel_fraction=0.1,
      linear_rmse=0.1,
    ),
    impact_test_event(
      "event:aa",
      ["diff:aa"],
      changed_pixel_fraction=0.9,
      linear_rmse=0.9,
    ),
    impact_test_event(
      "event:z",
      ["diff:z"],
      changed_pixel_fraction=0.8,
      linear_rmse=0.8,
    ),
  ])
  assert_eq(assessment.frontier_relation, "unique")
  assert_eq(assessment.frontier_groups[0].event_ids, ["event:aa"])
  assert_eq(assessment.domination_witnesses.length(), 2)
  assert_eq(assessment.domination_witnesses[0].dominant_event_id, "event:aa")
  assert_eq(assessment.domination_witnesses[0].dominated_event_id, "event:z")
  assert_eq(assessment.domination_witnesses[1].dominant_event_id, "event:z")
  assert_eq(
    assessment.domination_witnesses[1].dominated_event_id,
    "event:target",
  )
}

///|
test "Impact Assessment keeps missing rendered evidence incomparable" {
  let assessment = impact_assessment_for_events([
    impact_test_event("event:unknown", ["diff:unknown"]),
    impact_test_event(
      "event:visible",
      ["diff:visible"],
      changed_pixel_fraction=1.0,
      linear_rmse=1.0,
    ),
  ])
  assert_eq(assessment.status, "partial")
  assert_eq(assessment.frontier_relation, "incomparable")
  assert_eq(assessment.frontier_groups.length(), 2)
  assert_eq(assessment.frontier_groups[0].event_ids, ["event:unknown"])
  assert_true(assessment.frontier_groups[0].measurements is None)
  assert_eq(assessment.frontier_groups[1].event_ids, ["event:visible"])
  assert_true(assessment.frontier_groups[1].measurements is Some(_))
  assert_true(assessment.domination_witnesses.is_empty())
}
