///|
using @model {type ComparisonProfile, type DeclaredVisualFact, type Diagnostic}

///|
using @ir {type SourceSubject, source_subject_id, subject_value}

///|
using @computed {
  type CssBounds,
  type SvgLengthDirection,
  type ViewportContext,
  parse_svg_length,
  parse_svg_length_at,
}

///|
using @report_support {
  diagnostic_location,
  merge_diagnostic_into,
  unlocated_diagnostic,
}

///|
using @source_semantics {declared_fact_in_array}

///|
using @number_parser {type NumberParser}

///|
using @path_data {type PathSegmentEvidence}
