///|
priv enum SourcePreflight {
  SourceCovered
  SourcePartial(Array[Diagnostic])
  SourceFailed(Diagnostic)
}

///|
fn known_source_attribute(kind : String, name : String) -> Bool {
  if name == "id" ||
    name == "class" ||
    name.has_prefix("data-") ||
    name.has_prefix("aria-") ||
    name == "style" ||
    name == "transform" ||
    name == "color" ||
    name == "color-interpolation" ||
    name == "fill" ||
    name == "fill-opacity" ||
    name == "fill-rule" ||
    name == "stroke" ||
    name == "stroke-opacity" ||
    name == "stroke-width" ||
    name == "stroke-linecap" ||
    name == "stroke-linejoin" ||
    name == "stroke-miterlimit" ||
    name == "stroke-dasharray" ||
    name == "stroke-dashoffset" ||
    name == "vector-effect" ||
    name == "marker" ||
    name == "marker-start" ||
    name == "marker-mid" ||
    name == "marker-end" ||
    name == "paint-order" ||
    name == "clip-rule" ||
    name == "clip-path" ||
    name == "filter" ||
    name == "mask" ||
    name == "mask-mode" ||
    name == "mask-type" ||
    name == "mask-image" ||
    name == "mask-position" ||
    name == "mask-size" ||
    name == "mask-repeat" ||
    name == "mask-origin" ||
    name == "mask-clip" ||
    name == "mask-composite" ||
    name.has_prefix("mask-border") ||
    name == "opacity" {
    return true
  }
  match kind {
    "svg" =>
      name == "x" ||
      name == "y" ||
      name == "width" ||
      name == "height" ||
      name == "viewBox" ||
      name == "preserveAspectRatio" ||
      name == "xmlns"
    "symbol" =>
      name == "x" ||
      name == "y" ||
      name == "width" ||
      name == "height" ||
      name == "viewBox" ||
      name == "preserveAspectRatio"
    "use" =>
      name == "x" ||
      name == "y" ||
      name == "width" ||
      name == "height" ||
      name == "href"
    "image" =>
      name == "x" ||
      name == "y" ||
      name == "width" ||
      name == "height" ||
      name == "href" ||
      name == "preserveAspectRatio"
    "rect" =>
      name == "x" ||
      name == "y" ||
      name == "width" ||
      name == "height" ||
      name == "rx" ||
      name == "ry"
    "circle" => name == "cx" || name == "cy" || name == "r"
    "ellipse" => name == "cx" || name == "cy" || name == "rx" || name == "ry"
    "line" => name == "x1" || name == "y1" || name == "x2" || name == "y2"
    "polyline" | "polygon" => name == "points"
    "linearGradient" =>
      name == "x1" ||
      name == "y1" ||
      name == "x2" ||
      name == "y2" ||
      name == "gradientUnits" ||
      name == "gradientTransform" ||
      name == "spreadMethod" ||
      name == "href"
    "radialGradient" =>
      name == "cx" ||
      name == "cy" ||
      name == "r" ||
      name == "fx" ||
      name == "fy" ||
      name == "fr" ||
      name == "gradientUnits" ||
      name == "gradientTransform" ||
      name == "spreadMethod" ||
      name == "href"
    "pattern" =>
      name == "x" ||
      name == "y" ||
      name == "width" ||
      name == "height" ||
      name == "patternUnits" ||
      name == "patternContentUnits" ||
      name == "patternTransform" ||
      name == "viewBox" ||
      name == "preserveAspectRatio" ||
      name == "href" ||
      name == "overflow"
    "clipPath" => name == "clipPathUnits"
    "mask" =>
      name == "maskUnits" ||
      name == "maskContentUnits" ||
      name == "x" ||
      name == "y" ||
      name == "width" ||
      name == "height"
    "filter" =>
      name == "filterUnits" ||
      name == "primitiveUnits" ||
      name == "x" ||
      name == "y" ||
      name == "width" ||
      name == "height" ||
      name == "href"
    "feOffset" =>
      name == "in" ||
      name == "result" ||
      name == "dx" ||
      name == "dy" ||
      name == "x" ||
      name == "y" ||
      name == "width" ||
      name == "height"
    "marker" =>
      name == "markerUnits" ||
      name == "markerWidth" ||
      name == "markerHeight" ||
      name == "refX" ||
      name == "refY" ||
      name == "orient" ||
      name == "viewBox" ||
      name == "preserveAspectRatio" ||
      name == "overflow"
    "stop" => name == "offset" || name == "stop-color" || name == "stop-opacity"
    "text" =>
      name == "x" ||
      name == "y" ||
      name == "dx" ||
      name == "dy" ||
      name == "font-family" ||
      name == "font-size" ||
      name == "text-anchor"
    "title" | "desc" | "metadata" => true
    _ => false
  }
}

