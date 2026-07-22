///|
fn inherited_fill_document(
  group_attributes : String,
  rect_attributes : String,
) -> String {
  "<svg width='16' height='16'><g id='layer' \{group_attributes}><rect id='box' x='2' y='2' width='8' height='8' \{rect_attributes}/></g></svg>"
}

///|
test "moving fill to an ancestor preserves resolved fill and changes provenance" {
  let before_source = inherited_fill_document("", "fill='red'")
  let after_source = inherited_fill_document("fill='red'", "")
  let report = @engine.compare(
    before_source,
    after_source,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "complete")
  assert_eq(report.changed_facts.length(), 2)
  assert_eq(report.atomic_differences.length(), 1)
  let difference = report.atomic_differences[0]
  assert_eq(difference.domain, "paint.fill")
  assert_eq(difference.computed_relation.status, "equivalent")
  assert_eq(difference.changed_fact_ids.length(), 2)
  assert_eq(report.source_resolutions.length(), 1)
  let pair = report.source_resolutions[0]
  assert_eq(pair.subject_id, "box")
  match (pair.before, pair.after) {
    (Some(before_value), Some(after_value)) => {
      assert_eq(before_value.resolution, "local")
      assert_eq(before_value.declaration_owner_id, Some("box"))
      assert_eq(after_value.resolution, "inherited")
      assert_eq(after_value.declaration_owner_id, Some("layer"))
      assert_eq(before_value.resolved_value, after_value.resolved_value)
      let before_declaration = before_value.declaration.unwrap()
      let after_declaration = after_value.declaration.unwrap()
      assert_eq(before_declaration.origin, "presentation_attribute")
      assert_eq(after_declaration.origin, "presentation_attribute")
      assert_eq(before_declaration.authored_value, "red")
      assert_eq(after_declaration.authored_value, "red")
      assert_eq(
        before_source
        .view(
          start_offset=before_declaration.source_span.start_offset,
          end_offset=before_declaration.source_span.end_offset,
        )
        .to_owned(),
        "red",
      )
      assert_eq(
        after_source
        .view(
          start_offset=after_declaration.source_span.start_offset,
          end_offset=after_declaration.source_span.end_offset,
        )
        .to_owned(),
        "red",
      )
    }
    _ => fail("expected aligned fill resolutions")
  }
  assert_eq(report.events.length(), 1)
  assert_eq(report.events[0].rendered_outcome.status, "computed")
  assert_eq(
    report.events[0].rendered_outcome.magnitude.unwrap().changed_pixels,
    0,
  )
}

///|
test "one ancestor changed fact identifies every affected rect" {
  let before = "<svg width='16' height='16'><g id='layer' fill='red'><rect id='a' x='0' y='0' width='4' height='4'/><rect id='b' x='8' y='8' width='4' height='4'/></g></svg>"
  let after = "<svg width='16' height='16'><g id='layer' fill='blue'><rect id='a' x='0' y='0' width='4' height='4'/><rect id='b' x='8' y='8' width='4' height='4'/></g></svg>"
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.changed_facts.length(), 1)
  let changed = report.changed_facts[0]
  assert_eq(changed.subject_id, "layer")
  assert_eq(changed.property, "fill")
  assert_eq(changed.affected_subject_ids, ["a", "b"])
  assert_eq(report.atomic_differences.length(), 2)
  for difference in report.atomic_differences {
    assert_eq(difference.changed_fact_ids, [changed.id])
    assert_eq(difference.computed_relation.status, "different")
    let mut owner_count = 0
    for event in report.events {
      if event.atomic_difference_ids.contains(difference.id) {
        owner_count += 1
      }
    }
    assert_eq(owner_count, 1)
  }
  assert_eq(report.events.length(), 2)
  assert_true(
    report.events.all(event => event.atomic_difference_ids.length() == 1),
  )
  let subjects = [ for event in report.events => event.primary_subject_id ]
  subjects.sort()
  assert_eq(subjects, ["a", "b"])
  assert_true(
    report.events.all(event => {
      event.rendered_outcome.status == "computed" &&
      event.rendered_outcome.magnitude.unwrap().changed_pixels > 0
    }),
  )
  assert_true(
    !report.diagnostics.any(diagnostic => {
      diagnostic.code == "computed_fill_value_semantics_deferred"
    }),
  )
}

