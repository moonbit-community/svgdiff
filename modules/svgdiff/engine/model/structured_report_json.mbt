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
priv struct CompactIsolatedSubject {
  painted_boundary_displacement : PaintedBoundaryDisplacementMagnitude?
  painted_coverage_difference : PaintedCoverageDifferenceMagnitude?
}

///|
fn[T : ToJson] put_optional(
  fields : Map[String, Json],
  key : String,
  value : T?,
) -> Unit {
  match value {
    Some(value) => fields[key] = value.to_json()
    None => ()
  }
}

///|
fn compact_rendered_magnitude(value : RenderedMagnitude) -> Json {
  {
    "changed_pixels": value.changed_pixels,
    "changed_fraction": value.changed_pixel_fraction,
    "linear_rgba_rmse": value.linear_premultiplied_rgba_rmse,
  }
}

///|
fn compact_canvas_outcome(value : CanvasOutcome) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["status"] = value.status.to_json()
  match value.magnitude {
    Some(magnitude) => {
      fields["changed_pixels"] = magnitude.changed_pixels.to_json()
      fields["changed_fraction"] = magnitude.changed_pixel_fraction.to_json()
      fields["linear_rgba_rmse"] = magnitude.linear_premultiplied_rgba_rmse.to_json()
    }
    None => put_optional(fields, "reason", value.reason_code)
  }
  if value.perceptual_flip.status == "computed" {
    put_optional(
      fields,
      "perceptual_difference",
      value.perceptual_flip.canvas_mean,
    )
  }
  Json::object(fields)
}

///|
fn compact_comparison(profile : ComparisonProfile) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["viewport"] = {
    "width": profile.viewport_width,
    "height": profile.viewport_height,
  }
  put_optional(fields, "perceptual_background", profile.perceptual_background)
  match profile.flip_viewing_conditions {
    Some(value) =>
      fields["flip_pixels_per_degree"] = value.pixels_per_degree().to_json()
    None => ()
  }
  match profile.flip_error_threshold {
    Some(value) => fields["flip_error_threshold"] = value.value().to_json()
    None => ()
  }
  Json::object(fields)
}

///|
fn compact_intrinsic_raster(value : IntrinsicRasterMagnitude) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["before_size"] = [value.before_width, value.before_height].to_json()
  fields["after_size"] = [value.after_width, value.after_height].to_json()
  put_optional(fields, "compared_pixels", value.compared_pixels)
  put_optional(fields, "changed_pixels", value.changed_pixels)
  put_optional(fields, "changed_fraction", value.changed_pixel_fraction)
  put_optional(fields, "linear_rgba_rmse", value.linear_premultiplied_rgba_rmse)
  Json::object(fields)
}

///|
fn compact_boundary(value : PaintedBoundaryDisplacementMagnitude) -> Json {
  {
    "mean_css_px": value.mean_css_px,
    "p95_css_px": value.p95_css_px,
    "max_css_px": value.max_css_px,
  }
}

///|
fn compact_coverage(value : PaintedCoverageDifferenceMagnitude) -> Json {
  {
    "before_css_px2": value.before_coverage_css_px2,
    "after_css_px2": value.after_coverage_css_px2,
    "absolute_difference_css_px2": value.absolute_difference_css_px2,
    "union_css_px2": value.union_coverage_css_px2,
    "fraction": value.fraction,
  }
}

