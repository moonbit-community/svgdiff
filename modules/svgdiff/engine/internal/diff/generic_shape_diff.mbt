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
fn generic_property_domain(property : String) -> String {
  match property {
    "x" | "y" | "cx" | "cy" | "x1" | "y1" | "x2" | "y2" | "points" =>
      "geometry.position"
    "width" | "height" | "rx" | "ry" | "r" => "geometry.size"
    "fill" => "paint.fill"
    "fill-opacity" => "paint.fill_opacity"
    "fill-rule" => "paint.fill_rule"
    "stroke" => "paint.stroke"
    "stroke-opacity" => "paint.stroke_opacity"
    "stroke-width" => "geometry.stroke_width"
    "stroke-linecap" => "geometry.stroke_cap"
    "stroke-linejoin" => "geometry.stroke_join"
    "stroke-miterlimit" => "geometry.stroke_miter_limit"
    "stroke-dasharray" => "geometry.stroke_dash_pattern"
    "stroke-dashoffset" => "geometry.stroke_dash_offset"
    "vector-effect" => "geometry.stroke_vector_effect"
    "marker" | "marker-start" | "marker-mid" | "marker-end" =>
      "geometry.marker_attachment"
    "paint-order" => "paint.order"
    "clip-rule" => "clipping.rule"
    "clip-path" => "clipping.path"
    "mask" => "masking.attachment"
    "mask-mode" => "masking.mode"
    "opacity" => "paint.opacity"
    _ => "document.unsupported"
  }
}

///|
fn declared_fact_uses_length_unit(fact : DeclaredVisualFact?) -> Bool {
  match fact {
    Some(fact) =>
      fact.declared_value.trim().to_owned().to_lower() != "auto" &&
      parse_shape_number(fact.declared_value) is None
    None => false
  }
}

///|
fn generic_paint_operation_active(
  subject : SourceSubject,
  property : String,
) -> Bool {
  if property == "fill" && !subject.fillable_interior {
    return false
  }
  if property == "stroke" && !subject.stroke_active {
    return false
  }
  let paint = subject_value(subject, property).unwrap_or(
    if property == "fill" {
      "rgba(0,0,0,1)"
    } else {
      "none"
    },
  )
  if paint == "none" {
    return false
  }
  match @css_color.parse_solid_color(paint) {
    Resolved(color) if color.alpha == 0.0 => return false
    _ => ()
  }
  let paint_opacity = if property == "fill" {
    "fill-opacity"
  } else {
    "stroke-opacity"
  }
  generic_subject_alpha(subject, paint_opacity).unwrap_or(1.0) > 0.0 &&
  generic_subject_alpha(subject, "opacity").unwrap_or(1.0) > 0.0
}

///|
fn generic_active_paint_order(subject : SourceSubject) -> String {
  let source = subject_value(subject, "paint-order").unwrap_or(
    "fill stroke markers",
  )
  guard parse_paint_order_value(source) is ValidPaintOrder(order) else {
    return source
  }
  let active : Array[String] = []
  for operation in order {
    let enabled = match operation {
      "fill" => generic_paint_operation_active(subject, "fill")
      "stroke" => generic_paint_operation_active(subject, "stroke")
      "markers" => subject.marker_active
      _ => false
    }
    if enabled {
      active.push(operation)
    }
  }
  if active.is_empty() {
    "inactive"
  } else {
    paint_order_signature(active)
  }
}

///|
fn generic_winding_rule_value(
  subject : SourceSubject,
  property : String,
) -> String {
  if property == "clip-rule" {
    return if subject.clip_path_owner_id is Some(_) {
      subject_value(subject, property).unwrap_or("nonzero")
    } else {
      "inactive"
    }
  }
  if !generic_paint_operation_active(subject, "fill") {
    return "inactive"
  }
  match subject.kind {
    "rect" | "circle" | "ellipse" => "single_simple_contour"
    _ => subject_value(subject, property).unwrap_or("nonzero")
  }
}