///|
fn unsupported_visual_value_code(property : String, value : String) -> String? {
  let trimmed = value.trim().to_owned()
  let normalized = trimmed.to_lower()
  if css_wide_keyword(normalized) || normalized.find("var(") is Some(_) {
    return None
  }
  if property.has_prefix("mask-border") {
    return Some("mask_border_unsupported")
  }
  if property == "mask-image" {
    return Some("mask_image_unsupported")
  }
  if property == "mask-position" ||
    property == "mask-size" ||
    property == "mask-repeat" ||
    property == "mask-origin" ||
    property == "mask-clip" ||
    property == "mask-composite" {
    return Some("mask_layer_subproperty_unsupported")
  }
  if property == "mask" {
    if normalized.find("gradient(") is Some(_) ||
      normalized.has_prefix("image(") ||
      normalized.has_prefix("image-set(") ||
      normalized.has_prefix("cross-fade(") {
      return Some("mask_image_unsupported")
    }
    if normalized.find(",") is Some(_) {
      return Some("mask_multiple_layers_unsupported")
    }
    return match parse_mask_reference(trimmed) {
      MaskNone | MaskLocal(_) => None
      MaskExternal => Some("mask_external_reference_unsupported")
      MaskInvalid => Some("mask_reference_invalid")
    }
  }
  if property == "mask-mode" {
    return if normalized == "match-source" ||
      normalized == "alpha" ||
      normalized == "luminance" {
      None
    } else {
      Some("mask_mode_invalid")
    }
  }
  if property == "mask-type" {
    return if normalized == "alpha" || normalized == "luminance" {
      None
    } else {
      Some("mask_type_invalid")
    }
  }
  if property == "opacity" ||
    property == "fill-opacity" ||
    property == "stroke-opacity" ||
    property == "stop-opacity" {
    return if @css_color.parse_alpha_value(normalized) is Some(_) {
      None
    } else {
      Some("opacity_syntax_unsupported")
    }
  }
  if property == "paint-order" ||
    property == "fill-rule" ||
    property == "clip-rule" {
    return if paint_rule_value_valid(property, normalized) {
      None
    } else {
      Some(paint_rule_issue_code(property))
    }
  }
  if property != "color" &&
    property != "fill" &&
    property != "stroke" &&
    property != "stop-color" {
    return None
  }
  if property == "fill" || property == "stroke" {
    match parse_paint_value(trimmed) {
      NoPaint | LocalPaintServer(_, _) => return None
      ExternalPaintServer | ContextPaint =>
        return Some("paint_value_semantics_unsupported")
      InvalidPaint if ascii_url_start(trimmed, 0) =>
        return Some("paint_value_semantics_unsupported")
      SolidPaint(_) | InvalidPaint => ()
    }
  }
  match @css_color.parse_solid_color(normalized) {
    Resolved(_) | CurrentColor => None
    SystemColor(_) => Some("system_color_environment_unsupported")
    Invalid =>
      if normalized.has_prefix("lab(") ||
        normalized.has_prefix("lch(") ||
        normalized.has_prefix("oklab(") ||
        normalized.has_prefix("oklch(") ||
        normalized.has_prefix("color(") ||
        normalized.has_prefix("hwb(") {
        Some("color_profile_unsupported")
      } else {
        Some("solid_color_syntax_unsupported")
      }
  }
}

