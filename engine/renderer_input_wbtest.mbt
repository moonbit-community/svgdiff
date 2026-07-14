///|
test "renderer input normalizes complete inline precedence independently of order" {
  let style_first = "<svg width='4' height='4'><rect width='4' height='4' style='fill:red' fill='blue'/></svg>"
  let style_last = "<svg width='4' height='4'><rect width='4' height='4' fill='blue' style='fill:red'/></svg>"
  let normalized_first = normalize_renderer_style_precedence(style_first)
  let normalized_last = normalize_renderer_style_precedence(style_last)
  assert_true(normalized_first.find("fill='red'") is Some(_))
  assert_true(normalized_last.find("fill='red'") is Some(_))
  guard @svg.parse_svg_document(normalized_first) is Some(first_document) else {
    fail("normalized style-first source must parse")
  }
  guard @svg.parse_svg_document(normalized_last) is Some(last_document) else {
    fail("normalized style-last source must parse")
  }
  let first = @svg.render_svg_document_to_image(first_document, 4, 4)
  let last = @svg.render_svg_document_to_image(last_document, 4, 4)
  assert_eq(first.pixels.length(), last.pixels.length())
  for index in 0..<first.pixels.length() {
    let left = first.pixels[index]
    let right = last.pixels[index]
    assert_true(
      left.r == right.r &&
      left.g == right.g &&
      left.b == right.b &&
      left.a == right.a,
    )
  }
  assert_eq(
    (first.pixels[0].r, first.pixels[0].g, first.pixels[0].b),
    (255, 0, 0),
  )
}

///|
test "renderer input retains incomplete style for conservative guarding" {
  let source = "<svg width='4' height='4'><rect width='4' height='4' fill='blue' style='fill:red;unknown:value'/></svg>"
  assert_eq(normalize_renderer_style_precedence(source), source)
}

///|
test "renderer input materializes inline important winners" {
  let source = "<svg width='4' height='4'><rect width='4' height='4' fill='black' style='fill:red!important;fill:blue'/></svg>"
  let normalized = normalize_renderer_style_precedence(source)
  assert_true(normalized.find("fill='red'") is Some(_))
  assert_true(normalized.find("style='fill:red'") is Some(_))
  guard @svg.parse_svg_document(normalized) is Some(document) else {
    fail("normalized important declaration must parse")
  }
  let image = @svg.render_svg_document_to_image(document, 4, 4)
  assert_eq(
    (image.pixels[0].r, image.pixels[0].g, image.pixels[0].b),
    (255, 0, 0),
  )
}

///|
test "renderer input resolves and clamps rounded shape radii" {
  let implicit = "<svg width='10' height='6'><rect width='10' height='6' rx='8'/></svg>"
  let explicit = "<svg width='10' height='6'><rect width='10' height='6' rx='5' ry='3'/></svg>"
  let normalized_implicit = normalize_renderer_input(implicit)
  let normalized_explicit = normalize_renderer_input(explicit)
  assert_true(normalized_implicit.find("rx='5'") is Some(_))
  assert_true(normalized_implicit.find("ry=\"3\"") is Some(_))
  guard @svg.parse_svg_document(normalized_implicit) is Some(left_document) else {
    fail("normalized implicit-radius source must parse")
  }
  guard @svg.parse_svg_document(normalized_explicit) is Some(right_document) else {
    fail("normalized explicit-radius source must parse")
  }
  let left = @svg.render_svg_document_to_image(left_document, 10, 6)
  let right = @svg.render_svg_document_to_image(right_document, 10, 6)
  assert_eq(left.pixels.length(), right.pixels.length())
  for index in 0..<left.pixels.length() {
    let left_pixel = left.pixels[index]
    let right_pixel = right.pixels[index]
    assert_true(
      left_pixel.r == right_pixel.r &&
      left_pixel.g == right_pixel.g &&
      left_pixel.b == right_pixel.b &&
      left_pixel.a == right_pixel.a,
    )
  }
}

