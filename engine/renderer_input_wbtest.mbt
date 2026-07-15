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
test "renderer input materializes stylesheet specificity winners" {
  let source = "<svg width='4' height='4'><style>rect { fill: blue; } #box { fill: red; }</style><rect id='box' width='4' height='4'/></svg>"
  let normalized = normalize_renderer_style_precedence(source)
  assert_true(normalized.find("<style></style>") is Some(_))
  assert_true(normalized.find("style=\"fill:red\"") is Some(_))
  guard @svg.parse_svg_document(normalized) is Some(document) else {
    fail("normalized stylesheet declaration must parse")
  }
  let image = @svg.render_svg_document_to_image(document, 4, 4)
  assert_eq(
    (image.pixels[0].r, image.pixels[0].g, image.pixels[0].b),
    (255, 0, 0),
  )
}

///|
test "renderer input resolves stylesheet important against inline style" {
  let source = "<svg width='4' height='4'><style>#box { fill: red !important; }</style><rect id='box' width='4' height='4' style='fill:blue'/></svg>"
  let normalized = normalize_renderer_style_precedence(source)
  assert_true(normalized.find("style='fill:red'") is Some(_))
  guard @svg.parse_svg_document(normalized) is Some(document) else {
    fail("normalized important stylesheet declaration must parse")
  }
  let image = @svg.render_svg_document_to_image(document, 4, 4)
  assert_eq(
    (image.pixels[0].r, image.pixels[0].g, image.pixels[0].b),
    (255, 0, 0),
  )
}

///|
test "renderer input materializes ordinary inherited stroke geometry" {
  let inherited = "<svg width='16' height='16'><g stroke='black' stroke-width='2' stroke-linecap='round' stroke-linejoin='bevel' stroke-miterlimit='3' stroke-dasharray='2 1' stroke-dashoffset='1'><path id='edge' d='M1 8 L15 8'/></g></svg>"
  let local_source = "<svg width='16' height='16'><g><path id='edge' d='M1 8 L15 8' stroke='black' stroke-width='2' stroke-linecap='round' stroke-linejoin='bevel' stroke-miterlimit='3' stroke-dasharray='2 1' stroke-dashoffset='1'/></g></svg>"
  let normalized = normalize_renderer_input(inherited)
  assert_true(normalized.find("stroke-linecap:round") is Some(_))
  assert_true(normalized.find("stroke-linejoin:bevel") is Some(_))
  guard @svg.parse_svg_document(normalized) is Some(left_document) else {
    fail("normalized inherited stroke must parse")
  }
  guard @svg.parse_svg_document(normalize_renderer_input(local_source))
    is Some(right_document) else {
    fail("normalized local stroke must parse")
  }
  let left = @svg.render_svg_document_to_image(left_document, 16, 16)
  let right = @svg.render_svg_document_to_image(right_document, 16, 16)
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
test "renderer input materializes inherited paint order and winding rules" {
  let source = "<svg><g paint-order='stroke' fill-rule='evenodd' clip-rule='evenodd'><polygon id='shape' points='0,0 8,0 4,8' fill='red' stroke='blue'/></g></svg>"
  let normalized = normalize_renderer_input(source)
  let start = normalized.find("<polygon").unwrap()
  let finish = normalized
    .view(start_offset=start, end_offset=normalized.length())
    .to_owned()
    .find("/>")
    .unwrap() +
    start +
    2
  let shape = normalized.view(start_offset=start, end_offset=finish).to_owned()
  assert_true(shape.find("paint-order:stroke fill markers") is Some(_))
  assert_true(shape.find("fill-rule:evenodd") is Some(_))
  assert_true(shape.find("clip-rule:evenodd") is Some(_))
}

///|
test "renderer inheritance normalizer does not materialize opacity or vector effect" {
  let source = "<svg><g opacity='0.5' vector-effect='non-scaling-stroke'><rect id='box' width='4' height='4'/></g></svg>"
  let normalized = normalize_renderer_ordinary_inheritance(source)
  let box = normalized
    .view(
      start_offset=normalized.find("<rect").unwrap(),
      end_offset=normalized.find("/>").unwrap() + 2,
    )
    .to_owned()
  assert_true(box.find("opacity") is None)
  assert_true(box.find("vector-effect") is None)
}

///|
test "renderer inheritance normalizer materializes CSS-wide keywords" {
  let source = "<svg><g stroke-linecap='inherit'><line id='edge' x1='0' y1='2' x2='4' y2='2'/></g></svg>"
  assert_true(
    normalize_renderer_ordinary_inheritance(source).find("stroke-linecap:butt")
    is Some(_),
  )
}

///|
test "renderer input materializes currentColor and custom-property consumers" {
  let source = "<svg width='16' height='16' style='--paint:currentColor;color:red;--left:2'><rect id='box' x='var(--left)' y='2' width='4' height='4' fill='var(--paint)'/></svg>"
  let normalized = normalize_renderer_input(source)
  assert_true(normalized.find("fill:#ff0000") is Some(_))
  assert_true(normalized.find("x:2") is Some(_))
  assert_false(normalized.find("fill:var(") is Some(_))
  guard @svg.parse_svg_document(normalized) is Some(document) else {
    fail("normalized computed values must parse")
  }
  let image = @svg.render_svg_document_to_image(document, 16, 16)
  assert_true(
    image.pixels.any(pixel => pixel.r == 255 && pixel.g == 0 && pixel.b == 0),
  )
}

///|
test "renderer input materializes the selected paint fallback branch" {
  let missing = "<svg color='red'><rect id='box' width='4' height='4' fill='url(#missing) currentColor'/></svg>"
  let normalized_missing = normalize_renderer_input(missing)
  assert_true(normalized_missing.find("fill:#ff0000") is Some(_))
  let valid = "<svg><defs><linearGradient id='g'><stop stop-color='red'/></linearGradient></defs><rect id='box' width='4' height='4' fill='url(#g) blue'/></svg>"
  let normalized_valid = normalize_renderer_input(valid)
  assert_true(normalized_valid.find("fill:url(#g)") is Some(_))
  let absent = "<svg><rect id='box' width='4' height='4' fill='url(#missing)'/></svg>"
  let normalized_absent = normalize_renderer_input(absent)
  assert_true(normalized_absent.find("fill:none") is Some(_))
}

///|
test "renderer input separates sRGB channels and multiplies paint alpha" {
  let source = "<svg width='16' height='16'><rect id='box' width='8' height='8' fill='hsla(120,100%,50%,25%)' fill-opacity='50%'/></svg>"
  let normalized = normalize_renderer_input(source)
  assert_true(normalized.find("fill:#00ff00") is Some(_))
  assert_true(normalized.find("fill-opacity:0.125") is Some(_))
}

///|
test "computed solid paint includes color paint and leaf alpha factors" {
  let source = "<svg><rect id='box' width='8' height='8' fill='rgba(255,0,0,0.5)' fill-opacity='25%' opacity='0.5'/></svg>"
  let subject = extract_source_subjects_or_raise(source)[0]
  assert_eq(
    generic_subject_computed_value(
      subject,
      "fill",
      source_subject_fact(subject, "fill"),
    ),
    Some("rgba(255,0,0,0.0625)"),
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
  let normalized = normalize_renderer_input(source)
  assert_true(normalized.find("stroke-dasharray='4,-1'") is Some(_))
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