///|
fn generic_subject_computed_value(
  subject : SourceSubject,
  property : String,
  fact : DeclaredVisualFact?,
) -> String? {
  if basic_shape_geometry_property(subject.kind, property) {
    return subject_value(subject, property)
  }
  if property == "stroke" &&
    (!subject.stroke_path_present || stroke_subject_width(subject) <= 0.0) {
    return Some("none")
  }
  if stroke_geometry_property(property) {
    if !stroke_subject_property_active(subject, property) {
      return Some("inactive")
    }
    return subject_value(subject, property)
  }
  if property == "marker" {
    return Some(
      "\{subject_value(subject, "marker-start").unwrap_or("none")}|\{subject_value(subject, "marker-mid").unwrap_or("none")}|\{subject_value(subject, "marker-end").unwrap_or("none")}",
    )
  }
  if marker_attachment_property(property) {
    return subject_value(subject, property)
  }
  if property == "fill" && !subject.fillable_interior {
    return Some("none")
  }
  if property == "fill" || property == "stroke" {
    return generic_effective_paint(subject, property, fact)
  }
  if property == "paint-order" {
    return Some(generic_active_paint_order(subject))
  }
  if property == "fill-rule" || property == "clip-rule" {
    return Some(generic_winding_rule_value(subject, property))
  }
  if property == "opacity" ||
    property == "fill-opacity" ||
    property == "stroke-opacity" {
    return match subject_value(subject, property) {
      Some(value) => Some(generic_computed_string(property, value))
      None => generic_computed_value(property, fact)
    }
  }
  generic_computed_value(property, fact)
}

///|
fn stroke_subject_has_linear_effect(subject : SourceSubject) -> Bool {
  let matrix = subject.cumulative_transform
  matrix.a != 1.0 || matrix.b != 0.0 || matrix.c != 0.0 || matrix.d != 1.0
}

///|
fn stroke_subject_property_active(
  subject : SourceSubject,
  property : String,
) -> Bool {
  if property == "stroke-width" {
    return subject.stroke_paint_present && subject.stroke_path_present
  }
  if !subject.stroke_active {
    return false
  }
  match property {
    "stroke-linecap" =>
      subject_value(subject, "stroke-dasharray") != Some("none") ||
      subject.kind == "line" ||
      subject.kind == "polyline" ||
      subject.kind == "path"
    "stroke-linejoin" => stroke_subject_has_join(subject)
    "stroke-miterlimit" => {
      let join_uses_limit = match subject_value(subject, "stroke-linejoin") {
        Some("miter") | Some("miter-clip") | Some("arcs") => true
        _ => false
      }
      stroke_subject_has_join(subject) && join_uses_limit
    }
    "stroke-dashoffset" =>
      subject_value(subject, "stroke-dasharray") != Some("none")
    "vector-effect" => stroke_subject_has_linear_effect(subject)
    _ => true
  }
}

///|
fn shape_geometry_diagnostic_ids(
  before : SourceSubject,
  after : SourceSubject,
) -> Array[String] {
  let ids : Array[String] = []
  if !before.geometry_complete {
    ids.push(
      "diagnostic:basic-shape-geometry-unsupported:\{source_subject_id(before)}",
    )
  }
  if !after.geometry_complete {
    let id = "diagnostic:basic-shape-geometry-unsupported:\{source_subject_id(after)}"
    if !ids.contains(id) {
      ids.push(id)
    }
  }
  ids.sort()
  ids
}

///|
fn stroke_geometry_diagnostic_ids(
  before : SourceSubject,
  after : SourceSubject,
) -> Array[String] {
  let ids : Array[String] = []
  if !before.stroke_complete {
    ids.push(
      "diagnostic:stroke-geometry-unsupported:\{source_subject_id(before)}",
    )
  }
  if !after.stroke_complete {
    let id = "diagnostic:stroke-geometry-unsupported:\{source_subject_id(after)}"
    if !ids.contains(id) {
      ids.push(id)
    }
  }
  ids.sort()
  ids
}

