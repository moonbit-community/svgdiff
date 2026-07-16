///|
fn path_domain_differences(
  report : StructuredReport,
) -> Array[AtomicDifference] {
  [
    for difference in report.atomic_differences if difference.domain.find(
      "geometry.path.",
    ) ==
    Some(0) => difference
  ]
}

///|
test "path geometry enumerates exact normalized parameter differences" {
  let before = "<svg width='16' height='16'><path id='shape' d='M1 1L5 5'/></svg>"
  let after = "<svg width='16' height='16'><path id='shape' d='M1 1L6 7'/></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  let differences = path_domain_differences(report)
  assert_eq(differences.length(), 2)
  assert_eq(differences[0].source_before, "5")
  assert_eq(differences[0].source_after, "6")
  assert_eq(differences[0].parameter_delta_css_px, Some(1.0))
  assert_eq(differences[0].magnitude.parameter_abs_user_units, Some(1.0))
  assert_eq(differences[0].magnitude.parameter_signed_user_units, Some(1.0))
  assert_eq(differences[1].source_before, "5")
  assert_eq(differences[1].source_after, "7")
  assert_eq(differences[1].parameter_delta_css_px, Some(2.0))
  assert_eq(differences[1].magnitude.parameter_abs_user_units, Some(2.0))
  assert_eq(report.analysis_status, "partial")
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "unsupported_visual_subject" &&
      diagnostic.subject_id == "path"
    }),
  )
}

///|
test "diagonal path pixels use visual eight-neighbor connectivity" {
  let before = "<svg width='16' height='16'><path d='M2 2L14 14' fill='none' stroke='black'/></svg>"
  let after = "<svg width='16' height='16'><path d='M2 14L14 2' fill='none' stroke='black'/></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_eq(report.events.length(), 1)
  assert_eq(report.events[0].difference_regions.length(), 4)
  assert_true(
    report.events[0].difference_regions.all(region => region.changed_pixels > 1),
  )
}

///|
test "path command variants retain computed-equivalent source differences" {
  let before = "<svg><path d='M1 1H8V8Z'/></svg>"
  let after = "<svg><path d='M1 1L8 1L8 8Z'/></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  let differences = path_domain_differences(report)
  assert_eq(differences.length(), 2)
  assert_true(
    differences.all(difference => {
      difference.domain == "geometry.path.command" &&
      difference.computed_relation.status == "equivalent" &&
      difference.computed_relation.reason_code == "same_normalized_path_segment" &&
      difference.magnitude.parameter_abs_user_units is None &&
      difference.magnitude.geometry_displacement_css_px == Some(0.0)
    }),
  )
  assert_eq(differences[0].source_before, "H")
  assert_eq(differences[0].source_after, "L")
  assert_eq(differences[1].source_before, "V")
  assert_eq(differences[1].source_after, "L")
}

///|
test "path whitespace and numeric spelling do not create differences" {
  let before = "<svg><path d='M 1 1 L 8 1'/></svg>"
  let after = "<svg><path d='M1.0,1.00L8.0 1e0'/></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_true(path_domain_differences(report).is_empty())
  assert_eq(report.analysis_status, "partial")
}

///|
test "path topology changes retain deterministic segment evidence" {
  let before = "<svg><path d='M1 1L8 1Z'/></svg>"
  let after = "<svg><path d='M1 1Q4 4 8 1L8 8Z'/></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  let differences = path_domain_differences(report)
  assert_eq(differences.length(), 2)
  assert_eq(differences[0].domain, "geometry.path.structure")
  assert_eq(
    differences[0].computed_relation.reason_code,
    "path_segment_inserted",
  )
  assert_eq(differences[1].domain, "geometry.path.parameter")
  assert_eq(
    differences[1].computed_relation.reason_code,
    "path_segment_parameters_differ",
  )
}

///|
test "path sequence alignment preserves equal repeated segment geometry" {
  let before = "<svg><path d='M1 1L2 2L3 3'/></svg>"
  let after = "<svg><path d='M1 1L9 9L2 2L3 3'/></svg>"
  let differences = path_domain_differences(
    compare(before, after, ComparisonProfile::v1_default()),
  )
  assert_eq(differences.length(), 1)
  assert_eq(differences[0].domain, "geometry.path.structure")
  assert_eq(
    differences[0].computed_relation.reason_code,
    "path_segment_inserted",
  )
  assert_eq(differences[0].source_after, "L 9 9")
}

///|
test "painted path boundary uses symmetric maximum pixel distance" {
  let before = "<svg width='16' height='16'><path d='M1 1H5V5H1Z'/></svg>"
  let after = "<svg width='16' height='16'><path d='M3 1H7V5H3Z'/></svg>"
  let before_subjects = extract_source_subjects_or_raise(before)
  let after_subjects = extract_source_subjects_or_raise(after)
  assert_eq(
    isolated_painted_boundary_displacement_distribution(
      before_subjects[0],
      after_subjects[0],
      ComparisonProfile::v1_default(),
    ).map(distribution => distribution.max_css_px),
    Some(2.0),
  )
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_true(
    path_domain_differences(report).all(difference => {
      difference.magnitude.geometry_displacement_css_px == Some(2.0) &&
      difference.magnitude.painted_boundary_displacement.map(distribution => {
        distribution.max_css_px
      }) ==
      Some(2.0)
    }),
  )
}