///|
test "stylesheet selector participates in inherited fill without a CSS guard" {
  let source = "<svg width='16' height='16'><style>g { fill: red; }</style><g id='layer'><rect id='box' x='2' y='2' width='8' height='8'/></g></svg>"
  let report = @engine.compare(
    source,
    source,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "complete")
  assert_true(
    !report.diagnostics.any(diagnostic => {
      diagnostic.code == "css_cascade_unsupported"
    }),
  )
}

///|
test "matched stylesheet declarations retain inherited used values and provenance" {
  let before = "<svg width='16' height='16'><style>g.layer { stroke: black; stroke-width: 2; }</style><g class='layer' id='owner'><line id='edge' x1='1' y1='8' x2='15' y2='8'/></g></svg>"
  let after = "<svg width='16' height='16'><style>g.layer { stroke: black; stroke-width: 4; }</style><g class='layer' id='owner'><line id='edge' x1='1' y1='8' x2='15' y2='8'/></g></svg>"
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  let differences = [
    for difference in report.atomic_differences if difference.domain ==
    "geometry.stroke_width" => difference
  ]
  assert_eq(differences.length(), 1)
  assert_eq(differences[0].computed_relation.status, "different")
  assert_eq(differences[0].parameter_delta_css_px, Some(2.0))
  let pairs = [
    for pair in report.source_resolutions if pair.subject_id == "edge" &&
    pair.property == "stroke-width" => pair
  ]
  assert_eq(pairs.length(), 1)
  match (pairs[0].before, pairs[0].after) {
    (Some(before_value), Some(after_value)) => {
      assert_eq(before_value.declaration_owner_id, Some("owner"))
      assert_eq(after_value.declaration_owner_id, Some("owner"))
      assert_eq(before_value.declaration.unwrap().origin, "stylesheet_rule")
      assert_eq(after_value.declaration.unwrap().origin, "stylesheet_rule")
      assert_eq(before_value.declaration.unwrap().declared_value, "2")
      assert_eq(after_value.declaration.unwrap().declared_value, "4")
    }
    _ => fail("expected stylesheet inheritance resolutions")
  }
}

///|
test "removing an ancestor declaration falls back to the initial value" {
  let before = inherited_fill_document("fill='red'", "")
  let after = inherited_fill_document("", "")
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "complete")
  assert_eq(report.atomic_differences.length(), 1)
  assert_eq(report.atomic_differences[0].computed_relation.status, "different")
  match
    (report.source_resolutions[0].before, report.source_resolutions[0].after) {
    (Some(before_value), Some(after_value)) => {
      assert_eq(before_value.resolution, "inherited")
      assert_eq(after_value.resolution, "initial")
      assert_eq(after_value.resolved_value, "rgba(0,0,0,1)")
      assert_true(after_value.declaration is None)
    }
    _ => fail("expected inherited-to-initial resolutions")
  }
  assert_true(
    report.events[0].rendered_outcome.magnitude.unwrap().changed_pixels > 0,
  )
}

///|
test "structured report JSON hides inheritance implementation provenance" {
  let report = @engine.compare(
    inherited_fill_document("", "fill='red'"),
    inherited_fill_document("style='fill: red'", ""),
    @engine.ComparisonProfile::v1_default(),
  )
  let json = report.to_json_string()
  assert_true(json.find("source_resolutions") is None)
  assert_true(json.find("declaration_owner_id") is None)
  assert_true(json.find("source_span") is None)
}

