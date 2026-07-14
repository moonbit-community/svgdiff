///|
test "complete report exposes covered feature rows at each evidence layer" {
  let report = @engine.compare(
    "<svg width='16' height='16'><rect id='box' width='8' height='8' fill='red'/></svg>",
    "<svg width='16' height='16'><rect id='box' width='8' height='8' fill='blue'/></svg>",
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "complete")
  assert_true(
    report.coverage_matrix.any(row => {
      row.feature_id == "subject.rect" &&
      row.subject_id == "box" &&
      row.source_semantics == "covered" &&
      row.computed_appearance == "covered" &&
      row.rendered_evidence == "covered" &&
      row.diagnostic_ids.is_empty()
    }),
  )
  assert_true(
    report.coverage_matrix.any(row => {
      row.feature_id == "domain.paint.fill" &&
      row.source_semantics == "covered" &&
      row.computed_appearance == "covered" &&
      row.rendered_evidence == "covered"
    }),
  )
  assert_false(
    report.coverage_matrix.any(row => {
      row.source_semantics == "limited" ||
      row.computed_appearance == "limited" ||
      row.rendered_evidence == "limited"
    }),
  )
}

///|
test "partial report identifies each limited evidence layer" {
  let report = @engine.compare(
    "<svg width='16' height='16'><path d='M0 0 L8 8'/></svg>",
    "<svg width='16' height='16'><path d='M0 0 L9 9'/></svg>",
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "partial")
  assert_true(
    report.coverage_matrix.any(row => {
      row.feature_id == "guard.unsupported_visual_subject" &&
      row.subject_id == "path" &&
      row.source_semantics == "not_applicable" &&
      row.computed_appearance == "limited" &&
      row.rendered_evidence == "limited" &&
      row.diagnostic_ids == ["diagnostic:unsupported-visual-subject:path"]
    }),
  )
}

///|
test "failed report marks every evidence layer failed" {
  let report = @engine.compare(
    "<svg><rect></svg>",
    "<svg/>",
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "failed")
  assert_eq(report.coverage_matrix.length(), 1)
  let row = report.coverage_matrix[0]
  assert_eq(row.feature_id, "document.xml")
  assert_eq(row.source_semantics, "failed")
  assert_eq(row.computed_appearance, "failed")
  assert_eq(row.rendered_evidence, "failed")
  assert_eq(row.diagnostic_ids, ["diagnostic:svg-parse-failed:document"])
}

///|
test "one feature row retains every diagnostic for its subject" {
  let source = "<svg width='16' height='16'><rect id='box' width='8' height='8' fill='red' stroke='red' style='fill:blue;stroke:blue;unknown:value'/></svg>"
  let report = @engine.compare(
    source,
    source,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "partial")
  assert_true(
    report.coverage_matrix.any(row => {
      row.feature_id == "guard.renderer_style_precedence_unresolved" &&
      row.subject_id == "box" &&
      row.computed_appearance == "limited" &&
      row.rendered_evidence == "limited" &&
      row.diagnostic_ids ==
      [
        "diagnostic:renderer-style-precedence-unresolved:box:fill", "diagnostic:renderer-style-precedence-unresolved:box:stroke",
      ]
    }),
  )
}
