///|
fn structural_difference(
  report : StructuredReport,
  domain : String,
) -> AtomicDifference? {
  for difference in report.atomic_differences {
    if difference.domain == domain {
      return Some(difference)
    }
  }
  None
}

///|
fn structural_event(
  report : StructuredReport,
  difference_id : String,
) -> VisualEvent? {
  for event in report.events {
    if event.atomic_difference_ids.contains(difference_id) {
      return Some(event)
    }
  }
  None
}

///|
test "overlapping draw-order inversion is a structural difference" {
  let before = "<svg><rect id='red' width='12' height='12' fill='red'/><rect id='blue' x='4' y='4' width='12' height='12' fill='blue'/></svg>"
  let after = "<svg><rect id='blue' x='4' y='4' width='12' height='12' fill='blue'/><rect id='red' width='12' height='12' fill='red'/></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  guard structural_difference(report, "document.structure.stacking_order")
    is Some(difference) else {
    fail("expected active stacking-order difference")
  }
  assert_eq(difference.computed_relation.status, "different")
  assert_eq(
    difference.computed_relation.reason_code,
    "overlapping_draw_order_inverted",
  )
  assert_true(difference.evidence_layers.contains("rendered_evidence"))
  assert_eq(report.analysis_status, "complete")
  assert_true(
    difference.magnitude.raster_changed_pixel_fraction.unwrap_or(0.0) > 0.0,
  )
  assert_true(!difference.domain_ordering.components.is_empty())
  assert_true(
    report.changed_facts.any(fact => {
      fact.id == difference.changed_fact_ids[0] &&
      fact.property == "structure.stacking_order" &&
      fact.affected_subject_ids.length() == 2
    }),
  )
  guard structural_event(report, difference.id) is Some(event) else {
    fail("expected stacking event")
  }
  assert_true(!event.difference_regions.is_empty())
  assert_true(
    event.difference_regions.all(region => {
      region.cause_envelope.guarantee == "sound_overapproximation" &&
      region.cause_envelope.candidate_changed_fact_ids.contains(
        difference.changed_fact_ids[0],
      )
    }),
  )
}

///|
test "disjoint or visually equivalent reorderings stay nonvisual" {
  let disjoint_before = "<svg><rect id='red' width='4' height='4' fill='red'/><rect id='blue' x='8' width='4' height='4' fill='blue'/></svg>"
  let disjoint_after = "<svg><rect id='blue' x='8' width='4' height='4' fill='blue'/><rect id='red' width='4' height='4' fill='red'/></svg>"
  let disjoint = compare(
    disjoint_before,
    disjoint_after,
    ComparisonProfile::v1_default(),
  )
  assert_true(
    structural_difference(disjoint, "document.structure.stacking_order") is None,
  )
  let equivalent_before = "<svg><rect id='a' width='12' height='12' fill='red'/><rect id='b' x='4' y='4' width='12' height='12' fill='red'/></svg>"
  let equivalent_after = "<svg><rect id='b' x='4' y='4' width='12' height='12' fill='red'/><rect id='a' width='12' height='12' fill='red'/></svg>"
  let equivalent = compare(
    equivalent_before,
    equivalent_after,
    ComparisonProfile::v1_default(),
  )
  assert_true(
    structural_difference(equivalent, "document.structure.stacking_order")
    is None,
  )
}

///|
test "reparented inheritance links ancestry to the computed consequence" {
  let before = "<svg><g fill='red'><rect id='box' width='8' height='8'/></g><g fill='blue'/></svg>"
  let after = "<svg><g fill='red'/><g fill='blue'><rect id='box' width='8' height='8'/></g></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  guard structural_difference(report, "document.structure.ancestry")
    is Some(structure) else {
    fail("expected effective parent-path difference")
  }
  guard structural_difference(report, "paint.fill") is Some(fill) else {
    fail("expected inherited fill consequence")
  }
  assert_true(fill.changed_fact_ids.contains(structure.changed_fact_ids[0]))
  assert_true(
    report.events.any(event => {
      event.atomic_difference_ids.contains(structure.id) &&
      event.atomic_difference_ids.contains(fill.id)
    }),
  )
}

///|
test "reparented transform links ancestry to cumulative geometry" {
  let before = "<svg><g transform='translate(4 0)'><rect id='box' width='4' height='4'/></g><g/></svg>"
  let after = "<svg><g transform='translate(4 0)'/><g><rect id='box' width='4' height='4'/></g></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  guard structural_difference(report, "document.structure.ancestry")
    is Some(structure) else {
    fail("expected transform ancestry difference")
  }
  guard structural_difference(report, "geometry.transform.cumulative_matrix")
    is Some(cumulative) else {
    fail("expected cumulative transform consequence")
  }
  assert_true(
    cumulative.changed_fact_ids.contains(structure.changed_fact_ids[0]),
  )
}

///|
test "use target change links resource resolution to instance consequence" {
  let before = "<svg><defs><rect id='red-shape' width='8' height='8' fill='red'/><rect id='blue-shape' width='8' height='8' fill='blue'/></defs><use id='placed' href='#red-shape'/></svg>"
  let after = "<svg><defs><rect id='red-shape' width='8' height='8' fill='red'/><rect id='blue-shape' width='8' height='8' fill='blue'/></defs><use id='placed' href='#blue-shape'/></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  guard structural_difference(report, "document.structure.resource_resolution")
    is Some(structure) else {
    fail("expected instance resource-resolution difference")
  }
  assert_true(
    report.atomic_differences.any(difference => {
      difference.id != structure.id &&
      difference.subject_alignment_id == structure.subject_alignment_id &&
      difference.changed_fact_ids.contains(structure.changed_fact_ids[0])
    }),
  )
}

///|
test "ID renames and declaration-only changes do not invent structure" {
  let renamed = compare(
    "<svg><g id='old'><rect id='box' width='8' height='8' fill='red'/></g></svg>",
    "<svg><g id='new'><rect id='box' width='8' height='8' fill='red'/></g></svg>",
    ComparisonProfile::v1_default(),
  )
  assert_true(
    renamed.atomic_differences.all(difference => {
      difference.domain.find("document.structure.") != Some(0)
    }),
  )
  let declaration = compare(
    "<svg><g><rect id='box' width='8' height='8' fill='red'/></g></svg>",
    "<svg><g><rect id='box' width='8' height='8' fill='blue'/></g></svg>",
    ComparisonProfile::v1_default(),
  )
  assert_true(
    declaration.atomic_differences.all(difference => {
      difference.domain.find("document.structure.") != Some(0)
    }),
  )
}

///|
test "admitted compositing makes structural stacking blend-aware" {
  let before = "<svg><rect id='red' width='12' height='12' fill='red' style='mix-blend-mode:multiply'/><rect id='blue' x='4' y='4' width='12' height='12' fill='blue'/></svg>"
  let after = "<svg><rect id='blue' x='4' y='4' width='12' height='12' fill='blue'/><rect id='red' width='12' height='12' fill='red' style='mix-blend-mode:multiply'/></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "complete")
  assert_true(
    report.atomic_differences.any(difference => {
      difference.domain == "document.structure.stacking_order"
    }),
  )
  assert_true(
    report.diagnostics.all(diagnostic => {
      diagnostic.code != "unsupported_visual_attribute"
    }),
  )
}
