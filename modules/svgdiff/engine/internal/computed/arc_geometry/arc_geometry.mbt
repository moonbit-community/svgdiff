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
pub(all) struct SvgArcCenterParameters {
  center_x : Double
  center_y : Double
  radius_x : Double
  radius_y : Double
  cosine : Double
  sine : Double
  start_theta : Double
  sweep_theta : Double
}

///|
/// Axis-aligned bounds of one non-degenerate SVG elliptical arc.
pub(all) struct ArcBounds {
  x : Double
  y : Double
  width : Double
  height : Double
}

///|
fn normalized_positive_angle(angle : Double) -> Double {
  let turn = 2.0 * 3.141592653589793
  angle - turn * (angle / turn).floor()
}

///|
pub fn svg_arc_center_parameters(
  start_x : Double,
  start_y : Double,
  raw_rx : Double,
  raw_ry : Double,
  rotation : Double,
  large : Bool,
  sweep : Bool,
  end_x : Double,
  end_y : Double,
) -> SvgArcCenterParameters? {
  if start_x == end_x && start_y == end_y {
    return None
  }
  let mut radius_x = raw_rx.abs()
  let mut radius_y = raw_ry.abs()
  if radius_x == 0.0 || radius_y == 0.0 {
    return None
  }
  let phi = rotation * 3.141592653589793 / 180.0
  let cosine = @math.cos(phi)
  let sine = @math.sin(phi)
  let half_dx = (start_x - end_x) / 2.0
  let half_dy = (start_y - end_y) / 2.0
  let prime_x = cosine * half_dx + sine * half_dy
  let prime_y = -sine * half_dx + cosine * half_dy
  let radii_ratio = prime_x * prime_x / (radius_x * radius_x) +
    prime_y * prime_y / (radius_y * radius_y)
  if radii_ratio > 1.0 {
    let scale = radii_ratio.sqrt()
    radius_x *= scale
    radius_y *= scale
  }
  let numerator = (radius_x * radius_x * radius_y * radius_y -
  radius_x * radius_x * prime_y * prime_y -
  radius_y * radius_y * prime_x * prime_x).max(0.0)
  let denominator = radius_x * radius_x * prime_y * prime_y +
    radius_y * radius_y * prime_x * prime_x
  let coefficient = if denominator == 0.0 {
    0.0
  } else {
    (if large == sweep { -1.0 } else { 1.0 }) * (numerator / denominator).sqrt()
  }
  let prime_center_x = coefficient * radius_x * prime_y / radius_y
  let prime_center_y = coefficient * -radius_y * prime_x / radius_x
  let center_x = cosine * prime_center_x -
    sine * prime_center_y +
    (start_x + end_x) / 2.0
  let center_y = sine * prime_center_x +
    cosine * prime_center_y +
    (start_y + end_y) / 2.0
  let start_unit_x = (prime_x - prime_center_x) / radius_x
  let start_unit_y = (prime_y - prime_center_y) / radius_y
  let end_unit_x = (-prime_x - prime_center_x) / radius_x
  let end_unit_y = (-prime_y - prime_center_y) / radius_y
  let start_theta = @math.atan2(start_unit_y, start_unit_x)
  let mut sweep_theta = @math.atan2(
    start_unit_x * end_unit_y - start_unit_y * end_unit_x,
    start_unit_x * end_unit_x + start_unit_y * end_unit_y,
  )
  let turn = 2.0 * 3.141592653589793
  if !sweep && sweep_theta > 0.0 {
    sweep_theta -= turn
  } else if sweep && sweep_theta < 0.0 {
    sweep_theta += turn
  }
  Some({
    center_x,
    center_y,
    radius_x,
    radius_y,
    cosine,
    sine,
    start_theta,
    sweep_theta,
  })
}

///|
pub fn SvgArcCenterParameters::point(
  self : SvgArcCenterParameters,
  theta : Double,
) -> (Double, Double) {
  let unit_x = @math.cos(theta)
  let unit_y = @math.sin(theta)
  (
    self.center_x +
    self.radius_x * self.cosine * unit_x -
    self.radius_y * self.sine * unit_y,
    self.center_y +
    self.radius_x * self.sine * unit_x +
    self.radius_y * self.cosine * unit_y,
  )
}

///|
fn SvgArcCenterParameters::contains_angle(
  self : SvgArcCenterParameters,
  theta : Double,
) -> Bool {
  let tolerance = 1.0e-12
  if self.sweep_theta >= 0.0 {
    normalized_positive_angle(theta - self.start_theta) <=
    self.sweep_theta + tolerance
  } else {
    normalized_positive_angle(self.start_theta - theta) <=
    -self.sweep_theta + tolerance
  }
}

///|
pub fn SvgArcCenterParameters::tangent_angle_degrees(
  self : SvgArcCenterParameters,
  theta : Double,
) -> Double {
  let direction = if self.sweep_theta >= 0.0 { 1.0 } else { -1.0 }
  let dx = direction *
    (
      -self.radius_x * self.cosine * @math.sin(theta) -
      self.radius_y * self.sine * @math.cos(theta)
    )
  let dy = direction *
    (
      -self.radius_x * self.sine * @math.sin(theta) +
      self.radius_y * self.cosine * @math.cos(theta)
    )
  @math.atan2(dy, dx) * 180.0 / 3.141592653589793
}

///|
pub fn svg_arc_bounds(
  start_x : Double,
  start_y : Double,
  raw_rx : Double,
  raw_ry : Double,
  rotation : Double,
  large : Bool,
  sweep : Bool,
  end_x : Double,
  end_y : Double,
) -> ArcBounds? {
  guard svg_arc_center_parameters(
      start_x, start_y, raw_rx, raw_ry, rotation, large, sweep, end_x, end_y,
    )
    is Some(arc) else {
    return None
  }
  let mut min_x = start_x.min(end_x)
  let mut min_y = start_y.min(end_y)
  let mut max_x = start_x.max(end_x)
  let mut max_y = start_y.max(end_y)
  let x_extreme = @math.atan2(
    -arc.radius_y * arc.sine,
    arc.radius_x * arc.cosine,
  )
  let y_extreme = @math.atan2(
    arc.radius_y * arc.cosine,
    arc.radius_x * arc.sine,
  )
  let candidates = [
    x_extreme,
    x_extreme + 3.141592653589793,
    y_extreme,
    y_extreme + 3.141592653589793,
  ]
  for theta in candidates {
    if arc.contains_angle(theta) {
      let (x, y) = arc.point(theta)
      min_x = min_x.min(x)
      min_y = min_y.min(y)
      max_x = max_x.max(x)
      max_y = max_y.max(y)
    }
  }
  Some({ x: min_x, y: min_y, width: max_x - min_x, height: max_y - min_y })
}