///|
test "inherited stroke geometry retains declaration ownership" {
  let before = "<svg width='16' height='16'><g id='layer' stroke='black' stroke-linecap='butt'><line id='edge' x1='1' y1='8' x2='15' y2='8'/></g></svg>"
  let after = "<svg width='16' height='16'><g id='layer' stroke='black' stroke-linecap='round'><line id='edge' x1='1' y1='8' x2='15' y2='8'/></g></svg>"
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  let pairs = [
    for pair in report.source_resolutions if pair.subject_id == "edge" &&
    pair.property == "stroke-linecap" => pair
  ]
  assert_eq(pairs.length(), 1)
  let differences = [
    for difference in report.atomic_differences if difference.domain ==
    "geometry.stroke_cap" => difference
  ]
  assert_eq(differences.length(), 1)
  let difference = differences[0]
  assert_eq(difference.computed_relation.status, "different")
  match (pairs[0].before, pairs[0].after) {
    (Some(before), Some(after)) => {
      assert_eq(before.resolution, "inherited")
      assert_eq(after.resolution, "inherited")
      assert_eq(before.declaration_owner_id, Some("layer"))
      assert_eq(after.declaration_owner_id, Some("layer"))
      assert_true(
        before.declaration.unwrap().source_span.end_offset >
        before.declaration.unwrap().source_span.start_offset,
      )
      assert_true(
        after.declaration.unwrap().source_span.end_offset >
        after.declaration.unwrap().source_span.start_offset,
      )
    }
    _ => fail("expected inherited stroke cap resolutions")
  }
}

///|
test "CSS-wide defaulting distinguishes inherited and non-inherited properties" {
  let before = "<svg width='16' height='16'><g fill='red'><rect id='box' x='2' y='2' width='8' height='8' fill='inherit' opacity='unset'/></g></svg>"
  let after = "<svg width='16' height='16'><g fill='red'><rect id='box' x='2' y='2' width='8' height='8' fill='red' opacity='1'/></g></svg>"
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "complete")
  assert_true(
    report.atomic_differences.all(difference => {
      difference.computed_relation.status == "equivalent"
    }),
  )
  let fill = [
    for pair in report.source_resolutions if pair.subject_id == "box" &&
    pair.property == "fill" => pair
  ]
  assert_eq(fill.length(), 1)
  assert_eq(fill[0].before.unwrap().resolution, "explicit_inherit_inherit")
  assert_eq(fill[0].before.unwrap().resolved_value, "rgba(255,0,0,1)")
  let opacity = [
    for pair in report.source_resolutions if pair.subject_id == "box" &&
    pair.property == "opacity" => pair
  ]
  assert_eq(opacity.length(), 1)
  assert_eq(opacity[0].before.unwrap().resolution, "explicit_unset_initial")
  assert_eq(opacity[0].before.unwrap().resolved_value, "1")
}

///|
test "author revert follows ordinary defaulting in the author-only profile" {
  let before = "<svg width='16' height='16'><style>#box { fill: orange; }</style><g fill='blue'><rect id='box' x='2' y='2' width='8' height='8' fill='red' style='fill:green;fill:revert'/></g></svg>"
  let after = "<svg width='16' height='16'><g fill='blue'><rect id='box' x='2' y='2' width='8' height='8' fill='blue'/></g></svg>"
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "complete")
  assert_eq(report.atomic_differences.length(), 1)
  assert_eq(report.atomic_differences[0].computed_relation.status, "equivalent")
  assert_eq(
    report.source_resolutions[0].before.unwrap().resolution,
    "explicit_revert_inherit",
  )
  assert_eq(
    report.source_resolutions[0].before.unwrap().resolved_value,
    "rgba(0,0,255,1)",
  )
}

///|
test "currentColor tracks the inherited color dependency" {
  let before = "<svg width='16' height='16'><g id='theme' color='red'><rect id='box' x='2' y='2' width='8' height='8' fill='currentColor'/></g></svg>"
  let after = "<svg width='16' height='16'><g id='theme' color='blue'><rect id='box' x='2' y='2' width='8' height='8' fill='currentColor'/></g></svg>"
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "complete")
  assert_eq(report.changed_facts.length(), 1)
  assert_eq(report.changed_facts[0].property, "color")
  assert_eq(report.changed_facts[0].affected_subject_ids, ["box"])
  assert_eq(report.atomic_differences.length(), 1)
  assert_eq(report.atomic_differences[0].domain, "paint.fill")
  assert_eq(report.atomic_differences[0].computed_relation.status, "different")
  assert_eq(report.atomic_differences[0].changed_fact_ids, [
    report.changed_facts[0].id,
  ])
}

