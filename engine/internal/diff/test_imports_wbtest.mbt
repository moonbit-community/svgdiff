///|
using @model {
  type FlipErrorThreshold,
  type FlipViewingConditions,
  type PerceptualBackground,
  type PerceptualFlipMap,
  type ResolvedVisualFact,
}

///|
using @source_semantics {
  canonical_marker_reference,
  parse_filter_reference,
  source_range_slice,
  local_href_target,
  resource_url_locators,
  rendered_subject_plans,
  canonical_paint_order,
  canonical_winding_rule,
}

///|
using @resources {
  type ComputedGradient,
  type ComputedPattern,
  type ComputedPatternField,
  computed_gradient_number,
  decode_embedded_raster,
  extract_gradient_document_or_raise,
  extract_marker_resources_or_raise,
  extract_pattern_document_or_raise,
  marker_vertices_for_subject,
  resolve_gradient_by_id,
  resolve_pattern_by_id,
}

///|
using @effects {
  extract_filter_semantic_document_or_raise,
  resolve_filter_hosts_or_raise,
}

///|
using @computed {
  type ViewBoxValue,
  type ViewportContext,
  default_preserve_aspect_ratio,
  equivalent_viewport_transform,
  parse_preserve_aspect_ratio_value,
  parse_svg_length,
  parse_view_box_value,
  parse_viewport_length,
}

///|
using @geometry {
  type BasicShapeGeometryResolution,
  canonical_shape_points,
  parse_shape_points,
  resolve_basic_shape_geometry_with_context,
  shape_fact,
  type StrokeGeometryResolution,
  parse_stroke_dasharray_with_context,
  resolve_stroke_geometry_with_context,
}

///|
using @style {
  blend_mode_from_keyword,
  extract_fill_hierarchy_or_raise,
  inherited_visual_properties,
  initial_visual_value,
}

///|
using @rendered {
  delta_e_ok_after_background,
  encode_flip_u16_base64,
  perceptual_flip_statistics,
  render_product_document_to_image,
}

///|
using @normalization {normalize_renderer_input}

///|
using @attribution {
  type ResourceDependencyGraph,
  type ResourceDependencyNode,
  alignment_influence_subject_ids,
  build_subject_influence_index,
  event_changed_fact_ids,
  event_influence_subject_ids,
  event_may_influence_fact_ids,
  influence_operation_for_domain,
  build_resource_dependency_graph,
  impact_assessment_for_events,
  reference_cycle_diagnostic,
  reference_expansion_diagnostic,
  resource_dependency_forward_targets,
  resource_dependency_reverse_subjects,
  resource_dependency_target_kinds,
  subject_influence_fact_ids,
}

///|
using @measurement {
  alignment_bounds,
  alignment_side_bounds,
  painted_boundary_displacement_distribution,
  painted_coverage_difference,
  pixel_difference_regions,
  rendered_magnitude_for_regions,
  filter_event_side_bounds,
  isolated_subjects_painted_measurements,
  side_bounds_union,
}

///|
using @resource_diff {filter_primitive_source_fact}
