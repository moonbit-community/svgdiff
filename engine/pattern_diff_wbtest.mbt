///|
test "pattern resource and mediated fill differences are reported together" {
  let before = "<svg width='20' height='20'><defs><pattern id='tile' width='.25' height='.25'><rect id='dot' width='1' height='1' fill='red'/></pattern></defs><rect id='box' width='20' height='20' fill='url(#tile)'/></svg>"
  let after = "<svg width='20' height='20'><defs><pattern id='tile' patternUnits='userSpaceOnUse' width='5' height='5'><rect id='dot' width='1' height='1' fill='blue'/></pattern></defs><rect id='box' width='20' height='20' fill='url(#tile)'/></svg>"
  let report = compare(before, after, {
    ..ComparisonProfile::v1_default(),
    viewport_width: 20,
    viewport_height: 20,
  })
  assert_true(
    report.atomic_differences.any(diff => {
      diff.domain == "resource.pattern.units"
    }),
  )
  assert_true(
    report.atomic_differences.any(diff => {
      diff.domain == "resource.pattern.child.fill"
    }),
  )
  assert_false(
    report.changed_facts.any(fact => {
      fact.subject_id == "dot" && fact.property == "paint.fill"
    }),
  )
  assert_false(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "multiple_rects_unsupported"
    }),
  )
  assert_true(
    report.atomic_differences.any(diff => {
      diff.domain == "paint.fill" &&
      diff.subject_alignment_id == Some("alignment:0") &&
      diff.computed_relation.status == "different"
    }),
  )
  assert_true(
    report.changed_facts.any(fact => {
      fact.subject_id == "tile" && fact.affected_subject_ids.contains("box")
    }),
  )
  assert_true(
    report.changed_facts.any(fact => {
      fact.property == "child:dot:fill" &&
      fact.before.map(value => value.declared_value) == Some("red") &&
      fact.after.map(value => value.declared_value) == Some("blue")
    }),
  )
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "renderer_pattern_raster_unproven"
    }),
  )
  assert_false(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "resource_transform_semantics_unsupported"
    }),
  )
}

///|
test "equivalent direct and template pattern authoring remains source visible" {
  let before = "<svg width='20' height='20'><defs><pattern id='base' width='.25' height='.25'><rect id='dot' width='1' height='1' fill='red'/></pattern><pattern id='tile' href='#base'/></defs><rect id='box' width='20' height='20' fill='url(#tile)'/></svg>"
  let after = "<svg width='20' height='20'><defs><pattern id='base' width='.25' height='.25'><rect id='dot' width='1' height='1' fill='red'/></pattern><pattern id='tile' width='.25' height='.25'><rect id='dot2' width='1' height='1' fill='red'/></pattern></defs><rect id='box' width='20' height='20' fill='url(#tile)'/></svg>"
  let report = compare(before, after, {
    ..ComparisonProfile::v1_default(),
    viewport_width: 20,
    viewport_height: 20,
  })
  assert_true(
    report.atomic_differences.any(diff => {
      diff.domain == "resource.pattern.reference" &&
      diff.evidence_layers.contains("source_semantics")
    }),
  )
  assert_true(
    report.atomic_differences.any(diff => {
      diff.domain == "paint.fill" &&
      diff.computed_relation.status == "equivalent"
    }),
  )
}

///|
test "one pattern change fans out to fill and stroke consumers" {
  let before = "<svg width='20' height='20'><defs><pattern id='tile' width='.5' height='.5'><rect id='dot' width='1' height='1' fill='red'/></pattern></defs><rect id='a' width='10' height='10' fill='url(#tile)'/><circle id='b' cx='15' cy='15' r='3' fill='none' stroke='url(#tile)'/></svg>"
  let after = before.replace_all(old="fill='red'", new="fill='blue'")
  let report = compare(before, after, {
    ..ComparisonProfile::v1_default(),
    viewport_width: 20,
    viewport_height: 20,
  })
  assert_true(
    report.atomic_differences.any(diff => diff.domain == "paint.fill"),
  )
  assert_true(
    report.atomic_differences.any(diff => diff.domain == "paint.stroke"),
  )
  assert_true(
    report.changed_facts.any(fact => {
      fact.subject_id == "tile" &&
      fact.affected_subject_ids.contains("a") &&
      fact.affected_subject_ids.contains("b")
    }),
  )
}

