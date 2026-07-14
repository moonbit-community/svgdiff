///|
fn stroke_geometry_test_fact(
  property : String,
  value : String,
) -> DeclaredVisualFact {
  {
    property,
    authored_value: value,
    declared_value: value,
    origin: "presentation_attribute",
    source_span: { start_offset: 1, end_offset: value.length() + 1 },
  }
}

///|
fn stroke_geometry_value(
  resolution : StrokeGeometryResolution,
  property : String,
) -> String raise {
  for entry in resolution.values {
    let (name, value) = entry
    if name == property {
      return value
    }
  }
  fail("missing stroke geometry value: \{property}")
}

///|
test "stroke geometry resolves SVG defaults and keywords" {
  let resolution = resolve_stroke_geometry([])
  assert_true(resolution.complete)
  assert_eq(stroke_geometry_value(resolution, "stroke-width"), "1")
  assert_eq(stroke_geometry_value(resolution, "stroke-linecap"), "butt")
  assert_eq(stroke_geometry_value(resolution, "stroke-linejoin"), "miter")
  assert_eq(stroke_geometry_value(resolution, "stroke-miterlimit"), "4")
  assert_eq(stroke_geometry_value(resolution, "stroke-dasharray"), "none")
  assert_eq(stroke_geometry_value(resolution, "stroke-dashoffset"), "0")
  assert_eq(stroke_geometry_value(resolution, "vector-effect"), "none")
}

///|
test "stroke geometry admits every SVG 2 cap and join keyword" {
  for cap in ["butt", "round", "square"] {
    let resolution = resolve_stroke_geometry([
      stroke_geometry_test_fact("stroke-linecap", cap),
    ])
    assert_true(resolution.complete)
    assert_eq(stroke_geometry_value(resolution, "stroke-linecap"), cap)
  }
  for join in ["miter", "miter-clip", "round", "bevel", "arcs"] {
    let resolution = resolve_stroke_geometry([
      stroke_geometry_test_fact("stroke-linejoin", join),
    ])
    assert_true(resolution.complete)
    assert_eq(stroke_geometry_value(resolution, "stroke-linejoin"), join)
  }
}

///|
test "stroke dash lists duplicate odd values and normalize offsets" {
  let resolution = resolve_stroke_geometry([
    stroke_geometry_test_fact("stroke-dasharray", "5, 3 2"),
    stroke_geometry_test_fact("stroke-dashoffset", "-1"),
  ])
  assert_true(resolution.complete)
  assert_eq(
    stroke_geometry_value(resolution, "stroke-dasharray"),
    "5 3 2 5 3 2",
  )
  assert_eq(stroke_geometry_value(resolution, "stroke-dashoffset"), "19")
  let all_zero = resolve_stroke_geometry([
    stroke_geometry_test_fact("stroke-dasharray", "0,0,0"),
    stroke_geometry_test_fact("stroke-dashoffset", "7"),
  ])
  assert_true(all_zero.complete)
  assert_eq(stroke_geometry_value(all_zero, "stroke-dasharray"), "none")
  assert_eq(stroke_geometry_value(all_zero, "stroke-dashoffset"), "0")
}

///|
test "stroke dash grammar accepts compact signs and exponents" {
  let (values, complete) = parse_stroke_dasharray(".5e1 3-2")
  assert_true(complete)
  assert_eq(values, [5.0, 3.0, -2.0])
  let (_, malformed) = parse_stroke_dasharray("5,,3")
  assert_true(!malformed)
}

///|
test "stroke geometry rejects invalid values with authored facts" {
  let resolution = resolve_stroke_geometry([
    stroke_geometry_test_fact("stroke-width", "-1"),
    stroke_geometry_test_fact("stroke-linecap", "triangle"),
    stroke_geometry_test_fact("stroke-linejoin", "sharp"),
    stroke_geometry_test_fact("stroke-miterlimit", "-2"),
    stroke_geometry_test_fact("stroke-dasharray", "4 -1"),
    stroke_geometry_test_fact("stroke-dashoffset", "2px"),
    stroke_geometry_test_fact("vector-effect", "non-rotation"),
  ])
  assert_true(!resolution.complete)
  assert_eq(resolution.invalid_facts.map(fact => fact.property), [
    "stroke-width", "stroke-linecap", "stroke-linejoin", "stroke-miterlimit", "stroke-dasharray",
    "stroke-dashoffset", "vector-effect",
  ])
}

///|
test "stroke expansion is conservative for caps and joins" {
  let round = resolve_stroke_geometry([
    stroke_geometry_test_fact("stroke-width", "6"),
    stroke_geometry_test_fact("stroke-linecap", "round"),
    stroke_geometry_test_fact("stroke-linejoin", "round"),
  ])
  assert_eq(round.conservative_expansion, 3.0)
  let miter = resolve_stroke_geometry([
    stroke_geometry_test_fact("stroke-width", "6"),
    stroke_geometry_test_fact("stroke-linejoin", "miter"),
    stroke_geometry_test_fact("stroke-miterlimit", "5"),
  ])
  assert_eq(miter.conservative_expansion, 15.0)
}
