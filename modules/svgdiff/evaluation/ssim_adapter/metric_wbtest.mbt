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
fn constant_image(width : Int, height : Int, value : Double) -> Array[Double] {
  Array::make(width * height, value)
}

///|
test "SSIM has an exact symmetric identity maximum" {
  let left = constant_image(16, 16, 32.0)
  let right = constant_image(16, 16, 192.0)
  guard ssim_components(left, left, 16, 16) is Some(identity) &&
    ssim_components(left, right, 16, 16) is Some(forward) &&
    ssim_components(right, left, 16, 16) is Some(reverse) else {
    assert_true(false)
    return
  }
  assert_eq(identity.mean_ssim, 1.0)
  assert_eq(forward.mean_ssim, reverse.mean_ssim)
  let c1 = 0.01 * 255.0 * (0.01 * 255.0)
  let expected = (2.0 * 32.0 * 192.0 + c1) / (32.0 * 32.0 + 192.0 * 192.0 + c1)
  assert_true((forward.mean_ssim - expected).abs() < 0.000000000001)
}

///|
test "SSIM rejects a raster smaller than its window" {
  let image = constant_image(8, 8, 32.0)
  assert_true(ssim_components(image, image, 8, 8) is None)
}

///|
test "five-level MS-SSIM rejects insufficient dimensions" {
  let image = constant_image(16, 16, 0.0)
  let result = five_level_ms_ssim(image, image, 16, 16)
  assert_eq(result.value, None)
  assert_eq(result.reason_code, Some("insufficient_scale_extent"))
}

///|
test "five-level MS-SSIM preserves identity" {
  let image = constant_image(256, 256, 128.0)
  let result = five_level_ms_ssim(image, image, 256, 256)
  assert_eq(result.reason_code, None)
  assert_eq(result.value, Some(1.0))
}

///|
test "two-by-two downsampling averages disjoint blocks" {
  let source = [0.0, 2.0, 4.0, 6.0, 8.0, 10.0, 12.0, 14.0]
  guard downsample_2x2_box(source, 4, 2) is Some((output, width, height)) else {
    assert_true(false)
    return
  }
  assert_eq(width, 2)
  assert_eq(height, 1)
  assert_eq(output, [5.0, 9.0])
}