///|
test "custom properties cascade inherit and substitute without replacing source facts" {
  let before = "<svg width='16' height='16' style='--paint:red'><g><rect id='box' x='2' y='2' width='8' height='8' fill='var(--paint)'/></g></svg>"
  let after = "<svg width='16' height='16' style='--paint:blue'><g><rect id='box' x='2' y='2' width='8' height='8' fill='var(--paint)'/></g></svg>"
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "complete")
  assert_eq(report.changed_facts.length(), 1)
  assert_eq(report.changed_facts[0].property, "--paint")
  assert_eq(report.changed_facts[0].before.unwrap().origin, "inline_style")
  assert_true(
    report.changed_facts[0].before.unwrap().source_span.end_offset >
    report.changed_facts[0].before.unwrap().source_span.start_offset,
  )
  assert_eq(report.atomic_differences.length(), 1)
  assert_eq(
    report.atomic_differences[0].source_fact_before.unwrap().declared_value,
    "var(--paint)",
  )
  assert_eq(report.atomic_differences[0].source_before, "var(--paint)")
  assert_eq(report.atomic_differences[0].source_after, "var(--paint)")
}

///|
test "nested variable fallback can resolve a CSS-wide keyword" {
  let before = "<svg width='16' height='16'><g fill='red'><rect id='box' x='2' y='2' width='8' height='8' fill='var(--missing, var(--also-missing, inherit))'/></g></svg>"
  let after = "<svg width='16' height='16'><g fill='red'><rect id='box' x='2' y='2' width='8' height='8' fill='red'/></g></svg>"
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "complete")
  assert_eq(report.atomic_differences.length(), 1)
  assert_eq(report.atomic_differences[0].computed_relation.status, "equivalent")
  assert_eq(
    report.source_resolutions[0].before.unwrap().resolved_value,
    "rgba(255,0,0,1)",
  )
}

///|
test "cyclic variables become invalid and make the consuming property unset" {
  let before = "<svg width='16' height='16'><g fill='red' style='--a:var(--b);--b:var(--a)'><rect id='box' x='2' y='2' width='8' height='8' fill='var(--a)'/></g></svg>"
  let after = "<svg width='16' height='16'><g fill='red'><rect id='box' x='2' y='2' width='8' height='8' fill='red'/></g></svg>"
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "complete")
  assert_eq(report.atomic_differences.length(), 1)
  assert_eq(report.atomic_differences[0].computed_relation.status, "equivalent")
  assert_eq(
    report.source_resolutions[0].before.unwrap().resolved_value,
    "rgba(255,0,0,1)",
  )
}

///|
test "invalid substituted values make the consuming property unset" {
  let before = "<svg width='16' height='16'><g fill='red' style='--paint:20px'><rect id='box' x='2' y='2' width='8' height='8' fill='var(--paint)'/></g></svg>"
  let after = "<svg width='16' height='16'><g fill='red'><rect id='box' x='2' y='2' width='8' height='8' fill='red'/></g></svg>"
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "complete")
  assert_eq(report.atomic_differences.length(), 1)
  assert_eq(report.atomic_differences[0].computed_relation.status, "equivalent")
  assert_eq(
    report.source_resolutions[0].before.unwrap().resolved_value,
    "rgba(255,0,0,1)",
  )
}

///|
test "custom property names are case-sensitive and obey stylesheet cascade" {
  let before = "<svg width='16' height='16'><style>svg { --Paint: red; --paint: blue; } rect { fill: var(--Paint); }</style><rect id='box' x='2' y='2' width='8' height='8'/></svg>"
  let after = "<svg width='16' height='16'><rect id='box' x='2' y='2' width='8' height='8' fill='red'/></svg>"
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "complete")
  assert_eq(report.atomic_differences.length(), 1)
  assert_eq(report.atomic_differences[0].computed_relation.status, "equivalent")
}

