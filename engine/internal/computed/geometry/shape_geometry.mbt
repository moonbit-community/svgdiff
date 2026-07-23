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
pub(all) struct BasicShapeGeometryResolution {
  values : Array[(String, String)]
  invalid_facts : Array[DeclaredVisualFact]
  complete : Bool
  fillable_interior : Bool
  renders_geometry : Bool
}

///|
pub fn basic_shape_geometry_property(kind : String, property : String) -> Bool {
  match kind {
    "rect" =>
      property == "x" ||
      property == "y" ||
      property == "width" ||
      property == "height" ||
      property == "rx" ||
      property == "ry"
    "circle" => property == "cx" || property == "cy" || property == "r"
    "ellipse" =>
      property == "cx" ||
      property == "cy" ||
      property == "rx" ||
      property == "ry"
    "line" =>
      property == "x1" ||
      property == "y1" ||
      property == "x2" ||
      property == "y2"
    "polyline" | "polygon" => property == "points"
    _ => false
  }
}

///|
pub fn canonical_shape_number(value : Double) -> String {
  if value == 0.0 {
    "0"
  } else {
    value.to_string()
  }
}

///|
pub fn parse_shape_number(source : String) -> Double? {
  let parser : NumberParser = { data: source, position: 0 }
  ignore(parser.skip_whitespace())
  guard parser.parse_number() is Some(value) else { return None }
  ignore(parser.skip_whitespace())
  if parser.position == source.length() {
    Some(value)
  } else {
    None
  }
}

///|
pub fn basic_shape_length_direction(property : String) -> SvgLengthDirection {
  match property {
    "x" | "width" | "rx" | "cx" | "x1" | "x2" => Horizontal
    "y" | "height" | "ry" | "cy" | "y1" | "y2" => Vertical
    _ => Unspecified
  }
}

///|
pub fn shape_fact(
  facts : Array[DeclaredVisualFact],
  property : String,
) -> DeclaredVisualFact? {
  declared_fact_in_array(facts, property)
}

///|
pub fn push_invalid_shape_fact(
  invalid : Array[DeclaredVisualFact],
  fact : DeclaredVisualFact?,
) -> Unit {
  match fact {
    Some(fact) if !invalid.any(current => current.property == fact.property) =>
      invalid.push(fact)
    _ => ()
  }
}

///|
pub fn resolved_shape_number(
  facts : Array[DeclaredVisualFact],
  property : String,
  default_value : Double,
  nonnegative : Bool,
  invalid : Array[DeclaredVisualFact],
  viewport : ViewportContext,
  profile : ComparisonProfile,
) -> Double {
  let fact = shape_fact(facts, property)
  match fact {
    None => default_value
    Some(fact) =>
      match
        parse_svg_length(
          fact.declared_value,
          basic_shape_length_direction(property),
          viewport,
          profile,
        ) {
        Some(value) if !nonnegative || value >= 0.0 => value
        _ => {
          push_invalid_shape_fact(invalid, Some(fact))
          default_value
        }
      }
  }
}

///|
pub fn resolved_shape_dimension(
  facts : Array[DeclaredVisualFact],
  property : String,
  invalid : Array[DeclaredVisualFact],
  viewport : ViewportContext,
  profile : ComparisonProfile,
) -> Double {
  match shape_fact(facts, property) {
    None => 0.0
    Some(fact) if fact.declared_value.trim().to_owned().to_lower() == "auto" =>
      0.0
    Some(fact) =>
      match
        parse_svg_length(
          fact.declared_value,
          basic_shape_length_direction(property),
          viewport,
          profile,
        ) {
        Some(value) if value >= 0.0 => value
        _ => {
          push_invalid_shape_fact(invalid, Some(fact))
          0.0
        }
      }
  }
}

///|
pub fn resolved_auto_shape_radius(
  facts : Array[DeclaredVisualFact],
  property : String,
  invalid : Array[DeclaredVisualFact],
  viewport : ViewportContext,
  profile : ComparisonProfile,
) -> Double? {
  let fact = shape_fact(facts, property)
  match fact {
    None => None
    Some(fact) if fact.declared_value.trim().to_owned().to_lower() == "auto" =>
      None
    Some(fact) =>
      match
        parse_svg_length(
          fact.declared_value,
          basic_shape_length_direction(property),
          viewport,
          profile,
        ) {
        Some(value) if value >= 0.0 => Some(value)
        _ => {
          push_invalid_shape_fact(invalid, Some(fact))
          None
        }
      }
  }
}