///|
test "painted path boundary distinguishes zero from unavailable" {
  let empty_before = extract_source_subjects_or_raise(
      "<svg><path d='M1 1H5V5H1Z' fill='none' stroke='none'/></svg>",
    )[0]
  let empty_after = extract_source_subjects_or_raise(
      "<svg><path d='M2 1H6V5H2Z' fill='none' stroke='none'/></svg>",
    )[0]
  let painted = extract_source_subjects_or_raise(
      "<svg><path d='M2 1H6V5H2Z' fill='black'/></svg>",
    )[0]
  let profile = ComparisonProfile::v1_default()
  assert_eq(
    isolated_painted_boundary_displacement_distribution(
      empty_before, empty_after, profile,
    ).map(distribution => distribution.max_css_px),
    Some(0.0),
  )
  assert_true(
    isolated_painted_boundary_displacement_distribution(
      empty_before, painted, profile,
    )
    is None,
  )
}

///|
test "path boundary work budget preserves explicit measurement absence" {
  let before = extract_source_subjects_or_raise(
      "<svg><path d='M1 1H5V5H1Z'/></svg>",
    )[0]
  let after = extract_source_subjects_or_raise(
      "<svg><path d='M2 1H6V5H2Z'/></svg>",
    )[0]
  let profile = ComparisonProfile::v1_default()
  let budget = PathBoundaryBudget::new()
  for _ in 0..<64 {
    assert_true(budget.measure(before, after, profile) is Some(_))
  }
  assert_true(budget.measure(before, after, profile) is None)
}

///|
test "path alignment uses normalized geometry instead of source order" {
  let before = "<svg><path d='M1 1L2 2'/><path d='M10 10L12 12'/></svg>"
  let after = "<svg><path d='M10 10L13 13'/><path d='M1 1L3 3'/></svg>"
  let alignments = compare(before, after, ComparisonProfile::v1_default()).subject_alignments
  assert_eq(alignments.length(), 2)
  assert_eq(alignments[0].before[0].source_index, 0)
  assert_eq(alignments[0].after[0].source_index, 1)
  assert_eq(alignments[1].before[0].source_index, 1)
  assert_eq(alignments[1].after[0].source_index, 0)
}

///|
test "tiny path parameters remain exact across boundary quantization" {
  let before = "<svg width='16' height='16'><path d='M1 1L8 1L8 8Z'/></svg>"
  let after = "<svg width='16' height='16'><path d='M0.99999 1L8 1L8 8Z'/></svg>"
  let differences = path_domain_differences(
    compare(before, after, ComparisonProfile::v1_default()),
  )
  assert_eq(differences.length(), 1)
  assert_true(
    (differences[0].magnitude.parameter_abs_user_units.unwrap() - 0.00001).abs() <
    0.000000000001,
  )
  assert_true(differences[0].magnitude.geometry_displacement_css_px is Some(_))
  assert_true(
    differences[0].magnitude.geometry_displacement_css_px !=
    differences[0].magnitude.parameter_abs_user_units,
  )
}

///|
test "path coordinate parameters expose exact transformed scales" {
  let before = "<svg width='16' height='16'><path d='M1 1L4 1L4 4Z' transform='scale(2)'/></svg>"
  let after = "<svg width='16' height='16'><path d='M2 1L4 1L4 4Z' transform='scale(2)'/></svg>"
  let differences = path_domain_differences(
    compare(before, after, ComparisonProfile::v1_default()),
  )
  assert_eq(differences.length(), 1)
  assert_eq(differences[0].magnitude.parameter_abs_user_units, Some(1.0))
  assert_eq(differences[0].magnitude.parameter_abs_css_px, Some(2.0))
  assert_eq(
    differences[0].magnitude.parameter_viewport_fraction,
    Some(0.08838834764831843),
  )
  assert_true(
    (differences[0].magnitude.parameter_entity_fraction.unwrap() -
    0.23570226039551587).abs() <
    0.000000000000001,
  )
}

///|
test "path arc radii expose spatial scales while rotation remains angular" {
  let radius = path_domain_differences(
      compare(
        "<svg width='16' height='16'><path d='M1 1A2 3 0 0 0 8 8' transform='scale(2)'/></svg>",
        "<svg width='16' height='16'><path d='M1 1A3 3 0 0 0 8 8' transform='scale(2)'/></svg>",
        ComparisonProfile::v1_default(),
      ),
    )[0]
  assert_eq(radius.magnitude.parameter_abs_user_units, Some(1.0))
  assert_eq(radius.magnitude.parameter_abs_css_px, Some(2.0))
  assert_true(radius.magnitude.parameter_viewport_fraction is Some(_))
  assert_true(radius.magnitude.parameter_entity_fraction is None)
  let rotation = path_domain_differences(
      compare(
        "<svg width='16' height='16'><path d='M1 1A2 3 0 0 0 8 8' transform='scale(2)'/></svg>",
        "<svg width='16' height='16'><path d='M1 1A2 3 10 0 0 8 8' transform='scale(2)'/></svg>",
        ComparisonProfile::v1_default(),
      ),
    )[0]
  assert_eq(rotation.magnitude.parameter_abs_user_units, Some(10.0))
  assert_true(rotation.magnitude.parameter_abs_css_px is None)
  assert_true(rotation.magnitude.parameter_viewport_fraction is None)
  assert_true(rotation.magnitude.parameter_entity_fraction is None)
}
