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
    "group_opacity_compositing_unsupported" =>
      Some(("compositing.group_opacity", "unavailable"))
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