///|
fn compact_difference_magnitude(
  report : StructuredReport,
  difference : AtomicDifference,
) -> Json? {
  let value = difference.magnitude
  let isolated_subject = isolated_subject_for_difference(report, difference.id)
  let shared_boundary = match isolated_subject {
    Some(subject) => subject.painted_boundary_displacement
    None => None
  }
  let shared_coverage = match isolated_subject {
    Some(subject) => subject.painted_coverage_difference
    None => None
  }
  let shared_path_displacement = difference.domain.has_prefix("geometry.path.") &&
    (match (value.geometry_displacement_css_px, shared_boundary) {
      (Some(displacement), Some(boundary)) =>
        displacement == boundary.max_css_px
      _ => false
    })
  let fields : Map[String, Json] = Map([])
  put_optional(
    fields,
    "parameter_abs_user_units",
    value.parameter_abs_user_units,
  )
  put_optional(
    fields,
    "parameter_signed_user_units",
    value.parameter_signed_user_units,
  )
  put_optional(fields, "symmetric_relative", value.symmetric_relative)
  put_optional(fields, "parameter_abs_css_px", value.parameter_abs_css_px)
  put_optional(
    fields,
    "parameter_viewport_fraction",
    value.parameter_viewport_fraction,
  )
  put_optional(
    fields,
    "parameter_entity_fraction",
    value.parameter_entity_fraction,
  )
  if !shared_path_displacement {
    put_optional(
      fields,
      "geometry_displacement_css_px",
      value.geometry_displacement_css_px,
    )
  }
  match value.painted_boundary_displacement {
    Some(boundary) if Some(boundary) != shared_boundary =>
      fields["painted_boundary_displacement"] = compact_boundary(boundary)
    _ => ()
  }
  match value.painted_coverage_difference {
    Some(coverage) if Some(coverage) != shared_coverage =>
      fields["painted_coverage_difference"] = compact_coverage(coverage)
    _ => ()
  }
  if !shared_path_displacement {
    put_optional(
      fields,
      "geometry_viewport_fraction",
      value.geometry_viewport_fraction,
    )
  }
  put_optional(
    fields,
    "presence_painted_viewport_fraction",
    value.presence_painted_viewport_fraction,
  )
  match value.intrinsic_raster {
    Some(raster) =>
      fields["intrinsic_raster"] = compact_intrinsic_raster(raster)
    None => ()
  }
  put_optional(fields, "transform", value.transform_effect)
  match difference.presence_magnitude {
    Some(presence) => fields["presence"] = presence.to_json()
    None => ()
  }
  if fields.is_empty() {
    None
  } else {
    Some(Json::object(fields))
  }
}

///|
fn difference_category(domain : String) -> String {
  if domain.has_prefix("presence.") {
    "presence"
  } else if domain.has_prefix("geometry.") || domain.has_prefix("transform.") {
    "geometry"
  } else if domain.has_prefix("paint.") || domain.has_prefix("stroke.") {
    "paint"
  } else if domain.has_prefix("resource.") {
    "resource"
  } else if domain.has_prefix("text.") {
    "text"
  } else if domain.has_prefix("structure.") || domain.has_prefix("document.") {
    "structure"
  } else if domain.has_prefix("compositing.") ||
    domain.has_prefix("effect.") ||
    domain.has_prefix("effects.") ||
    domain.has_prefix("filter.") ||
    domain.has_prefix("filtering.") ||
    domain.has_prefix("mask.") ||
    domain.has_prefix("masking.") ||
    domain.has_prefix("clip.") ||
    domain.has_prefix("clipping.") ||
    domain.has_prefix("blend.") ||
    domain.has_prefix("blending.") ||
    domain.has_prefix("isolation.") ||
    domain.has_prefix("opacity.") {
    "compositing"
  } else {
    "other"
  }
}

///|
fn difference_subject(
  report : StructuredReport,
  difference : AtomicDifference,
) -> String {
  for event in report.events {
    if event.atomic_difference_ids.contains(difference.id) {
      return event.primary_subject_id
    }
  }
  match difference.subject_alignment_id {
    Some(value) => value
    None => difference.subject_role
  }
}

///|
fn authored_before(difference : AtomicDifference) -> String {
  match difference.source_fact_before {
    Some(fact) => fact.authored_value
    None => difference.source_before
  }
}

///|
fn authored_after(difference : AtomicDifference) -> String {
  match difference.source_fact_after {
    Some(fact) => fact.authored_value
    None => difference.source_after
  }
}

