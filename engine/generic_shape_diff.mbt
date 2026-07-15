///|
fn source_subject_fact(
  subject : SourceSubject,
  property : String,
) -> DeclaredVisualFact? {
  declared_fact_in_array(subject.facts, property)
}

///|
fn source_subject_id(subject : SourceSubject) -> String {
  subject.reference.authored_id.unwrap_or(
    "\{subject.kind}:\{subject.reference.source_index}",
  )
}

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
fn generic_default_value(property : String) -> String? {
  match property {
    "x"
    | "y"
    | "cx"
    | "cy"
    | "x1"
    | "y1"
    | "x2"
    | "y2"
    | "width"
    | "height"
    | "rx"
    | "ry"
    | "r" => Some("0")
    "fill" => Some("rgba(0,0,0,1)")
    "fill-rule" | "clip-rule" => Some("nonzero")
    "stroke" => Some("none")
    "stroke-width" | "opacity" | "fill-opacity" | "stroke-opacity" => Some("1")
    "stroke-linecap" => Some("butt")
    "stroke-linejoin" => Some("miter")
    "stroke-miterlimit" => Some("4")
    "stroke-dasharray" => Some("none")
    "stroke-dashoffset" => Some("0")
    "vector-effect" => Some("none")
    "marker" | "marker-start" | "marker-mid" | "marker-end" => Some("none")
    "paint-order" => Some("fill stroke markers")
    _ => None
  }
}

///|
fn generic_computed_value(
  property : String,
  fact : DeclaredVisualFact?,
) -> String? {
  match fact {
    Some(fact) => Some(generic_computed_string(property, fact.declared_value))
    None => generic_default_value(property)
  }
}

///|
fn generic_computed_string(property : String, source : String) -> String {
  let value = source.trim().to_owned().to_lower()
  match property {
    "fill" | "stroke" | "color" | "stop-color" =>
      match @css_color.parse_solid_color(value) {
        Resolved(color) => color.signature()
        _ => value
      }
    "opacity" | "fill-opacity" | "stroke-opacity" | "stop-opacity" =>
      match @css_color.parse_alpha_value(value) {
        Some(alpha) => alpha.to_string()
        None => value
      }
    _ => value
  }
}