///|
test "unreferenced pattern changes stay resource only" {
  let before = "<svg><defs><pattern id='tile' width='.5' height='.5'><rect id='dot' width='1' height='1' fill='red'/></pattern></defs></svg>"
  let after = before.replace_all(old="fill='red'", new="fill='blue'")
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "complete")
  assert_true(
    report.atomic_differences.any(diff => {
      diff.domain == "resource.pattern.child.fill"
    }),
  )
  assert_false(
    report.atomic_differences.any(diff => {
      diff.domain == "paint.fill" || diff.domain == "paint.stroke"
    }),
  )
  guard report.events[0].rendered_outcome.magnitude is Some(magnitude) else {
    fail("expected computed resource-only rendered evidence")
  }
  assert_eq(magnitude.changed_pixels, 0)
}

///|
test "resource children do not offset following visible subject references" {
  let before = "<svg><defs><pattern id='tile' width='1' height='1'><rect id='dot' width='1' height='1'/></pattern></defs><rect id='a' width='2' height='2'/><circle id='b' cx='5' cy='5' r='2'/></svg>"
  let after = before.replace_all(old="r='2'", new="r='3'")
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_true(
    report.atomic_differences.any(diff => {
      diff.domain == "geometry.size" &&
      diff.subject_alignment_id == Some("alignment:1")
    }),
  )
}

///|
test "pattern child computed-value dependencies retain their authored cause" {
  let before = "<svg width='16' height='16'><defs><pattern id='tile' color='red' width='.5' height='.5'><rect id='dot' width='2' height='2' fill='currentColor'/></pattern></defs><rect id='box' width='8' height='8' fill='url(#tile)'/></svg>"
  let after = before.replace_all(old="color='red'", new="color='blue'")
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_true(
    report.changed_facts.any(fact => {
      fact.property == "child:dot:color" &&
      fact.before.map(value => value.declared_value) == Some("red") &&
      fact.after.map(value => value.declared_value) == Some("blue") &&
      fact.affected_subject_ids == ["box"]
    }),
  )
  assert_true(
    report.atomic_differences.any(diff => {
      diff.domain == "resource.pattern.child.color" &&
      diff.computed_relation.status == "different"
    }),
  )
}

///|
test "equivalent pattern child paint and transform spellings remain source visible" {
  let before = "<svg width='16' height='16'><defs><pattern id='tile' width='.5' height='.5'><rect id='dot' width='2' height='2' fill='red' transform='translate(1)'/></pattern></defs><rect id='box' width='8' height='8' fill='url(#tile)'/></svg>"
  let after = before
    .replace_all(old="fill='red'", new="fill='#ff0000'")
    .replace_all(
      old="transform='translate(1)'",
      new="transform='matrix(1 0 0 1 1 0)'",
    )
  let report = compare(before, after, ComparisonProfile::v1_default())
  for
    domain in [
      "resource.pattern.child.fill", "resource.pattern.child.transform",
    ] {
    assert_true(
      report.atomic_differences.any(diff => {
        diff.domain == domain &&
        diff.evidence_layers == ["source_semantics"] &&
        diff.computed_relation.status == "equivalent"
      }),
    )
  }
  assert_true(
    report.atomic_differences.any(diff => {
      diff.domain == "paint.fill" &&
      diff.computed_relation.status == "equivalent"
    }),
  )
}

///|
test "pattern child stacking order is a resource difference" {
  let before = "<svg width='16' height='16'><defs><pattern id='tile' width='.5' height='.5'><rect id='red' width='2' height='2' fill='red'/><rect id='blue' width='1' height='1' fill='blue'/></pattern></defs><rect id='box' width='8' height='8' fill='url(#tile)'/></svg>"
  let after = "<svg width='16' height='16'><defs><pattern id='tile' width='.5' height='.5'><rect id='blue' width='1' height='1' fill='blue'/><rect id='red' width='2' height='2' fill='red'/></pattern></defs><rect id='box' width='8' height='8' fill='url(#tile)'/></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_true(
    report.atomic_differences.any(diff => {
      diff.domain == "resource.pattern.content_order" &&
      diff.computed_relation.status == "different"
    }),
  )
  assert_true(
    report.atomic_differences.any(diff => {
      diff.domain == "paint.fill" &&
      diff.computed_relation.status == "different"
    }),
  )
}

///|
test "unsupported visible overflow remains an authored resource difference" {
  let before = "<svg><defs><pattern id='tile' overflow='hidden'/></defs></svg>"
  let after = before.replace_all(old="hidden", new="visible")
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_true(
    report.atomic_differences.any(diff => {
      diff.domain == "resource.pattern.viewport.overflow" &&
      diff.source_before == "hidden" &&
      diff.source_after == "visible" &&
      diff.computed_relation.status == "indeterminate"
    }),
  )
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "pattern_visible_overflow_unsupported"
    }),
  )
}