///|
fn compact_difference(
  report : StructuredReport,
  difference : AtomicDifference,
) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["id"] = difference.id.to_json()
  fields["subject"] = difference_subject(report, difference).to_json()
  fields["subject_role"] = difference.subject_role.to_json()
  fields["kind"] = difference.domain.to_json()
  fields["source"] = {
    "before": authored_before(difference),
    "after": authored_after(difference),
  }
  let effective : Map[String, Json] = Map([])
  effective["relation"] = difference.computed_relation.status.to_json()
  if difference.computed_relation.status == "indeterminate" ||
    difference.computed_relation.status == "not_applicable" {
    effective["reason"] = difference.computed_relation.reason_code.to_json()
  }
  if !difference.computed_relation.diagnostic_ids.is_empty() {
    effective["limitation_ids"] = difference.computed_relation.diagnostic_ids.to_json()
  }
  fields["effective"] = Json::object(effective)
  match compact_difference_magnitude(report, difference) {
    Some(magnitude) => fields["magnitude"] = magnitude
    None => ()
  }
  Json::object(fields)
}

///|
fn compact_difference_groups(report : StructuredReport) -> Array[Json] {
  let categories : Array[String] = []
  for difference in report.atomic_differences {
    let category = difference_category(difference.domain)
    if !categories.contains(category) {
      categories.push(category)
    }
  }
  let groups : Array[Json] = []
  for category in categories {
    let items : Array[Json] = []
    for difference in report.atomic_differences {
      if difference_category(difference.domain) == category {
        items.push(compact_difference(report, difference))
      }
    }
    groups.push({ "category": category, "items": items })
  }
  groups
}

///|
fn candidate_difference_ids(
  report : StructuredReport,
  changed_fact_ids : Array[String],
) -> Array[String] {
  let result : Array[String] = []
  for difference in report.atomic_differences {
    if difference.changed_fact_ids.any(id => changed_fact_ids.contains(id)) {
      result.push(difference.id)
    }
  }
  result
}

///|
fn isolated_subject_for_event(
  report : StructuredReport,
  event : VisualEvent,
) -> CompactIsolatedSubject? {
  let mut boundary : PaintedBoundaryDisplacementMagnitude? = None
  let mut coverage : PaintedCoverageDifferenceMagnitude? = None
  let mut boundary_conflict = false
  let mut coverage_conflict = false
  for difference in report.atomic_differences {
    if !event.atomic_difference_ids.contains(difference.id) {
      continue
    }
    match difference.magnitude.painted_boundary_displacement {
      Some(value) =>
        match boundary {
          Some(existing) if existing != value => boundary_conflict = true
          None => boundary = Some(value)
          _ => ()
        }
      None => ()
    }
    match difference.magnitude.painted_coverage_difference {
      Some(value) =>
        match coverage {
          Some(existing) if existing != value => coverage_conflict = true
          None => coverage = Some(value)
          _ => ()
        }
      None => ()
    }
  }
  if boundary_conflict {
    boundary = None
  }
  if coverage_conflict {
    coverage = None
  }
  if boundary is None && coverage is None {
    None
  } else {
    Some({
      painted_boundary_displacement: boundary,
      painted_coverage_difference: coverage,
    })
  }
}

///|
fn isolated_subject_for_difference(
  report : StructuredReport,
  difference_id : String,
) -> CompactIsolatedSubject? {
  for event in report.events {
    if event.atomic_difference_ids.contains(difference_id) {
      return isolated_subject_for_event(report, event)
    }
  }
  None
}

///|
fn compact_isolated_subject(value : CompactIsolatedSubject) -> Json {
  let fields : Map[String, Json] = Map([])
  match value.painted_boundary_displacement {
    Some(boundary) =>
      fields["painted_boundary_displacement"] = compact_boundary(boundary)
    None => ()
  }
  match value.painted_coverage_difference {
    Some(coverage) =>
      fields["painted_coverage_difference"] = compact_coverage(coverage)
    None => ()
  }
  Json::object(fields)
}

