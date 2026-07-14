///|
priv struct StrokeGeometryResolution {
  values : Array[(String, String)]
  invalid_facts : Array[DeclaredVisualFact]
  complete : Bool
  conservative_expansion : Double
}

///|
fn stroke_geometry_property(property : String) -> Bool {
  match property {
    "stroke-width"
    | "stroke-linecap"
    | "stroke-linejoin"
    | "stroke-miterlimit"
    | "stroke-dasharray"
    | "stroke-dashoffset"
    | "vector-effect" => true
    _ => false
  }
}

///|
fn push_invalid_stroke_fact(
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
fn parse_stroke_dasharray(source : String) -> (Array[Double], Bool) {
  let parser : TransformListParser = { data: source, position: 0 }
  let values : Array[Double] = []
  ignore(parser.skip_whitespace())
  if parser.position == source.length() {
    return (values, false)
  }
  while parser.position < source.length() {
    match parser.parse_number() {
      Some(value) => values.push(value)
      None => return (values, false)
    }
    let had_whitespace = parser.skip_whitespace()
    if parser.position >= source.length() {
      break
    }
    if source[parser.position] == ',' {
      parser.position += 1
      ignore(parser.skip_whitespace())
      if parser.position >= source.length() || source[parser.position] == ',' {
        return (values, false)
      }
    } else if !had_whitespace &&
      source[parser.position] != '+' &&
      source[parser.position] != '-' {
      return (values, false)
    }
  }
  (values, true)
}

///|
fn canonical_stroke_dasharray(values : Array[Double]) -> String {
  values.map(canonical_shape_number).join(" ")
}

///|
fn normalized_stroke_keyword(
  facts : Array[DeclaredVisualFact],
  property : String,
  default_value : String,
  allowed : Array[String],
  invalid : Array[DeclaredVisualFact],
) -> String {
  match shape_fact(facts, property) {
    None => default_value
    Some(fact) => {
      let value = fact.declared_value.trim().to_owned().to_lower()
      if allowed.contains(value) {
        value
      } else {
        push_invalid_stroke_fact(invalid, Some(fact))
        default_value
      }
    }
  }
}

///|
fn normalized_stroke_number(
  facts : Array[DeclaredVisualFact],
  property : String,
  default_value : Double,
  nonnegative : Bool,
  invalid : Array[DeclaredVisualFact],
) -> Double {
  match shape_fact(facts, property) {
    None => default_value
    Some(fact) =>
      match parse_shape_number(fact.declared_value) {
        Some(value) if !nonnegative || value >= 0.0 => value
        _ => {
          push_invalid_stroke_fact(invalid, Some(fact))
          default_value
        }
      }
  }
}

///|
fn normalized_dash_pattern(
  facts : Array[DeclaredVisualFact],
  invalid : Array[DeclaredVisualFact],
) -> Array[Double] {
  let fact = shape_fact(facts, "stroke-dasharray")
  match fact {
    None => []
    Some(fact) if fact.declared_value.trim().to_owned().to_lower() == "none" =>
      []
    Some(fact) => {
      let (parsed, complete) = parse_stroke_dasharray(fact.declared_value)
      if !complete || parsed.any(value => value < 0.0) {
        push_invalid_stroke_fact(invalid, Some(fact))
        return []
      }
      if parsed.all(value => value == 0.0) {
        return []
      }
      if parsed.length() % 2 == 1 {
        let original = parsed.copy()
        parsed.push_iter(original.iter())
      }
      parsed
    }
  }
}

///|
fn effective_dash_offset(offset : Double, pattern : Array[Double]) -> Double {
  let sum = pattern.fold(init=0.0, (total, value) => total + value)
  if sum == 0.0 {
    0.0
  } else {
    offset - (offset / sum).floor() * sum
  }
}

///|
fn resolve_stroke_geometry(
  facts : Array[DeclaredVisualFact],
) -> StrokeGeometryResolution {
  let invalid_facts : Array[DeclaredVisualFact] = []
  let width = normalized_stroke_number(
    facts, "stroke-width", 1.0, true, invalid_facts,
  )
  let linecap = normalized_stroke_keyword(
    facts,
    "stroke-linecap",
    "butt",
    ["butt", "round", "square"],
    invalid_facts,
  )
  let linejoin = normalized_stroke_keyword(
    facts,
    "stroke-linejoin",
    "miter",
    ["miter", "miter-clip", "round", "bevel", "arcs"],
    invalid_facts,
  )
  let miterlimit = normalized_stroke_number(
    facts, "stroke-miterlimit", 4.0, true, invalid_facts,
  )
  let dasharray = normalized_dash_pattern(facts, invalid_facts)
  let authored_offset = normalized_stroke_number(
    facts, "stroke-dashoffset", 0.0, false, invalid_facts,
  )
  let dashoffset = effective_dash_offset(authored_offset, dasharray)
  let vector_effect = normalized_stroke_keyword(
    facts,
    "vector-effect",
    "none",
    ["none", "non-scaling-stroke"],
    invalid_facts,
  )
  let half_width = width / 2.0
  let conservative_expansion = match linejoin {
    "miter" | "miter-clip" | "arcs" => half_width.max(miterlimit * half_width)
    _ => half_width
  }
  let values : Array[(String, String)] = [
    ("stroke-width", canonical_shape_number(width)),
    ("stroke-linecap", linecap),
    ("stroke-linejoin", linejoin),
    ("stroke-miterlimit", canonical_shape_number(miterlimit)),
    (
      "stroke-dasharray",
      if dasharray.is_empty() {
        "none"
      } else {
        canonical_stroke_dasharray(dasharray)
      },
    ),
    ("stroke-dashoffset", canonical_shape_number(dashoffset)),
    ("vector-effect", vector_effect),
  ]
  {
    values,
    invalid_facts,
    complete: invalid_facts.is_empty(),
    conservative_expansion,
  }
}

///|
fn resolved_stroke_value(
  resolution : StrokeGeometryResolution,
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
fn stroke_geometry_number(
  resolution : StrokeGeometryResolution,
  property : String,
) -> Double {
  parse_shape_number(resolved_stroke_value(resolution, property)).unwrap_or(0.0)
}

///|
fn resolved_stroke_paint_present(facts : Array[DeclaredVisualFact]) -> Bool {
  match shape_fact(facts, "stroke") {
    Some(fact) => fact.declared_value.trim().to_owned().to_lower() != "none"
    None => false
  }
}

///|
fn point_sequence_has_nonzero_segment(points : Array[Double]) -> Bool {
  let mut index = 2
  while index + 1 < points.length() {
    if points[index] != points[index - 2] ||
      points[index + 1] != points[index - 1] {
      return true
    }
    index += 2
  }
  false
}

///|
fn resolved_stroke_path_present(
  kind : String,
  geometry : BasicShapeGeometryResolution,
  path_segments : Array[PathSegmentEvidence],
  stroke : StrokeGeometryResolution,
) -> Bool {
  let linecap = resolved_stroke_value(stroke, "stroke-linecap")
  match kind {
    "rect" | "circle" | "ellipse" | "polygon" => geometry.renders_geometry
    "line" => {
      let x1 = resolved_shape_number_value(geometry, "x1")
      let y1 = resolved_shape_number_value(geometry, "y1")
      let x2 = resolved_shape_number_value(geometry, "x2")
      let y2 = resolved_shape_number_value(geometry, "y2")
      x1 != x2 || y1 != y2 || linecap != "butt"
    }
    "polyline" => {
      let (points, complete, odd) = parse_shape_points(
        resolved_shape_value(geometry, "points"),
      )
      complete &&
      !odd &&
      points.length() >= 4 &&
      (point_sequence_has_nonzero_segment(points) || linecap != "butt")
    }
    "path" => !path_segments.is_empty()
    _ => false
  }
}

///|
fn resolved_stroke_expansion(
  kind : String,
  geometry : BasicShapeGeometryResolution,
  stroke : StrokeGeometryResolution,
) -> Double {
  let width = stroke_geometry_number(stroke, "stroke-width")
  let has_join = match kind {
    "rect" | "polygon" => geometry.renders_geometry
    "polyline" => {
      let (points, complete, odd) = parse_shape_points(
        resolved_shape_value(geometry, "points"),
      )
      complete && !odd && points.length() >= 6
    }
    "path" => true
    _ => false
  }
  if has_join {
    stroke.conservative_expansion
  } else {
    width / 2.0
  }
}

///|
fn append_stroke_geometry_diagnostics(
  subjects : Array[SourceSubject],
  source_role : String,
  diagnostics : Array[Diagnostic],
) -> Unit {
  for subject in subjects {
    if subject.stroke_complete {
      continue
    }
    let subject_id = source_subject_id(subject)
    merge_diagnostic_into(diagnostics, {
      ..unlocated_diagnostic(
        "diagnostic:stroke-geometry-unsupported:\{subject_id}",
        "stroke_geometry_unsupported",
        subject_id,
        ["computed_appearance", "rendered_evidence"],
      ),
      source_locations: subject.stroke_invalid_facts.map(fn(fact) {
        diagnostic_location(source_role, fact.source_span)
      }),
    })
  }
}

///|
fn append_stroke_renderer_diagnostics(
  subjects : Array[SourceSubject],
  source_role : String,
  diagnostics : Array[Diagnostic],
) -> Unit {
  for subject in subjects {
    if !subject.stroke_complete || !subject.stroke_active {
      continue
    }
    let subject_id = source_subject_id(subject)
    let guards : Array[(String, Array[String])] = [
      (
        "renderer_stroke_outline_raster_unproven",
        ["stroke", "stroke-width", "stroke-linecap"],
      ),
    ]
    if stroke_subject_has_join(subject) {
      guards.push(
        (
          "renderer_stroke_join_raster_unproven",
          ["stroke-linejoin", "stroke-miterlimit"],
        ),
      )
    }
    if subject_value(subject, "stroke-dasharray") != Some("none") {
      guards.push(
        (
          "renderer_stroke_dash_raster_unproven",
          ["stroke-dasharray", "stroke-dashoffset"],
        ),
      )
    }
    if subject.stroke_non_scaling {
      guards.push(("renderer_non_scaling_stroke_unproven", ["vector-effect"]))
    }
    for renderer_gap in guards {
      let (code, properties) = renderer_gap
      let id_code = code.replace_all(old="_", new="-")
      merge_diagnostic_into(diagnostics, {
        ..unlocated_diagnostic(
          "diagnostic:\{id_code}:\{subject_id}",
          code,
          subject_id,
          ["rendered_evidence"],
        ),
        source_locations: [
          for fact in subject.facts if properties.contains(fact.property) => {
            diagnostic_location(source_role, fact.source_span)
          }
        ],
      })
    }
  }
}
