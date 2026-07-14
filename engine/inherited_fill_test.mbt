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
  assert_eq(report.analysis_status, "partial")
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
  assert_eq(report.events[0].rendered_outcome.status, "not_computed")
  assert_true(report.events[0].rendered_outcome.magnitude is None)
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
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "computed_fill_value_semantics_deferred" &&
      diagnostic.source_locations.length() == 2 &&
      diagnostic.source_locations[0].source_role == "before" &&
      diagnostic.source_locations[1].source_role == "after"
    }),
  )
}

///|
test "stylesheet fill keeps inherited source analysis partial" {
  let source = "<svg width='16' height='16'><style>g { fill: red; }</style><g id='layer'><rect id='box' x='2' y='2' width='8' height='8'/></g></svg>"
  let report = @engine.compare(
    source,
    source,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "partial")
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "css_cascade_unsupported"
    }),
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
      "schema_version": "1.2",
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
