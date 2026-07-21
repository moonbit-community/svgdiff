///|
fn paint_rule_difference(
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
test "paint-order source rewrites compare their active operation sequence" {
  let normal = "<svg><rect id='box' x='2' y='2' width='8' height='8' fill='red' stroke='blue' stroke-width='4' paint-order='normal'/></svg>"
  let expanded = normal.replace_all(
    old="paint-order='normal'",
    new="paint-order='fill stroke markers'",
  )
  let equivalent = compare(normal, expanded, ComparisonProfile::v1_default())
  guard paint_rule_difference(equivalent, "paint.order")
    is Some(equivalent_difference) else {
    fail("expected paint-order source difference")
  }
  assert_eq(equivalent.analysis_status, "partial")
  assert_eq(equivalent_difference.computed_relation.status, "equivalent")
  let reordered = normal.replace_all(
    old="paint-order='normal'",
    new="paint-order='stroke'",
  )
  let different = compare(normal, reordered, ComparisonProfile::v1_default())
  guard paint_rule_difference(different, "paint.order") is Some(different_order) else {
    fail("expected reordered paint operations")
  }
  assert_eq(different_order.computed_relation.status, "different")
  assert_true(different_order.evidence_layers.contains("computed_appearance"))
}

///|
test "paint-order ignores operations that cannot contribute" {
  let before = "<svg><rect id='box' width='8' height='8' fill='red' stroke='none' paint-order='fill'/></svg>"
  let after = before.replace_all(
    old="paint-order='fill'",
    new="paint-order='stroke'",
  )
  let report = compare(before, after, ComparisonProfile::v1_default())
  guard paint_rule_difference(report, "paint.order") is Some(difference) else {
    fail("expected inactive paint-order source difference")
  }
  assert_eq(difference.computed_relation.status, "equivalent")
}

///|
test "inherited custom paint-order retains owner dependency" {
  let before = "<svg><g id='layer' style='--order:stroke;paint-order:var(--order)'><rect id='box' width='8' height='8' fill='red' stroke='blue' stroke-width='4'/></g></svg>"
  let after = before.replace_all(old="--order:stroke", new="--order:fill")
  let report = compare(before, after, ComparisonProfile::v1_default())
  guard paint_rule_difference(report, "paint.order") is Some(difference) else {
    fail("expected inherited paint-order difference")
  }
  assert_eq(difference.computed_relation.status, "different")
  assert_true(
    report.changed_facts.any(fact => {
      fact.subject_id == "layer" &&
      fact.property == "--order" &&
      fact.affected_subject_ids.contains("box")
    }),
  )
  assert_true(
    report.source_resolutions.any(pair => {
      pair.subject_id == "box" &&
      pair.property == "paint-order" &&
      pair.before.map(value => value.declaration_owner_id) ==
      Some(Some("layer"))
    }),
  )
}

///|
test "fill-rule is inactive for simple contours and absent fill" {
  for
    before in [
      "<svg><rect id='box' width='8' height='8' fill='red' fill-rule='nonzero'/></svg>",
      "<svg><polygon id='box' points='0,0 8,0 4,8' fill='none' fill-rule='nonzero'/></svg>",
    ] {
    let after = before.replace_all(
      old="fill-rule='nonzero'",
      new="fill-rule='evenodd'",
    )
    let report = compare(before, after, ComparisonProfile::v1_default())
    guard paint_rule_difference(report, "paint.fill_rule") is Some(difference) else {
      fail("expected fill-rule source difference")
    }
    assert_eq(difference.computed_relation.status, "equivalent")
  }
}

///|
test "fill-rule changes a potentially self-intersecting polygon" {
  let before = "<svg width='16' height='16'><polygon id='star' points='8,1 12,14 1,6 15,6 4,14' fill='red' fill-rule='nonzero'/></svg>"
  let after = before.replace_all(
    old="fill-rule='nonzero'",
    new="fill-rule='evenodd'",
  )
  let report = compare(before, after, ComparisonProfile::v1_default())
  guard paint_rule_difference(report, "paint.fill_rule") is Some(difference) else {
    fail("expected fill-rule difference")
  }
  assert_eq(difference.computed_relation.status, "different")
  assert_true(difference.evidence_layers.contains("computed_appearance"))
}

///|
test "clip-rule is inactive outside clipPath and guarded in unsupported content" {
  let outside_before = "<svg><rect id='box' width='8' height='8' clip-rule='nonzero'/></svg>"
  let outside_after = outside_before.replace_all(
    old="clip-rule='nonzero'",
    new="clip-rule='evenodd'",
  )
  let outside = compare(
    outside_before,
    outside_after,
    ComparisonProfile::v1_default(),
  )
  guard paint_rule_difference(outside, "clipping.rule")
    is Some(outside_difference) else {
    fail("expected outside clip-rule source difference")
  }
  assert_eq(outside.analysis_status, "complete")
  assert_eq(outside_difference.computed_relation.status, "equivalent")
  let inside_before = "<svg><defs><clipPath id='clip' clip-rule='nonzero'><polygon id='cut' points='0,0 8,0 4,8'/></clipPath></defs><rect width='8' height='8' clip-path='url(#clip)'/></svg>"
  let inside_after = inside_before.replace_all(
    old="clip-rule='nonzero'",
    new="clip-rule='evenodd'",
  )
  let inside = compare(
    inside_before,
    inside_after,
    ComparisonProfile::v1_default(),
  )
  assert_eq(inside.analysis_status, "partial")
  assert_true(
    inside.diagnostics.any(diagnostic => {
      diagnostic.code == "clip_path_content_unsupported" &&
      !diagnostic.source_locations.is_empty()
    }),
  )
  guard paint_rule_difference(inside, "clipping.rule")
    is Some(inside_difference) else {
    fail("expected inherited clip-rule difference")
  }
  assert_eq(inside_difference.computed_relation.status, "indeterminate")
  assert_true(
    inside.changed_facts.any(fact => {
      fact.subject_id == "clip" &&
      fact.property == "clip-rule" &&
      fact.affected_subject_ids.contains("cut")
    }),
  )
}

///|
test "invalid paint and winding rules retain located guards" {
  for
    property_and_value in [
      ("paint-order", "stroke stroke"),
      ("fill-rule", "positive"),
      ("clip-rule", "negative"),
    ] {
    let (property, value) = property_and_value
    let source = "<svg><polygon points='0,0 8,0 4,8' \{property}='\{value}'/></svg>"
    let report = compare(source, source, ComparisonProfile::v1_default())
    assert_eq(report.analysis_status, "partial")
    assert_true(
      report.diagnostics.any(diagnostic => {
        diagnostic.code == paint_rule_issue_code(property) &&
        !diagnostic.source_locations.is_empty()
      }),
    )
  }
}
