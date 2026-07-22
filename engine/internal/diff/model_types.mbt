///|
using @model {
  type AtomicDifference,
  type ChangedFact,
  type ComparisonProfile,
  type ComputedRelation,
  type DeclaredVisualFact,
  type Diagnostic,
  type DifferenceMagnitude,
  type FeatureCoverage,
  type PresenceMagnitude,
  type RenderedEvidence,
  type RendererCapabilityGap,
  type ReportSourceSpan,
  type SourceResolutionPair,
  type StructuredReport,
  type SubjectAlignment,
  type SubjectReference,
  type TransformEffectMagnitude,
  type VisualEvent,
}

///|
using @source_audit {visual_semantic_input}

///|
using @source_semantics {
  ascii_url_start,
  type RectDeclaredFacts,
  css_custom_property_name,
  css_stylesheet_match_for_source,
  declared_fact,
  declared_fact_changed,
  declared_fact_in_array,
  extract_rect_declared_facts,
  inline_style_facts,
  marker_attachment_property,
  parse_mask_reference,
  parse_paint_value,
  parse_static_css_document_or_raise,
  push_unique,
  rect_property_order,
  supported_presentation_property,
  authored_subject_id,
  group_opacity_container,
  known_source_element,
  extract_structural_document_or_raise,
  paint_server_reference,
  paint_value_uses_url,
  paint_order_signature,
  paint_rule_issue_code,
  paint_rule_value_valid,
  parse_paint_order_value,
}

///|
using @resources {
  type EmbeddedImageSubject,
  alignment_property_order,
  append_clip_path_diagnostics,
  append_marker_geometry_diagnostics,
  append_mask_diagnostics,
  embedded_image_only_scene,
  embedded_raster_source_limit,
  extract_clip_semantic_document_or_raise,
  extract_embedded_image_subjects_or_raise,
  extract_mask_semantic_document_or_raise,
  extract_pattern_document,
  extract_source_subjects_internal_or_raise,
  extract_source_subjects_or_raise,
  extract_source_subjects_with_profile_or_raise,
  source_has_clip_resources,
  source_has_mask_resources,
  source_subject_bounds,
}

///|
using @effects {append_blend_diagnostics, append_filter_diagnostics}

///|
using @rendered_effects {render_product_source_to_image}

///|
using @computed {
  type CssBounds,
  type SourceTransformSite,
  append_viewport_preflight_diagnostics,
  decompose_affine_transform,
  shortest_transform_angle_delta,
}

///|
using @geometry {
  append_basic_shape_geometry_diagnostics,
  append_basic_shape_renderer_diagnostics,
  basic_shape_geometry_property,
  basic_shape_length_direction,
  parse_shape_number,
  parse_alignment_number,
  append_stroke_geometry_diagnostics,
  append_stroke_renderer_diagnostics,
  stroke_geometry_property,
  stroke_subject_has_join,
  stroke_subject_width,
}

///|
using @style {
  type FillHierarchy,
  type StyleDependency,
  append_style_dependencies,
  generic_computed_string,
  generic_computed_value,
  generic_effective_paint,
  generic_subject_alpha,
  local_property_declaration,
  resolution_source_changed,
  computed_visual_for_subject,
  css_wide_keyword,
  extract_fill_hierarchy,
  resolved_visual_for_subject,
  resolved_visual_properties,
}

///|
using @structure {
  append_use_structure_diagnostics,
  empty_rendered_scene_supported,
  structural_definition_facts,
  unused_definition_indices,
}

///|
using @rendered {
  computed_rendered_evidence,
  not_computed_canvas_outcome,
  not_computed_rendered_evidence,
  rendered_difference,
  rendered_image_difference,
}

///|
using @normalization {normalize_renderer_input_with_profile}

///|
using @report_support {
  append_unique_subjects,
  declared_value_or_empty,
  diagnostic_ids,
  attach_diagnostic_fact_locations,
  diagnostic_location,
  element_diagnostic_locations,
  empty_difference_magnitude,
  empty_domain_ordering,
  located_diagnostic,
  merge_diagnostic_into,
  unlocated_diagnostic,
}

///|
using @ir {
  type SourceSubject,
  source_subject_id,
  source_subject_fact,
  source_subject_resolution,
  source_subject_ids,
  subjects_for_references,
  subject_value,
}

///|
using @control {
  type ComparisonControl,
  type ComparisonGuard,
  type ComparisonInterrupted,
}

///|
using @alignment {
  align_source_subjects_with_guard,
  align_structural_subjects_with_guard,
  structural_alignment_subjects,
  source_structural_alignment_basis,
}

///|
using @attribution {
  attach_cause_envelopes,
  attach_impact_assessment,
  empty_impact_assessment,
  reference_safety_diagnostic,
}

///|
using @measurement {
  type PathBoundaryBudget,
  append_path_geometry_differences,
  attach_difference_magnitudes,
  attach_difference_regions,
  common_parameter_directional_css_scale,
  common_scalar_parameter_css_scale,
  parameter_entity_fraction_from_bounds,
  symmetric_relative_delta,
}

///|
using @resource_diff {
  append_marker_resource_diagnostics,
  attach_blend_differences,
  attach_clip_path_differences,
  attach_embedded_image_differences,
  attach_filter_differences,
  attach_gradient_differences,
  attach_group_opacity_differences,
  attach_marker_resource_differences,
  attach_mask_differences,
  attach_pattern_differences,
  embedded_image_alignments_for_sources,
  embedded_image_preflight_diagnostics,
}

///|
using @resource_model {
  type ComparisonResourceBundles,
  type ResourceBundle,
  type ResourceLimits,
  default_resource_limits,
  resource_limit_diagnostic,
  utf8_byte_length,
  utf8_byte_length_exceeds,
  validate_resource_bundle,
}