///|
fn geometry_source_property(kind : String, property : String) -> Bool {
  basic_shape_geometry_property(kind, property)
}

///|
fn contains_fractional_number(value : String) -> Bool {
  let normalized = value
    .replace_all(old=",", new=" ")
    .replace_all(old="\t", new=" ")
    .replace_all(old="\n", new=" ")
    .replace_all(old="\r", new=" ")
  for token in normalized.split(" ") {
    let token = token.trim()
    if token == "" {
      continue
    }
    match parse_alignment_number(Some(token.to_owned())) {
      Some(number) if number != number.floor() => return true
      _ => ()
    }
  }
  false
}

///|
fn contains_fractional_paint_alpha(property : String, value : String) -> Bool {
  if property == "opacity" ||
    property == "fill-opacity" ||
    property == "stroke-opacity" ||
    property == "stop-opacity" {
    match @css_color.parse_alpha_value(value) {
      Some(alpha) => return alpha > 0.0 && alpha < 1.0
      None => return false
    }
  }
  if property == "color" ||
    property == "fill" ||
    property == "stroke" ||
    property == "stop-color" {
    match @css_color.parse_solid_color(value) {
      Resolved(color) => return color.alpha > 0.0 && color.alpha < 1.0
      _ => return false
    }
  }
  false
}

///|
fn preflight_element_subject_id(element : @xml.NamespaceElement) -> String {
  authored_subject_id(element).unwrap_or(element.name.local_name)
}

///|
fn append_transform_preflight_diagnostics(
  diagnostics : Array[Diagnostic],
  element : @xml.NamespaceElement,
  source_role : String,
) -> Unit {
  let subject_id = preflight_element_subject_id(element)
  for attribute in element.attributes {
    let name = attribute.name.local_name
    if name != "transform" &&
      name != "gradientTransform" &&
      name != "patternTransform" {
      continue
    }
    match parse_transform_list(attribute.value) {
      InvalidTransformList => {
        let id = "diagnostic:transform-syntax-unsupported:\{subject_id}:\{name}"
        merge_diagnostic_into(
          diagnostics,
          located_diagnostic(
            id,
            "transform_syntax_unsupported",
            subject_id,
            ["source_semantics", "computed_appearance", "rendered_evidence"],
            source_role,
            attribute.span,
          ),
        )
      }
      ValidTransformList(transform) if name == "transform" &&
        !transform.matrix.has_proven_renderer_conformance() => {
        let id = "diagnostic:renderer-transform-raster-unproven:\{subject_id}"
        merge_diagnostic_into(
          diagnostics,
          located_diagnostic(
            id,
            "renderer_transform_raster_unproven",
            subject_id,
            ["rendered_evidence"],
            source_role,
            attribute.span,
          ),
        )
      }
      _ => ()
    }
  }
}

///|
fn object_bbox_clip_child_offsets(
  input : String,
  profile : ComparisonProfile,
) -> Array[Int] {
  let document = extract_clip_semantic_document_or_raise(input, profile) catch {
    _ => return []
  }
  let offsets : Array[Int] = []
  for resource in document.resources {
    if resource.complete &&
      resource.units == "objectBoundingBox" &&
      resource.rect_source_offset is Some(offset) {
      offsets.push(offset)
    }
  }
  let masks = extract_mask_semantic_document_or_raise(input, profile) catch {
    _ => return offsets
  }
  for resource in masks.resources {
    if resource.complete &&
      resource.content_units == "objectBoundingBox" &&
      resource.rect_source_offset is Some(offset) {
      offsets.push(offset)
    }
  }
  offsets
}

///|
fn admitted_mask_content_offsets(
  input : String,
  profile : ComparisonProfile,
) -> Array[Int] {
  let document = extract_mask_semantic_document_or_raise(input, profile) catch {
    _ => return []
  }
  let offsets : Array[Int] = []
  for resource in document.resources {
    if resource.complete && resource.rect_source_offset is Some(offset) {
      offsets.push(offset)
    }
  }
  offsets
}

