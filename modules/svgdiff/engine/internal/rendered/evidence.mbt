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
pub fn to_pixelmatch_image(image : @svg.Image) -> @pixelmatch.Image {
  let pixels : Array[@pixelmatch.Color] = []
  for index in 0..<image_pixel_count(image) {
    let pixel = image_pixel_at(image, index)
    pixels.push(@pixelmatch.Color::rgba(pixel.r, pixel.g, pixel.b, pixel.a))
  }
  @pixelmatch.Image::from_pixels(image.width(), image.height(), pixels)
}

///|
pub fn exact_pixel_options() -> @pixelmatch.Options {
  let defaults = @pixelmatch.Options::default()
  { ..defaults, threshold: 0.0, include_aa: true, detect_shift: false }
}

///|
pub fn raw_rgba8_squared_error(left : @svg.Color, right : @svg.Color) -> Double {
  let red = (left.r - right.r).to_double() / 255.0
  let green = (left.g - right.g).to_double() / 255.0
  let blue = (left.b - right.b).to_double() / 255.0
  let alpha = (left.a - right.a).to_double() / 255.0
  red * red + green * green + blue * blue + alpha * alpha
}

///|
pub fn srgb8_to_linear(value : Int) -> Double {
  let channel = value.to_double() / 255.0
  if channel <= 0.04045 {
    channel / 12.92
  } else {
    @math.pow((channel + 0.055) / 1.055, 2.4)
  }
}

///|
pub fn linear_premultiplied_rgba_squared_error(
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
pub fn rendered_difference(
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
pub fn rendered_image_difference(
  before_image : @svg.Image,
  after_image : @svg.Image,
) -> RenderedMagnitude {
  let mut squared_error = 0.0
  let mut linear_squared_error = 0.0
  let pixel_count = image_pixel_count(before_image)
  for index in 0..<pixel_count {
    let before_pixel = image_pixel_at(before_image, index)
    let after_pixel = image_pixel_at(after_image, index)
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
    rgba8_rmse: (squared_error / (pixel_count * 4).to_double()).sqrt(),
    linear_premultiplied_rgba_rmse: (linear_squared_error /
    (pixel_count * 4).to_double()).sqrt(),
  }
}

///|
pub fn computed_rendered_evidence(
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
pub fn not_computed_rendered_evidence(reason_code : String) -> RenderedEvidence {
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
pub fn not_computed_canvas_perceptual_flip_evidence(
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
pub fn computed_canvas_perceptual_flip_evidence(
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
pub fn not_computed_canvas_outcome(reason_code : String) -> CanvasOutcome {
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
pub fn computed_perceptual_color_evidence(
  magnitude : PerceptualColorMagnitude,
) -> PerceptualColorEvidence {
  { status: "computed", reason_code: None, magnitude: Some(magnitude) }
}

///|
pub fn not_computed_perceptual_color_evidence(
  reason_code : String,
) -> PerceptualColorEvidence {
  { status: "not_computed", reason_code: Some(reason_code), magnitude: None }
}

///|
pub fn computed_perceptual_flip_evidence(
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
pub fn not_computed_perceptual_flip_evidence(
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
