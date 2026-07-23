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
fn renderer_capability_for_diagnostic(code : String) -> (String, String)? {
  match code {
    "renderer_style_precedence_unresolved" =>
      Some(("css.inline_style_precedence", "guarded"))
    "renderer_fractional_geometry_unproven" =>
      Some(("raster.fractional_geometry", "guarded"))
    "renderer_gradient_raster_unproven" =>
      Some(("raster.referenced_gradient", "guarded"))
    "renderer_pattern_raster_unproven" =>
      Some(("raster.referenced_pattern", "guarded"))
    "renderer_fractional_opacity_unproven" =>
      Some(("raster.fractional_opacity", "guarded"))
    "renderer_transform_raster_unproven" =>
      Some(("raster.affine_transform", "guarded"))
    "renderer_use_transform_raster_unproven" =>
      Some(("raster.use_transform_placement", "guarded"))
    "renderer_use_inherited_paint_raster_unproven" =>
      Some(("raster.use_inherited_paint", "guarded"))
    "renderer_viewport_raster_unproven" =>
      Some(("raster.viewport_mapping", "guarded"))
    "renderer_curved_shape_raster_unproven" =>
      Some(("raster.curved_shapes", "guarded"))
    "renderer_point_shape_raster_unproven" =>
      Some(("raster.point_shapes", "guarded"))
    "renderer_stroke_outline_raster_unproven" =>
      Some(("raster.stroke_outline", "guarded"))
    "renderer_stroke_join_raster_unproven" =>
      Some(("raster.stroke_join", "guarded"))
    "renderer_stroke_dash_raster_unproven" =>
      Some(("raster.stroke_dash", "guarded"))
    "renderer_non_scaling_stroke_unproven" =>
      Some(("raster.non_scaling_stroke", "guarded"))
    "renderer_marker_raster_unproven" => Some(("raster.marker", "guarded"))
    "renderer_embedded_raster_unavailable" =>
      Some(("raster.embedded_images", "unavailable"))
    "clip_path_content_unsupported"
    | "clip_path_dynamic_unsupported"
    | "clip_path_nested_reference_unsupported"
    | "clip_path_instance_unsupported"
    | "clip_path_units_invalid"
    | "clip_path_transform_unproven"
    | "clip_path_geometry_unsupported"
    | "clip_path_object_bbox_container_unsupported"
    | "clip_path_effect_bounds_unavailable"
    | "clip_path_target_kind_unsupported"
    | "clip_path_target_missing"
    | "clip_path_external_reference_unsupported"
    | "clip_path_reference_invalid" => Some(("raster.clip_path", "guarded"))
    _ => None
  }
}

///|
fn attach_renderer_capability_gaps(
  report : StructuredReport,
) -> StructuredReport {
  let gaps : Array[RendererCapabilityGap] = []
  for diagnostic in report.diagnostics {
    match renderer_capability_for_diagnostic(diagnostic.code) {
      Some((capability_id, support_status)) => {
        let mut found = false
        for gap in gaps {
          if gap.capability_id == capability_id {
            if !gap.diagnostic_ids.contains(diagnostic.id) {
              gap.diagnostic_ids.push(diagnostic.id)
            }
            found = true
          }
        }
        if !found {
          gaps.push({
            capability_id,
            support_status,
            diagnostic_ids: [diagnostic.id],
          })
        }
      }
      None => ()
    }
  }
  for gap in gaps {
    gap.diagnostic_ids.sort()
  }
  gaps.sort_by(fn(left, right) {
    left.capability_id.compare(right.capability_id)
  })
  { ..report, renderer_capability_gaps: gaps }
}
