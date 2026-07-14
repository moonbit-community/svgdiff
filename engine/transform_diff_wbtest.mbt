///|
fn transform_differences(report : StructuredReport) -> Array[AtomicDifference] {
  [
    for difference in report.atomic_differences if difference.domain.find(
      "geometry.transform.",
    ) ==
    Some(0) => difference
  ]
}

///|
test "equivalent transform lists retain source semantics only" {
  let before = "<svg width='16' height='16'><rect id='box' x='1' y='1' width='4' height='4' transform='translate(1)'/></svg>"
  let after = "<svg width='16' height='16'><rect id='box' x='1' y='1' width='4' height='4' transform='matrix(1 0 0 1 1 0)'/></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  let differences = transform_differences(report)
  assert_eq(report.analysis_status, "complete")
  assert_eq(differences.length(), 1)
  assert_eq(differences[0].domain, "geometry.transform.list")
  assert_eq(differences[0].computed_relation.status, "equivalent")
  assert_eq(
    differences[0].computed_relation.reason_code,
    "same_local_transform_matrix",
  )
  assert_eq(differences[0].source_before, "translate(1)")
  assert_eq(differences[0].source_after, "matrix(1 0 0 1 1 0)")
  assert_eq(
    report.events.last().unwrap().rendered_outcome.magnitude.unwrap().changed_pixels,
    0,
  )
}

///|
test "local transform change reports its cumulative matrix" {
  let before = "<svg width='16' height='16'><rect id='box' x='1' y='1' width='4' height='4' transform='translate(1 0)'/></svg>"
  let after = "<svg width='16' height='16'><rect id='box' x='1' y='1' width='4' height='4' transform='translate(3 0)'/></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  let differences = transform_differences(report)
  assert_eq(differences.length(), 2)
  assert_eq(differences[0].domain, "geometry.transform.list")
  assert_eq(differences[0].computed_relation.status, "different")
  assert_eq(differences[1].domain, "geometry.transform.cumulative_matrix")
  assert_eq(differences[1].source_before, "matrix(1,0,0,1,1,0)")
  assert_eq(differences[1].source_after, "matrix(1,0,0,1,3,0)")
  assert_true(differences[1].parameter_delta_css_px is None)
  assert_true(differences[1].magnitude.parameter_abs_user_units is None)
  assert_eq(report.changed_facts.length(), 1)
}

///|
test "integer axis transforms are complete while general affine raster stays guarded" {
  let supported = compare(
    "<svg width='16' height='16'><rect id='box' width='4' height='4' transform='translate(1)'/></svg>",
    "<svg width='16' height='16'><rect id='box' width='4' height='4' transform='translate(3)'/></svg>",
    ComparisonProfile::v1_default(),
  )
  assert_eq(supported.analysis_status, "complete")
  let guarded = compare(
    "<svg width='16' height='16'><rect id='box' width='4' height='4' transform='skewX(10)'/></svg>",
    "<svg width='16' height='16'><rect id='box' width='4' height='4' transform='skewX(20)'/></svg>",
    ComparisonProfile::v1_default(),
  )
  assert_eq(guarded.analysis_status, "partial")
  assert_true(
    guarded.diagnostics.any(diagnostic => {
      diagnostic.code == "renderer_transform_raster_unproven" &&
      diagnostic.subject_id == "box" &&
      diagnostic.affected_evidence_layers == ["rendered_evidence"]
    }),
  )
  assert_true(
    guarded.atomic_differences.any(difference => {
      difference.domain == "geometry.transform.cumulative_matrix" &&
      difference.computed_relation.status == "different" &&
      !difference.computed_relation.diagnostic_ids.is_empty()
    }),
  )
}

///|
test "ancestor affine guard constrains each affected transform domain row" {
  let before = "<svg><g id='layer' transform='skewX(10)'><rect id='box' width='4' height='4'/></g></svg>"
  let after = "<svg><g id='layer' transform='skewX(20)'><rect id='box' width='4' height='4'/></g></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_true(
    report.coverage_matrix.any(row => {
      row.feature_id == "domain.geometry.transform.cumulative_matrix" &&
      row.subject_id == "alignment:0" &&
      row.rendered_evidence == "limited" &&
      !row.diagnostic_ids.is_empty()
    }),
  )
}

