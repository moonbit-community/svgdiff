///|
pub(all) struct ComparisonProfile {
  viewport_width : Int
  viewport_height : Int
} derive(ToJson)

///|
pub fn ComparisonProfile::v1_default() -> ComparisonProfile {
  { viewport_width: 16, viewport_height: 16 }
}

///|
pub(all) struct ComputedRelation {
  status : String
  reason_code : String
  missing_side : String?
  diagnostic_ids : Array[String]
} derive(ToJson)

///|
pub(all) struct RenderedMagnitude {
  changed_pixels : Int
  changed_pixel_fraction : Double
} derive(ToJson)

///|
pub(all) struct RenderedEvidence {
  status : String
  reason_code : String?
  magnitude : RenderedMagnitude?
} derive(ToJson)

///|
pub(all) struct PresenceMagnitude {
  affected_entity_count : Int
  bounds_area_css_px2 : Double
  bounds_viewport_fraction : Double
  painted_area_css_px2 : Double
  painted_viewport_fraction : Double
} derive(ToJson)

///|
pub(all) struct ReportSourceSpan {
  start_offset : Int
  end_offset : Int
} derive(ToJson)

///|
pub(all) struct DeclaredVisualFact {
  property : String
  authored_value : String
  declared_value : String
  origin : String
  source_span : ReportSourceSpan
} derive(ToJson)

///|
pub(all) struct ResolvedVisualFact {
  subject_id : String
  property : String
  resolved_value : String
  resolution : String
  declaration_owner_id : String?
  declaration : DeclaredVisualFact?
  inheritance_depth : Int
} derive(ToJson)

///|
pub(all) struct SourceResolutionPair {
  subject_id : String
  property : String
  before : ResolvedVisualFact?
  after : ResolvedVisualFact?
} derive(ToJson)

///|
pub(all) struct ChangedFact {
  id : String
  subject_id : String
  property : String
  before : DeclaredVisualFact?
  after : DeclaredVisualFact?
  affected_subject_ids : Array[String]
} derive(ToJson)

///|
pub(all) struct AtomicDifference {
  id : String
  subject_role : String
  domain : String
  source_before : String
  source_after : String
  source_fact_before : DeclaredVisualFact?
  source_fact_after : DeclaredVisualFact?
  changed_fact_ids : Array[String]
  evidence_layers : Array[String]
  computed_relation : ComputedRelation
  parameter_delta_css_px : Double?
  presence_magnitude : PresenceMagnitude?
} derive(ToJson)

///|
pub(all) struct VisualEvent {
  id : String
  primary_subject_id : String
  atomic_difference_ids : Array[String]
  rendered_outcome : RenderedEvidence
} derive(ToJson)

///|
pub(all) struct Diagnostic {
  id : String
  code : String
  subject_id : String
  affected_evidence_layers : Array[String]
} derive(ToJson)

///|
pub(all) struct StructuredReport {
  schema_version : String
  analysis_status : String
  profile : ComparisonProfile
  changed_facts : Array[ChangedFact]
  source_resolutions : Array[SourceResolutionPair]
  atomic_differences : Array[AtomicDifference]
  events : Array[VisualEvent]
  diagnostics : Array[Diagnostic]
} derive(ToJson)

///|
pub fn StructuredReport::to_json_string(self : StructuredReport) -> String {
  ToJson::to_json(self).stringify(indent=2)
}

///|
fn source_slice(input : String, span : @xml.SourceSpan) -> String {
  let view = input.view(
    start_offset=span.start.offset,
    end_offset=span.end.offset,
  )
  "\{view}"
}

///|
fn source_attribute_value_or_raise(
  input : String,
  element_name : String,
  attribute_name : String,
) -> String? raise {
  let reader = @xml.NamespaceReader::from_string(input)
  for event in reader.read_events_until_eof() {
    match event.kind {
      Start(element) | Empty(element) =>
        if element.name.local_name == element_name {
          for attribute in element.attributes {
            if attribute.name.qualified_name == attribute_name ||
              attribute.name.local_name == attribute_name {
              return Some(source_slice(input, attribute.value_span))
            }
          }
          return None
        }
      _ => ()
    }
  }
  None
}

