///|
pub(all) struct ComparisonProfile {
  viewport_width : Int
  viewport_height : Int
  comparison_dpr : Double
  color_interpretation : String
  raster_representation : String
  renderer_id : String
} derive(ToJson)

///|
pub fn ComparisonProfile::v1_default() -> ComparisonProfile {
  {
    viewport_width: 16,
    viewport_height: 16,
    comparison_dpr: 1.0,
    color_interpretation: "srgb",
    raster_representation: "linear_srgb_premultiplied_rgba_f64",
    renderer_id: "mizchi/svg@0.2.1",
  }
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
  rgba8_rmse : Double
  linear_premultiplied_rgba_rmse : Double
} derive(ToJson)

///|
pub(all) struct RenderedEvidence {
  status : String
  reason_code : String?
  magnitude : RenderedMagnitude?
} derive(ToJson)

///|
pub(all) struct CauseEnvelope {
  guarantee : String
  coverage : String
  fallback_scope : String
  candidate_changed_fact_ids : Array[String]
  diagnostic_ids : Array[String]
} derive(ToJson)

///|
pub(all) struct DifferenceRegion {
  id : String
  source : String
  pixel_x : Int
  pixel_y : Int
  pixel_width : Int
  pixel_height : Int
  css_x : Double
  css_y : Double
  css_width : Double
  css_height : Double
  changed_pixels : Int
  viewport_fraction : Double
  cause_envelope : CauseEnvelope
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
pub(all) struct DifferenceMagnitude {
  parameter_abs_user_units : Double?
  parameter_signed_user_units : Double?
  symmetric_relative : Double?
  geometry_displacement_css_px : Double?
  geometry_viewport_fraction : Double?
  presence_painted_viewport_fraction : Double?
  raster_changed_pixel_fraction : Double?
  raster_rgba8_rmse : Double?
  raster_linear_premultiplied_rgba_rmse : Double?
} derive(ToJson)

///|
pub(all) struct DomainOrdering {
  policy_id : String
  components : Array[Double]
} derive(ToJson)

///|
fn empty_difference_magnitude() -> DifferenceMagnitude {
  {
    parameter_abs_user_units: None,
    parameter_signed_user_units: None,
    symmetric_relative: None,
    geometry_displacement_css_px: None,
    geometry_viewport_fraction: None,
    presence_painted_viewport_fraction: None,
    raster_changed_pixel_fraction: None,
    raster_rgba8_rmse: None,
    raster_linear_premultiplied_rgba_rmse: None,
  }
}

///|
fn empty_domain_ordering() -> DomainOrdering {
  { policy_id: "v1_domain_lexicographic", components: [] }
}

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
pub(all) struct SubjectReference {
  source_index : Int
  kind : String
  authored_id : String?
} derive(ToJson)

///|
pub(all) struct SubjectAlignment {
  id : String
  relation : String
  before : Array[SubjectReference]
  after : Array[SubjectReference]
  basis : String
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
  subject_alignment_id : String?
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
  magnitude : DifferenceMagnitude
  domain_ordering : DomainOrdering
} derive(ToJson)

///|
pub(all) struct VisualEvent {
  id : String
  primary_subject_id : String
  atomic_difference_ids : Array[String]
  rendered_outcome : RenderedEvidence
  difference_regions : Array[DifferenceRegion]
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
  subject_alignments : Array[SubjectAlignment]
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
priv enum SourcePreflight {
  SourceCovered
  SourcePartial(Array[Diagnostic])
  SourceFailed
}

///|
fn known_source_element(kind : String) -> Bool {
  match kind {
    "svg"
    | "g"
    | "rect"
    | "circle"
    | "ellipse"
    | "line"
    | "polyline"
    | "polygon"
    | "defs"
    | "linearGradient"
    | "stop"
    | "text"
    | "title"
    | "desc"
    | "metadata"
    | "style" => true
    _ => false
  }
}

///|
fn known_source_attribute(kind : String, name : String) -> Bool {
  if name == "id" ||
    name == "style" ||
    name == "fill" ||
    name == "stroke" ||
    name == "stroke-width" ||
    name == "opacity" {
    return true
  }
  match kind {
    "svg" =>
      name == "width" ||
      name == "height" ||
      name == "viewBox" ||
      name == "preserveAspectRatio" ||
      name == "xmlns"
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
      name == "href"
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
fn preflight_source_or_raise(input : String) -> Array[Diagnostic] raise {
  let diagnostics : Array[Diagnostic] = []
  let reader = @xml.NamespaceReader::from_string(input)
  for event in reader.read_events_until_eof() {
    match event.kind {
      Start(element) | Empty(element) => {
        let kind = element.name.local_name
        if !known_source_element(kind) {
          let id = "diagnostic:unsupported-visual-subject:\{kind}"
          if !diagnostics.any(diagnostic => diagnostic.id == id) {
            diagnostics.push({
              id,
              code: "unsupported_visual_subject",
              subject_id: kind,
              affected_evidence_layers: [
                "computed_appearance", "rendered_evidence",
              ],
            })
          }
        } else {
          let presentation_properties : Array[String] = []
          let mut style_attribute : @xml.NamespaceAttribute? = None
          let mut subject_id = kind
          for attribute in element.attributes {
            let name = attribute.name.local_name
            if name == "id" && attribute.value.trim() != "" {
              subject_id = attribute.value.trim().to_owned()
            } else if name == "style" {
              style_attribute = Some(attribute)
            } else if supported_rect_property(name) {
              presentation_properties.push(name)
            }
            if !known_source_attribute(kind, name) {
              let id = "diagnostic:unsupported-visual-attribute:\{kind}:\{name}"
              if !diagnostics.any(diagnostic => diagnostic.id == id) {
                diagnostics.push({
                  id,
                  code: "unsupported_visual_attribute",
                  subject_id: kind,
                  affected_evidence_layers: [
                    "source_semantics", "computed_appearance", "rendered_evidence",
                  ],
                })
              }
            }
          }
          match style_attribute {
            Some(attribute) => {
              let style = inline_style_facts(input, attribute)
              for fact in style.facts {
                if presentation_properties.contains(fact.property) {
                  let id = "diagnostic:renderer-style-precedence-unresolved:\{subject_id}:\{fact.property}"
                  if !diagnostics.any(diagnostic => diagnostic.id == id) {
                    diagnostics.push({
                      id,
                      code: "renderer_style_precedence_unresolved",
                      subject_id,
                      affected_evidence_layers: [
                        "computed_appearance", "rendered_evidence",
                      ],
                    })
                  }
                }
              }
            }
            None => ()
          }
        }
      }
      _ => ()
    }
  }
  diagnostics
}

///|
fn preflight_source(input : String) -> SourcePreflight {
  try preflight_source_or_raise(input) catch {
    _ => SourceFailed
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
fn failed_source_report(profile : ComparisonProfile) -> StructuredReport {
  {
    schema_version: "0.3-prototype",
    analysis_status: "failed",
    profile,
    subject_alignments: [],
    changed_facts: [],
    source_resolutions: [],
    atomic_differences: [],
    events: [],
    diagnostics: [
      {
        id: "diagnostic:svg-parse-failed:document",
        code: "svg_parse_failed",
        subject_id: "document",
        affected_evidence_layers: [
          "source_semantics", "computed_appearance", "rendered_evidence",
        ],
      },
    ],
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
    if !combined.any(current => current.id == diagnostic.id) {
      combined.push(diagnostic)
    }
  }
  {
    schema_version: report.schema_version,
    analysis_status: if report.analysis_status == "failed" {
      "failed"
    } else {
      "partial"
    },
    profile: report.profile,
    subject_alignments: report.subject_alignments,
    changed_facts: report.changed_facts,
    source_resolutions: report.source_resolutions,
    atomic_differences: report.atomic_differences,
    events: report.events,
    diagnostics: combined,
  }
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
fn raw_rgba8_squared_error(left : @svg.Color, right : @svg.Color) -> Double {
  let red = (left.r - right.r).to_double() / 255.0
  let green = (left.g - right.g).to_double() / 255.0
  let blue = (left.b - right.b).to_double() / 255.0
  let alpha = (left.a - right.a).to_double() / 255.0
  red * red + green * green + blue * blue + alpha * alpha
}

///|
fn srgb8_to_linear(value : Int) -> Double {
  let channel = value.to_double() / 255.0
  if channel <= 0.04045 {
    channel / 12.92
  } else {
    @math.pow((channel + 0.055) / 1.055, 2.4)
  }
}

///|
fn linear_premultiplied_rgba_squared_error(
  left : @svg.Color,
  right : @svg.Color,
) -> Double {
  let left_alpha = left.a.to_double() / 255.0
  let right_alpha = right.a.to_double() / 255.0
  let red = srgb8_to_linear(left.r) * left_alpha -
    srgb8_to_linear(right.r) * right_alpha
  let green = srgb8_to_linear(left.g) * left_alpha -
    srgb8_to_linear(right.g) * right_alpha
  let blue = srgb8_to_linear(left.b) * left_alpha -
    srgb8_to_linear(right.b) * right_alpha
  let alpha = left_alpha - right_alpha
  red * red + green * green + blue * blue + alpha * alpha
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
  let mut squared_error = 0.0
  let mut linear_squared_error = 0.0
  for index in 0..<before_image.pixels.length() {
    let before_pixel = before_image.pixels[index]
    let after_pixel = after_image.pixels[index]
    squared_error += raw_rgba8_squared_error(before_pixel, after_pixel)
    linear_squared_error += linear_premultiplied_rgba_squared_error(
      before_pixel, after_pixel,
    )
  }
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
    rgba8_rmse: (squared_error / (before_image.pixels.length() * 4).to_double()).sqrt(),
    linear_premultiplied_rgba_rmse: (linear_squared_error /
    (before_image.pixels.length() * 4).to_double()).sqrt(),
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
        subject_alignments: [],
        changed_facts: [],
        source_resolutions: [],
        atomic_differences: [
          {
            id: difference_id,
            subject_role: "entity",
            subject_alignment_id: None,
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
            magnitude: empty_difference_magnitude(),
            domain_ordering: empty_domain_ordering(),
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
            difference_regions: [],
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
        subject_alignments: [],
        changed_facts: [],
        source_resolutions: [],
        atomic_differences: [
          {
            id: difference_id,
            subject_role: "entity",
            subject_alignment_id: None,
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
            magnitude: empty_difference_magnitude(),
            domain_ordering: empty_domain_ordering(),
          },
        ],
        events: [
          {
            id: "event:box",
            primary_subject_id: "box",
            atomic_difference_ids: [difference_id],
            rendered_outcome: computed_rendered_evidence(rendered),
            difference_regions: [],
          },
        ],
        diagnostics: [],
      })
    }
    (Some(presence_magnitude), None) => {
      let difference_id = "diff:entity:box:presence"
      let rendered = rendered_difference(
        before_document, after_document, profile,
      )
      Some({
        schema_version: "0.3-prototype",
        analysis_status: "complete",
        profile,
        subject_alignments: [],
        changed_facts: [],
        source_resolutions: [],
        atomic_differences: [
          {
            id: difference_id,
            subject_role: "entity",
            subject_alignment_id: None,
            domain: "presence.deletion",
            source_before: "rect#box",
            source_after: "",
            source_fact_before: None,
            source_fact_after: None,
            changed_fact_ids: [],
            evidence_layers: ["source_semantics", "computed_appearance"],
            computed_relation: {
              status: "not_applicable",
              reason_code: "after_fact_absent",
              missing_side: Some("after"),
              diagnostic_ids: [],
            },
            parameter_delta_css_px: None,
            presence_magnitude: Some(presence_magnitude),
            magnitude: empty_difference_magnitude(),
            domain_ordering: empty_domain_ordering(),
          },
        ],
        events: [
          {
            id: "event:box",
            primary_subject_id: "box",
            atomic_difference_ids: [difference_id],
            rendered_outcome: computed_rendered_evidence(rendered),
            difference_regions: [],
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
        subject_alignment_id: None,
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
        magnitude: empty_difference_magnitude(),
        domain_ordering: empty_domain_ordering(),
      }
      if !has_subject(before_document, "box") &&
        !has_subject(after_document, "box") {
        Some({
          schema_version: "0.3-prototype",
          analysis_status: "complete",
          profile,
          subject_alignments: [],
          changed_facts: [],
          source_resolutions: [],
          atomic_differences: [resource_difference],
          events: [
            {
              id: "event:gradient",
              primary_subject_id: "gradient",
              atomic_difference_ids: [resource_id],
              rendered_outcome: computed_rendered_evidence(rendered),
              difference_regions: [],
            },
          ],
          diagnostics: [],
        })
      } else {
        Some({
          schema_version: "0.3-prototype",
          analysis_status: "complete",
          profile,
          subject_alignments: [],
          changed_facts: [],
          source_resolutions: [],
          atomic_differences: [
            resource_difference,
            {
              id: entity_id,
              subject_role: "entity",
              subject_alignment_id: None,
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
              magnitude: empty_difference_magnitude(),
              domain_ordering: empty_domain_ordering(),
            },
          ],
          events: [
            {
              id: "event:box",
              primary_subject_id: "box",
              atomic_difference_ids: [resource_id, entity_id],
              rendered_outcome: computed_rendered_evidence(rendered),
              difference_regions: [],
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
  let preflight_diagnostics : Array[Diagnostic] = []
  match (preflight_source(before_svg), preflight_source(after_svg)) {
    (SourceFailed, _) | (_, SourceFailed) =>
      return failed_source_report(profile)
    (SourcePartial(before), SourcePartial(after)) => {
      preflight_diagnostics.push_iter(before.iter())
      preflight_diagnostics.push_iter(after.iter())
    }
    (SourcePartial(diagnostics), _) | (_, SourcePartial(diagnostics)) =>
      preflight_diagnostics.push_iter(diagnostics.iter())
    _ => ()
  }
  let subject_alignments = subject_alignments_for_sources(before_svg, after_svg)
  match inherited_fill_report(before_svg, after_svg, profile) {
    Some(report) =>
      return finish_report(
        report, preflight_diagnostics, subject_alignments, before_svg, after_svg,
      )
    None => ()
  }
  match
    (@svg.parse_svg_document(before_svg), @svg.parse_svg_document(after_svg)) {
    (Some(before_document), Some(after_document)) => {
      match
        generic_basic_shape_report(
          before_svg, after_svg, before_document, after_document, profile, subject_alignments,
        ) {
        Some(report) =>
          return finish_report(
            report, preflight_diagnostics, subject_alignments, before_svg, after_svg,
          )
        None => ()
      }
      match deferred_font_report(before_svg, after_svg, profile) {
        Some(report) =>
          return finish_report(
            report, preflight_diagnostics, subject_alignments, before_svg, after_svg,
          )
        None => ()
      }
      match presence_change_report(before_document, after_document, profile) {
        Some(report) =>
          return finish_report(
            report, preflight_diagnostics, subject_alignments, before_svg, after_svg,
          )
        None => ()
      }
      match
        gradient_change_report(
          before_svg, after_svg, before_document, after_document, profile,
        ) {
        Some(report) =>
          return finish_report(
            report, preflight_diagnostics, subject_alignments, before_svg, after_svg,
          )
        None => ()
      }
      match
        solid_rect_change_report(
          before_svg, after_svg, before_document, after_document, profile,
        ) {
        Some(report) =>
          finish_report(
            report, preflight_diagnostics, subject_alignments, before_svg, after_svg,
          )
        None =>
          finish_report(
            {
              schema_version: "0.3-prototype",
              analysis_status: "partial",
              profile,
              subject_alignments: [],
              changed_facts: [],
              source_resolutions: [],
              atomic_differences: [],
              events: [],
              diagnostics: [
                {
                  id: "diagnostic:analysis-coverage-unproven:document",
                  code: "analysis_coverage_unproven",
                  subject_id: "document",
                  affected_evidence_layers: [
                    "source_semantics", "computed_appearance", "rendered_evidence",
                  ],
                },
              ],
            },
            preflight_diagnostics,
            subject_alignments,
            before_svg,
            after_svg,
          )
      }
    }
    _ => failed_source_report(profile)
  }
}