///|
test "pattern container transforms retain their authored source cause" {
  let before = "<svg><defs><pattern id='tile' width='.5' height='.5'><g id='layer' transform='translate(1)'><rect id='dot' width='2' height='2'/></g></pattern></defs><rect id='box' width='8' height='8' fill='url(#tile)'/></svg>"
  let after = before.replace_all(old="translate(1)", new="translate(3)")
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_true(
    report.atomic_differences.any(diff => {
      diff.domain == "resource.pattern.child.transform" &&
      diff.source_fact_before.map(fact => fact.property) == Some("transform") &&
      diff.source_fact_after.map(fact => fact.property) == Some("transform") &&
      diff.computed_relation.status == "different"
    }),
  )
  assert_true(
    report.changed_facts.any(fact => {
      fact.property == "child:dot:transform:layer" &&
      fact.affected_subject_ids == ["box"]
    }),
  )
}

///|
test "pattern resource insertion reaches its existing paint consumer" {
  let before = "<svg><rect id='box' width='8' height='8' fill='url(#tile)'/></svg>"
  let after = "<svg><defs><pattern id='tile' width='.5' height='.5'><rect width='1' height='1' fill='red'/></pattern></defs><rect id='box' width='8' height='8' fill='url(#tile)'/></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_true(
    report.atomic_differences.any(diff => {
      diff.domain == "resource.pattern.presence" &&
      diff.computed_relation.missing_side == Some("before")
    }),
  )
  assert_true(
    report.atomic_differences.any(diff => {
      diff.domain == "paint.fill" &&
      diff.subject_alignment_id == Some("alignment:0") &&
      diff.computed_relation.status == "not_applicable" &&
      diff.computed_relation.missing_side == Some("before")
    }),
  )
}

///|
test "changing the referenced pattern retains the consumer paint fact" {
  let before = "<svg><defs><pattern id='a' width='.5' height='.5'><rect width='1' height='1' fill='red'/></pattern><pattern id='b' width='.5' height='.5'><rect width='1' height='1' fill='blue'/></pattern></defs><rect id='box' width='8' height='8' fill='url(#a)'/></svg>"
  let after = before.replace_all(old="url(#a)", new="url(#b)")
  let report = compare(before, after, ComparisonProfile::v1_default())
  let mut selected : AtomicDifference? = None
  for difference in report.atomic_differences {
    if difference.domain == "paint.fill" &&
      difference.subject_alignment_id == Some("alignment:0") {
      selected = Some(difference)
      break
    }
  }
  guard selected is Some(difference) else {
    fail("expected mediated paint difference")
  }
  assert_true(
    difference.changed_fact_ids.any(id => {
      report.changed_facts.any(fact => {
        fact.id == id &&
        fact.before.map(value => value.declared_value) == Some("url(#a)") &&
        fact.after.map(value => value.declared_value) == Some("url(#b)")
      })
    }),
  )
  assert_eq(
    report.changed_facts
    .filter(fact => {
      fact.subject_id == "box" &&
      fact.before.map(value => value.declared_value) == Some("url(#a)") &&
      fact.after.map(value => value.declared_value) == Some("url(#b)")
    })
    .length(),
    1,
  )
}

///|
test "pattern child stroke geometry changes reach the consumer signature" {
  let before = "<svg><defs><pattern id='tile' width='.5' height='.5'><line id='edge' x1='0' y1='1' x2='2' y2='1' stroke='black' stroke-width='1' stroke-linecap='butt'/></pattern></defs><rect id='box' width='8' height='8' fill='url(#tile)'/></svg>"
  let after = before.replace_all(old="linecap='butt'", new="linecap='round'")
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_true(
    report.atomic_differences.any(diff => {
      diff.domain == "resource.pattern.child.stroke_linecap" &&
      diff.computed_relation.status == "different"
    }),
  )
  assert_true(
    report.atomic_differences.any(diff => {
      diff.domain == "paint.fill" &&
      diff.computed_relation.status == "different"
    }),
  )
}

///|
test "pattern child paint servers remain an explicit unsupported boundary" {
  let source = "<svg><defs><linearGradient id='g'><stop stop-color='red'/></linearGradient><pattern id='tile' width='.5' height='.5'><rect width='1' height='1' fill='url(#g)'/></pattern></defs><rect id='box' width='8' height='8' fill='url(#tile)'/></svg>"
  let report = compare(source, source, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "partial")
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "pattern_child_semantics_unsupported"
    }),
  )
}