///|
fn generic_subject_alpha(subject : SourceSubject, property : String) -> Double? {
  let value = subject_value(subject, property).unwrap_or("1")
  @css_color.parse_alpha_value(value)
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
fn generic_effective_paint(
  subject : SourceSubject,
  property : String,
  fact : DeclaredVisualFact?,
) -> String? {
  let value = match subject_value(subject, property) {
    Some(value) => value
    None => return generic_computed_value(property, fact)
  }
  guard @css_color.parse_solid_color(value) is Resolved(color) else {
    return Some(generic_computed_string(property, value))
  }
  let paint_opacity_property = if property == "fill" {
    "fill-opacity"
  } else {
    "stroke-opacity"
  }
  guard generic_subject_alpha(subject, paint_opacity_property)
    is Some(paint_opacity) else {
    return Some(color.signature())
  }
  guard generic_subject_alpha(subject, "opacity") is Some(opacity) else {
    return Some(color.signature())
  }
  Some({ ..color, alpha: color.alpha * paint_opacity * opacity }.signature())
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
fn stroke_subject_width(subject : SourceSubject) -> Double {
  parse_shape_number(subject_value(subject, "stroke-width").unwrap_or("1")).unwrap_or(
    0.0,
  )
}

///|
fn stroke_subject_has_join(subject : SourceSubject) -> Bool {
  match subject.kind {
    "rect" | "polygon" => subject.renders_geometry
    "polyline" =>
      match parse_shape_points(subject_value(subject, "points").unwrap_or("")) {
        (points, true, false) => points.length() >= 6
        _ => false
      }
    "path" => subject.path_segments.length() >= 2
    _ => false
  }
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
        (
          before_subject.clip_path_owner_id is Some(_) ||
          after_subject.clip_path_owner_id is Some(_)
        ) {
        let ids : Array[String] = []
        for subject in [before_subject, after_subject] {
          match subject.clip_path_owner_id {
            Some(owner) => {
              let id = "diagnostic:clip-path-semantics-unsupported:\{owner}"
              if !ids.contains(id) {
                ids.push(id)
              }
            }
            None => ()
          }
        }
        ids.sort()
        return {
          status: "indeterminate",
          reason_code: "clip_path_semantics_unsupported",
          missing_side: None,
          diagnostic_ids: ids,
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
  if relation.status != "different" {
    return magnitude
  }
  match parameter_delta {
    Some(delta) => {
      if property == "opacity" ||
        property == "fill-opacity" ||
        property == "stroke-opacity" {
        fn computed_number(subject : SourceSubject) -> Double? {
          match
            generic_subject_computed_value(
              subject,
              property,
              source_subject_fact(subject, property),
            ) {
            Some(value) => parse_alignment_number(Some(value))
            None => None
          }
        }
        let before = computed_number(before_subject)
        let after = computed_number(after_subject)
        return {
          ..magnitude,
          parameter_abs_user_units: Some(delta.abs()),
          parameter_signed_user_units: Some(delta),
          symmetric_relative: match (before, after) {
            (Some(before), Some(after)) =>
              Some(symmetric_relative_delta(before, after))
            _ => None
          },
        }
      }
      if basic_shape_geometry_property(before_subject.kind, property) {
        fn scale(subject : SourceSubject) -> Double {
          let matrix = subject.cumulative_transform
          match basic_shape_length_direction(property) {
            Horizontal => @math.hypot(matrix.a, matrix.b)
            Vertical => @math.hypot(matrix.c, matrix.d)
            Unspecified => matrix.max_linear_scale()
          }
        }
        return {
          ..magnitude,
          geometry_displacement_css_px: Some(
            delta.abs() * scale(before_subject).max(scale(after_subject)),
          ),
        }
      }
      if property != "stroke-width" {
        return magnitude
      }
      let before_scale = if before_subject.stroke_non_scaling {
        1.0
      } else {
        before_subject.cumulative_transform.max_linear_scale()
      }
      let after_scale = if after_subject.stroke_non_scaling {
        1.0
      } else {
        after_subject.cumulative_transform.max_linear_scale()
      }
      {
        ..magnitude,
        geometry_displacement_css_px: Some(
          delta.abs() / 2.0 * before_scale.max(after_scale),
        ),
      }
    }
    None => magnitude
  }
}

///|
fn alignment_subject_ids(
  before : Array[SourceSubject],
  after : Array[SourceSubject],
) -> Array[String] {
  let ids : Array[String] = []
  for subject in before {
    let id = source_subject_id(subject)
    if !ids.contains(id) {
      ids.push(id)
    }
  }
  for subject in after {
    let id = source_subject_id(subject)
    if !ids.contains(id) {
      ids.push(id)
    }
  }
  ids
}

///|
fn subjects_for_references(
  subjects : Array[SourceSubject],
  references : Array[SubjectReference],
) -> Array[SourceSubject] {
  let selected : Array[SourceSubject] = []
  for reference in references {
    for subject in subjects {
      if subject.reference.source_index == reference.source_index &&
        subject.reference.kind == reference.kind {
        selected.push(subject)
        break
      }
    }
  }
  selected
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
        "marker-start", "marker-mid", "marker-end", "paint-order", "clip-rule",
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
    before.any(subject => subject.kind != "rect") ||
    after.any(subject => subject.kind != "rect") ||
    single_rect_special_change
  if !needs_generic {
    return None
  }
  let changed_facts : Array[ChangedFact] = []
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
          let fact_id = "fact:\{alignment.id}:\{property}"
          let difference_id = "diff:\{alignment.id}:\{property}"
          let relation = generic_relation(
            property, before_subject, after_subject, before_fact, after_fact,
          )
          changed_facts.push({
            id: fact_id,
            subject_id: alignment.id,
            property,
            before: before_fact,
            after: after_fact,
            affected_subject_ids: alignment_subject_ids([before_subject], [
              after_subject,
            ]),
          })
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
          affected_subject_ids: alignment_subject_ids(
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
      _ => {
        let fact_id = "fact:\{alignment.id}:structure"
        let difference_id = "diff:\{alignment.id}:structure"
        changed_facts.push({
          id: fact_id,
          subject_id: alignment.id,
          property: "structure",
          before: None,
          after: None,
          affected_subject_ids: alignment_subject_ids(
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
    schema_version: "1.20",
    analysis_status: "complete",
    coverage_matrix: [],
    renderer_capability_gaps: [],
    profile,
    subject_alignments: alignments,
    changed_facts,
    source_resolutions: [],
    atomic_differences: differences,
    events,
    diagnostics: [],
  })
}
