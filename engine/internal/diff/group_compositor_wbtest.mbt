///|
fn group_compositor_test_pixel(
  image : @svg.Image,
  x : Int,
  y : Int,
) -> @svg.Color {
  image.pixels[y * image.width + x]
}

///|
fn render_group_compositor_test_source(
  source : String,
  profile : ComparisonProfile,
) -> @svg.Image? {
  let normalized = normalize_renderer_input_with_profile(source, profile)
  match @svg.parse_svg_document(normalized) {
    Some(document) =>
      Some(
        render_product_document_to_image(
          document,
          profile.viewport_width,
          profile.viewport_height,
        ),
      )
    None => None
  }
}

///|
fn assert_group_compositor_pixel(
  image : @svg.Image,
  x : Int,
  y : Int,
  red : Int,
  green : Int,
  blue : Int,
  alpha : Int,
) -> Unit raise {
  let pixel = group_compositor_test_pixel(image, x, y)
  assert_true(
    pixel.r == red && pixel.g == green && pixel.b == blue && pixel.a == alpha,
  )
}

///|
test "group compositor isolates overlap before applying opacity" {
  let source =
    #|<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16">
    #|  <g opacity="0.5">
    #|    <rect x="1" y="1" width="10" height="10" fill="#ff0000"/>
    #|    <rect x="5" y="5" width="10" height="10" fill="#0000ff"/>
    #|  </g>
    #|</svg>
  guard render_group_compositor_test_source(
      source,
      ComparisonProfile::v1_default(),
    )
    is Some(image) else {
    fail("expected product render")
  }
  assert_group_compositor_pixel(image, 2, 2, 255, 0, 0, 128)
  assert_group_compositor_pixel(image, 6, 6, 0, 0, 255, 128)
  assert_group_compositor_pixel(image, 13, 13, 0, 0, 255, 128)
  assert_group_compositor_pixel(image, 0, 0, 0, 0, 0, 0)
}

///|
test "group compositor nests opacity layers and composites over backdrop" {
  let nested =
    #|<svg width="8" height="8">
    #|  <g opacity="0.5"><g opacity="0.5"><rect width="4" height="4" fill="red"/></g></g>
    #|</svg>
  guard render_group_compositor_test_source(nested, {
      ..ComparisonProfile::v1_default(),
      viewport_width: 8,
      viewport_height: 8,
    })
    is Some(nested_image) else {
    fail("expected nested product render")
  }
  assert_group_compositor_pixel(nested_image, 1, 1, 255, 0, 0, 64)

  let backdrop =
    #|<svg width="8" height="8">
    #|  <rect width="8" height="8" fill="lime"/>
    #|  <g opacity="0.5"><rect width="4" height="4" fill="red"/></g>
    #|</svg>
  guard render_group_compositor_test_source(backdrop, {
      ..ComparisonProfile::v1_default(),
      viewport_width: 8,
      viewport_height: 8,
    })
    is Some(backdrop_image) else {
    fail("expected backdrop product render")
  }
  assert_group_compositor_pixel(backdrop_image, 1, 1, 128, 127, 0, 255)
  assert_group_compositor_pixel(backdrop_image, 6, 6, 0, 255, 0, 255)
}

///|
test "group compositor activation preserves an unchanged opaque backdrop" {
  let before =
    #|<svg width="16" height="16">
    #|  <rect width="16" height="16" fill="lime"/>
    #|  <g id="layer" opacity="1"><rect x="2" y="2" width="10" height="10" fill="red"/><rect x="6" y="6" width="8" height="8" fill="blue"/></g>
    #|</svg>
  let after = before.replace_all(old="opacity=\"1\"", new="opacity=\"0.5\"")
  let profile = ComparisonProfile::v1_default()
  guard render_group_compositor_test_source(before, profile) is Some(left) &&
    render_group_compositor_test_source(after, profile) is Some(right) else {
    fail("expected product renders")
  }
  let left_pixel = group_compositor_test_pixel(left, 0, 0)
  let right_pixel = group_compositor_test_pixel(right, 0, 0)
  assert_eq(
    (left_pixel.r, left_pixel.g, left_pixel.b, left_pixel.a),
    (right_pixel.r, right_pixel.g, right_pixel.b, right_pixel.a),
  )
}

///|
test "group compositor preserves transformed and sibling layer order" {
  let source =
    #|<svg width="12" height="8">
    #|  <g opacity="0.5" transform="translate(4 0)"><rect width="4" height="4" fill="red"/></g>
    #|  <g opacity="0.5"><rect x="6" y="2" width="4" height="4" fill="blue"/></g>
    #|</svg>
  let profile = {
    ..ComparisonProfile::v1_default(),
    viewport_width: 12,
    viewport_height: 8,
  }
  guard render_group_compositor_test_source(source, profile) is Some(image) else {
    fail("expected transformed product render")
  }
  assert_group_compositor_pixel(image, 1, 1, 0, 0, 0, 0)
  assert_group_compositor_pixel(image, 5, 1, 255, 0, 0, 128)
  assert_group_compositor_pixel(image, 7, 3, 85, 0, 170, 192)
  assert_group_compositor_pixel(image, 9, 5, 0, 0, 255, 128)
}

///|
test "group compositor materializes symbol opacity on each use instance" {
  let source =
    #|<svg width="12" height="8">
    #|  <defs><symbol id="badge" opacity="0.5"><rect width="4" height="4" fill="red"/><rect x="2" width="4" height="4" fill="blue"/></symbol></defs>
    #|  <use href="#badge" x="3" y="2" opacity="0.5"/>
    #|</svg>
  let profile = {
    ..ComparisonProfile::v1_default(),
    viewport_width: 12,
    viewport_height: 8,
  }
  guard render_group_compositor_test_source(source, profile) is Some(image) else {
    fail("expected symbol instance render")
  }
  assert_group_compositor_pixel(image, 3, 2, 255, 0, 0, 64)
  assert_group_compositor_pixel(image, 5, 2, 0, 0, 255, 64)
  assert_group_compositor_pixel(image, 9, 2, 0, 0, 0, 0)
}
