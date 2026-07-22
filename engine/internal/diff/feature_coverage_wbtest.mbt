///|
fn coverage_row(status : String) -> FeatureCoverage {
  {
    feature_id: "test.feature",
    subject_id: "test",
    source_semantics: status,
    computed_appearance: "not_applicable",
    rendered_evidence: "not_applicable",
    diagnostic_ids: [],
  }
}

///|
test "analysis status is summarized from the strongest coverage cell" {
  assert_eq(summarized_analysis_status([coverage_row("covered")]), "complete")
  assert_eq(summarized_analysis_status([coverage_row("limited")]), "partial")
  assert_eq(
    summarized_analysis_status([coverage_row("limited"), coverage_row("failed")]),
    "failed",
  )
}
