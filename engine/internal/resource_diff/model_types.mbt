///|
using @model {
  type AtomicDifference,
  type ChangedFact,
  type ComparisonProfile,
  type ComputedRelation,
  type DeclaredVisualFact,
  type Diagnostic,
  type DiagnosticSourceLocation,
  type DifferenceMagnitude,
  type IntrinsicRasterMagnitude,
  type RenderedEvidence,
  type ResolvedVisualFact,
  type StructuredReport,
  type SubjectAlignment,
  type SubjectReference,
  type VisualEvent,
}

///|
using @source_semantics {
  declared_fact_changed,
  declared_fact_in_array,
  parse_filter_reference,
  push_unique,
  source_range_slice,
  group_opacity_container,
  paint_server_reference,
}

///|
using @resources {
  authored_paint_server_reference,
  type ClipRectResource,
  type ClipSemanticDocument,
  type ComputedGradient,
  type ComputedGradientField,
  type ComputedGradientStop,
  type ComputedPattern,
  type ComputedPatternChild,
  type ComputedPatternChildTransform,
  type ComputedPatternField,
  type DecodedEmbeddedRaster,
  type EmbeddedImageSubject,
  embedded_image_subject_for_reference,
  type EmbeddedRasterDecodeResult,
  type GradientDocument,
  type GradientSemanticIssue,
  type GradientSource,
  type MarkerResource,
  type MaskHostAttachment,
  type MaskLength,
  type MaskRectResource,
  type MaskSemanticDocument,
  type PatternDocument,
  type PatternSemanticIssue,
  type PatternSource,
  clip_source_fact,
  embedded_image_subject_bounds,
  embedded_image_unique_id_count,
  extract_clip_semantic_document_or_raise,
  extract_embedded_image_subjects_or_raise,
  extract_gradient_document,
  extract_marker_resources_or_raise,
  extract_mask_semantic_document_or_raise,
  extract_pattern_document,
  extract_source_subjects_with_profile_or_raise,
  resolve_computed_gradient,
  resolve_computed_pattern,
  resolve_gradient_by_id,
  resolve_pattern_by_id,
  subject_references_marker,
}

///|
using @effects {
  type BlendSemanticDocument,
  type BlendSite,
  type FilterHostAttachment,
  type FilterLength,
  type FilterOffsetPrimitive,
  type FilterPrimitiveSource,
  type FilterResource,
  type FilterSemanticDocument,
  type ResolvedFilterHost,
  resolve_blend_semantic_document_or_raise,
  resolve_filter_hosts_or_raise,
}

///|
using @rendered_effects {render_product_source_to_image}

///|
using @computed {normalized_view_box_signature, preserve_aspect_ratio_signature}

///|
using @affine_transform {type AffineTransform}

///|
using @geometry {
  basic_shape_length_direction,
  canonical_shape_number,
  parse_shape_number,
  parse_alignment_number,
  shape_fact,
}

///|
using @style {
  type FillHierarchy,
  type StyleDependency,
  append_style_dependencies,
  generic_effective_paint,
  local_property_declaration,
  resolution_source_changed,
  computed_visual_for_subject,
  extract_fill_hierarchy_or_raise,
  fill_entity_kind,
}

///|
using @structure {}

///|
using @rendered {
  computed_rendered_evidence,
  not_computed_rendered_evidence,
  rendered_difference,
  rendered_image_difference,
  srgb8_to_linear,
}

///|
using @normalization {normalize_renderer_input_with_profile}

///|
using @report_support {
  append_unique_subjects,
  declared_value_or_empty,
  diagnostic_location,
  empty_difference_magnitude,
  empty_domain_ordering,
  merge_diagnostic_into,
  unlocated_diagnostic,
}

///|
using @ir {
  type SourceSubject,
  source_subject_id,
  source_subject_fact,
  subject_value,
}

///|
using @control {}

///|
using @alignment {alignment_evidence}

///|
using @attribution {}

///|
using @measurement {
  common_parameter_directional_css_scale,
  parameter_entity_fraction_from_bounds,
  symmetric_relative_delta,
}

///|
using @resource_model {
  type ComparisonResourceBundles,
  type ResourceBundle,
  type ResourceLimits,
}
