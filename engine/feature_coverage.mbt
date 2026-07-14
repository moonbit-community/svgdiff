///|
fn coverage_diagnostics_for_subject(
  report : StructuredReport,
  subject_id : String,
  subject_kind : String,
) -> Array[Diagnostic] {
  [
    for diagnostic in report.diagnostics if diagnostic.subject_id == "document" ||
    diagnostic.subject_id == subject_id ||
    diagnostic.subject_id == subject_kind => diagnostic
  ]
}

///|
fn coverage_diagnostic_ids(diagnostics : Array[Diagnostic]) -> Array[String] {
  let ids = [ for diagnostic in diagnostics => diagnostic.id ]
  ids.sort()
  ids
}

///|
fn coverage_status_for_layer(
  diagnostics : Array[Diagnostic],
  layer : String,
  default_status : String,
) -> String {
  if diagnostics.any(diagnostic => {
      diagnostic.affected_evidence_layers.contains(layer)
    }) {
    "limited"
  } else {
    default_status
  }
}

///|
fn add_feature_coverage(
  matrix : Array[FeatureCoverage],
  entry : FeatureCoverage,
) -> Unit {
  for index, current in matrix {
    if current.feature_id == entry.feature_id &&
      current.subject_id == entry.subject_id {
      let diagnostic_ids = current.diagnostic_ids.copy()
      for id in entry.diagnostic_ids {
        if !diagnostic_ids.contains(id) {
          diagnostic_ids.push(id)
        }
      }
      diagnostic_ids.sort()
      fn merged_status(left : String, right : String) -> String {
        if left == "failed" || right == "failed" {
          "failed"
        } else if left == "limited" || right == "limited" {
          "limited"
        } else if left == "covered" || right == "covered" {
          "covered"
        } else {
          "not_applicable"
        }
      }
      matrix[index] = {
        ..current,
        source_semantics: merged_status(
          current.source_semantics,
          entry.source_semantics,
        ),
        computed_appearance: merged_status(
          current.computed_appearance,
          entry.computed_appearance,
        ),
        rendered_evidence: merged_status(
          current.rendered_evidence,
          entry.rendered_evidence,
        ),
        diagnostic_ids,
      }
      return
    }
  }
  matrix.push(entry)
}

///|
fn add_source_subject_coverage(
  matrix : Array[FeatureCoverage],
  report : StructuredReport,
  subject : SourceSubject,
) -> Unit {
  let subject_id = source_subject_id(subject)
  let diagnostics = coverage_diagnostics_for_subject(
    report,
    subject_id,
    subject.kind,
  )
  let diagnostic_ids = coverage_diagnostic_ids(diagnostics)
  let source_status = coverage_status_for_layer(
    diagnostics, "source_semantics", "covered",
  )
  let computed_status = coverage_status_for_layer(
    diagnostics, "computed_appearance", "covered",
  )
  let rendered_status = coverage_status_for_layer(
    diagnostics, "rendered_evidence", "covered",
  )
  add_feature_coverage(matrix, {
    feature_id: "subject.\{subject.kind}",
    subject_id,
    source_semantics: source_status,
    computed_appearance: computed_status,
    rendered_evidence: rendered_status,
    diagnostic_ids,
  })
  for fact in subject.facts {
    add_feature_coverage(matrix, {
      feature_id: "property.\{fact.property}",
      subject_id,
      source_semantics: source_status,
      computed_appearance: computed_status,
      rendered_evidence: rendered_status,
      diagnostic_ids,
    })
  }
}

///|
fn difference_subject_id(
  report : StructuredReport,
  difference : AtomicDifference,
) -> String {
  for event in report.events {
    if event.atomic_difference_ids.contains(difference.id) {
      return event.primary_subject_id
    }
  }
  difference.subject_alignment_id.unwrap_or("unattributed")
}

