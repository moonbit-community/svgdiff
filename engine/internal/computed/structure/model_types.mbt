///|
using @model {
  type ComparisonProfile,
  type DeclaredVisualFact,
  type Diagnostic,
  type ReportSourceSpan,
}

///|
using @source_semantics {
  type CssStaticDocument,
  type RenderedSubjectPlan,
  type StructuralDocument,
  type StructuralSourceNode,
  authored_subject_id,
  css_stylesheet_match_for_source,
  local_href_target,
  presentation_fact,
  use_target_index,
  extract_structural_document_or_raise,
  known_source_element,
  rendered_subject_plans,
  supported_use_target,
  upsert_declared_fact,
}

///|
using @computed {
  type SourceTransformSite,
  type SourceViewportResolution,
  type SvgLengthDirection,
  type ViewportContext,
  default_preserve_aspect_ratio,
  equivalent_viewport_transform,
  normalized_view_box_signature,
  normalized_viewport_fact,
  parse_preserve_aspect_ratio_value,
  parse_view_box_value,
  parse_viewport_length,
  preserve_aspect_ratio_signature,
  source_transform_site,
}

///|
using @affine_transform {type AffineTransform}

///|
using @style {
  type FillHierarchy,
  type FillSourceElement,
  type PaintServerTarget,
  add_fill_source_element,
  visual_declarations_from_element,
}

///|
using @report_support {
  diagnostic_location,
  merge_diagnostic_into,
  unlocated_diagnostic,
}
