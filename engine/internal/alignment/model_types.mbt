///|
using @model {
  type AlignmentEvidence,
  type ComparisonProfile,
  type DeclaredVisualFact,
  type SubjectAlignment,
  type SubjectReference,
}

///|
using @ir {
  type SourceSubject,
  type StructuralAlignmentSubject,
  source_subject_fact,
  subject_value,
}

///|
using @control {type ComparisonGuard, type ComparisonInterrupted}

///|
using @source_semantics {
  type StructuralDocument,
  authored_subject_id,
  structural_path_segment,
}

///|
using @path_data {type NormalizedPathSegment, normalized_path_segment_signature}

///|
using @affine_transform {type AffineTransform}

///|
using @computed {type CssBounds}

///|
using @geometry {basic_shape_geometry_property, parse_alignment_number}

///|
using @resources {alignment_property_order, source_subject_bounds}
