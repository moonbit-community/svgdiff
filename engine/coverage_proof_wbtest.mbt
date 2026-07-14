///|
fn proof_test_svg(fill : String) -> String {
  "<svg width='16' height='16'><rect id='box' x='2' y='2' width='8' height='8' fill='\{fill}'/></svg>"
}

///|
fn proof_matrix_without(
  matrix : Array[FeatureCoverage],
  feature_id : String,
) -> Array[FeatureCoverage] {
  let result : Array[FeatureCoverage] = []
  for row in matrix {
    if row.feature_id != feature_id {
      result.push(row)
    }
  }
  result
}

///|
test "missing domain coverage prevents a complete report" {
  let before = proof_test_svg("red")
  let after = proof_test_svg("blue")
  let report = compare(before, after, ComparisonProfile::v1_default())
  let incomplete = {
    ..report,
    coverage_matrix: proof_matrix_without(
      report.coverage_matrix,
      "domain.paint.fill",
    ),
  }
  let enforced = enforce_coverage_proof(incomplete, before, after)
  assert_eq(enforced.analysis_status, "partial")
  assert_true(
    enforced.diagnostics.any(diagnostic => {
      diagnostic.code == "coverage_proof_incomplete" &&
      diagnostic.id.contains("domain_row_missing")
    }),
  )
  assert_true(
    enforced.coverage_matrix.any(row => {
      row.feature_id == "guard.coverage_proof_incomplete" &&
      row.source_semantics == "limited" &&
      row.computed_appearance == "limited" &&
      row.rendered_evidence == "limited"
    }),
  )
}

///|
test "missing encountered property coverage prevents complete equality" {
  let source = proof_test_svg("red")
  let report = compare(source, source, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "complete")
  let incomplete = {
    ..report,
    coverage_matrix: proof_matrix_without(
      report.coverage_matrix,
      "property.fill",
    ),
  }
  let enforced = enforce_coverage_proof(incomplete, source, source)
  assert_eq(enforced.analysis_status, "partial")
  assert_true(
    enforced.diagnostics.any(diagnostic => {
      diagnostic.code == "coverage_proof_incomplete" &&
      diagnostic.id.contains("property_row_missing")
    }),
  )
}

///|
test "current complete partial and failed reports satisfy coverage proof" {
  let complete_before = proof_test_svg("red")
  let complete_after = proof_test_svg("blue")
  let complete = compare(
    complete_before,
    complete_after,
    ComparisonProfile::v1_default(),
  )
  assert_eq(
    coverage_proof_failures(complete, complete_before, complete_after),
    [],
  )
  let partial_before = "<svg><path d='M0 0 L8 8'/></svg>"
  let partial_after = "<svg><path d='M0 0 L9 9'/></svg>"
  let partial = compare(
    partial_before,
    partial_after,
    ComparisonProfile::v1_default(),
  )
  assert_eq(coverage_proof_failures(partial, partial_before, partial_after), [])
  let failed_before = "<svg><rect></svg>"
  let failed_after = "<svg/>"
  let failed = compare(
    failed_before,
    failed_after,
    ComparisonProfile::v1_default(),
  )
  assert_eq(coverage_proof_failures(failed, failed_before, failed_after), [])
}