///|
fn generic_relation(
  property : String,
  before_subject : SourceSubject,
  after_subject : SourceSubject,
  before : DeclaredVisualFact?,
  after : DeclaredVisualFact?,
) -> ComputedRelation {
  if basic_shape_geometry_property(before_subject.kind, property) &&
    (!before_subject.geometry_complete || !after_subject.geometry_complete) {
    return {
      status: "indeterminate",
      reason_code: "basic_shape_geometry_unsupported",
      missing_side: None,
      diagnostic_ids: shape_geometry_diagnostic_ids(
        before_subject, after_subject,
      ),
    }
  }
  if stroke_geometry_property(property) &&
    (!before_subject.stroke_complete || !after_subject.stroke_complete) {
    return {
      status: "indeterminate",
      reason_code: "stroke_geometry_unsupported",
      missing_side: None,
      diagnostic_ids: stroke_geometry_diagnostic_ids(
        before_subject, after_subject,
      ),
    }
  }
  if marker_attachment_property(property) &&
    (!before_subject.marker_complete || !after_subject.marker_complete) {
    let ids : Array[String] = []
    for subject in [before_subject, after_subject] {
      if !subject.marker_complete {
        let id = "diagnostic:marker-semantics-unsupported:\{source_subject_id(subject)}"
        if !ids.contains(id) {
          ids.push(id)
        }
      }
    }
    ids.sort()
    return {
      status: "indeterminate",
      reason_code: "marker_semantics_unsupported",
      missing_side: None,
      diagnostic_ids: ids,
    }
  }
  let before_value = generic_subject_computed_value(
    before_subject, property, before,
  )
  let after_value = generic_subject_computed_value(
    after_subject, property, after,
  )
  match (before_value, after_value) {
    (Some(before_value), Some(after_value)) => {
      let equivalent = match
        (
          parse_alignment_number(Some(before_value)),
          parse_alignment_number(Some(after_value)),
        ) {
        (Some(before_number), Some(after_number)) =>
          before_number == after_number
        _ => before_value == after_value
      }
      if marker_attachment_property(property) && !equivalent {
        let ids : Array[String] = []
        for subject in [before_subject, after_subject] {
          if subject.marker_active {
            let id = "diagnostic:marker-content-semantics-unsupported:\{source_subject_id(subject)}"
            if !ids.contains(id) {
              ids.push(id)
            }
          }
        }
        if !ids.is_empty() {
          ids.sort()
          return {
            status: "indeterminate",
            reason_code: "marker_content_semantics_unsupported",
            missing_side: None,
            diagnostic_ids: ids,
          }
        }
      }
      if property == "paint-order" &&
        !equivalent &&
        (before_subject.marker_active || after_subject.marker_active) {
        let ids : Array[String] = []
        for subject in [before_subject, after_subject] {
          if subject.marker_active {
            let id = "diagnostic:marker-content-semantics-unsupported:\{source_subject_id(subject)}"
            if !ids.contains(id) {
              ids.push(id)
            }
          }
        }
        ids.sort()
        return {
          status: "indeterminate",
          reason_code: "marker_content_semantics_unsupported",
          missing_side: None,
          diagnostic_ids: ids,
        }
      }
      if property == "clip-rule" &&
        !equivalent &&
        before_subject.kind == "rect" &&
        after_subject.kind == "rect" &&
        before_subject.clip_path_owner_id is Some(_) &&
        after_subject.clip_path_owner_id is Some(_) &&
        before_subject.clip_complete &&
        after_subject.clip_complete {
        return {
          status: "equivalent",
          reason_code: "same_simple_clip_contour",
          missing_side: None,
          diagnostic_ids: [],
        }
      }
      if property == "clip-rule" &&
        !equivalent &&
        (
          before_subject.clip_path_owner_id is Some(_) ||
          after_subject.clip_path_owner_id is Some(_)
        ) {
        let ids : Array[String] = []
        for subject in [before_subject, after_subject] {
          match subject.clip_path_owner_id {
            Some(owner) =>
              if subject.clip_issue_codes.is_empty() {
                push_unique(
                  ids,
                  "diagnostic:clip_path_content_unsupported:\{owner}",
                )
              } else {
                for code in subject.clip_issue_codes {
                  push_unique(ids, "diagnostic:\{code}:\{owner}")
                }
              }
            None => ()
          }
        }
        ids.sort()
        return {
          status: "indeterminate",
          reason_code: "clip_resource_coverage_partial",
          missing_side: None,
          diagnostic_ids: ids,
        }
      }
      if property == "clip-path" &&
        (!before_subject.clip_complete || !after_subject.clip_complete) {
        let ids : Array[String] = []
        for subject in [before_subject, after_subject] {
          for code in subject.clip_issue_codes {
            push_unique(ids, "diagnostic:\{code}:\{source_subject_id(subject)}")
          }
        }
        ids.sort()
        return {
          status: "indeterminate",
          reason_code: "clip_path_coverage_partial",
          missing_side: None,
          diagnostic_ids: ids,
        }
      }
      if (property == "mask" || property == "mask-mode") &&
        (!before_subject.mask_complete || !after_subject.mask_complete) {
        let ids : Array[String] = []
        for subject in [before_subject, after_subject] {
          for code in subject.mask_issue_codes {
            push_unique(ids, "diagnostic:\{code}:\{source_subject_id(subject)}")
          }
        }
        ids.sort()
        return {
          status: "indeterminate",
          reason_code: "mask_coverage_partial",
          missing_side: None,
          diagnostic_ids: ids,
        }
      }
      if property == "mask" &&
        !equivalent &&
        (
          before_subject.mask_outcome
          .map(value => value.has_prefix("transparent_black_"))
          .unwrap_or(false) ||
          after_subject.mask_outcome
          .map(value => value.has_prefix("transparent_black_"))
          .unwrap_or(false)
        ) {
        return {
          status: "different",
          reason_code: "transparent_black_mask_outcome_changed",
          missing_side: None,
          diagnostic_ids: [],
        }
      }
      {
        status: if equivalent {
          "equivalent"
        } else {
          "different"
        },
        reason_code: if equivalent {
          "same_resolved_fact"
        } else {
          "resolved_facts_differ"
        },
        missing_side: None,
        diagnostic_ids: [],
      }
    }
    (None, Some(_)) =>
      {
        status: "not_applicable",
        reason_code: "before_fact_absent",
        missing_side: Some("before"),
        diagnostic_ids: [],
      }
    (Some(_), None) =>
      {
        status: "not_applicable",
        reason_code: "after_fact_absent",
        missing_side: Some("after"),
        diagnostic_ids: [],
      }
    _ =>
      {
        status: "equivalent",
        reason_code: "both_facts_absent",
        missing_side: None,
        diagnostic_ids: [],
      }
  }
}

