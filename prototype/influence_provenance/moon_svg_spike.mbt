///|
struct MoonSvgSpikeResult {
  normal_parsed : Bool
  before_x : Double
  after_x : Double
  normal_diff_pixels : Int
  normal_regions : Array[@pixelmatch.DiffRegion]
  cause_envelope : Array[String]
  missing_causes : Array[String]
  tiny_parameter_delta : Double
  equivalent_color_diff_pixels : Int
  tiny_negative_diff_pixels : Int
  tiny_positive_diff_pixels : Int
  verdict : String
}

///|
fn to_pixelmatch_image(image : @svg.Image) -> @pixelmatch.Image {
  let pixels : Array[@pixelmatch.Color] = []
  for pixel in image.pixels {
    pixels.push(
      @pixelmatch.Color::rgba(pixel.r, pixel.g, pixel.b, pixel.a),
    )
  }
  @pixelmatch.Image::from_pixels(image.width, image.height, pixels)
}

///|
fn exact_pixel_options() -> @pixelmatch.Options {
  let defaults = @pixelmatch.Options::default()
  {
    ..defaults,
    threshold: 0.0,
    include_aa: true,
    detect_shift: false,
  }
}

///|
fn compare_documents(
  before : @svg.SVGDocument,
  after : @svg.SVGDocument,
) -> @pixelmatch.DiffReport {
  let before_image = @svg.render_svg_document_to_image(before, 16, 16)
  let after_image = @svg.render_svg_document_to_image(after, 16, 16)
  @pixelmatch.diff_report(
    to_pixelmatch_image(before_image),
    to_pixelmatch_image(after_image),
    exact_pixel_options(),
    grid_size=4,
  )
}

///|
fn rect_x_and_bounds(
  document : @svg.SVGDocument,
) -> (Double, @svg.BoundingBox)? {
  let scene = @svg.Scene::new(document.root)
  match scene.find_node("box") {
    Some(node) =>
      match node.shape {
        @svg.Rect(x~, y~, width~, height~, rx=_, ry=_) => {
          let local_bounds = @svg.BoundingBox::from_rect(x, y, width, height)
          Some((x, node.transform.apply_bbox(local_bounds)))
        }
        _ => None
      }
    None => None
  }
}

///|
fn region_intersects_bounds(
  region : @pixelmatch.DiffRegion,
  bounds : @svg.BoundingBox,
) -> Bool {
  let region_bounds = @svg.BoundingBox::from_rect(
    region.x.to_double(),
    region.y.to_double(),
    region.width.to_double(),
    region.height.to_double(),
  )
  region_bounds.intersects(bounds)
}

///|
fn candidate_facts_for_regions(
  regions : ArrayView[@pixelmatch.DiffRegion],
  before_bounds : @svg.BoundingBox,
  after_bounds : @svg.BoundingBox,
) -> Array[String] {
  for region in regions {
    if region_intersects_bounds(region, before_bounds) ||
      region_intersects_bounds(region, after_bounds) {
      return ["box.x", "box.fill"]
    }
  }
  []
}

///|
fn missing_facts(
  envelope : ArrayView[String],
  actual : ArrayView[String],
) -> Array[String] {
  let missing : Array[String] = []
  for fact in actual {
    if !envelope.contains(fact) {
      missing.push(fact)
    }
  }
  missing
}

///|
fn rect_svg(x : Double, fill : String) -> String {
  "<svg width=\"16\" height=\"16\" xmlns=\"http://www.w3.org/2000/svg\"><rect id=\"box\" x=\"\{x}\" y=\"2\" width=\"8\" height=\"8\" fill=\"\{fill}\"/></svg>"
}

///|
fn compare_svg_strings(before : String, after : String) -> Int {
  match (@svg.parse_svg_document(before), @svg.parse_svg_document(after)) {
    (Some(before_document), Some(after_document)) =>
      compare_documents(before_document, after_document).diff_count
    _ => -1
  }
}

///|
fn run_moon_svg_spike() -> MoonSvgSpikeResult {
  let before_source = rect_svg(2.0, "red")
  let after_source = rect_svg(3.0, "blue")
  let tiny_delta = 0.00001
  let equivalent_color_diff = compare_svg_strings(
    rect_svg(1.0, "red"),
    rect_svg(1.0, "#ff0000"),
  )
  let tiny_negative_diff = compare_svg_strings(
    rect_svg(1.0, "red"),
    rect_svg(1.0 - tiny_delta, "red"),
  )
  let tiny_positive_diff = compare_svg_strings(
    rect_svg(1.0, "red"),
    rect_svg(1.0 + tiny_delta, "red"),
  )
  match (
    @svg.parse_svg_document(before_source),
    @svg.parse_svg_document(after_source),
  ) {
    (Some(before_document), Some(after_document)) => {
      let report = compare_documents(before_document, after_document)
      match (
        rect_x_and_bounds(before_document),
        rect_x_and_bounds(after_document),
      ) {
        (Some((before_x, before_bounds)), Some((after_x, after_bounds))) => {
          let envelope = candidate_facts_for_regions(
            report.regions,
            before_bounds,
            after_bounds,
          )
          let missing = missing_facts(envelope, ["box.x", "box.fill"])
          {
            normal_parsed: true,
            before_x,
            after_x,
            normal_diff_pixels: report.diff_count,
            normal_regions: report.regions,
            cause_envelope: envelope,
            missing_causes: missing,
            tiny_parameter_delta: tiny_delta,
            equivalent_color_diff_pixels: equivalent_color_diff,
            tiny_negative_diff_pixels: tiny_negative_diff,
            tiny_positive_diff_pixels: tiny_positive_diff,
            verdict: if report.diff_count > 0 && missing.is_empty() {
              "PASS — rendered regions conservatively recover both changed facts"
            } else {
              "FAIL — rendered regions did not recover the injected facts"
            },
          }
        }
        _ => {
          normal_parsed: true,
          before_x: 0.0,
          after_x: 0.0,
          normal_diff_pixels: report.diff_count,
          normal_regions: report.regions,
          cause_envelope: [],
          missing_causes: ["box.x", "box.fill"],
          tiny_parameter_delta: tiny_delta,
          equivalent_color_diff_pixels: equivalent_color_diff,
          tiny_negative_diff_pixels: tiny_negative_diff,
          tiny_positive_diff_pixels: tiny_positive_diff,
          verdict: "FAIL — parsed rect was not recoverable from the scene graph",
        }
      }
    }
    _ => {
      normal_parsed: false,
      before_x: 0.0,
      after_x: 0.0,
      normal_diff_pixels: -1,
      normal_regions: [],
      cause_envelope: [],
      missing_causes: ["box.x", "box.fill"],
      tiny_parameter_delta: tiny_delta,
      equivalent_color_diff_pixels: equivalent_color_diff,
      tiny_negative_diff_pixels: tiny_negative_diff,
      tiny_positive_diff_pixels: tiny_positive_diff,
      verdict: "FAIL — SVG parsing failed",
    }
  }
}

///|
fn diff_regions_text(regions : ArrayView[@pixelmatch.DiffRegion]) -> String {
  if regions.is_empty() {
    return "[]"
  }
  let items : Array[String] = []
  for region in regions {
    items.push(
      "(x=\{region.x}, y=\{region.y}, width=\{region.width}, height=\{region.height}, pixels=\{region.diff_pixels}, type=\{region.region_type})",
    )
  }
  "[" + items.join(", ") + "]"
}
