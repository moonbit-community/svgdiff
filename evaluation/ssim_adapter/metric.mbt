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
priv struct SsimComponents {
  mean_ssim : Double
  mean_contrast_structure : Double
}

///|
priv struct MultiScaleSsim {
  value : Double?
  reason_code : String?
}

///|
fn gaussian_kernel_11_sigma_1_5() -> Array[Double] {
  let result = Array::make(11, 0.0)
  let mut sum = 0.0
  for index in 0..<11 {
    let offset = (index - 5).to_double()
    let value = @math.exp(-(offset * offset) / (2.0 * 1.5 * 1.5))
    result[index] = value
    sum += value
  }
  for index in 0..<11 {
    result[index] = result[index] / sum
  }
  result
}

///|
fn exact_double_samples(left : Array[Double], right : Array[Double]) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for index in 0..<left.length() {
    if left[index] != right[index] {
      return false
    }
  }
  true
}

///|
fn convolve_valid_separable(
  source : Array[Double],
  width : Int,
  height : Int,
  kernel : Array[Double],
) -> (Array[Double], Int, Int)? {
  let kernel_width = kernel.length()
  if width < kernel_width ||
    height < kernel_width ||
    source.length() != width * height {
    return None
  }
  let horizontal_width = width - kernel_width + 1
  let horizontal = Array::make(horizontal_width * height, 0.0)
  for y in 0..<height {
    for x in 0..<horizontal_width {
      let mut value = 0.0
      for offset in 0..<kernel_width {
        value += source[y * width + x + offset] * kernel[offset]
      }
      horizontal[y * horizontal_width + x] = value
    }
  }
  let output_height = height - kernel_width + 1
  let output = Array::make(horizontal_width * output_height, 0.0)
  for y in 0..<output_height {
    for x in 0..<horizontal_width {
      let mut value = 0.0
      for offset in 0..<kernel_width {
        value += horizontal[(y + offset) * horizontal_width + x] *
          kernel[offset]
      }
      output[y * horizontal_width + x] = value
    }
  }
  Some((output, horizontal_width, output_height))
}

///|
fn ssim_components(
  left : Array[Double],
  right : Array[Double],
  width : Int,
  height : Int,
) -> SsimComponents? {
  if width < 11 ||
    height < 11 ||
    left.length() != right.length() ||
    left.length() != width * height {
    return None
  }
  if exact_double_samples(left, right) {
    return Some({ mean_ssim: 1.0, mean_contrast_structure: 1.0 })
  }
  let left_square = Array::make(left.length(), 0.0)
  let right_square = Array::make(right.length(), 0.0)
  let product = Array::make(left.length(), 0.0)
  for index in 0..<left.length() {
    left_square[index] = left[index] * left[index]
    right_square[index] = right[index] * right[index]
    product[index] = left[index] * right[index]
  }
  let kernel = gaussian_kernel_11_sigma_1_5()
  guard convolve_valid_separable(left, width, height, kernel)
    is Some((left_mean, output_width, output_height)) &&
    convolve_valid_separable(right, width, height, kernel)
    is Some((right_mean, _, _)) &&
    convolve_valid_separable(left_square, width, height, kernel)
    is Some((left_second_moment, _, _)) &&
    convolve_valid_separable(right_square, width, height, kernel)
    is Some((right_second_moment, _, _)) &&
    convolve_valid_separable(product, width, height, kernel)
    is Some((product_moment, _, _)) else {
    return None
  }
  let c1 = 0.01 * 255.0 * (0.01 * 255.0)
  let c2 = 0.03 * 255.0 * (0.03 * 255.0)
  let mut ssim_sum = 0.0
  let mut contrast_structure_sum = 0.0
  let sample_count = output_width * output_height
  for index in 0..<sample_count {
    let left_mean_square = left_mean[index] * left_mean[index]
    let right_mean_square = right_mean[index] * right_mean[index]
    let mean_product = left_mean[index] * right_mean[index]
    let left_variance = (left_second_moment[index] - left_mean_square).max(0.0)
    let right_variance = (right_second_moment[index] - right_mean_square).max(
      0.0,
    )
    let covariance = product_moment[index] - mean_product
    let luminance_numerator = 2.0 * mean_product + c1
    let luminance_denominator = left_mean_square + right_mean_square + c1
    let contrast_structure_numerator = 2.0 * covariance + c2
    let contrast_structure_denominator = left_variance + right_variance + c2
    let contrast_structure = contrast_structure_numerator /
      contrast_structure_denominator
    ssim_sum += luminance_numerator *
      contrast_structure_numerator /
      (luminance_denominator * contrast_structure_denominator)
    contrast_structure_sum += contrast_structure
  }
  Some({
    mean_ssim: ssim_sum / sample_count.to_double(),
    mean_contrast_structure: contrast_structure_sum / sample_count.to_double(),
  })
}

