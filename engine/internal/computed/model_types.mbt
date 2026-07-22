///|
using @model {
  type ComparisonProfile,
  type DeclaredVisualFact,
  type Diagnostic,
  type DiagnosticSourceLocation,
}

///|
using @report_support {
  diagnostic_location,
  merge_diagnostic_into,
  unlocated_diagnostic,
}

///|
using @source_semantics {
  authored_subject_id,
  generated_subject_id,
  presentation_fact,
}

///|
using @affine_transform {parse_transform_list}
