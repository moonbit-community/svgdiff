///|
fn inherited_fill_document(
  group_attributes : String,
  rect_attributes : String,
) -> String {
  "<svg width='16' height='16'><g id='layer' \{group_attributes}><rect id='box' x='2' y='2' width='8' height='8' \{rect_attributes}/></g></svg>"
}

///|
test "moving fill to an ancestor preserves resolved fill and changes provenance" {
  let before = inherited_fill_document("", "fill='red'")
  let after = inherited_fill_document("fill='red'", "")
  let report = @engine.compare(
    before,
    after,
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
    (Some(before), Some(after)) => {
      assert_eq(before.resolution, "local")
      assert_eq(before.declaration_owner_id, Some("box"))
      assert_eq(after.resolution, "inherited")
      assert_eq(after.declaration_owner_id, Some("layer"))
      assert_eq(before.resolved_value, after.resolved_value)
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
      assert_eq(after_value.resolved_value, "black")
      assert_true(after_value.declaration is None)
    }
    _ => fail("expected inherited-to-initial resolutions")
  }
  assert_true(
    report.events[0].rendered_outcome.magnitude.unwrap().changed_pixels > 0,
  )
}

///|
test "structured report JSON exposes inherited fill provenance" {
  let report = @engine.compare(
    inherited_fill_document("", "fill='red'"),
    inherited_fill_document("style='fill: red'", ""),
    @engine.ComparisonProfile::v1_default(),
  )
  match @json.parse(report.to_json_string()) {
    {
      "schema_version": "1.14",
      "source_resolutions": [
        {
          "subject_id": "box",
          "after": {
            "resolution": "inherited",
            "declaration_owner_id": "layer",
            "declaration": {
              "origin": "inline_style",
              "source_span": {
                "start_offset": Number(_),
                "end_offset": Number(_),
                ..
              },
              ..
            },
            ..
          },
          ..
        },
      ],
      ..
    } => ()
    _ => fail("serialized report did not retain inherited fill provenance")
  }
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
