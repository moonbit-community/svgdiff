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