///|
pub fn push_shape_value(
  values : Array[(String, String)],
  property : String,
  value : Double,
) -> Unit {
  values.push((property, canonical_shape_number(value)))
}

///|
pub fn resolved_shape_value(
  resolution : BasicShapeGeometryResolution,
  property : String,
) -> String {
  for entry in resolution.values {
    let (name, value) = entry
    if name == property {
      return value
    }
  }
  ""
}

///|
pub fn resolved_shape_number_value(
  resolution : BasicShapeGeometryResolution,
  property : String,
) -> Double {
  parse_shape_number(resolved_shape_value(resolution, property)).unwrap_or(0.0)
}

///|
pub fn parse_shape_points(source : String) -> (Array[Double], Bool, Bool) {
  let parser : NumberParser = { data: source, position: 0 }
  let values : Array[Double] = []
  ignore(parser.skip_whitespace())
  while parser.position < source.length() {
    match parser.parse_number() {
      Some(value) => values.push(value)
      None => return (values, false, false)
    }
    let had_whitespace = parser.skip_whitespace()
    if parser.position >= source.length() {
      break
    }
    if source[parser.position] == ',' {
      parser.position += 1
      ignore(parser.skip_whitespace())
      if parser.position >= source.length() || source[parser.position] == ',' {
        return (values, false, false)
      }
    } else if !had_whitespace &&
      source[parser.position] != '+' &&
      source[parser.position] != '-' {
      return (values, false, false)
    }
  }
  let odd = values.length() % 2 == 1
  if odd {
    ignore(values.pop())
  }
  (values, true, odd)
}

///|
pub fn canonical_shape_points(values : Array[Double]) -> String {
  let pairs : Array[String] = []
  let mut index = 0
  while index + 1 < values.length() {
    pairs.push(
      "\{canonical_shape_number(values[index])},\{canonical_shape_number(values[index + 1])}",
    )
    index += 2
  }
  pairs.join(" ")
}

///|
pub fn resolve_basic_shape_geometry_with_context(
  kind : String,
  facts : Array[DeclaredVisualFact],
  viewport : ViewportContext,
  profile : ComparisonProfile,
) -> BasicShapeGeometryResolution {
  let values : Array[(String, String)] = []
  let invalid_facts : Array[DeclaredVisualFact] = []
  let mut fillable_interior = kind != "line" && kind != "polyline"
  let mut renders_geometry = true
  match kind {
    "rect" => {
      let x = resolved_shape_number(
        facts, "x", 0.0, false, invalid_facts, viewport, profile,
      )
      let y = resolved_shape_number(
        facts, "y", 0.0, false, invalid_facts, viewport, profile,
      )
      let width = resolved_shape_dimension(
        facts, "width", invalid_facts, viewport, profile,
      )
      let height = resolved_shape_dimension(
        facts, "height", invalid_facts, viewport, profile,
      )
      let authored_rx = resolved_auto_shape_radius(
        facts, "rx", invalid_facts, viewport, profile,
      )
      let authored_ry = resolved_auto_shape_radius(
        facts, "ry", invalid_facts, viewport, profile,
      )
      let (unclamped_rx, unclamped_ry) = match (authored_rx, authored_ry) {
        (None, None) => (0.0, 0.0)
        (Some(rx), None) => (rx, rx)
        (None, Some(ry)) => (ry, ry)
        (Some(rx), Some(ry)) => (rx, ry)
      }
      let rx = unclamped_rx.min(width / 2.0)
      let ry = unclamped_ry.min(height / 2.0)
      push_shape_value(values, "x", x)
      push_shape_value(values, "y", y)
      push_shape_value(values, "width", width)
      push_shape_value(values, "height", height)
      push_shape_value(values, "rx", rx)
      push_shape_value(values, "ry", ry)
      renders_geometry = width > 0.0 && height > 0.0
    }
    "circle" => {
      let cx = resolved_shape_number(
        facts, "cx", 0.0, false, invalid_facts, viewport, profile,
      )
      let cy = resolved_shape_number(
        facts, "cy", 0.0, false, invalid_facts, viewport, profile,
      )
      let radius = resolved_shape_number(
        facts, "r", 0.0, true, invalid_facts, viewport, profile,
      )
      push_shape_value(values, "cx", cx)
      push_shape_value(values, "cy", cy)
      push_shape_value(values, "r", radius)
      renders_geometry = radius > 0.0
    }
    "ellipse" => {
      let cx = resolved_shape_number(
        facts, "cx", 0.0, false, invalid_facts, viewport, profile,
      )
      let cy = resolved_shape_number(
        facts, "cy", 0.0, false, invalid_facts, viewport, profile,
      )
      let authored_rx = resolved_auto_shape_radius(
        facts, "rx", invalid_facts, viewport, profile,
      )
      let authored_ry = resolved_auto_shape_radius(
        facts, "ry", invalid_facts, viewport, profile,
      )
      let (rx, ry) = match (authored_rx, authored_ry) {
        (None, None) => (0.0, 0.0)
        (Some(rx), None) => (rx, rx)
        (None, Some(ry)) => (ry, ry)
        (Some(rx), Some(ry)) => (rx, ry)
      }
      push_shape_value(values, "cx", cx)
      push_shape_value(values, "cy", cy)
      push_shape_value(values, "rx", rx)
      push_shape_value(values, "ry", ry)
      renders_geometry = rx > 0.0 && ry > 0.0
    }
    "line" =>
      for property in ["x1", "y1", "x2", "y2"] {
        push_shape_value(
          values,
          property,
          resolved_shape_number(
            facts, property, 0.0, false, invalid_facts, viewport, profile,
          ),
        )
      }
    "polyline" | "polygon" => {
      let points_fact = shape_fact(facts, "points")
      let source = match points_fact {
        Some(fact) => fact.declared_value
        None => ""
      }
      let (points, syntax_complete, odd) = parse_shape_points(source)
      if !syntax_complete || odd {
        push_invalid_shape_fact(invalid_facts, points_fact)
      }
      values.push(("points", canonical_shape_points(points)))
      let minimum_coordinates = if kind == "polygon" { 6 } else { 4 }
      renders_geometry = points.length() >= minimum_coordinates
      fillable_interior = points.length() >= 6
    }
    _ => ()
  }
  values.sort_by(fn(left, right) { left.0.compare(right.0) })
  {
    values,
    invalid_facts,
    complete: invalid_facts.is_empty(),
    fillable_interior,
    renders_geometry,
  }
}