///|
test "compact signed transform numbers reach the renderer without partial parsing" {
  let source = "<svg width='16' height='16'><rect id='box' width='4' height='4' transform='translate(+.5-2E-1)'/></svg>"
  let report = compare(source, source, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "partial")
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "renderer_transform_raster_unproven"
    }),
  )
  assert_true(
    report.diagnostics.all(diagnostic => {
      diagnostic.code != "transform_syntax_unsupported"
    }),
  )
}

///|
test "group transform fact fans out to every affected subject" {
  let before = "<svg width='16' height='16'><g id='layer' transform='translate(1 0)'><rect id='a' width='2' height='2'/><rect id='b' x='4' width='2' height='2'/></g></svg>"
  let after = "<svg width='16' height='16'><g id='layer' transform='translate(2 0)'><rect id='a' width='2' height='2'/><rect id='b' x='4' width='2' height='2'/></g></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  let differences = transform_differences(report)
  assert_eq(differences.length(), 4)
  let transform_facts = [
    for fact in report.changed_facts if fact.property == "transform" => fact
  ]
  assert_eq(transform_facts.length(), 1)
  assert_eq(transform_facts[0].subject_id, "layer")
  assert_eq(transform_facts[0].affected_subject_ids, ["a", "b"])
  assert_true(
    differences.all(difference => {
      difference.changed_fact_ids == [transform_facts[0].id]
    }),
  )
}

///|
test "transform event keeps the complete scene mask until bounds are transform aware" {
  let before = "<svg width='16' height='16'><g transform='translate(1 0)'><rect id='box' x='2' y='4' width='5' height='5' fill='red'/></g></svg>"
  let after = "<svg width='16' height='16'><g transform='translate(5 0)'><rect id='box' x='2' y='4' width='5' height='5' fill='red'/></g></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  let event = report.events.last().unwrap()
  assert_eq(event.rendered_outcome.magnitude.unwrap().changed_pixels, 40)
  assert_eq(event.difference_regions.length(), 2)
  assert_eq(event.difference_regions.map(region => region.changed_pixels), [
    20, 20,
  ])
}

///|
test "nested groups and viewports accumulate root to element" {
  let source = "<svg transform='translate(1 0)'><g transform='scale(2)'><svg transform='translate(3 4)'><rect width='1' height='1'/></svg></g></svg>"
  let subject = extract_source_subjects_or_raise(source)[0]
  assert_eq(subject.cumulative_transform.signature(), "matrix(2,0,0,2,7,8)")
  assert_true(subject.transform_complete)
  assert_eq(subject.transform_chain.length(), 4)
}

///|
test "resource-container ancestry participates in cumulative transforms" {
  let source = "<svg><defs transform='translate(2 3)'><g transform='scale(2)'><rect id='resource-shape' width='1' height='1'/></g></defs></svg>"
  let subject = extract_source_subjects_or_raise(source)[0]
  assert_eq(subject.cumulative_transform.signature(), "matrix(2,0,0,2,2,3)")
  assert_eq(subject.transform_chain.length(), 4)
}

///|
test "malformed transform syntax remains partial and source located" {
  let source = "<svg><rect id='box' width='4' height='4' transform='translate(1,) '/></svg>"
  let report = compare(source, source, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "partial")
  assert_true(transform_differences(report).is_empty())
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "transform_syntax_unsupported" &&
      diagnostic.subject_id == "box" &&
      diagnostic.source_locations.length() == 2
    }),
  )
}

///|
test "identical malformed transform declarations do not create a false diff" {
  let source = "<svg><rect id='box' width='4' height='4' transform='translate(1,)'/></svg>"
  let report = compare(source, source, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "partial")
  assert_true(transform_differences(report).is_empty())
}

///|
test "different malformed transform declarations remain source reportable" {
  let before = "<svg><rect id='box' width='4' height='4' transform='translate(1,)'/></svg>"
  let after = "<svg><rect id='box' width='4' height='4' transform='translate(2,)'/></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  let differences = transform_differences(report)
  assert_eq(report.analysis_status, "partial")
  assert_eq(differences.length(), 1)
  assert_eq(differences[0].domain, "geometry.transform.list")
  assert_eq(differences[0].computed_relation.status, "indeterminate")
  assert_true(differences[0].computed_relation.diagnostic_ids.length() > 0)
  assert_true(
    differences[0].computed_relation.diagnostic_ids.all(id => {
      report.diagnostics.any(diagnostic => {
        diagnostic.id == id && diagnostic.subject_id == "box"
      })
    }),
  )
}