///|
fn generic_parameter_delta(
  property : String,
  before_subject : SourceSubject,
  after_subject : SourceSubject,
  before : DeclaredVisualFact?,
  after : DeclaredVisualFact?,
) -> Double? {
  match
    (
      generic_subject_computed_value(before_subject, property, before),
      generic_subject_computed_value(after_subject, property, after),
    ) {
    (Some(before_value), Some(after_value)) =>
      match
        (
          parse_alignment_number(Some(before_value)),
          parse_alignment_number(Some(after_value)),
        ) {
        (Some(before_number), Some(after_number)) =>
          Some(after_number - before_number)
        _ => None
      }
    _ => None
  }
}

///|
fn generic_initial_magnitude(
  property : String,
  relation : ComputedRelation,
  before_subject : SourceSubject,
  after_subject : SourceSubject,
  parameter_delta : Double?,
) -> DifferenceMagnitude {
  let magnitude = empty_difference_magnitude()
  match parameter_delta {
    Some(delta) => {
      let before_value = generic_subject_computed_value(
        before_subject,
        property,
        source_subject_fact(before_subject, property),
      ).bind(value => parse_alignment_number(Some(value)))
      let after_value = generic_subject_computed_value(
        after_subject,
        property,
        source_subject_fact(after_subject, property),
      ).bind(value => parse_alignment_number(Some(value)))
      let parameter_magnitude = {
        ..magnitude,
        parameter_abs_user_units: Some(delta.abs()),
        parameter_signed_user_units: Some(delta),
        symmetric_relative: match (before_value, after_value) {
          (Some(before), Some(after)) =>
            Some(symmetric_relative_delta(before, after))
          _ => None
        },
      }
      if relation.status != "different" {
        return parameter_magnitude
      }
      if property == "opacity" ||
        property == "fill-opacity" ||
        property == "stroke-opacity" {
        return parameter_magnitude
      }
      if !before_subject.transform_complete || !after_subject.transform_complete {
        return parameter_magnitude
      }
      if basic_shape_geometry_property(before_subject.kind, property) {
        guard common_parameter_directional_css_scale(
            before_subject.cumulative_transform,
            after_subject.cumulative_transform,
            basic_shape_length_direction(property),
          )
          is Some(scale) else {
          return parameter_magnitude
        }
        let css_displacement = delta.abs() * scale
        return {
          ..parameter_magnitude,
          parameter_abs_css_px: Some(css_displacement),
          parameter_entity_fraction: parameter_entity_fraction_from_bounds(
            css_displacement,
            [
              source_subject_bounds(before_subject),
              source_subject_bounds(after_subject),
            ],
          ),
          geometry_displacement_css_px: Some(css_displacement),
        }
      }
      if property != "stroke-width" {
        return parameter_magnitude
      }
      let before_boundary_scale = if before_subject.stroke_non_scaling {
        1.0
      } else {
        before_subject.cumulative_transform.max_linear_scale()
      }
      let after_boundary_scale = if after_subject.stroke_non_scaling {
        1.0
      } else {
        after_subject.cumulative_transform.max_linear_scale()
      }
      let boundary_css_px = delta.abs() /
        2.0 *
        before_boundary_scale.max(after_boundary_scale)
      guard common_scalar_parameter_css_scale(
          before_subject, after_subject, property,
        )
        is Some(scale) else {
        return {
          ..parameter_magnitude,
          geometry_displacement_css_px: Some(boundary_css_px),
        }
      }
      let parameter_css_px = delta.abs() * scale
      {
        ..parameter_magnitude,
        parameter_abs_css_px: Some(parameter_css_px),
        parameter_entity_fraction: parameter_entity_fraction_from_bounds(
          parameter_css_px,
          [
            source_subject_bounds(before_subject),
            source_subject_bounds(after_subject),
          ],
        ),
        geometry_displacement_css_px: Some(boundary_css_px),
      }
    }
    None => magnitude
  }
}

