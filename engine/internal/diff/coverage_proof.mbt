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
fn add_coverage_proof_failure(
  failures : Array[String],
  failure : String,
) -> Unit {
  if !failures.contains(failure) {
    failures.push(failure)
  }
}

///|
fn valid_coverage_status(status : String) -> Bool {
  status == "covered" ||
  status == "limited" ||
  status == "not_applicable" ||
  status == "failed"
}

///|
fn coverage_layer_status(row : FeatureCoverage, layer : String) -> String {
  match layer {
    "source_semantics" => row.source_semantics
    "computed_appearance" => row.computed_appearance
    "rendered_evidence" => row.rendered_evidence
    _ => "invalid"
  }
}

///|
fn find_coverage_row(
  report : StructuredReport,
  feature_id : String,
  subject_id : String,
) -> FeatureCoverage? {
  for row in report.coverage_matrix {
    if row.feature_id == feature_id && row.subject_id == subject_id {
      return Some(row)
    }
  }
  None
}

///|
fn coverage_reference_subject_id(reference : SubjectReference) -> String {
  match reference.instance_context {
    Some(context) => context.instance_id
    None =>
      reference.authored_id.unwrap_or(
        "\{reference.kind}:\{reference.source_index}",
      )
  }
}

///|
fn validate_coverage_rows(
  report : StructuredReport,
  failures : Array[String],
) -> Unit {
  if report.coverage_matrix.is_empty() {
    add_coverage_proof_failure(failures, "matrix_empty")
    return
  }
  if find_coverage_row(report, "document.xml", "document") is None {
    add_coverage_proof_failure(failures, "document_row_missing")
  }
  for row in report.coverage_matrix {
    for
      layer in ["source_semantics", "computed_appearance", "rendered_evidence"] {
      let status = coverage_layer_status(row, layer)
      if !valid_coverage_status(status) {
        add_coverage_proof_failure(
          failures,
          "invalid_status:\{row.feature_id}:\{row.subject_id}:\{layer}",
        )
      }
      if status == "limited" || status == "failed" {
        let justified = report.diagnostics.any(diagnostic => {
          row.diagnostic_ids.contains(diagnostic.id) &&
          diagnostic.affected_evidence_layers.contains(layer)
        })
        if !justified {
          add_coverage_proof_failure(
            failures,
            "unjustified_cell:\{row.feature_id}:\{row.subject_id}:\{layer}",
          )
        }
      }
    }
    for id in row.diagnostic_ids {
      if !report.diagnostics.any(diagnostic => diagnostic.id == id) {
        add_coverage_proof_failure(
          failures,
          "unknown_diagnostic:\{row.feature_id}:\{row.subject_id}:\{id}",
        )
      }
    }
  }
  for diagnostic in report.diagnostics {
    if !report.coverage_matrix.any(row => {
        row.diagnostic_ids.contains(diagnostic.id)
      }) {
      add_coverage_proof_failure(
        failures,
        "unreferenced_diagnostic:\{diagnostic.id}",
      )
    }
    for layer in diagnostic.affected_evidence_layers {
      let witnessed = report.coverage_matrix.any(row => {
        row.diagnostic_ids.contains(diagnostic.id) &&
        (
          coverage_layer_status(row, layer) == "limited" ||
          coverage_layer_status(row, layer) == "failed"
        )
      })
      if !witnessed {
        add_coverage_proof_failure(
          failures,
          "unwitnessed_diagnostic_layer:\{diagnostic.id}:\{layer}",
        )
      }
    }
  }
  if summarized_analysis_status(report.coverage_matrix) !=
    report.analysis_status {
    add_coverage_proof_failure(failures, "analysis_status_mismatch")
  }
}