///|
test "renderer input canonicalizes inline geometry and paired radii" {
  let implicit = "<svg width='10' height='6'><rect style='rx:8' width='10' height='6'/></svg>"
  let explicit = "<svg width='10' height='6'><rect style='rx:5;ry:3' width='10' height='6'/></svg>"
  let normalized_implicit = normalize_renderer_input(implicit)
  let normalized_explicit = normalize_renderer_input(explicit)
  assert_true(normalized_implicit.find("style='rx:5'") is Some(_))
  assert_true(normalized_implicit.find("ry=\"3\"") is Some(_))
  guard @svg.parse_svg_document(normalized_implicit) is Some(left_document) else {
    fail("normalized implicit inline radius must parse")
  }
  guard @svg.parse_svg_document(normalized_explicit) is Some(right_document) else {
    fail("normalized explicit inline radii must parse")
  }
  let left = @svg.render_svg_document_to_image(left_document, 10, 6)
  let right = @svg.render_svg_document_to_image(right_document, 10, 6)
  for index in 0..<left.pixels.length() {
    let left_pixel = left.pixels[index]
    let right_pixel = right.pixels[index]
    assert_true(
      left_pixel.r == right_pixel.r &&
      left_pixel.g == right_pixel.g &&
      left_pixel.b == right_pixel.b &&
      left_pixel.a == right_pixel.a,
    )
  }
}

///|
test "renderer input canonicalizes valid point-list syntax" {
  let compact = "<svg><polygon points='0 0 4-0 4e0,4'/></svg>"
  let normalized = normalize_renderer_input(compact)
  assert_true(normalized.find("points='0,0 4,0 4,4'") is Some(_))
}

///|
test "renderer input leaves invalid shape geometry for diagnostics" {
  let source = "<svg><circle cx='4' cy='4' r='-1'/></svg>"
  assert_eq(normalize_renderer_input(source), source)
}

///|
test "renderer input canonicalizes used dash geometry" {
  let source = "<svg><line stroke='black' stroke-dasharray='5,3,2' stroke-dashoffset='-1'/></svg>"
  let normalized = normalize_renderer_input(source)
  assert_true(normalized.find("stroke-dasharray='5 3 2 5 3 2'") is Some(_))
  assert_true(normalized.find("stroke-dashoffset='19'") is Some(_))
  let solid = "<svg><line stroke='black' style='stroke-dasharray:0,0,0;stroke-dashoffset:7'/></svg>"
  let normalized_solid = normalize_renderer_input(solid)
  assert_true(normalized_solid.find("stroke-dasharray:none") is Some(_))
  assert_true(normalized_solid.find("stroke-dashoffset:0") is Some(_))
}

///|
test "renderer input leaves invalid stroke geometry for diagnostics" {
  let source = "<svg><line stroke='black' stroke-dasharray='4,-1'/></svg>"
  assert_eq(normalize_renderer_input(source), source)
}

///|
test "renderer input resolves supported units with the comparison profile" {
  let profile = {
    ..ComparisonProfile::v1_default(),
    viewport_width: 200,
    viewport_height: 100,
  }
  let source =
    #|<svg xmlns="http://www.w3.org/2000/svg" width="100vw" height="100vh" viewBox="0 0 400 200"><defs><marker id="m" markerWidth="25%" markerHeight="25%" refX="1in" refY="10vh"/></defs><line x1="25%" y1="25%" x2="75%" y2="75%" stroke="black" stroke-width="10%" stroke-dasharray="10% 1cm" marker-end="url(#m)"/></svg>
  let normalized = normalize_renderer_input_with_profile(source, profile)
  assert_true(normalized.find("width=\"200\"") is Some(_))
  assert_true(normalized.find("height=\"100\"") is Some(_))
  assert_true(normalized.find("markerWidth=\"100\"") is Some(_))
  assert_true(normalized.find("markerHeight=\"50\"") is Some(_))
  assert_true(normalized.find("refX=\"96\"") is Some(_))
  assert_true(normalized.find("refY=\"10\"") is Some(_))
  assert_true(normalized.find("x1=\"100\"") is Some(_))
  assert_true(normalized.find("y1=\"50\"") is Some(_))
  assert_true(normalized.find("x2=\"300\"") is Some(_))
  assert_true(normalized.find("y2=\"150\"") is Some(_))
  assert_true(normalized.find("stroke-width=\"31.62277660168379\"") is Some(_))
  assert_true(
    normalized.find("stroke-dasharray=\"31.62277660168379 37.79527559055118\"")
    is Some(_),
  )
}