///|
fn instance_changed_fact_owner(
  before : SourceSubject,
  after : SourceSubject,
  property : String,
) -> String? {
  if before.reference.instance_context is None &&
    after.reference.instance_context is None {
    return None
  }
  let before_owner = source_subject_resolution(before, property).bind(fact => {
    fact.declaration_owner_id
  })
  let after_owner = source_subject_resolution(after, property).bind(fact => {
    fact.declaration_owner_id
  })
  match (before_owner, after_owner) {
    (Some(before_owner), Some(after_owner)) if before_owner == after_owner =>
      Some(before_owner)
    (Some(owner), None) | (None, Some(owner)) => Some(owner)
    _ => None
  }
}

///|
fn append_or_merge_changed_fact(
  changed_facts : Array[ChangedFact],
  id : String,
  subject_id : String,
  property : String,
  before : DeclaredVisualFact?,
  after : DeclaredVisualFact?,
  affected_subject_ids : Array[String],
) -> Unit {
  for index, fact in changed_facts {
    if fact.id == id {
      let affected = fact.affected_subject_ids.copy()
      for affected_id in affected_subject_ids {
        if !affected.contains(affected_id) {
          affected.push(affected_id)
        }
      }
      affected.sort()
      changed_facts[index] = { ..fact, affected_subject_ids: affected }
      return
    }
  }
  changed_facts.push({
    id,
    subject_id,
    property,
    before,
    after,
    affected_subject_ids,
  })
}

///|
fn append_source_resolution_pair(
  resolutions : Array[SourceResolutionPair],
  subject : SourceSubject,
  other : SourceSubject,
  property : String,
) -> Unit {
  let subject_id = source_subject_id(subject)
  if resolutions.any(pair => {
      pair.subject_id == subject_id && pair.property == property
    }) {
    return
  }
  resolutions.push({
    subject_id,
    property,
    before: source_subject_resolution(subject, property),
    after: source_subject_resolution(other, property),
  })
}

