///|
using @model {
  type ComparisonProfile,
  type DeclaredVisualFact,
  type Diagnostic,
  type ResolvedVisualFact,
}

///|
using @ir {type SourceSubject, source_subject_id}

///|
using @source_semantics {
  authored_subject_id,
  parse_filter_reference,
  presentation_fact,
  push_unique,
  visual_subject_kind,
}

///|
using @computed {type CssBounds, intersect_bounds, parse_svg_length}

///|
using @geometry {basic_shape_length_direction, parse_shape_number}

///|
using @affine_transform {type AffineTransform}

///|
using @style {
  type FillHierarchy,
  type StyleDependency,
  blend_mode_from_keyword,
  computed_visual_for_subject,
  extract_fill_hierarchy_or_raise,
  fill_entity_kind,
  fill_source_element,
}

///|
using @resources {
  clip_attribute,
  clip_hierarchy_subject_id_at,
  clip_source_fact,
  extract_source_subjects_with_profile_or_raise,
  source_subject_bounds,
}

///|
using @report_support {
  diagnostic_location,
  merge_diagnostic_into,
  unlocated_diagnostic,
}