///|
fn compact_region(report : StructuredReport, region : DifferenceRegion) -> Json {
  let cause : Map[String, Json] = Map([])
  cause["guarantee"] = region.cause_envelope.guarantee.to_json()
  cause["coverage"] = region.cause_envelope.coverage.to_json()
  cause["scope"] = region.cause_envelope.fallback_scope.to_json()
  if region.cause_envelope.fallback_scope != "comparison" {
    cause["candidate_difference_ids"] = candidate_difference_ids(
      report,
      region.cause_envelope.candidate_changed_fact_ids,
    ).to_json()
  }
  let comparison_limitation_ids = [
    for diagnostic in report.diagnostics => diagnostic.id
  ]
  if !region.cause_envelope.diagnostic_ids.is_empty() &&
    region.cause_envelope.diagnostic_ids != comparison_limitation_ids {
    cause["limitation_ids"] = region.cause_envelope.diagnostic_ids.to_json()
  }
  {
    "id": region.id,
    "kind": if region.source == "pixel_mask" {
      "observed"
    } else {
      "conservative"
    },
    "bounds": {
      "x": region.css_x,
      "y": region.css_y,
      "width": region.css_width,
      "height": region.css_height,
    },
    "changed_pixels": region.changed_pixels,
    "viewport_fraction": region.viewport_fraction,
    "possible_causes": Json::object(cause),
  }
}

///|
fn compact_event_outcome(
  value : RenderedEvidence,
  isolated_subject : CompactIsolatedSubject?,
) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["status"] = value.status.to_json()
  match value.magnitude {
    Some(magnitude) => {
      let compact = compact_rendered_magnitude(magnitude)
      guard compact is Object(values) else { return compact }
      for key, item in values {
        fields[key] = item
      }
    }
    None => put_optional(fields, "reason", value.reason_code)
  }
  match value.perceptual_color {
    { status: "computed", magnitude: Some(magnitude), .. } =>
      fields["perceptual_color"] = {
        "sample_count": magnitude.sample_count,
        "mean_delta_e_ok": magnitude.mean_delta_e_ok,
      }
    _ => ()
  }
  match value.perceptual_flip {
    { status: "computed", statistics: Some(statistics), .. } => {
      let flip : Map[String, Json] = Map([])
      flip["canvas_mean"] = statistics.canvas_mean.to_json()
      flip["event_region_mean"] = statistics.event_region_mean.to_json()
      flip["response_p95"] = statistics.response_p95.to_json()
      flip["response_maximum"] = statistics.response_maximum.to_json()
      put_optional(
        flip,
        "area_above_threshold",
        statistics.area_above_threshold,
      )
      fields["perceptual_difference"] = Json::object(flip)
    }
    _ => ()
  }
  match isolated_subject {
    Some(subject) =>
      fields["isolated_subject"] = compact_isolated_subject(subject)
    None => ()
  }
  Json::object(fields)
}

///|
fn compact_event(report : StructuredReport, event : VisualEvent) -> Json {
  {
    "id": event.id,
    "subject": event.primary_subject_id,
    "difference_ids": event.atomic_difference_ids,
    "outcome": compact_event_outcome(
      event.rendered_outcome,
      isolated_subject_for_event(report, event),
    ),
    "regions": [
      for region in event.difference_regions => compact_region(report, region)
    ],
  }
}

///|
fn compact_limitation(value : Diagnostic) -> Json {
  {
    "id": value.id,
    "code": value.code,
    "subject": value.subject_id,
    "affects": value.affected_evidence_layers,
  }
}

///|
fn compact_visual_object_bounds(value : VisualObjectBounds) -> Json {
  [value.x, value.y, value.width, value.height].to_json()
}