///|
fn generic_basic_shape_report(
  before_svg : String,
  after_svg : String,
  before_document : @svg.SVGDocument,
  after_document : @svg.SVGDocument,
  profile : ComparisonProfile,
  alignments : Array[SubjectAlignment],
) -> StructuredReport? {
  let before = extract_source_subjects_with_profile_or_raise(
    before_svg, profile,
  ) catch {
    _ => return None
  }
  let after = extract_source_subjects_with_profile_or_raise(after_svg, profile) catch {
    _ => return None
  }
  let single_rect_special_change = match (before, after) {
    ([before_subject], [after_subject]) if before_subject.kind == "rect" &&
      after_subject.kind == "rect" => {
      let properties = [
        "rx", "ry", "fill-opacity", "fill-rule", "stroke", "stroke-opacity", "marker",
        "marker-start", "marker-mid", "marker-end", "paint-order", "clip-rule", "clip-path",
        "mask", "mask-mode",
      ]
      for property in alignment_property_order() {
        if stroke_geometry_property(property) {
          properties.push(property)
        }
      }
      source_subject_fact(before_subject, "fill")
      .map(fact => paint_value_uses_url(fact.declared_value))
      .unwrap_or(false) ||
      source_subject_fact(after_subject, "fill")
      .map(fact => paint_value_uses_url(fact.declared_value))
      .unwrap_or(false) ||
      properties.any(property => {
        declared_fact_changed(
          source_subject_fact(before_subject, property),
          source_subject_fact(after_subject, property),
        )
      }) ||
      ["x", "y", "width", "height"].any(property => {
        let before_fact = source_subject_fact(before_subject, property)
        let after_fact = source_subject_fact(after_subject, property)
        declared_fact_changed(before_fact, after_fact) &&
        (
          declared_fact_uses_length_unit(before_fact) ||
          declared_fact_uses_length_unit(after_fact)
        )
      })
    }
    _ => false
  }
  let needs_generic = before.length() > 1 ||
    after.length() > 1 ||
    source_has_clip_resources(before_svg, profile) ||
    source_has_clip_resources(after_svg, profile) ||
    before.any(subject => subject.clip_resource_id is Some(_)) ||
    after.any(subject => subject.clip_resource_id is Some(_)) ||
    source_has_mask_resources(before_svg, profile) ||
    source_has_mask_resources(after_svg, profile) ||
    before.any(subject => subject.mask_resource_id is Some(_)) ||
    after.any(subject => subject.mask_resource_id is Some(_)) ||
    before.any(subject => subject.reference.instance_context is Some(_)) ||
    after.any(subject => subject.reference.instance_context is Some(_)) ||
    before.any(subject => subject.kind != "rect") ||
    after.any(subject => subject.kind != "rect") ||
    single_rect_special_change
  if !needs_generic {
    return None
  }
  let changed_facts : Array[ChangedFact] = []
  let source_resolutions : Array[SourceResolutionPair] = []
  let differences : Array[AtomicDifference] = []
  let events : Array[VisualEvent] = []
  let path_boundary_budget = PathBoundaryBudget::new()
  let rendered = rendered_difference(before_document, after_document, profile)
  for alignment in alignments {
    let before_subjects = subjects_for_references(before, alignment.before)
    let after_subjects = subjects_for_references(after, alignment.after)
    let alignment_difference_ids : Array[String] = []
    match (before_subjects, after_subjects) {
      ([before_subject], [after_subject]) => {
        if before_subject.kind == "path" && after_subject.kind == "path" {
          append_path_geometry_differences(
            alignment, before_subject, after_subject, profile, path_boundary_budget,
            changed_facts, differences, alignment_difference_ids,
          )
        }
        for property in alignment_property_order() {
          let before_fact = source_subject_fact(before_subject, property)
          let after_fact = source_subject_fact(after_subject, property)
          if !declared_fact_changed(before_fact, after_fact) {
            continue
          }
          let changed_owner = instance_changed_fact_owner(
            before_subject, after_subject, property,
          )
          let fact_id = match changed_owner {
            Some(owner) => "fact:source:\{owner}:\{property}"
            None => "fact:\{alignment.id}:\{property}"
          }
          let difference_id = "diff:\{alignment.id}:\{property}"
          let relation = generic_relation(
            property, before_subject, after_subject, before_fact, after_fact,
          )
          append_or_merge_changed_fact(
            changed_facts,
            fact_id,
            changed_owner.unwrap_or(alignment.id),
            property,
            before_fact,
            after_fact,
            source_subject_ids([before_subject], [after_subject]),
          )
          if before_subject.reference.instance_context is Some(_) ||
            after_subject.reference.instance_context is Some(_) ||
            property == "clip-path" ||
            property == "mask" ||
            property == "mask-mode" {
            append_source_resolution_pair(
              source_resolutions, before_subject, after_subject, property,
            )
          }
          let evidence_layers : Array[String] = ["source_semantics"]
          if relation.status == "different" {
            evidence_layers.push("computed_appearance")
          }
          if rendered.changed_pixels > 0 {
            evidence_layers.push("rendered_evidence")
          }
          let parameter_delta = generic_parameter_delta(
            property, before_subject, after_subject, before_fact, after_fact,
          )
          differences.push({
            id: difference_id,
            subject_role: "entity",
            subject_alignment_id: Some(alignment.id),
            domain: generic_property_domain(property),
            source_before: declared_value_or_empty(before_fact),
            source_after: declared_value_or_empty(after_fact),
            source_fact_before: before_fact,
            source_fact_after: after_fact,
            changed_fact_ids: [fact_id],
            evidence_layers,
            computed_relation: relation,
            parameter_delta_css_px: if basic_shape_geometry_property(
                before_subject.kind,
                property,
              ) ||
              property == "stroke-width" {
              parameter_delta
            } else {
              None
            },
            presence_magnitude: None,
            magnitude: generic_initial_magnitude(
              property, relation, before_subject, after_subject, parameter_delta,
            ),
            domain_ordering: empty_domain_ordering(),
          })
          alignment_difference_ids.push(difference_id)
        }
      }
      ([], [_]) | ([_], []) => {
        let property = "presence"
        let fact_id = "fact:\{alignment.id}:presence"
        let difference_id = "diff:\{alignment.id}:presence"
        changed_facts.push({
          id: fact_id,
          subject_id: alignment.id,
          property,
          before: None,
          after: None,
          affected_subject_ids: source_subject_ids(
            before_subjects, after_subjects,
          ),
        })
        let insertion = before_subjects.is_empty()
        differences.push({
          id: difference_id,
          subject_role: "entity",
          subject_alignment_id: Some(alignment.id),
          domain: if insertion {
            "presence.insertion"
          } else {
            "presence.deletion"
          },
          source_before: if insertion {
            ""
          } else {
            "present"
          },
          source_after: if insertion {
            "present"
          } else {
            ""
          },
          source_fact_before: None,
          source_fact_after: None,
          changed_fact_ids: [fact_id],
          evidence_layers: [
            "source_semantics", "computed_appearance", "rendered_evidence",
          ],
          computed_relation: {
            status: "not_applicable",
            reason_code: if insertion {
              "before_fact_absent"
            } else {
              "after_fact_absent"
            },
            missing_side: Some(if insertion { "before" } else { "after" }),
            diagnostic_ids: [],
          },
          parameter_delta_css_px: None,
          presence_magnitude: None,
          magnitude: empty_difference_magnitude(),
          domain_ordering: empty_domain_ordering(),
        })
        alignment_difference_ids.push(difference_id)
      }
      _ if alignment.basis == "exact_visual_equivalence_class" => ()
      _ => {
        let fact_id = "fact:\{alignment.id}:structure"
        let difference_id = "diff:\{alignment.id}:structure"
        changed_facts.push({
          id: fact_id,
          subject_id: alignment.id,
          property: "structure",
          before: None,
          after: None,
          affected_subject_ids: source_subject_ids(
            before_subjects, after_subjects,
          ),
        })
        differences.push({
          id: difference_id,
          subject_role: "entity",
          subject_alignment_id: Some(alignment.id),
          domain: "document.structure",
          source_before: "\{before_subjects.length()} subjects",
          source_after: "\{after_subjects.length()} subjects",
          source_fact_before: None,
          source_fact_after: None,
          changed_fact_ids: [fact_id],
          evidence_layers: ["source_semantics", "computed_appearance"],
          computed_relation: {
            status: "equivalent",
            reason_code: alignment.basis,
            missing_side: None,
            diagnostic_ids: [],
          },
          parameter_delta_css_px: None,
          presence_magnitude: None,
          magnitude: empty_difference_magnitude(),
          domain_ordering: empty_domain_ordering(),
        })
        alignment_difference_ids.push(difference_id)
      }
    }
    if !alignment_difference_ids.is_empty() {
      events.push({
        id: "event:\{alignment.id}",
        primary_subject_id: alignment.id,
        atomic_difference_ids: alignment_difference_ids,
        rendered_outcome: computed_rendered_evidence(rendered),
        difference_regions: [],
      })
    }
  }
  Some({
    schema_version: "3.0",
    analysis_status: "complete",
    canvas_outcome: not_computed_canvas_outcome("rendered_evidence_unavailable"),
    impact_assessment: empty_impact_assessment(),
    coverage_matrix: [],
    renderer_capability_gaps: [],
    visual_scene: @model.empty_visual_scene_analysis(),
    profile,
    subject_alignments: alignments,
    changed_facts,
    source_resolutions,
    atomic_differences: differences,
    events,
    diagnostics: [],
  })
}