///|
test "resource transform syntax remains reportable behind its coverage guard" {
  let before = "<svg><defs><linearGradient id='paint' gradientTransform='translate(1)'><stop offset='0' stop-color='red'/></linearGradient></defs></svg>"
  let after = "<svg><defs><linearGradient id='paint' gradientTransform='matrix(1 0 0 1 1 0)'><stop offset='0' stop-color='red'/></linearGradient></defs></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  let differences = [
    for difference in report.atomic_differences if difference.domain.find(
      "resource.transform.",
    ) ==
    Some(0) => difference
  ]
  assert_eq(report.analysis_status, "partial")
  assert_eq(differences.length(), 1)
  assert_eq(differences[0].subject_role, "resource")
  assert_eq(differences[0].computed_relation.status, "equivalent")
  assert_eq(differences[0].changed_fact_ids.length(), 1)
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "resource_transform_semantics_unsupported" &&
      diagnostic.subject_id == "paint" &&
      diagnostic.source_locations.length() == 2
    }),
  )
}

///|
test "resource transform matrix changes remain numeric but not scored" {
  let before = "<svg><defs><linearGradient id='paint' gradientTransform='translate(1)'/></defs></svg>"
  let after = "<svg><defs><linearGradient id='paint' gradientTransform='translate(3)'/></defs></svg>"
  let differences = [
    for
      difference in compare(before, after, ComparisonProfile::v1_default()).atomic_differences if difference.domain.find(
      "resource.transform.",
    ) ==
    Some(0) => difference
  ]
  assert_eq(differences.length(), 2)
  assert_eq(differences[1].domain, "resource.transform.matrix")
  assert_eq(differences[1].source_before, "matrix(1,0,0,1,1,0)")
  assert_eq(differences[1].source_after, "matrix(1,0,0,1,3,0)")
  assert_true(differences[1].parameter_delta_css_px is None)
  assert_true(differences[1].magnitude.parameter_abs_user_units is None)
}

///|
test "anonymous resource transform differences retain their coverage guard" {
  let before = "<svg><defs><linearGradient gradientTransform='translate(1)'/></defs></svg>"
  let after = "<svg><defs><linearGradient gradientTransform='translate(2)'/></defs></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "partial")
  assert_true(
    report.diagnostics.all(diagnostic => {
      diagnostic.code != "coverage_proof_incomplete"
    }),
  )
  assert_true(
    report.atomic_differences.any(difference => {
      difference.domain == "resource.transform.matrix" &&
      !difference.computed_relation.diagnostic_ids.is_empty()
    }),
  )
}

///|
test "pattern transform is retained while pattern semantics remain unsupported" {
  let before = "<svg><defs><pattern id='tile' patternTransform='scale(1)'/></defs></svg>"
  let after = "<svg><defs><pattern id='tile' patternTransform='scale(2)'/></defs></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_true(
    report.atomic_differences.any(difference => {
      difference.domain == "resource.transform.matrix" &&
      difference.source_before == "matrix(1,0,0,1,0,0)" &&
      difference.source_after == "matrix(2,0,0,2,0,0)"
    }),
  )
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "unsupported_visual_subject" &&
      diagnostic.subject_id == "pattern"
    }),
  )
  assert_true(
    report.diagnostics.all(diagnostic => {
      diagnostic.code != "coverage_proof_incomplete"
    }),
  )
}

///|
test "radial gradient transform remains reportable behind resource guards" {
  let before = "<svg><defs><radialGradient id='paint' gradientTransform='translate(1)'/></defs></svg>"
  let after = "<svg><defs><radialGradient id='paint' gradientTransform='translate(2)'/></defs></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_true(
    report.atomic_differences.any(difference => {
      difference.domain == "resource.transform.matrix" &&
      difference.source_before == "matrix(1,0,0,1,1,0)" &&
      difference.source_after == "matrix(1,0,0,1,2,0)"
    }),
  )
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "resource_transform_semantics_unsupported" &&
      diagnostic.subject_id == "paint"
    }),
  )
}
