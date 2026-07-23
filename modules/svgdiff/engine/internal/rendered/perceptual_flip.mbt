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
pub(all) struct FlipPixelBounds {
  pixel_x : Int
  pixel_y : Int
  pixel_width : Int
  pixel_height : Int
}

///|
pub(all) struct PerceptualFlipComputation {
  evidence : PerceptualFlipEvidence
  output_pixels : Int
  convolution_samples : Int
}

///|
pub fn selected_raw_difference_bounds(
  before : @svg.Image,
  after : @svg.Image,
  regions : Array[DifferenceRegion],
) -> FlipPixelBounds? {
  if regions.is_empty() {
    return None
  }
  let mut start_x = before.width()
  let mut start_y = before.height()
  let mut end_x = 0
  let mut end_y = 0
  for region in regions {
    start_x = start_x.min(region.pixel_x.max(0))
    start_y = start_y.min(region.pixel_y.max(0))
    end_x = end_x.max((region.pixel_x + region.pixel_width).min(before.width()))
    end_y = end_y.max(
      (region.pixel_y + region.pixel_height).min(before.height()),
    )
  }
  let mut min_x = before.width()
  let mut min_y = before.height()
  let mut max_x = -1
  let mut max_y = -1
  for y in start_y..<end_y {
    for x in start_x..<end_x {
      let index = y * before.width() + x
      if pixel_in_regions(x, y, regions) && pixels_differ(before, after, index) {
        min_x = min_x.min(x)
        min_y = min_y.min(y)
        max_x = max_x.max(x)
        max_y = max_y.max(y)
      }
    }
  }
  if max_x < min_x || max_y < min_y {
    None
  } else {
    Some({
      pixel_x: min_x,
      pixel_y: min_y,
      pixel_width: max_x - min_x + 1,
      pixel_height: max_y - min_y + 1,
    })
  }
}

///|
pub fn expand_flip_bounds(
  bounds : FlipPixelBounds,
  radius : Int,
  width : Int,
  height : Int,
) -> FlipPixelBounds {
  let pixel_x = (bounds.pixel_x - radius).max(0)
  let pixel_y = (bounds.pixel_y - radius).max(0)
  let end_x = (bounds.pixel_x + bounds.pixel_width + radius).min(width)
  let end_y = (bounds.pixel_y + bounds.pixel_height + radius).min(height)
  {
    pixel_x,
    pixel_y,
    pixel_width: end_x - pixel_x,
    pixel_height: end_y - pixel_y,
  }
}

///|
pub fn displayed_linear_flip_color(
  pixel : @svg.Color,
  background : PerceptualBackground,
) -> @ldr_flip.FlipLinearRgb {
  let alpha = pixel.a.to_double() / 255.0
  {
    red: composite_linear_srgb_channel(pixel.r, alpha, background.red),
    green: composite_linear_srgb_channel(pixel.g, alpha, background.green),
    blue: composite_linear_srgb_channel(pixel.b, alpha, background.blue),
  }
}

///|
pub fn encode_flip_u16_base64(values : Array[Double]) -> String {
  let encoded = FixedArray::make(values.length() * 2, b'\x00')
  for index, value in values {
    let quantized = @ldr_flip.quantize_flip_u16(value)
    encoded[index * 2] = ((quantized >> 8) & 0xff).to_byte()
    encoded[index * 2 + 1] = (quantized & 0xff).to_byte()
  }
  let bytes = Bytes::from_array(encoded)
  @base64.encode(bytes[:])
}

///|
pub fn empty_perceptual_flip_map() -> PerceptualFlipMap {
  {
    method_id: "nvlabs_ldr_flip/v1.7-b475eb4b",
    pixel_x: 0,
    pixel_y: 0,
    pixel_width: 0,
    pixel_height: 0,
    encoding: "uint16_be_base64",
    quantization_step: 1.0 / 65535.0,
    values_base64: "",
  }
}

///|
pub fn perceptual_flip_statistics(
  response_values : Array[Double],
  event_region_values : Array[Double],
  canvas_pixel_count : Int,
  threshold : FlipErrorThreshold?,
) -> PerceptualFlipStatistics {
  let mut response_sum = 0.0
  let mut response_maximum = 0.0
  for value in response_values {
    response_sum += value
    response_maximum = response_maximum.max(value)
  }
  let mut event_region_sum = 0.0
  for value in event_region_values {
    event_region_sum += value
  }
  let response_p95 = if response_values.is_empty() {
    0.0
  } else {
    let sorted = response_values.copy()
    sorted.sort()
    let rank = (sorted.length() * 95 + 99) / 100
    sorted[rank - 1]
  }
  let area_above_threshold = match threshold {
    None => None
    Some(threshold) => {
      let value = threshold.value
      let mut pixel_count = 0
      for sample in response_values {
        if sample > value {
          pixel_count += 1
        }
      }
      let area : PerceptualFlipAreaAboveThreshold = {
        threshold: value,
        pixel_count,
        canvas_fraction: pixel_count.to_double() /
        canvas_pixel_count.to_double(),
      }
      Some(area)
    }
  }
  {
    method_id: "event_local_ldr_flip_pooling/v1",
    canvas_pixel_count,
    event_region_sample_count: event_region_values.length(),
    response_sample_count: response_values.length(),
    canvas_mean: response_sum / canvas_pixel_count.to_double(),
    event_region_mean: if event_region_values.is_empty() {
      0.0
    } else {
      event_region_sum / event_region_values.length().to_double()
    },
    response_p95,
    response_maximum,
    area_above_threshold,
  }
}

