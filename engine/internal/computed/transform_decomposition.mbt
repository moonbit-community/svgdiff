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
pub(all) struct CanonicalLinearTransform {
  rotation_degrees : Double
  scale_x : Double
  scale_y : Double
  skew_x_degrees : Double
}

///|
pub(all) struct CanonicalAffineTransform {
  translation_x_css_px : Double
  translation_y_css_px : Double
  linear : CanonicalLinearTransform?
}

///|
fn transform_radians_to_degrees(value : Double) -> Double {
  normalized_transform_component(value * 180.0 / @math.PI)
}

///|
pub fn shortest_transform_angle_delta(
  before_degrees : Double,
  after_degrees : Double,
) -> Double {
  let delta = after_degrees - before_degrees
  normalized_transform_component(
    delta - ((delta + 180.0) / 360.0).floor() * 360.0,
  )
}

///|
pub fn decompose_affine_transform(
  matrix : AffineTransform,
) -> CanonicalAffineTransform {
  let scale_x = @math.hypot(matrix.a, matrix.b)
  let determinant = matrix.a * matrix.d - matrix.b * matrix.c
  if scale_x == 0.0 || determinant == 0.0 {
    return {
      translation_x_css_px: matrix.e,
      translation_y_css_px: matrix.f,
      linear: None,
    }
  }
  let scale_y = determinant / scale_x
  let shear = (matrix.a * matrix.c + matrix.b * matrix.d) / (scale_x * scale_y)
  {
    translation_x_css_px: matrix.e,
    translation_y_css_px: matrix.f,
    linear: Some({
      rotation_degrees: transform_radians_to_degrees(
        @math.atan2(matrix.b, matrix.a),
      ),
      scale_x: normalized_transform_component(scale_x),
      scale_y: normalized_transform_component(scale_y),
      skew_x_degrees: transform_radians_to_degrees(@math.atan(shear)),
    }),
  }
}
