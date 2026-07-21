///|
fn source_slice(input : String, span : @xml.SourceSpan) -> String {
  let view = input.view(
    start_offset=span.start.offset,
    end_offset=span.end.offset,
  )
  "\{view}"
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
  let before_image = render_product_document_to_image(
    before,
    profile.viewport_width,
    profile.viewport_height,
  )
  let after_image = render_product_document_to_image(
    after,
    profile.viewport_width,
    profile.viewport_height,
  )
  rendered_image_difference(before_image, after_image)
}

///|
fn rendered_image_difference(
  before_image : @svg.Image,
  after_image : @svg.Image,
) -> RenderedMagnitude {
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
  {
    status: "computed",
    reason_code: None,
    magnitude: Some(magnitude),
    perceptual_color: not_computed_perceptual_color_evidence(
      "perceptual_background_absent",
    ),
    perceptual_flip: not_computed_perceptual_flip_evidence("flip_not_requested"),
  }
}

///|
fn not_computed_rendered_evidence(reason_code : String) -> RenderedEvidence {
  {
    status: "not_computed",
    reason_code: Some(reason_code),
    magnitude: None,
    perceptual_color: not_computed_perceptual_color_evidence(
      "rendered_evidence_unavailable",
    ),
    perceptual_flip: not_computed_perceptual_flip_evidence("flip_not_requested"),
  }
}

///|
fn not_computed_canvas_perceptual_flip_evidence(
  reason_code : String,
) -> CanvasPerceptualFlipEvidence {
  {
    status: "not_computed",
    reason_code: Some(reason_code),
    method_id: None,
    canvas_mean: None,
  }
}

///|
fn computed_canvas_perceptual_flip_evidence(
  canvas_mean : Double,
) -> CanvasPerceptualFlipEvidence {
  {
    status: "computed",
    reason_code: None,
    method_id: Some("nvlabs_ldr_flip/v1.7-b475eb4b"),
    canvas_mean: Some(canvas_mean),
  }
}

///|
fn not_computed_canvas_outcome(reason_code : String) -> CanvasOutcome {
  {
    status: "not_computed",
    reason_code: Some(reason_code),
    magnitude: None,
    perceptual_flip: not_computed_canvas_perceptual_flip_evidence(
      "rendered_evidence_unavailable",
    ),
  }
}

///|
fn computed_perceptual_color_evidence(
  magnitude : PerceptualColorMagnitude,
) -> PerceptualColorEvidence {
  { status: "computed", reason_code: None, magnitude: Some(magnitude) }
}

///|
fn not_computed_perceptual_color_evidence(
  reason_code : String,
) -> PerceptualColorEvidence {
  { status: "not_computed", reason_code: Some(reason_code), magnitude: None }
}

///|
fn computed_perceptual_flip_evidence(
  map : PerceptualFlipMap,
  statistics : PerceptualFlipStatistics,
) -> PerceptualFlipEvidence {
  {
    status: "computed",
    reason_code: None,
    map: Some(map),
    statistics: Some(statistics),
  }
}

///|
fn not_computed_perceptual_flip_evidence(
  reason_code : String,
) -> PerceptualFlipEvidence {
  {
    status: "not_computed",
    reason_code: Some(reason_code),
    map: None,
    statistics: None,
  }
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
        schema_version: "1.45",
        analysis_status: "partial",
        canvas_outcome: not_computed_canvas_outcome(
          "rendered_evidence_unavailable",
        ),
        impact_assessment: empty_impact_assessment(),
        coverage_matrix: [],
        renderer_capability_gaps: [],
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
            source_locations: element_diagnostic_locations(
              before_svg, "before", "text",
            ) +
            element_diagnostic_locations(after_svg, "after", "text"),
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
        schema_version: "1.45",
        analysis_status: "complete",
        canvas_outcome: not_computed_canvas_outcome(
          "rendered_evidence_unavailable",
        ),
        impact_assessment: empty_impact_assessment(),
        coverage_matrix: [],
        renderer_capability_gaps: [],
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
        schema_version: "1.45",
        analysis_status: "complete",
        canvas_outcome: not_computed_canvas_outcome(
          "rendered_evidence_unavailable",
        ),
        impact_assessment: empty_impact_assessment(),
        coverage_matrix: [],
        renderer_capability_gaps: [],
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