///|
fn validate_subject_and_property_coverage(
  report : StructuredReport,
  before_svg : String,
  after_svg : String,
  failures : Array[String],
) -> Unit {
  let before_subjects = extract_source_subjects_with_profile_or_raise(
    before_svg,
    report.profile,
  ) catch {
    _ => {
      add_coverage_proof_failure(failures, "before_subject_inventory_failed")
      []
    }
  }
  let after_subjects = extract_source_subjects_with_profile_or_raise(
    after_svg,
    report.profile,
  ) catch {
    _ => {
      add_coverage_proof_failure(failures, "after_subject_inventory_failed")
      []
    }
  }
  for subject in before_subjects + after_subjects {
    let subject_id = source_subject_id(subject)
    if find_coverage_row(report, "subject.\{subject.kind}", subject_id) is None {
      add_coverage_proof_failure(
        failures,
        "subject_row_missing:\{subject.kind}:\{subject_id}",
      )
    }
    for fact in subject.facts {
      if find_coverage_row(report, "property.\{fact.property}", subject_id)
        is None {
        add_coverage_proof_failure(
          failures,
          "property_row_missing:\{fact.property}:\{subject_id}",
        )
      }
    }
  }
  for alignment in report.subject_alignments {
    for reference in alignment.before + alignment.after {
      let subject_id = coverage_reference_subject_id(reference)
      if find_coverage_row(report, "subject.\{reference.kind}", subject_id)
        is None {
        add_coverage_proof_failure(
          failures,
          "aligned_subject_row_missing:\{reference.kind}:\{subject_id}",
        )
      }
    }
  }
}

///|
fn validate_difference_coverage(
  report : StructuredReport,
  failures : Array[String],
) -> Unit {
  for difference in report.atomic_differences {
    let subject_id = difference_subject_id(report, difference)
    match find_coverage_row(report, "domain.\{difference.domain}", subject_id) {
      Some(row) => {
        if difference.computed_relation.status == "indeterminate" &&
          row.computed_appearance != "limited" {
          add_coverage_proof_failure(
            failures,
            "indeterminate_computed_cell:\{difference.id}",
          )
        }
        let rendered_status = difference_rendered_status(report, difference.id)
        if rendered_status == "limited" && row.rendered_evidence != "limited" {
          add_coverage_proof_failure(
            failures,
            "unavailable_rendered_cell:\{difference.id}",
          )
        }
      }
      None =>
        add_coverage_proof_failure(
          failures,
          "domain_row_missing:\{difference.id}",
        )
    }
  }
}

///|
fn coverage_proof_failures(
  report : StructuredReport,
  before_svg : String,
  after_svg : String,
) -> Array[String] {
  let failures : Array[String] = []
  validate_coverage_rows(report, failures)
  if report.analysis_status != "failed" {
    validate_subject_and_property_coverage(
      report, before_svg, after_svg, failures,
    )
    validate_difference_coverage(report, failures)
  }
  failures.sort()
  failures
}

///|
fn enforce_coverage_proof(
  report : StructuredReport,
  before_svg : String,
  after_svg : String,
) -> StructuredReport {
  let failures = coverage_proof_failures(report, before_svg, after_svg)
  if failures.is_empty() {
    return report
  }
  let diagnostics = report.diagnostics.copy()
  let matrix = report.coverage_matrix.copy()
  for failure in failures {
    let diagnostic = unlocated_diagnostic(
      "diagnostic:coverage-proof-incomplete:\{failure}",
      "coverage_proof_incomplete",
      "document",
      ["source_semantics", "computed_appearance", "rendered_evidence"],
    )
    diagnostics.push(diagnostic)
    add_guard_coverage(matrix, diagnostic)
  }
  matrix.sort_by(fn(left, right) {
    let feature_order = left.feature_id.compare(right.feature_id)
    if feature_order != 0 {
      feature_order
    } else {
      left.subject_id.compare(right.subject_id)
    }
  })
  {
    ..report,
    analysis_status: summarized_analysis_status(matrix),
    coverage_matrix: matrix,
    diagnostics,
  }
}
