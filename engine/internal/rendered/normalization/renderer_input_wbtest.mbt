// Copyright 2026 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
fn assert_renderer_images_equal(
  left : @svg.Image,
  right : @svg.Image,
) -> Unit raise {
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
test "renderer input delegates cascade and ordinary inheritance to svg" {
  let cascade = "<svg width='4' height='4'><style>rect { fill: blue; } #box { fill: red; }</style><rect id='box' width='4' height='4'/></svg>"
  assert_eq(normalize_renderer_input(cascade), cascade)
  guard @svg.parse_svg_document(cascade) is Some(cascade_document) else {
    fail("cascade source must parse")
  }
  let cascade_image = @svg.render_svg_document_to_image(cascade_document, 4, 4)
  assert_eq(
    (
      cascade_image.pixels[0].r,
      cascade_image.pixels[0].g,
      cascade_image.pixels[0].b,
      cascade_image.pixels[0].a,
    ),
    (255, 0, 0, 255),
  )

  let inherited = "<svg width='16' height='16'><g stroke='black' stroke-width='2' stroke-linecap='round' stroke-linejoin='bevel' stroke-miterlimit='3' stroke-dasharray='2 1' stroke-dashoffset='1'><path d='M1 8 L15 8'/></g></svg>"
  let explicit = "<svg width='16' height='16'><path d='M1 8 L15 8' stroke='black' stroke-width='2' stroke-linecap='round' stroke-linejoin='bevel' stroke-miterlimit='3' stroke-dasharray='2 1' stroke-dashoffset='1'/></svg>"
  assert_eq(normalize_renderer_input(inherited), inherited)
  guard @svg.parse_svg_document(inherited) is Some(inherited_document) &&
    @svg.parse_svg_document(explicit) is Some(explicit_document) else {
    fail("inherited stroke sources must parse")
  }
  assert_renderer_images_equal(
    @svg.render_svg_document_to_image(inherited_document, 16, 16),
    @svg.render_svg_document_to_image(explicit_document, 16, 16),
  )
}

///|
test "renderer input retains unresolved paint alpha adaptations" {
  let source = "<svg width='16' height='16'><rect width='8' height='8' fill='hsla(120,100%,50%,25%)' fill-opacity='50%'/></svg>"
  let normalized = normalize_renderer_input(source)
  assert_true(normalized.find("fill:#00ff00") is Some(_))
  assert_true(normalized.find("fill-opacity:0.125") is Some(_))

  let inherited = "<svg><g fill-opacity='25%'><rect fill='red'/></g></svg>"
  assert_true(
    normalize_renderer_input(inherited).find("fill-opacity:0.25") is Some(_),
  )

  let unsupported_named = "<svg><rect fill='lime'/></svg>"
  assert_true(
    normalize_renderer_input(unsupported_named).find("fill:#00ff00") is Some(_),
  )
}

///|
test "renderer input leaves native numeric radii and dash semantics to svg" {
  let radius = "<svg width='10' height='6'><rect width='10' height='6' rx='8'/></svg>"
  let dash = "<svg><line stroke='black' stroke-dasharray='5,3,2' stroke-dashoffset='-1'/></svg>"
  assert_eq(normalize_renderer_input(radius), radius)
  assert_eq(normalize_renderer_input(dash), dash)
}

///|
test "renderer input keeps unsupported inline geometry and point syntax adapters" {
  let implicit = "<svg width='10' height='6'><rect style='rx:8' width='10' height='6'/></svg>"
  let explicit = "<svg width='10' height='6'><rect style='rx:5;ry:3' width='10' height='6'/></svg>"
  let normalized_implicit = normalize_renderer_input(implicit)
  let normalized_explicit = normalize_renderer_input(explicit)
  assert_true(normalized_implicit.find("style='rx:5'") is Some(_))
  assert_true(normalized_implicit.find("ry=\"3\"") is Some(_))
  guard @svg.parse_svg_document(normalized_implicit) is Some(left_document) &&
    @svg.parse_svg_document(normalized_explicit) is Some(right_document) else {
    fail("normalized inline geometry must parse")
  }
  assert_renderer_images_equal(
    @svg.render_svg_document_to_image(left_document, 10, 6),
    @svg.render_svg_document_to_image(right_document, 10, 6),
  )

  let compact = "<svg><polygon points='0 0 4-0 4e0,4'/></svg>"
  assert_true(
    normalize_renderer_input(compact).find("points='0,0 4,0 4,4'") is Some(_),
  )
}

///|
test "renderer input resolves unsupported authored length units" {
  let profile = {
    ..ComparisonProfile::v1_default(),
    viewport_width: 200,
    viewport_height: 100,
  }
  let source =
    #|<svg xmlns="http://www.w3.org/2000/svg" width="100vw" height="100vh" viewBox="0 0 400 200"><defs><marker id="m" markerWidth="25%" markerHeight="25%" refX="1in" refY="10vh"/></defs><line x1="25%" y1="25%" x2="75%" y2="75%" stroke="black" stroke-width="10%" stroke-dasharray="10% 1cm" marker-end="url(#m)"/></svg>
  let normalized = normalize_renderer_input_with_profile(source, profile)
  for
    expected in [
      "width=\"200\"", "height=\"100\"", "markerWidth=\"100\"", "markerHeight=\"50\"",
      "refX=\"96\"", "refY=\"10\"", "x1=\"100\"", "y1=\"50\"", "x2=\"300\"", "y2=\"150\"",
      "stroke-width=\"31.62277660168379\"", "stroke-dasharray=\"31.62277660168379 37.79527559055118\"",
    ] {
    assert_true(normalized.find(expected) is Some(_))
  }
}