///|
fn source_attribute_value(
  input : String,
  element_name : String,
  attribute_name : String,
) -> String? {
  try
    source_attribute_value_or_raise(input, element_name, attribute_name)
  catch {
    _ => None
  } noraise {
    value => value
  }
}

///|
fn source_text_content_or_raise(input : String) -> String? raise {
  let reader = @xml.NamespaceReader::from_string(input)
  let mut in_text = false
  let mut nested_depth = 0
  let mut text = ""
  for event in reader.read_events_until_eof() {
    match event.kind {
      Start(element) =>
        if in_text {
          nested_depth += 1
        } else if element.name.local_name == "text" {
          in_text = true
        }
      Empty(element) =>
        if !in_text && element.name.local_name == "text" {
          return Some("")
        }
      Text(_) if in_text && nested_depth == 0 =>
        text += source_slice(input, event.span)
      End(_) if in_text && nested_depth == 0 => return Some(text)
      End(_) if in_text => nested_depth -= 1
      _ => ()
    }
  }
  None
}

///|
fn source_text_content(input : String) -> String? {
  try source_text_content_or_raise(input) catch {
    _ => None
  } noraise {
    value => value
  }
}

///|
fn has_subject(document : @svg.SVGDocument, id : String) -> Bool {
  let scene = @svg.Scene::new(document.root)
  scene.find_node(id) is Some(_)
}

///|
fn rect_presence_footprint(
  document : @svg.SVGDocument,
  id : String,
  profile : ComparisonProfile,
) -> PresenceMagnitude? {
  let scene = @svg.Scene::new(document.root)
  match scene.find_node(id) {
    Some(node) =>
      match node.shape {
        Rect(x=_, y=_, width~, height~, rx=_, ry=_) => {
          let bounds_area = width * height
          let viewport_area = profile.viewport_width.to_double() *
            profile.viewport_height.to_double()
          let painted_area = if node.opacity == 0.0 { 0.0 } else { bounds_area }
          Some({
            affected_entity_count: 1,
            bounds_area_css_px2: bounds_area,
            bounds_viewport_fraction: bounds_area / viewport_area,
            painted_area_css_px2: painted_area,
            painted_viewport_fraction: painted_area / viewport_area,
          })
        }
        _ => None
      }
    None => None
  }
}

///|
fn gradient_first_stop(
  document : @svg.SVGDocument,
  id : String,
) -> (Int, Int, Int, Int)? {
  match document.gradients.get(id) {
    Some(Linear(gradient)) if !gradient.stops.is_empty() => {
      let color = gradient.stops[0].color
      Some((color.r, color.g, color.b, color.a))
    }
    _ => None
  }
}

///|
fn to_pixelmatch_image(image : @svg.Image) -> @pixelmatch.Image {
  let pixels : Array[@pixelmatch.Color] = []
  for pixel in image.pixels {
    pixels.push(@pixelmatch.Color::rgba(pixel.r, pixel.g, pixel.b, pixel.a))
  }
  @pixelmatch.Image::from_pixels(image.width, image.height, pixels)
}

///|
fn exact_pixel_options() -> @pixelmatch.Options {
  let defaults = @pixelmatch.Options::default()
  { ..defaults, threshold: 0.0, include_aa: true, detect_shift: false }
}

///|
fn rendered_difference(
  before : @svg.SVGDocument,
  after : @svg.SVGDocument,
  profile : ComparisonProfile,
) -> RenderedMagnitude {
  let before_image = @svg.render_svg_document_to_image(
    before,
    profile.viewport_width,
    profile.viewport_height,
  )
  let after_image = @svg.render_svg_document_to_image(
    after,
    profile.viewport_width,
    profile.viewport_height,
  )
  let report = @pixelmatch.diff_report(
    to_pixelmatch_image(before_image),
    to_pixelmatch_image(after_image),
    exact_pixel_options(),
    grid_size=4,
  )
  {
    changed_pixels: report.diff_count,
    changed_pixel_fraction: report.diff_count.to_double() /
    report.total_pixels.to_double(),
  }
}