///|
pub fn append_basic_shape_geometry_diagnostics(
  subjects : Array[SourceSubject],
  source_role : String,
  diagnostics : Array[Diagnostic],
) -> Unit {
  for subject in subjects {
    if subject.geometry_complete {
      continue
    }
    let subject_id = source_subject_id(subject)
    merge_diagnostic_into(diagnostics, {
      ..unlocated_diagnostic(
        "diagnostic:basic-shape-geometry-unsupported:\{subject_id}",
        "basic_shape_geometry_unsupported",
        subject_id,
        ["computed_appearance", "rendered_evidence"],
      ),
      source_locations: subject.geometry_invalid_facts.map(fn(fact) {
        diagnostic_location(source_role, fact.source_span)
      }),
    })
  }
}

///|
pub fn append_basic_shape_renderer_diagnostics(
  subjects : Array[SourceSubject],
  source_role : String,
  diagnostics : Array[Diagnostic],
) -> Unit {
  for subject in subjects {
    if !subject.geometry_complete {
      continue
    }
    let (code, relevant_properties) = match subject.kind {
      "rect" => {
        let rounded = parse_shape_number(
            subject_value(subject, "rx").unwrap_or("0"),
          ).unwrap_or(0.0) >
          0.0 ||
          parse_shape_number(subject_value(subject, "ry").unwrap_or("0")).unwrap_or(
            0.0,
          ) >
          0.0
        if !rounded {
          continue
        }
        ("renderer_curved_shape_raster_unproven", ["rx", "ry"])
      }
      "circle" if subject.renders_geometry =>
        ("renderer_curved_shape_raster_unproven", ["r"])
      "ellipse" if subject.renders_geometry =>
        ("renderer_curved_shape_raster_unproven", ["rx", "ry"])
      "polyline" | "polygon" if subject.fillable_interior =>
        ("renderer_point_shape_raster_unproven", ["points"])
      _ => continue
    }
    let subject_id = source_subject_id(subject)
    let id_code = code.replace_all(old="_", new="-")
    merge_diagnostic_into(diagnostics, {
      ..unlocated_diagnostic(
        "diagnostic:\{id_code}:\{subject_id}",
        code,
        subject_id,
        ["rendered_evidence"],
      ),
      source_locations: [
        for fact in subject.facts if relevant_properties.contains(fact.property) => {
          diagnostic_location(source_role, fact.source_span)
        }
      ],
    })
  }
}
