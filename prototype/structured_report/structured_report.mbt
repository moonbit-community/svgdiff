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
pub(all) struct AtomicDifference {
  id : String
  subject_role : String
  domain : String
  source_before : String
  source_after : String
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
  atomic_differences : Array[AtomicDifference]
  events : Array[VisualEvent]
  diagnostics : Array[Diagnostic]
} derive(ToJson)

///|
pub fn StructuredReport::to_json_string(self : StructuredReport) -> String {
  ToJson::to_json(self).stringify(indent=2)
}

///|
fn source_attribute_value(
  input : String,
  element_name : String,
  attribute_name : String,
) -> String? {
  match @source.parse(input) {
    Ok(document) =>
      match document.elements_named(element_name).get(0) {
        Some(element) =>
          match element.attribute(attribute_name) {
            Some(attribute) => Some(attribute.value)
            None => None
          }
        None => None
      }
    Err(_) => None
  }
}

///|
fn source_text_content(input : String) -> String? {
  match @source.parse(input) {
    Ok(document) =>
      match document.elements_named("text").get(0) {
        Some(element) => Some(element.direct_text())
        None => None
      }
    Err(_) => None
  }
}

///|
fn solid_fill(
  document : @svg.SVGDocument,
  id : String,
) -> (Int, Int, Int, Int)? {
  let scene = @svg.Scene::new(document.root)
  match scene.find_node(id) {
    Some(node) =>
      match node.fill {
        SolidColor(color) => Some((color.r, color.g, color.b, color.a))
        _ => None
      }
    None => None
  }
}

///|
fn rect_x(document : @svg.SVGDocument, id : String) -> Double? {
  let scene = @svg.Scene::new(document.root)
  match scene.find_node(id) {
    Some(node) =>
      match node.shape {
        Rect(x~, y=_, width=_, height=_, rx=_, ry=_) => Some(x)
        _ => None
      }
    None => None
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
fn parse_number(source : String) -> Double? {
  try @string.parse_double(source) catch {
    _ => None
  } noraise {
    value => Some(value)
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
        schema_version: "0.1-prototype",
        analysis_status: "partial",
        profile,
        atomic_differences: [
          {
            id: difference_id,
            subject_role: "entity",
            domain: "text.content",
            source_before,
            source_after,
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
        schema_version: "0.1-prototype",
        analysis_status: "complete",
        profile,
        atomic_differences: [
          {
            id: difference_id,
            subject_role: "entity",
            domain: "presence.insertion",
            source_before: "",
            source_after: "rect#box",
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
        evidence_layers: ["source_semantics", "computed_appearance"],
        computed_relation: resource_relation,
        parameter_delta_css_px: None,
        presence_magnitude: None,
      }
      if !has_subject(before_document, "box") &&
        !has_subject(after_document, "box") {
        Some({
          schema_version: "0.1-prototype",
          analysis_status: "complete",
          profile,
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
          schema_version: "0.1-prototype",
          analysis_status: "complete",
          profile,
          atomic_differences: [
            resource_difference,
            {
              id: entity_id,
              subject_role: "entity",
              domain: "paint.fill",
              source_before: "url(#gradient)",
              source_after: "url(#gradient)",
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
      let before_source = source_attribute_value(before_svg, "rect", "fill")
      let after_source = source_attribute_value(after_svg, "rect", "fill")
      match (before_source, after_source) {
        (Some(source_before), Some(source_after)) if source_before !=
          source_after => {
          let before_fill = solid_fill(before_document, "box")
          let after_fill = solid_fill(after_document, "box")
          let rendered = rendered_difference(
            before_document, after_document, profile,
          )
          let computed_relation = if before_fill == after_fill {
            {
              status: "equivalent",
              reason_code: "same_resolved_color",
              missing_side: None,
              diagnostic_ids: [],
            }
          } else {
            {
              status: "different",
              reason_code: "resolved_colors_differ",
              missing_side: None,
              diagnostic_ids: [],
            }
          }
          let evidence_layers : Array[String] = ["source_semantics"]
          if computed_relation.status == "different" {
            evidence_layers.push("computed_appearance")
          }
          if rendered.changed_pixels > 0 {
            evidence_layers.push("rendered_evidence")
          }
          let difference_id = "diff:entity:box:fill"
          {
            schema_version: "0.1-prototype",
            analysis_status: "complete",
            profile,
            atomic_differences: [
              {
                id: difference_id,
                subject_role: "entity",
                domain: "paint.fill",
                source_before,
                source_after,
                evidence_layers,
                computed_relation,
                parameter_delta_css_px: None,
                presence_magnitude: None,
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
          }
        }
        _ => {
          let before_x_source = source_attribute_value(before_svg, "rect", "x")
          let after_x_source = source_attribute_value(after_svg, "rect", "x")
          match (before_x_source, after_x_source) {
            (Some(source_before), Some(source_after)) if source_before !=
              source_after => {
              let before_x = rect_x(before_document, "box")
              let after_x = rect_x(after_document, "box")
              let rendered = rendered_difference(
                before_document, after_document, profile,
              )
              let computed_relation = if before_x == after_x {
                {
                  status: "equivalent",
                  reason_code: "same_resolved_position",
                  missing_side: None,
                  diagnostic_ids: [],
                }
              } else {
                {
                  status: "different",
                  reason_code: "resolved_positions_differ",
                  missing_side: None,
                  diagnostic_ids: [],
                }
              }
              let evidence_layers : Array[String] = ["source_semantics"]
              if computed_relation.status == "different" {
                evidence_layers.push("computed_appearance")
              }
              if rendered.changed_pixels > 0 {
                evidence_layers.push("rendered_evidence")
              }
              let parameter_delta_css_px = match
                (parse_number(source_before), parse_number(source_after)) {
                (Some(before_value), Some(after_value)) =>
                  Some(after_value - before_value)
                _ => None
              }
              let difference_id = "diff:entity:box:position"
              {
                schema_version: "0.1-prototype",
                analysis_status: "complete",
                profile,
                atomic_differences: [
                  {
                    id: difference_id,
                    subject_role: "entity",
                    domain: "geometry.position",
                    source_before,
                    source_after,
                    evidence_layers,
                    computed_relation,
                    parameter_delta_css_px,
                    presence_magnitude: None,
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
              }
            }
            _ =>
              {
                schema_version: "0.1-prototype",
                analysis_status: "complete",
                profile,
                atomic_differences: [],
                events: [],
                diagnostics: [],
              }
          }
        }
      }
    }
    _ =>
      {
        schema_version: "0.1-prototype",
        analysis_status: "failed",
        profile,
        atomic_differences: [],
        events: [],
        diagnostics: [],
      }
  }
}