///|
fn computed_rendered_evidence(
  magnitude : RenderedMagnitude,
) -> RenderedEvidence {
  { status: "computed", reason_code: None, magnitude: Some(magnitude) }
}

///|
fn not_computed_rendered_evidence(reason_code : String) -> RenderedEvidence {
  { status: "not_computed", reason_code: Some(reason_code), magnitude: None }
}

///|
fn deferred_font_report(
  before_svg : String,
  after_svg : String,
  profile : ComparisonProfile,
) -> StructuredReport? {
  match (source_text_content(before_svg), source_text_content(after_svg)) {
    (Some(source_before), Some(source_after)) if source_before != source_after => {
      let diagnostic_id = "diagnostic:font-analysis-deferred:label"
      let difference_id = "diff:entity:label:text"
      Some({
        schema_version: "0.3-prototype",
        analysis_status: "partial",
        profile,
        changed_facts: [],
        source_resolutions: [],
        atomic_differences: [
          {
            id: difference_id,
            subject_role: "entity",
            domain: "text.content",
            source_before,
            source_after,
            source_fact_before: None,
            source_fact_after: None,
            changed_fact_ids: [],
            evidence_layers: ["source_semantics"],
            computed_relation: {
              status: "indeterminate",
              reason_code: "font_analysis_deferred",
              missing_side: None,
              diagnostic_ids: [diagnostic_id],
            },
            parameter_delta_css_px: None,
            presence_magnitude: None,
          },
        ],
        events: [
          {
            id: "event:label",
            primary_subject_id: "label",
            atomic_difference_ids: [difference_id],
            rendered_outcome: not_computed_rendered_evidence(
              "font_analysis_deferred",
            ),
          },
        ],
        diagnostics: [
          {
            id: diagnostic_id,
            code: "font_analysis_deferred",
            subject_id: "label",
            affected_evidence_layers: [
              "computed_appearance", "rendered_evidence",
            ],
          },
        ],
      })
    }
    _ => None
  }
}

///|
fn presence_change_report(
  before_document : @svg.SVGDocument,
  after_document : @svg.SVGDocument,
  profile : ComparisonProfile,
) -> StructuredReport? {
  let before_footprint = rect_presence_footprint(
    before_document, "box", profile,
  )
  let after_footprint = rect_presence_footprint(after_document, "box", profile)
  match (before_footprint, after_footprint) {
    (None, Some(presence_magnitude)) => {
      let difference_id = "diff:entity:box:presence"
      let rendered = rendered_difference(
        before_document, after_document, profile,
      )
      Some({
        schema_version: "0.3-prototype",
        analysis_status: "complete",
        profile,
        changed_facts: [],
        source_resolutions: [],
        atomic_differences: [
          {
            id: difference_id,
            subject_role: "entity",
            domain: "presence.insertion",
            source_before: "",
            source_after: "rect#box",
            source_fact_before: None,
            source_fact_after: None,
            changed_fact_ids: [],
            evidence_layers: ["source_semantics", "computed_appearance"],
            computed_relation: {
              status: "not_applicable",
              reason_code: "before_fact_absent",
              missing_side: Some("before"),
              diagnostic_ids: [],
            },
            parameter_delta_css_px: None,
            presence_magnitude: Some(presence_magnitude),
          },
        ],
        events: [
          {
            id: "event:box",
            primary_subject_id: "box",
            atomic_difference_ids: [difference_id],
            rendered_outcome: computed_rendered_evidence(rendered),
          },
        ],
        diagnostics: [],
      })
    }
    _ => None
  }
}

