///|
fn parsed_transform(value : String) -> NormalizedTransformList {
  match parse_transform_list(value) {
    ValidTransformList(result) => result
    InvalidTransformList => abort("expected valid transform list")
  }
}

///|
fn apply_transform(
  transform : AffineTransform,
  x : Double,
  y : Double,
) -> (Double, Double) {
  (
    transform.a * x + transform.c * y + transform.e,
    transform.b * x + transform.d * y + transform.f,
  )
}

///|
test "transform list supports every SVG transform function" {
  assert_true(
    parsed_transform("matrix(1 2 3 4 5 6)").matrix ==
    { a: 1.0, b: 2.0, c: 3.0, d: 4.0, e: 5.0, f: 6.0 },
  )
  assert_eq(parsed_transform("translate(2)").matrix.e, 2.0)
  assert_eq(parsed_transform("translate(2 3)").matrix.f, 3.0)
  assert_eq(parsed_transform("scale(2)").matrix.d, 2.0)
  assert_eq(parsed_transform("scale(2 3)").matrix.d, 3.0)
  assert_true(
    parsed_transform("rotate(90)").matrix ==
    { a: 0.0, b: 1.0, c: -1.0, d: 0.0, e: 0.0, f: 0.0 },
  )
  assert_true(parsed_transform("skewX(0)").matrix.is_identity())
  assert_true(parsed_transform("skewY(0)").matrix.is_identity())
  assert_true(parsed_transform("skewX(180)").matrix.is_identity())
  assert_true(parsed_transform("skewY(-180)").matrix.is_identity())
}

///|
test "transform list post-multiplies functions in authored order" {
  let transform = parsed_transform("translate(10 5) scale(2 3)").matrix
  assert_eq(apply_transform(transform, 1.0, 1.0), (12.0, 8.0))
  assert_eq(transform.signature(), "matrix(2,0,0,3,10,5)")
}

///|
test "rotation around a point preserves its center" {
  let transform = parsed_transform("rotate(90 2 3)").matrix
  assert_eq(apply_transform(transform, 2.0, 3.0), (2.0, 3.0))
  assert_eq(apply_transform(transform, 3.0, 3.0), (2.0, 4.0))
}

///|
test "transform numeric spelling and whitespace normalize" {
  let first = parsed_transform(" translate(1.0, 2e0)   scale(3) ")
  let second = parsed_transform("translate(1 2),scale(3.00)")
  assert_true(first.matrix == second.matrix)
  assert_eq(first.signature, second.signature)
  assert_eq(first.signature, "translate(1,2) scale(3)")
  assert_true(parsed_transform("").matrix.is_identity())
}

///|
test "transform numbers accept compact signs decimals and exponents" {
  let compact = parsed_transform("translate(+.5-2E-1)")
  let separated = parsed_transform("translate(0.5, -0.2)")
  assert_true(compact.matrix == separated.matrix)
  assert_eq(parsed_transform("scale(1.)").matrix.a, 1.0)
  assert_eq(parsed_transform("translate(1e+2)").matrix.e, 100.0)
  assert_eq(
    parsed_transform("translate(1\t2)\nscale(3,4)").matrix.signature(),
    "matrix(3,0,0,4,1,2)",
  )
}

///|
test "transform list retains equivalent authored function structure" {
  let shorthand = parsed_transform("translate(1)")
  let explicit = parsed_transform("translate(1 0)")
  let matrix = parsed_transform("matrix(1 0 0 1 1 0)")
  assert_true(shorthand.matrix == explicit.matrix)
  assert_true(explicit.matrix == matrix.matrix)
  assert_true(shorthand.signature != explicit.signature)
  assert_true(explicit.signature != matrix.signature)
}

///|
test "transform list rejects partial or malformed syntax" {
  for
    value in [
      "translate()", "translate(1,)", "translate(1,,2)", "translate(1)scale(2)",
      "matrix(1 0 0 1 0)", "rotate(1 2)", "skewX(1 2)", "unknown(1)", "translate(1) trailing",
      "translate(1e)", "translate(NaN)", "translate(inf)", "translate(1.2.3)",
    ] {
    assert_true(parse_transform_list(value) is InvalidTransformList)
  }
}

///|
test "renderer conformance slice admits integer axis transforms only" {
  assert_true(
    parsed_transform("translate(2) scale(3)").matrix.has_proven_renderer_conformance(),
  )
  assert_true(
    parsed_transform("rotate(90 4 5)").matrix.has_proven_renderer_conformance(),
  )
  assert_true(
    !parsed_transform("translate(0.5)").matrix.has_proven_renderer_conformance(),
  )
  assert_true(
    !parsed_transform("rotate(20)").matrix.has_proven_renderer_conformance(),
  )
  assert_true(
    !parsed_transform("skewX(45)").matrix.has_proven_renderer_conformance(),
  )
  assert_true(
    !parsed_transform("matrix(1 0 1 1 0 0)").matrix.has_proven_renderer_conformance(),
  )
}