///|
fn preflight_source_or_raise(
  input : String,
  profile : ComparisonProfile,
  source_role : String,
  bundle : ResourceBundle,
  limits : ResourceLimits,
) -> Array[Diagnostic] raise {
  let diagnostics : Array[Diagnostic] = []
  for
    diagnostic in embedded_image_preflight_diagnostics(
      input, profile, source_role, bundle, limits,
    ) {
    merge_diagnostic_into(diagnostics, diagnostic)
  }
  let css_document = parse_static_css_document_or_raise(input)
  if !css_document.complete {
    merge_diagnostic_into(
      diagnostics,
      unlocated_diagnostic(
        "diagnostic:css-cascade-unsupported:document",
        "css_cascade_unsupported",
        "document",
        ["source_semantics", "computed_appearance", "rendered_evidence"],
      ),
    )
  }
  let gradient_ids : Array[String] = []
  let pattern_ids : Array[String] = []
  let paint_server_references : Array[
    (String, String, String, ReportSourceSpan),
  ] = []
  let object_bbox_clip_offsets = object_bbox_clip_child_offsets(input, profile)
  let mask_content_offsets = admitted_mask_content_offsets(input, profile)
  let reader = @xml.NamespaceReader::from_string(input)
  for event in reader.read_events_until_eof() {
    match event.kind {
      Start(element) | Empty(element) => {
        let kind = element.name.local_name
        append_transform_preflight_diagnostics(
          diagnostics, element, source_role,
        )
        if !known_source_element(kind) {
          let id = "diagnostic:unsupported-visual-subject:\{kind}"
          merge_diagnostic_into(
            diagnostics,
            located_diagnostic(
              id,
              "unsupported_visual_subject",
              kind,
              ["computed_appearance", "rendered_evidence"],
              source_role,
              event.span,
            ),
          )
        } else {
          let presentation_properties : Array[(String, ReportSourceSpan)] = []
          let unsupported_visual_values : Array[
            (String, String, ReportSourceSpan),
          ] = []
          let paint_references : Array[(String, String, ReportSourceSpan)] = []
          let fractional_geometry_properties : Array[(String, ReportSourceSpan)] = []
          let mut style_attribute : @xml.NamespaceAttribute? = None
          let mut subject_id = kind
          let fractional_leaf_opacity_spans : Array[ReportSourceSpan] = []
          for attribute in element.attributes {
            let name = attribute.name.local_name
            let attribute_span : ReportSourceSpan = {
              start_offset: attribute.span.start.offset,
              end_offset: attribute.span.end.offset,
            }
            if name == "id" && attribute.value.trim() != "" {
              subject_id = attribute.value.trim().to_owned()
            } else if name == "style" {
              style_attribute = Some(attribute)
            } else if supported_presentation_property(name) {
              presentation_properties.push((name, attribute_span))
            }
            match unsupported_visual_value_code(name, attribute.value) {
              Some(code) =>
                unsupported_visual_values.push((name, code, attribute_span))
              None => ()
            }
            match paint_server_reference(attribute.value) {
              Some(id) if name == "fill" || name == "stroke" =>
                paint_references.push((name, id, attribute_span))
              _ => ()
            }
            if geometry_source_property(kind, name) &&
              contains_fractional_number(attribute.value) &&
              !object_bbox_clip_offsets.contains(event.span.start.offset) {
              fractional_geometry_properties.push((name, attribute_span))
            }
            if !(name == "opacity" && group_opacity_container(kind)) &&
              !mask_content_offsets.contains(event.span.start.offset) &&
              contains_fractional_paint_alpha(name, attribute.value) {
              fractional_leaf_opacity_spans.push(attribute_span)
            }
            if !known_source_attribute(kind, name) {
              let id = "diagnostic:unsupported-visual-attribute:\{kind}:\{name}"
              merge_diagnostic_into(
                diagnostics,
                located_diagnostic(
                  id,
                  "unsupported_visual_attribute",
                  kind,
                  [
                    "source_semantics", "computed_appearance", "rendered_evidence",
                  ],
                  source_role,
                  attribute.span,
                ),
              )
            }
          }
          if (kind == "linearGradient" || kind == "radialGradient") &&
            subject_id != kind {
            gradient_ids.push(subject_id)
          }
          if kind == "pattern" && subject_id != kind {
            pattern_ids.push(subject_id)
          }
          for reference in paint_references {
            let (property, id, span) = reference
            paint_server_references.push((subject_id, property, id, span))
          }
          for property_and_span in fractional_geometry_properties {
            let (property, span) = property_and_span
            merge_diagnostic_into(diagnostics, {
              ..unlocated_diagnostic(
                "diagnostic:renderer-fractional-geometry-unproven:\{subject_id}:\{property}",
                "renderer_fractional_geometry_unproven",
                subject_id,
                ["rendered_evidence"],
              ),
              source_locations: [diagnostic_location(source_role, span)],
            })
          }
          for span in fractional_leaf_opacity_spans {
            merge_diagnostic_into(diagnostics, {
              ..unlocated_diagnostic(
                "diagnostic:renderer-fractional-opacity-unproven:\{subject_id}",
                "renderer_fractional_opacity_unproven",
                subject_id,
                ["rendered_evidence"],
              ),
              source_locations: [diagnostic_location(source_role, span)],
            })
          }
          for entry in unsupported_visual_values {
            let (property, code, span) = entry
            merge_diagnostic_into(diagnostics, {
              ..unlocated_diagnostic(
                "diagnostic:\{code}:\{subject_id}:\{property}",
                code,
                subject_id,
                ["computed_appearance", "rendered_evidence"],
              ),
              source_locations: [diagnostic_location(source_role, span)],
            })
          }
          match style_attribute {
            Some(attribute) => {
              let style = inline_style_facts(input, attribute)
              for fact in style.facts {
                if geometry_source_property(kind, fact.property) &&
                  contains_fractional_number(fact.declared_value) &&
                  !object_bbox_clip_offsets.contains(event.span.start.offset) {
                  let id = "diagnostic:renderer-fractional-geometry-unproven:\{subject_id}:\{fact.property}"
                  merge_diagnostic_into(diagnostics, {
                    ..unlocated_diagnostic(
                      id,
                      "renderer_fractional_geometry_unproven",
                      subject_id,
                      ["rendered_evidence"],
                    ),
                    source_locations: [
                      diagnostic_location(source_role, fact.source_span),
                    ],
                  })
                }
                if !(fact.property == "opacity" && group_opacity_container(kind)) &&
                  !mask_content_offsets.contains(event.span.start.offset) &&
                  contains_fractional_paint_alpha(
                    fact.property,
                    fact.declared_value,
                  ) {
                  let id = "diagnostic:renderer-fractional-opacity-unproven:\{subject_id}"
                  merge_diagnostic_into(diagnostics, {
                    ..unlocated_diagnostic(
                      id,
                      "renderer_fractional_opacity_unproven",
                      subject_id,
                      ["rendered_evidence"],
                    ),
                    source_locations: [
                      diagnostic_location(source_role, fact.source_span),
                    ],
                  })
                }
                match
                  unsupported_visual_value_code(
                    fact.property,
                    fact.declared_value,
                  ) {
                  Some(code) => {
                    let id = "diagnostic:\{code}:\{subject_id}:\{fact.property}"
                    merge_diagnostic_into(diagnostics, {
                      ..unlocated_diagnostic(id, code, subject_id, [
                        "computed_appearance", "rendered_evidence",
                      ]),
                      source_locations: [
                        diagnostic_location(source_role, fact.source_span),
                      ],
                    })
                  }
                  None => ()
                }
                match paint_server_reference(fact.declared_value) {
                  Some(id) if fact.property == "fill" ||
                    fact.property == "stroke" =>
                    paint_server_references.push(
                      (subject_id, fact.property, id, fact.source_span),
                    )
                  _ => ()
                }
                for presentation in presentation_properties {
                  let (property, presentation_span) = presentation
                  if !style.complete && property == fact.property {
                    let id = "diagnostic:renderer-style-precedence-unresolved:\{subject_id}:\{fact.property}"
                    merge_diagnostic_into(diagnostics, {
                      ..unlocated_diagnostic(
                        id,
                        "renderer_style_precedence_unresolved",
                        subject_id,
                        ["computed_appearance", "rendered_evidence"],
                      ),
                      source_locations: [
                        diagnostic_location(source_role, presentation_span),
                        diagnostic_location(source_role, fact.source_span),
                      ],
                    })
                  }
                }
              }
            }
            None => ()
          }
          let stylesheet_match = css_stylesheet_match_for_source(
            css_document,
            event.span.start.offset,
          )
          for candidate in stylesheet_match.candidates {
            let fact = candidate.declaration
            if geometry_source_property(kind, fact.property) &&
              contains_fractional_number(fact.declared_value) &&
              !object_bbox_clip_offsets.contains(event.span.start.offset) {
              merge_diagnostic_into(diagnostics, {
                ..unlocated_diagnostic(
                  "diagnostic:renderer-fractional-geometry-unproven:{subject_id}:{fact.property}",
                  "renderer_fractional_geometry_unproven",
                  subject_id,
                  ["rendered_evidence"],
                ),
                source_locations: [
                  diagnostic_location(source_role, fact.source_span),
                ],
              })
            }
            if !(fact.property == "opacity" && group_opacity_container(kind)) &&
              !mask_content_offsets.contains(event.span.start.offset) &&
              contains_fractional_paint_alpha(
                fact.property,
                fact.declared_value,
              ) {
              merge_diagnostic_into(diagnostics, {
                ..unlocated_diagnostic(
                  "diagnostic:renderer-fractional-opacity-unproven:{subject_id}",
                  "renderer_fractional_opacity_unproven",
                  subject_id,
                  ["rendered_evidence"],
                ),
                source_locations: [
                  diagnostic_location(source_role, fact.source_span),
                ],
              })
            }
            match
              unsupported_visual_value_code(fact.property, fact.declared_value) {
              Some(code) =>
                merge_diagnostic_into(diagnostics, {
                  ..unlocated_diagnostic(
                    "diagnostic:{code}:{subject_id}:{fact.property}",
                    code,
                    subject_id,
                    ["computed_appearance", "rendered_evidence"],
                  ),
                  source_locations: [
                    diagnostic_location(source_role, fact.source_span),
                  ],
                })
              None => ()
            }
            match paint_server_reference(fact.declared_value) {
              Some(id) if fact.property == "fill" || fact.property == "stroke" =>
                paint_server_references.push(
                  (subject_id, fact.property, id, fact.source_span),
                )
              _ => ()
            }
          }
        }
      }
      _ => ()
    }
  }
  append_viewport_preflight_diagnostics(
    input, profile, source_role, diagnostics,
  )
  append_use_structure_diagnostics(input, profile, source_role, diagnostics)
  append_marker_resource_diagnostics(input, profile, source_role, diagnostics)
  let visual_subjects = extract_source_subjects_with_profile_or_raise(
    input, profile,
  )
  append_basic_shape_geometry_diagnostics(
    visual_subjects, source_role, diagnostics,
  )
  append_stroke_geometry_diagnostics(visual_subjects, source_role, diagnostics)
  append_marker_geometry_diagnostics(visual_subjects, source_role, diagnostics)
  append_clip_path_diagnostics(input, profile, source_role, diagnostics)
  append_mask_diagnostics(input, profile, source_role, diagnostics)
  append_filter_diagnostics(input, profile, source_role, diagnostics)
  append_blend_diagnostics(input, profile, source_role, diagnostics)
  append_basic_shape_renderer_diagnostics(
    visual_subjects, source_role, diagnostics,
  )
  append_stroke_renderer_diagnostics(visual_subjects, source_role, diagnostics)
  for reference in paint_server_references {
    let (subject_id, property, server_id, span) = reference
    if gradient_ids.contains(server_id) {
      let id = "diagnostic:renderer-gradient-raster-unproven:\{subject_id}:\{property}"
      merge_diagnostic_into(diagnostics, {
        ..unlocated_diagnostic(
          id,
          "renderer_gradient_raster_unproven",
          subject_id,
          ["rendered_evidence"],
        ),
        source_locations: [diagnostic_location(source_role, span)],
      })
    } else if pattern_ids.contains(server_id) {
      let id = "diagnostic:renderer-pattern-raster-unproven:\{subject_id}:\{property}"
      merge_diagnostic_into(diagnostics, {
        ..unlocated_diagnostic(
          id,
          "renderer_pattern_raster_unproven",
          subject_id,
          ["rendered_evidence"],
        ),
        source_locations: [diagnostic_location(source_role, span)],
      })
    }
  }
  diagnostics
}