///|
fn difference_rendered_status(
  report : StructuredReport,
  difference_id : String,
) -> String {
  for event in report.events {
    if event.atomic_difference_ids.contains(difference_id) {
      return if event.rendered_outcome.status == "computed" {
        "covered"
      } else {
        "limited"
      }
    }
  }
  "not_applicable"
}

///|
fn add_difference_coverage(
  matrix : Array[FeatureCoverage],
  report : StructuredReport,
  difference : AtomicDifference,
) -> Unit {
  let subject_id = difference_subject_id(report, difference)
  let diagnostics = coverage_diagnostics_for_subject(
    report, subject_id, subject_id,
  )
  for diagnostic in report.diagnostics {
    if difference.computed_relation.diagnostic_ids.contains(diagnostic.id) &&
      !diagnostics.any(current => current.id == diagnostic.id) {
      diagnostics.push(diagnostic)
    }
  }
  let source_default = if difference.evidence_layers.contains(
      "source_semantics",
    ) {
    "covered"
  } else {
    "not_applicable"
  }
  let computed_default = if difference.computed_relation.status ==
    "indeterminate" {
    "limited"
  } else {
    "covered"
  }
  add_feature_coverage(matrix, {
    feature_id: "domain.\{difference.domain}",
    subject_id,
    source_semantics: coverage_status_for_layer(
      diagnostics, "source_semantics", source_default,
    ),
    computed_appearance: coverage_status_for_layer(
      diagnostics, "computed_appearance", computed_default,
    ),
    rendered_evidence: coverage_status_for_layer(
      diagnostics,
      "rendered_evidence",
      difference_rendered_status(report, difference.id),
    ),
    diagnostic_ids: coverage_diagnostic_ids(diagnostics),
  })
}

///|
fn add_guard_coverage(
  matrix : Array[FeatureCoverage],
  diagnostic : Diagnostic,
) -> Unit {
  fn status(layer : String) -> String {
    if diagnostic.affected_evidence_layers.contains(layer) {
      "limited"
    } else {
      "not_applicable"
    }
  }
  add_feature_coverage(matrix, {
    feature_id: "guard.\{diagnostic.code}",
    subject_id: diagnostic.subject_id,
    source_semantics: status("source_semantics"),
    computed_appearance: status("computed_appearance"),
    rendered_evidence: status("rendered_evidence"),
    diagnostic_ids: [diagnostic.id],
  })
}

///|
fn summarized_analysis_status(matrix : Array[FeatureCoverage]) -> String {
  if matrix.any(entry => {
      entry.source_semantics == "failed" ||
      entry.computed_appearance == "failed" ||
      entry.rendered_evidence == "failed"
    }) {
    "failed"
  } else if matrix.any(entry => {
      entry.source_semantics == "limited" ||
      entry.computed_appearance == "limited" ||
      entry.rendered_evidence == "limited"
    }) {
    "partial"
  } else {
    "complete"
  }
}

///|
fn attach_feature_coverage(
  report : StructuredReport,
  before_svg : String,
  after_svg : String,
) -> StructuredReport {
  if report.analysis_status == "failed" {
    return report
  }
  let matrix : Array[FeatureCoverage] = [
    {
      feature_id: "document.xml",
      subject_id: "document",
      source_semantics: "covered",
      computed_appearance: "not_applicable",
      rendered_evidence: "not_applicable",
      diagnostic_ids: [],
    },
  ]
  let before_subjects = extract_source_subjects_or_raise(before_svg) catch {
    _ => []
  }
  let after_subjects = extract_source_subjects_or_raise(after_svg) catch {
    _ => []
  }
  for subject in before_subjects {
    add_source_subject_coverage(matrix, report, subject)
  }
  for subject in after_subjects {
    add_source_subject_coverage(matrix, report, subject)
  }
  for difference in report.atomic_differences {
    add_difference_coverage(matrix, report, difference)
  }
  for diagnostic in report.diagnostics {
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
  }
}