///|
pub fn event_local_perceptual_flip_evidence(
  before : @svg.Image,
  after : @svg.Image,
  regions : Array[DifferenceRegion],
  background : PerceptualBackground,
  viewing : FlipViewingConditions,
  threshold : FlipErrorThreshold?,
  remaining_output_pixels : Int,
  remaining_convolution_samples : Int,
) -> PerceptualFlipComputation {
  if before.width() != after.width() || before.height() != after.height() {
    return {
      evidence: not_computed_perceptual_flip_evidence(
        "rendered_evidence_unavailable",
      ),
      output_pixels: 0,
      convolution_samples: 0,
    }
  }
  let selected = match selected_raw_difference_bounds(before, after, regions) {
    None =>
      return {
        evidence: computed_perceptual_flip_evidence(
          empty_perceptual_flip_map(),
          perceptual_flip_statistics(
            [],
            [],
            before.width() * before.height(),
            threshold,
          ),
        ),
        output_pixels: 0,
        convolution_samples: 0,
      }
    Some(bounds) => bounds
  }
  let pixels_per_degree = viewing.pixels_per_degree
  let response_radius = @ldr_flip.flip_response_radius(pixels_per_degree)
  let output_bounds = expand_flip_bounds(
    selected,
    response_radius,
    before.width(),
    before.height(),
  )
  let context_bounds = expand_flip_bounds(
    output_bounds,
    response_radius,
    before.width(),
    before.height(),
  )
  let output_pixels = output_bounds.pixel_width * output_bounds.pixel_height
  let context_pixels = context_bounds.pixel_width * context_bounds.pixel_height
  let spatial_width = 2 *
    @ldr_flip.flip_spatial_filter_radius(pixels_per_degree) +
    1
  let feature_width = 2 *
    @ldr_flip.flip_feature_filter_radius(pixels_per_degree) +
    1
  let samples_per_pixel = 4 * (spatial_width + feature_width)
  if output_pixels > remaining_output_pixels ||
    (
      context_pixels > 0 &&
      context_pixels > remaining_convolution_samples / samples_per_pixel
    ) {
    return {
      evidence: not_computed_perceptual_flip_evidence(
        "perceptual_map_budget_exceeded",
      ),
      output_pixels: 0,
      convolution_samples: 0,
    }
  }
  let reference : Array[@ldr_flip.FlipLinearRgb] = []
  let candidate : Array[@ldr_flip.FlipLinearRgb] = []
  for local_y in 0..<context_bounds.pixel_height {
    let y = context_bounds.pixel_y + local_y
    for local_x in 0..<context_bounds.pixel_width {
      let x = context_bounds.pixel_x + local_x
      let index = y * before.width() + x
      let reference_color = displayed_linear_flip_color(
        image_pixel_at(before, index),
        background,
      )
      reference.push(reference_color)
      candidate.push(
        if pixel_in_regions(x, y, regions) &&
          pixels_differ(before, after, index) {
          displayed_linear_flip_color(image_pixel_at(after, index), background)
        } else {
          reference_color
        },
      )
    }
  }
  let error_map = @ldr_flip.ldr_flip_error_map(
    reference,
    candidate,
    context_bounds.pixel_width,
    context_bounds.pixel_height,
    pixels_per_degree,
  )
  let values : Array[Double] = []
  let event_region_values : Array[Double] = []
  let local_start_x = output_bounds.pixel_x - context_bounds.pixel_x
  let local_start_y = output_bounds.pixel_y - context_bounds.pixel_y
  for y in 0..<output_bounds.pixel_height {
    for x in 0..<output_bounds.pixel_width {
      let value = error_map.values[(local_start_y + y) *
        context_bounds.pixel_width +
        local_start_x +
        x]
      values.push(value)
      let global_x = output_bounds.pixel_x + x
      let global_y = output_bounds.pixel_y + y
      let global_index = global_y * before.width() + global_x
      if pixel_in_regions(global_x, global_y, regions) &&
        pixels_differ(before, after, global_index) {
        event_region_values.push(value)
      }
    }
  }
  {
    evidence: computed_perceptual_flip_evidence(
      {
        method_id: "nvlabs_ldr_flip/v1.7-b475eb4b",
        pixel_x: output_bounds.pixel_x,
        pixel_y: output_bounds.pixel_y,
        pixel_width: output_bounds.pixel_width,
        pixel_height: output_bounds.pixel_height,
        encoding: "uint16_be_base64",
        quantization_step: 1.0 / 65535.0,
        values_base64: encode_flip_u16_base64(values),
      },
      perceptual_flip_statistics(
        values,
        event_region_values,
        before.width() * before.height(),
        threshold,
      ),
    ),
    output_pixels,
    convolution_samples: context_pixels * samples_per_pixel,
  }
}