///|
test "custom properties feed supported geometry used values" {
  let before = "<svg width='16' height='16' style='--left:2'><rect id='box' x='var(--left)' y='2' width='8' height='8' fill='red'/></svg>"
  let after = "<svg width='16' height='16' style='--left:4'><rect id='box' x='var(--left)' y='2' width='8' height='8' fill='red'/></svg>"
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  let positions = [
    for difference in report.atomic_differences if difference.domain ==
    "geometry.position" => difference
  ]
  assert_eq(report.analysis_status, "complete")
  assert_eq(positions.length(), 1)
  assert_eq(positions[0].parameter_delta_css_px, Some(2.0))
  assert_eq(report.changed_facts.length(), 1)
  assert_eq(report.changed_facts[0].property, "--left")
}

///|
test "unused custom property changes do not claim a visual outcome" {
  let before = "<svg width='16' height='16' style='--unused:red'><rect id='box' x='2' y='2' width='8' height='8' fill='black'/></svg>"
  let after = "<svg width='16' height='16' style='--unused:blue'><rect id='box' x='2' y='2' width='8' height='8' fill='black'/></svg>"
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "complete")
  assert_true(report.changed_facts.is_empty())
  assert_true(report.atomic_differences.is_empty())
  assert_true(report.events.is_empty())
}

///|
test "custom properties and currentColor reach admitted gradient stop colors" {
  let before = "<svg width='16' height='16' color='red' style='--stop:currentColor'><defs><linearGradient id='gradient'><stop offset='0' stop-color='var(--stop)'/><stop offset='1' stop-color='black'/></linearGradient></defs><rect id='box' x='2' y='2' width='8' height='8' fill='url(#gradient)'/></svg>"
  let after = "<svg width='16' height='16' color='blue' style='--stop:currentColor'><defs><linearGradient id='gradient'><stop offset='0' stop-color='var(--stop)'/><stop offset='1' stop-color='black'/></linearGradient></defs><rect id='box' x='2' y='2' width='8' height='8' fill='url(#gradient)'/></svg>"
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  let resource = [
    for difference in report.atomic_differences if difference.domain ==
    "resource.gradient.stop.stop_color" => difference
  ]
  assert_eq(resource.length(), 1)
  assert_eq(resource[0].computed_relation.status, "different")
  assert_eq(report.changed_facts.length(), 1)
  assert_eq(report.changed_facts[0].property, "color")
  assert_true(report.changed_facts[0].affected_subject_ids.contains("box"))
}

///|
test "CSS-wide and custom values reach marker attachment resolution" {
  let before = "<svg width='16' height='16' style='--tip:url(#m)'><defs><marker id='m'/></defs><g marker-end='var(--tip)'><line id='edge' x1='1' y1='8' x2='15' y2='8' marker-end='inherit'/></g></svg>"
  let after = "<svg width='16' height='16'><defs><marker id='m'/></defs><line id='edge' x1='1' y1='8' x2='15' y2='8' marker-end='url(#m)'/></svg>"
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  let attachments = [
    for difference in report.atomic_differences if difference.domain ==
    "geometry.marker_attachment" => difference
  ]
  assert_eq(attachments.length(), 1)
  assert_eq(attachments[0].computed_relation.status, "equivalent")
}

///|
test "malformed variable syntax remains explicitly guarded" {
  let source = "<svg width='16' height='16'><rect id='box' x='2' y='2' width='8' height='8' fill='var(--paint'/></svg>"
  let report = @engine.compare(
    source,
    source,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "partial")
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "css_variable_syntax_unsupported"
    }),
  )
}

///|
test "excessive variable expansion remains explicitly guarded" {
  let declarations = StringBuilder::new()
  for index in 0..<65 {
    declarations.write_string("--v\{index}:var(--v\{index + 1});")
  }
  declarations.write_string("--v65:red")
  let source = "<svg width='16' height='16' style='\{declarations}'><rect id='box' x='2' y='2' width='8' height='8' fill='var(--v0)'/></svg>"
  let report = @engine.compare(
    source,
    source,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "partial")
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "css_variable_expansion_limit"
    }),
  )
}