///|
fn downsample_2x2_box(
  source : Array[Double],
  width : Int,
  height : Int,
) -> (Array[Double], Int, Int)? {
  if width % 2 != 0 || height % 2 != 0 || source.length() != width * height {
    return None
  }
  let output_width = width / 2
  let output_height = height / 2
  let output = Array::make(output_width * output_height, 0.0)
  for y in 0..<output_height {
    for x in 0..<output_width {
      let source_x = x * 2
      let source_y = y * 2
      output[y * output_width + x] = (
          source[source_y * width + source_x] +
          source[source_y * width + source_x + 1] +
          source[(source_y + 1) * width + source_x] +
          source[(source_y + 1) * width + source_x + 1]
        ) /
        4.0
    }
  }
  Some((output, output_width, output_height))
}

///|
fn five_level_ms_ssim(
  left : Array[Double],
  right : Array[Double],
  width : Int,
  height : Int,
) -> MultiScaleSsim {
  if width < 176 ||
    height < 176 ||
    left.length() != width * height ||
    right.length() != width * height {
    return { value: None, reason_code: Some("insufficient_scale_extent") }
  }
  if left.length() == width * height && exact_double_samples(left, right) {
    return { value: Some(1.0), reason_code: None }
  }
  let weights = [0.0448, 0.2856, 0.3001, 0.2363, 0.1333]
  let mut current_left = left
  let mut current_right = right
  let mut current_width = width
  let mut current_height = height
  let components : Array[SsimComponents] = []
  for level in 0..<5 {
    guard ssim_components(
        current_left, current_right, current_width, current_height,
      )
      is Some(component) else {
      return { value: None, reason_code: Some("insufficient_scale_extent") }
    }
    components.push(component)
    if level < 4 {
      guard downsample_2x2_box(current_left, current_width, current_height)
        is Some((next_left, next_width, next_height)) &&
        downsample_2x2_box(current_right, current_width, current_height)
        is Some((next_right, _, _)) else {
        return { value: None, reason_code: Some("invalid_scale_pyramid") }
      }
      current_left = next_left
      current_right = next_right
      current_width = next_width
      current_height = next_height
    }
  }
  let mut value = 1.0
  for level in 0..<4 {
    let component = components[level].mean_contrast_structure
    if component <= 0.0 {
      return {
        value: None,
        reason_code: Some("non_positive_contrast_structure_mean"),
      }
    }
    value *= @math.pow(component, weights[level])
  }
  let final_ssim = components[4].mean_ssim
  if final_ssim <= 0.0 {
    return { value: None, reason_code: Some("non_positive_final_ssim") }
  }
  value *= @math.pow(final_ssim, weights[4])
  { value: Some(value), reason_code: None }
}

///|
fn displayed_grayscale_over_white(image : @svg.Image) -> Array[Double] {
  image.pixels.map(pixel => {
    let alpha = pixel.a.to_double() / 255.0
    let inverse_alpha = 1.0 - alpha
    let red = pixel.r.to_double() * alpha + 255.0 * inverse_alpha
    let green = pixel.g.to_double() * alpha + 255.0 * inverse_alpha
    let blue = pixel.b.to_double() * alpha + 255.0 * inverse_alpha
    0.2989 * red + 0.5870 * green + 0.1140 * blue
  })
}

///|
fn exact_pixels(left : @svg.Image, right : @svg.Image) -> Bool {
  if left.width != right.width ||
    left.height != right.height ||
    left.pixels.length() != right.pixels.length() {
    return false
  }
  for index in 0..<left.pixels.length() {
    let left_pixel = left.pixels[index]
    let right_pixel = right.pixels[index]
    if left_pixel.r != right_pixel.r ||
      left_pixel.g != right_pixel.g ||
      left_pixel.b != right_pixel.b ||
      left_pixel.a != right_pixel.a {
      return false
    }
  }
  true
}
