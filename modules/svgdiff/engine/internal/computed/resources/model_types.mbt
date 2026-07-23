// Copyright 2026 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
using @model {
  type ComparisonProfile,
  type DeclaredVisualFact,
  type Diagnostic,
  type DiagnosticSourceLocation,
  type ResolvedVisualFact,
  type SubjectInstanceContext,
  type SubjectReference,
}

///|
using @ir {
  type MarkerPlacement,
  type SourceSubject,
  source_subject_id,
  source_subject_fact,
  subject_value,
}

///|
using @resource_model {
  type ResourceBundle,
  type ResourceLimits,
  resource_bundle_entry,
  normalized_bundle_media_type,
  resource_limit_diagnostic,
}

///|
using @source_semantics {
  type CssCascadeCandidate,
  type CssStaticDocument,
  type CssStylesheetMatch,
  type RenderedSubjectPlan,
  type StructuralDocument,
  authored_subject_id,
  cascade_visual_declarations,
  canonical_marker_reference,
  css_stylesheet_match_for_source,
  declared_fact_in_array,
  extract_structural_document_or_raise,
  generated_subject_id,
  group_opacity_container,
  inline_style_facts,
  marker_attachment_property,
  parse_marker_reference,
  parse_clip_path_reference,
  parse_mask_reference,
  parse_static_css_document_or_raise,
  parse_document_stylesheets_or_raise,
  presentation_cascade_candidate,
  presentation_fact,
  push_unique,
  rendered_subject_plans,
  source_range_slice,
  source_slice,
  structural_parent_path_signature,
  rendered_plan_instance_resolution_signature,
  structural_href_fact,
  upsert_declared_fact,
  visual_subject_kind,
  paint_server_reference,
  paint_order_signature,
  parse_paint_order_value,
}

///|
using @computed {
  type CssBounds,
  type PreserveAspectRatioValue,
  type SourceTransformSite,
  type SvgLengthDirection,
  type ViewBoxValue,
  type ViewportContext,
  cumulative_transform,
  default_preserve_aspect_ratio,
  equivalent_viewport_transform,
  normalized_view_box_signature,
  normalized_viewport_fact,
  parse_preserve_aspect_ratio_value,
  parse_svg_length,
  parse_view_box_value,
  preserve_aspect_ratio_signature,
  source_transform_site_with_viewport,
  transform_bounds,
  inflate_bounds,
  intersect_bounds,
  union_bounds,
}

///|
using @affine_transform {
  type AffineTransform,
  normalized_transform_component,
  parse_transform_list,
}

///|
using @geometry {
  basic_shape_length_direction,
  basic_shape_geometry_property,
  canonical_shape_number,
  parse_shape_number,
  parse_shape_points,
  push_invalid_stroke_fact,
  resolve_basic_shape_geometry_with_context,
  resolve_stroke_geometry_with_context,
  shape_fact,
  bounds_number,
  source_subject_geometry_bounds,
  stroke_geometry_number,
  stroke_geometry_property,
  resolved_stroke_expansion,
  resolved_stroke_paint_present,
  resolved_stroke_path_present,
  resolved_stroke_value,
  stroke_subject_width,
}

///|
using @style {
  type FillHierarchy,
  type StyleDependency,
  append_style_dependencies,
  computed_visual_facts_for_subject,
  computed_visual_for_subject,
  computed_visual_for_index,
  extract_fill_hierarchy_or_raise,
  fill_source_element,
  resolved_visual_facts_for_subject,
  resolved_visual_properties,
  inherited_visual_properties,
}

///|
using @structure {
  rendered_plan_fill_hierarchy,
  source_instanced_viewport_site,
  source_use_transform_site,
}

///|
using @report_support {
  diagnostic_location,
  merge_diagnostic_into,
  unlocated_diagnostic,
}

///|
using @path_data {type PathSegmentEvidence}

///|
using @path_data {parse_path_attribute_data, path_segments_signature}
