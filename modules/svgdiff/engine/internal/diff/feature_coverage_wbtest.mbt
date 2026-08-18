// Copyright 2026 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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

///|
test "visual scene failure becomes an explicit partial coverage limitation" {
  let source = "<svg><rect id='box' width='10' height='10'/></svg>"
  let report = compare(source, source, ComparisonProfile::v1_default())
  let limited = attach_visual_scene_limitation(report)
  assert_eq(limited.analysis_status, "partial")
  assert_true(
    limited.diagnostics.any(diagnostic => {
      diagnostic.code == "visual_scene_analysis_unavailable" &&
      diagnostic.subject_id == "document"
    }),
  )
  assert_true(
    limited.coverage_matrix.any(row => {
      row.feature_id == "document.visual_scene" &&
      row.source_semantics == "limited" &&
      row.computed_appearance == "limited" &&
      row.rendered_evidence == "not_applicable"
    }),
  )
  assert_eq(coverage_proof_failures(limited, source, source), [])
}
