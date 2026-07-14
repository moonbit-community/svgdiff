///|
fn shape_geometry_test_fact(
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
fn shape_geometry_value(
  resolution : BasicShapeGeometryResolution,
  property : String,
) -> String raise {
  for entry in resolution.values {
    let (name, value) = entry
    if name == property {
      return value
    }
  }
  fail("missing shape geometry value: \{property}")
}

///|
test "shape numbers accept SVG exponent syntax and reject units" {
  assert_eq(parse_shape_number(" +.5e1 "), Some(5.0))
  assert_eq(parse_shape_number("-.25E+2"), Some(-25.0))
  assert_true(parse_shape_number("1px") is None)
  assert_true(parse_shape_number("1 trailing") is None)
}

///|
test "point lists normalize separators compact signs exponents and odd tails" {
  let (values, complete, odd) = parse_shape_points("0,0 1-2 3e0,+4")
  assert_true(complete)
  assert_true(!odd)
  assert_eq(canonical_shape_points(values), "0,0 1,-2 3,4")
  let (odd_values, odd_complete, recovered_odd) = parse_shape_points("0 0 4")
  assert_true(odd_complete)
  assert_true(recovered_odd)
  assert_eq(canonical_shape_points(odd_values), "0,0")
  let (empty, empty_complete, empty_odd) = parse_shape_points("  ")
  assert_true(empty_complete)
  assert_true(!empty_odd)
  assert_true(empty.is_empty())
  let (_, malformed_complete, _) = parse_shape_points("0,0,")
  assert_true(!malformed_complete)
}

///|
test "rectangle used radii propagate and clamp independently" {
  let resolution = resolve_basic_shape_geometry("rect", [
    shape_geometry_test_fact("width", "10"),
    shape_geometry_test_fact("height", "6"),
    shape_geometry_test_fact("rx", "8"),
  ])
  assert_true(resolution.complete)
  assert_eq(shape_geometry_value(resolution, "rx"), "5")
  assert_eq(shape_geometry_value(resolution, "ry"), "3")
  assert_true(resolution.renders_geometry)
  let invalid = resolve_basic_shape_geometry("rect", [
    shape_geometry_test_fact("width", "-1"),
  ])
  assert_true(!invalid.complete)
  assert_eq(invalid.invalid_facts[0].property, "width")
  let auto = resolve_basic_shape_geometry("rect", [
    shape_geometry_test_fact("width", "auto"),
    shape_geometry_test_fact("height", "6"),
  ])
  assert_true(auto.complete)
  assert_eq(shape_geometry_value(auto, "width"), "0")
  assert_true(!auto.renders_geometry)
}

///|
test "circle and ellipse radii preserve valid zero and auto behavior" {
  let circle = resolve_basic_shape_geometry("circle", [])
  assert_true(circle.complete)
  assert_eq(shape_geometry_value(circle, "r"), "0")
  assert_true(!circle.renders_geometry)
  let ellipse = resolve_basic_shape_geometry("ellipse", [
    shape_geometry_test_fact("rx", "4"),
    shape_geometry_test_fact("ry", "auto"),
  ])
  assert_eq(shape_geometry_value(ellipse, "rx"), "4")
  assert_eq(shape_geometry_value(ellipse, "ry"), "4")
  assert_true(ellipse.renders_geometry)
  let invalid = resolve_basic_shape_geometry("ellipse", [
    shape_geometry_test_fact("rx", "-1"),
    shape_geometry_test_fact("ry", "2"),
  ])
  assert_true(!invalid.complete)
  assert_eq(invalid.invalid_facts[0].property, "rx")
}

///|
test "lines and point shapes retain interior and rendering distinctions" {
  let line = resolve_basic_shape_geometry("line", [])
  assert_true(!line.fillable_interior)
  assert_true(line.renders_geometry)
  let polyline = resolve_basic_shape_geometry("polyline", [
    shape_geometry_test_fact("points", "0,0 1,1"),
  ])
  assert_true(!polyline.fillable_interior)
  assert_true(polyline.renders_geometry)
  let filled_polyline = resolve_basic_shape_geometry("polyline", [
    shape_geometry_test_fact("points", "0,0 1,1 2,0"),
  ])
  assert_true(filled_polyline.fillable_interior)
  let polygon = resolve_basic_shape_geometry("polygon", [
    shape_geometry_test_fact("points", "0,0 1,1 2,0"),
  ])
  assert_true(polygon.fillable_interior)
  assert_true(polygon.renders_geometry)
}