///|
fn compact_visual_object(value : VisualObjectSummary) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["id"] = value.id.to_json()
  fields["role"] = value.role.to_json()
  put_optional(fields, "label", value.label)
  if !value.semantic_text.is_empty() {
    fields["text"] = value.semantic_text.to_json()
  }
  if !value.symbolic_text.is_empty() {
    fields["symbols"] = value.symbolic_text.to_json()
  }
  fields["primitives"] = value.primitive_kinds.to_json()
  fields["subjects"] = value.subject_ids.to_json()
  match value.bounds {
    Some(bounds) => fields["bounds"] = compact_visual_object_bounds(bounds)
    None => ()
  }
  Json::object(fields)
}

///|
fn compact_visual_object_alignment(value : VisualObjectAlignment) -> Json {
  {
    "id": value.id,
    "relation": value.relation,
    "before": value.before_object_ids,
    "after": value.after_object_ids,
    "basis": value.basis,
    "ambiguity": value.ambiguity,
  }
}

///|
fn compact_visual_relation(value : VisualRelationSummary) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["id"] = value.id.to_json()
  put_optional(fields, "label", value.label)
  fields["endpoints"] = value.endpoint_object_ids.to_json()
  fields["endpoint_basis"] = value.endpoint_basis.to_json()
  Json::object(fields)
}

///|
fn compact_visual_change_event(value : VisualChangeEvent) -> Json {
  {
    "id": value.id,
    "kind": value.kind,
    "scope": value.scope,
    "object_alignment_ids": value.object_alignment_ids,
    "difference_ids": value.atomic_difference_ids,
    "evidence_event_ids": value.evidence_event_ids,
    "evidence_difference_count": value.evidence_difference_count,
    "evidence_domains": [
      for item in value.evidence_domains => {
        { "domain": item.domain, "count": item.count }
      }
    ],
  }
}

///|
fn compact_visual_scene(value : VisualSceneAnalysis) -> Json {
  {
    "summary": {
      "status": value.summary.status,
      "content": value.summary.content,
      "object_set": value.summary.object_set,
      "relation_graph": value.summary.relation_graph,
      "layout": value.summary.layout,
      "style": value.summary.style,
      "representation": value.summary.representation,
      "before_object_count": value.summary.before_object_count,
      "after_object_count": value.summary.after_object_count,
      "before_relation_count": value.summary.before_relation_count,
      "after_relation_count": value.summary.after_relation_count,
    },
    "before_objects": [
      for object in value.before_objects => compact_visual_object(object)
    ],
    "after_objects": [
      for object in value.after_objects => compact_visual_object(object)
    ],
    "before_relations": [
      for relation in value.before_relations => {
        compact_visual_relation(relation)
      }
    ],
    "after_relations": [
      for relation in value.after_relations => compact_visual_relation(relation)
    ],
    "alignments": [
      for alignment in value.alignments => {
        compact_visual_object_alignment(alignment)
      }
    ],
    "events": [
      for event in value.events => compact_visual_change_event(event)
    ],
    "evidence_coverage": {
      "effective_difference_count": value.evidence_coverage.effective_difference_count,
      "classified_difference_count": value.evidence_coverage.classified_difference_count,
      "residual_difference_count": value.evidence_coverage.residual_difference_count,
      "residual_domains": [
        for item in value.evidence_coverage.residual_domains => {
          { "domain": item.domain, "count": item.count }
        }
      ],
    },
  }
}

///|
pub impl ToJson for StructuredReport with fn to_json(self) {
  {
    "schema_version": self.schema_version,
    "analysis_status": self.analysis_status,
    "comparison": compact_comparison(self.profile),
    "canvas": compact_canvas_outcome(self.canvas_outcome),
    "scene": compact_visual_scene(self.visual_scene),
    "difference_groups": compact_difference_groups(self),
    "events": [
      for event in self.events => compact_event(self, event)
    ],
    "limitations": [
      for diagnostic in self.diagnostics => compact_limitation(diagnostic)
    ],
  }
}
