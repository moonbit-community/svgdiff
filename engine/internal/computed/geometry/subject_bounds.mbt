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
pub fn bounds_number(subject : SourceSubject, property : String) -> Double? {
  parse_alignment_number(subject_value(subject, property))
}

///|
pub fn points_bounds(subject : SourceSubject) -> CssBounds? {
  let (points, complete, odd) = parse_shape_points(
    subject_value(subject, "points").unwrap_or(""),
  )
  if !complete || odd || points.length() < 2 {
    return None
  }
  let mut min_x = points[0]
  let mut max_x = points[0]
  let mut min_y = points[1]
  let mut max_y = points[1]
  let mut index = 2
  while index + 1 < points.length() {
    min_x = min_x.min(points[index])
    max_x = max_x.max(points[index])
    min_y = min_y.min(points[index + 1])
    max_y = max_y.max(points[index + 1])
    index += 2
  }
  Some({ x: min_x, y: min_y, width: max_x - min_x, height: max_y - min_y })
}

///|
pub fn path_control_hull_bounds(subject : SourceSubject) -> CssBounds? {
  if !subject.path_data_complete || subject.path_segments.is_empty() {
    return None
  }
  let mut min_x = 1.7976931348623157e308
  let mut min_y = 1.7976931348623157e308
  let mut max_x = -1.7976931348623157e308
  let mut max_y = -1.7976931348623157e308
  let mut point_count = 0
  let mut drawable = false
  let mut current_x = 0.0
  let mut current_y = 0.0
  let mut subpath_x = 0.0
  let mut subpath_y = 0.0
  fn include_point(x : Double, y : Double) -> Unit {
    min_x = min_x.min(x)
    min_y = min_y.min(y)
    max_x = max_x.max(x)
    max_y = max_y.max(y)
    point_count += 1
  }
  fn include_bounds(bounds : CssBounds) -> Unit {
    include_point(bounds.x, bounds.y)
    include_point(bounds.x + bounds.width, bounds.y + bounds.height)
  }
  for segment in subject.path_segments {
    match segment.normalized {
      MoveTo(x, y) => {
        include_point(x, y)
        current_x = x
        current_y = y
        subpath_x = x
        subpath_y = y
      }
      LineTo(x, y) => {
        include_point(x, y)
        drawable = true
        current_x = x
        current_y = y
      }
      CubicTo(x1, y1, x2, y2, x, y) => {
        include_point(x1, y1)
        include_point(x2, y2)
        include_point(x, y)
        drawable = true
        current_x = x
        current_y = y
      }
      QuadraticTo(x1, y1, x, y) => {
        include_point(x1, y1)
        include_point(x, y)
        drawable = true
        current_x = x
        current_y = y
      }
      ArcTo(rx, ry, rotation, large, sweep, x, y) => {
        if current_x != x || current_y != y {
          match
            @arc_geometry.svg_arc_bounds(
              current_x, current_y, rx, ry, rotation, large, sweep, x, y,
            ) {
            Some(bounds) =>
              include_bounds({
                x: bounds.x,
                y: bounds.y,
                width: bounds.width,
                height: bounds.height,
              })
            None => include_point(x, y)
          }
          drawable = true
        }
        current_x = x
        current_y = y
      }
      ClosePath => {
        drawable = true
        current_x = subpath_x
        current_y = subpath_y
      }
    }
  }
  if !drawable || point_count == 0 {
    None
  } else {
    Some({ x: min_x, y: min_y, width: max_x - min_x, height: max_y - min_y })
  }
}

///|
pub fn source_subject_geometry_bounds(subject : SourceSubject) -> CssBounds? {
  if !subject.renders_geometry {
    if !subject.stroke_active {
      return None
    }
  }
  match subject.kind {
    "rect" =>
      match
        (bounds_number(subject, "width"), bounds_number(subject, "height")) {
        (Some(width), Some(height)) =>
          Some({
            x: bounds_number(subject, "x").unwrap_or(0.0),
            y: bounds_number(subject, "y").unwrap_or(0.0),
            width,
            height,
          })
        _ => None
      }
    "circle" =>
      match bounds_number(subject, "r") {
        Some(radius) => {
          let cx = bounds_number(subject, "cx").unwrap_or(0.0)
          let cy = bounds_number(subject, "cy").unwrap_or(0.0)
          Some({
            x: cx - radius,
            y: cy - radius,
            width: radius * 2.0,
            height: radius * 2.0,
          })
        }
        _ => None
      }
    "ellipse" =>
      match (bounds_number(subject, "rx"), bounds_number(subject, "ry")) {
        (Some(rx), Some(ry)) => {
          let cx = bounds_number(subject, "cx").unwrap_or(0.0)
          let cy = bounds_number(subject, "cy").unwrap_or(0.0)
          Some({ x: cx - rx, y: cy - ry, width: rx * 2.0, height: ry * 2.0 })
        }
        _ => None
      }
    "line" => {
      let x1 = bounds_number(subject, "x1").unwrap_or(0.0)
      let y1 = bounds_number(subject, "y1").unwrap_or(0.0)
      let x2 = bounds_number(subject, "x2").unwrap_or(0.0)
      let y2 = bounds_number(subject, "y2").unwrap_or(0.0)
      Some({
        x: x1.min(x2),
        y: y1.min(y2),
        width: (x2 - x1).abs(),
        height: (y2 - y1).abs(),
      })
    }
    "polyline" | "polygon" => points_bounds(subject)
    "path" => path_control_hull_bounds(subject)
    _ => None
  }
}