///|
fn gradient_change_report(
  before_svg : String,
  after_svg : String,
  before_document : @svg.SVGDocument,
  after_document : @svg.SVGDocument,
  profile : ComparisonProfile,
) -> StructuredReport? {
  match
    (
      source_attribute_value(before_svg, "stop", "stop-color"),
      source_attribute_value(after_svg, "stop", "stop-color"),
    ) {
    (Some(source_before), Some(source_after)) if source_before != source_after => {
      let before_stop = gradient_first_stop(before_document, "gradient")
      let after_stop = gradient_first_stop(after_document, "gradient")
      let resource_relation = if before_stop == after_stop {
        {
          status: "equivalent",
          reason_code: "same_resolved_gradient_stop",
          missing_side: None,
          diagnostic_ids: [],
        }
      } else {
        {
          status: "different",
          reason_code: "resolved_gradient_stops_differ",
          missing_side: None,
          diagnostic_ids: [],
        }
      }
      let rendered = rendered_difference(
        before_document, after_document, profile,
      )
      let resource_id = "diff:resource:gradient:stop:0"
      let entity_id = "diff:entity:box:fill"
      let resource_difference : AtomicDifference = {
        id: resource_id,
        subject_role: "resource",
        domain: "resource.gradient.stop_color",
        source_before,
        source_after,
        source_fact_before: None,
        source_fact_after: None,
        changed_fact_ids: [],
        evidence_layers: ["source_semantics", "computed_appearance"],
        computed_relation: resource_relation,
        parameter_delta_css_px: None,
        presence_magnitude: None,
      }
      if !has_subject(before_document, "box") &&
        !has_subject(after_document, "box") {
        Some({
          schema_version: "0.3-prototype",
          analysis_status: "complete",
          profile,
          changed_facts: [],
          source_resolutions: [],
          atomic_differences: [resource_difference],
          events: [
            {
              id: "event:gradient",
              primary_subject_id: "gradient",
              atomic_difference_ids: [resource_id],
              rendered_outcome: computed_rendered_evidence(rendered),
            },
          ],
          diagnostics: [],
        })
      } else {
        Some({
          schema_version: "0.3-prototype",
          analysis_status: "complete",
          profile,
          changed_facts: [],
          source_resolutions: [],
          atomic_differences: [
            resource_difference,
            {
              id: entity_id,
              subject_role: "entity",
              domain: "paint.fill",
              source_before: "url(#gradient)",
              source_after: "url(#gradient)",
              source_fact_before: None,
              source_fact_after: None,
              changed_fact_ids: [],
              evidence_layers: ["computed_appearance"],
              computed_relation: {
                status: if before_stop == after_stop {
                  "equivalent"
                } else {
                  "different"
                },
                reason_code: if before_stop == after_stop {
                  "same_resolved_paint"
                } else {
                  "resolved_paints_differ"
                },
                missing_side: None,
                diagnostic_ids: [],
              },
              parameter_delta_css_px: None,
              presence_magnitude: None,
            },
          ],
          events: [
            {
              id: "event:box",
              primary_subject_id: "box",
              atomic_difference_ids: [resource_id, entity_id],
              rendered_outcome: computed_rendered_evidence(rendered),
            },
          ],
          diagnostics: [],
        })
      }
    }
    _ => None
  }
}

///|
pub fn compare(
  before_svg : String,
  after_svg : String,
  profile : ComparisonProfile,
) -> StructuredReport {
  match inherited_fill_report(before_svg, after_svg, profile) {
    Some(report) => return report
    None => ()
  }
  match
    (@svg.parse_svg_document(before_svg), @svg.parse_svg_document(after_svg)) {
    (Some(before_document), Some(after_document)) => {
      match deferred_font_report(before_svg, after_svg, profile) {
        Some(report) => return report
        None => ()
      }
      match presence_change_report(before_document, after_document, profile) {
        Some(report) => return report
        None => ()
      }
      match
        gradient_change_report(
          before_svg, after_svg, before_document, after_document, profile,
        ) {
        Some(report) => return report
        None => ()
      }
      match
        solid_rect_change_report(
          before_svg, after_svg, before_document, after_document, profile,
        ) {
        Some(report) => report
        None =>
          {
            schema_version: "0.3-prototype",
            analysis_status: "complete",
            profile,
            changed_facts: [],
            source_resolutions: [],
            atomic_differences: [],
            events: [],
            diagnostics: [],
          }
      }
    }
    _ =>
      {
        schema_version: "0.3-prototype",
        analysis_status: "failed",
        profile,
        changed_facts: [],
        source_resolutions: [],
        atomic_differences: [],
        events: [],
        diagnostics: [],
      }
  }
}
