///|
fn viewport_differences(report : StructuredReport) -> Array[AtomicDifference] {
  [
    for difference in report.atomic_differences if difference.domain ==
    "document.viewport" => difference
  ]
}

///|
test "root viewBox change reports its source cause and cumulative scale" {
  let before = "<svg width='16' height='16' viewBox='0 0 16 16'><rect id='box' width='4' height='4'/></svg>"
  let after = "<svg width='16' height='16' viewBox='0 0 8 8'><rect id='box' width='4' height='4'/></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "complete")
  let viewport = viewport_differences(report)
  assert_eq(viewport.length(), 1)
  assert_eq(viewport[0].computed_relation.status, "different")
  assert_eq(viewport[0].source_before, "0,0,16,16")
  assert_eq(viewport[0].source_after, "0,0,8,8")
  assert_true(
    viewport[0].source_fact_before.unwrap().source_span.start_offset > 0,
  )
  let cumulative = transform_effect_difference(
    report, "geometry.transform.cumulative_matrix",
  )
  assert_eq(cumulative.source_before, "matrix(1,0,0,1,0,0)")
  assert_eq(cumulative.source_after, "matrix(2,0,0,2,0,0)")
  assert_eq(cumulative.changed_fact_ids, viewport[0].changed_fact_ids)
  match
    transform_effect_difference(report, "geometry.transform.scale").magnitude.transform_effect {
    Some(ScaleEffect(value)) => {
      assert_eq(value.before_x, 1.0)
      assert_eq(value.after_x, 2.0)
      assert_eq(value.max_abs_delta, 1.0)
    }
    _ => fail("expected viewport-induced scale effect")
  }
}

///|
test "root intrinsic size changes remain source-visible under one explicit viewport" {
  let before = "<svg width='16' height='16'><rect id='box' width='4' height='4'/></svg>"
  let after = "<svg width='32' height='16'><rect id='box' width='4' height='4'/></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  let viewport = viewport_differences(report)
  assert_eq(report.analysis_status, "complete")
  assert_eq(viewport.length(), 1)
  assert_eq(viewport[0].source_fact_before.unwrap().property, "width")
  assert_eq(viewport[0].computed_relation.status, "equivalent")
  assert_true(
    report.atomic_differences.all(difference => {
      difference.domain != "geometry.transform.cumulative_matrix"
    }),
  )
  assert_eq(
    report.events.last().unwrap().rendered_outcome.magnitude.unwrap().changed_pixels,
    0,
  )
}

///|
test "preserveAspectRatio remains computed-equivalent without viewBox" {
  let before = "<svg width='16' height='16'><rect id='box' width='4' height='4'/></svg>"
  let after = "<svg width='16' height='16' preserveAspectRatio='none'><rect id='box' width='4' height='4'/></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  let viewport = viewport_differences(report)
  assert_eq(report.analysis_status, "complete")
  assert_eq(viewport.length(), 1)
  assert_eq(viewport[0].computed_relation.status, "equivalent")
  assert_true(
    report.atomic_differences.all(difference => {
      difference.domain != "geometry.transform.cumulative_matrix"
    }),
  )
}

///|
test "nested viewport mapping interleaves with generic transforms" {
  let source = "<svg width='16' height='16'><g transform='translate(1 2)'><svg x='3' y='4' width='8' height='6' viewBox='0 0 4 3' transform='scale(2)'><rect id='box' width='1' height='1'/></svg></g></svg>"
  let subject = extract_source_subjects_with_profile_or_raise(
      source,
      ComparisonProfile::v1_default(),
    )[0]
  assert_eq(subject.cumulative_transform.signature(), "matrix(4,0,0,4,7,10)")
}

///|
test "nested percentage lengths use the nearest viewport user dimensions" {
  let source = "<svg width='16' height='16' viewBox='0 0 8 8'><svg x='25%' y='25%' width='50%' height='50%' viewBox='0 0 2 2'><rect id='box' width='1' height='1'/></svg></svg>"
  let subject = extract_source_subjects_with_profile_or_raise(
      source,
      ComparisonProfile::v1_default(),
    )[0]
  assert_eq(subject.cumulative_transform.signature(), "matrix(4,0,0,4,4,4)")
}

///|
test "viewport and transform causes fan out to every affected leaf" {
  let before = "<svg width='16' height='16' viewBox='0 0 16 16'><g transform='translate(1 0)'><rect id='a' width='2' height='2'/><rect id='b' x='4' width='2' height='2'/></g></svg>"
  let after = "<svg width='16' height='16' viewBox='0 0 8 8'><g transform='translate(3 0)'><rect id='a' width='2' height='2'/><rect id='b' x='4' width='2' height='2'/></g></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "complete")
  let viewport_fact_id = viewport_differences(report)[0].changed_fact_ids[0]
  let transform_fact_id = transform_effect_difference(
      report, "geometry.transform.list",
    ).changed_fact_ids[0]
  let cumulative = [
    for difference in report.atomic_differences if difference.domain ==
    "geometry.transform.cumulative_matrix" => difference
  ]
  assert_eq(cumulative.length(), 2)
  for difference in cumulative {
    assert_true(difference.changed_fact_ids.contains(viewport_fact_id))
    assert_true(difference.changed_fact_ids.contains(transform_fact_id))
  }
  let viewport_facts = [
    for fact in report.changed_facts if fact.id == viewport_fact_id => fact
  ]
  assert_eq(viewport_facts.length(), 1)
  assert_eq(viewport_facts[0].affected_subject_ids, ["a", "b"])
}

///|
test "invalid and nonconformant viewport mappings retain distinct guards" {
  let invalid = compare(
    "<svg viewBox='0 0 0 8'><rect id='box' width='4' height='4'/></svg>",
    "<svg viewBox='0 0 0 8'><rect id='box' width='4' height='4'/></svg>",
    ComparisonProfile::v1_default(),
  )
  assert_eq(invalid.analysis_status, "partial")
  assert_true(
    invalid.diagnostics.any(diagnostic => {
      diagnostic.code == "viewport_semantics_unsupported" &&
      !diagnostic.source_locations.is_empty()
    }),
  )
  let guarded = compare(
    "<svg viewBox='0 0 10 10'><rect id='box' width='4' height='4'/></svg>",
    "<svg viewBox='0 0 10 10'><rect id='box' width='4' height='4'/></svg>",
    ComparisonProfile::v1_default(),
  )
  assert_eq(guarded.analysis_status, "partial")
  assert_true(
    guarded.diagnostics.any(diagnostic => {
      diagnostic.code == "renderer_viewport_raster_unproven" &&
      diagnostic.affected_evidence_layers == ["rendered_evidence"]
    }),
  )
}