///|
fn preflight_source(
  input : String,
  profile : ComparisonProfile,
  source_role : String,
  bundle : ResourceBundle,
  limits : ResourceLimits,
) -> SourcePreflight {
  try
    preflight_source_or_raise(input, profile, source_role, bundle, limits)
  catch {
    @xml.At(error=_, span~) =>
      SourceFailed(
        located_diagnostic(
          "diagnostic:svg-parse-failed:document",
          "svg_parse_failed",
          "document",
          ["source_semantics", "computed_appearance", "rendered_evidence"],
          source_role,
          span,
        ),
      )
    _ =>
      SourceFailed(
        unlocated_diagnostic(
          "diagnostic:svg-parse-failed:document",
          "svg_parse_failed",
          "document",
          ["source_semantics", "computed_appearance", "rendered_evidence"],
        ),
      )
  } noraise {
    diagnostics =>
      if diagnostics.is_empty() {
        SourceCovered
      } else {
        SourcePartial(diagnostics)
      }
  }
}

///|
fn failed_source_report(
  profile : ComparisonProfile,
  diagnostics : Array[Diagnostic],
) -> StructuredReport {
  let diagnostic_id = "diagnostic:svg-parse-failed:document"
  {
    schema_version: "2.0",
    analysis_status: "failed",
    canvas_outcome: not_computed_canvas_outcome("rendered_evidence_unavailable"),
    impact_assessment: empty_impact_assessment(),
    coverage_matrix: [
      {
        feature_id: "document.xml",
        subject_id: "document",
        source_semantics: "failed",
        computed_appearance: "failed",
        rendered_evidence: "failed",
        diagnostic_ids: [diagnostic_id],
      },
    ],
    renderer_capability_gaps: [],
    profile,
    subject_alignments: [],
    changed_facts: [],
    source_resolutions: [],
    atomic_differences: [],
    events: [],
    diagnostics,
  }
}

///|
fn apply_preflight_diagnostics(
  report : StructuredReport,
  diagnostics : Array[Diagnostic],
) -> StructuredReport {
  if diagnostics.is_empty() {
    return report
  }
  let combined = report.diagnostics.copy()
  for diagnostic in diagnostics {
    merge_diagnostic_into(combined, diagnostic)
  }
  {
    schema_version: report.schema_version,
    analysis_status: if report.analysis_status == "failed" {
      "failed"
    } else {
      "partial"
    },
    canvas_outcome: report.canvas_outcome,
    impact_assessment: report.impact_assessment,
    coverage_matrix: report.coverage_matrix,
    renderer_capability_gaps: report.renderer_capability_gaps,
    profile: report.profile,
    subject_alignments: report.subject_alignments,
    changed_facts: report.changed_facts,
    source_resolutions: report.source_resolutions,
    atomic_differences: report.atomic_differences,
    events: report.events,
    diagnostics: combined,
  }
}
