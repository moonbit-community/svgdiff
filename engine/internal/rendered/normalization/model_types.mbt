///|
using @model {type ComparisonProfile, type DeclaredVisualFact}

///|
using @ir {type SourceSubject}

///|
using @source_semantics {
  type CssCascadeCandidate,
  type CssStylesheetMatch,
  type StructuralDocument,
  type StructuralSourceNode,
  authored_subject_id,
  cascade_visual_declarations,
  css_stylesheet_match_for_source,
  empty_css_stylesheet_match,
  extract_structural_document_or_raise,
  fill_hierarchy_kind,
  group_opacity_container,
  inline_style_facts,
  parse_mask_reference,
  parse_static_css_document_or_raise,
  presentation_cascade_candidate,
  presentation_fact,
  push_unique,
  rect_declared_facts_from_element,
  source_range_slice,
  supported_presentation_property,
  upsert_declared_fact,
  use_target_index,
  visual_subject_kind,
}

///|
using @computed {
  type ViewportContext,
  source_transform_site_with_viewport,
  source_viewport_resolution,
}

///|
using @geometry {
  type BasicShapeGeometryResolution,
  resolve_basic_shape_geometry_with_context,
  resolve_stroke_geometry_with_context,
  shape_fact,
}

///|
using @style {
  type FillHierarchy,
  type FillSourceElement,
  computed_visual_for_subject,
  extract_fill_hierarchy,
  renderer_computed_override_facts_for_subject,
}

///|
using @resources {
  type MaskRectResource,
  type MaskSemanticDocument,
  extract_mask_semantic_document_or_raise,
  extract_source_subjects_with_profile_or_raise,
  marker_resource_from_element,
  mask_resource_for_id,
}
