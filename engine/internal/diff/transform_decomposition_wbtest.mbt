///|
fn assert_transform_close(actual : Double, expected : Double) -> Unit raise {
  assert_true((actual - expected).abs() < 0.000000000001)
}

///|
fn assert_affine_close(
  actual : AffineTransform,
  expected : AffineTransform,
) -> Unit raise {
  assert_transform_close(actual.a, expected.a)
  assert_transform_close(actual.b, expected.b)
  assert_transform_close(actual.c, expected.c)
  assert_transform_close(actual.d, expected.d)
  assert_transform_close(actual.e, expected.e)
  assert_transform_close(actual.f, expected.f)
}

///|
fn recompose_affine_transform(
  decomposition : @computed.CanonicalAffineTransform,
) -> AffineTransform {
  match decomposition.linear {
    Some(linear) =>
      AffineTransform::translate(
        decomposition.translation_x_css_px,
        decomposition.translation_y_css_px,
      )
      .multiply(AffineTransform::rotate(linear.rotation_degrees))
      .multiply(AffineTransform::skew_x(linear.skew_x_degrees))
      .multiply(AffineTransform::scale(linear.scale_x, linear.scale_y))
    None =>
      AffineTransform::translate(
        decomposition.translation_x_css_px,
        decomposition.translation_y_css_px,
      )
  }
}

///|
test "canonical transform decomposition reconstructs combined affine effects" {
  let matrix = AffineTransform::translate(3.0, -4.0)
    .multiply(AffineTransform::rotate(30.0))
    .multiply(AffineTransform::skew_x(20.0))
    .multiply(AffineTransform::scale(2.0, -3.0))
  let decomposition = decompose_affine_transform(matrix)
  let linear = decomposition.linear.unwrap()
  assert_eq(decomposition.translation_x_css_px, 3.0)
  assert_eq(decomposition.translation_y_css_px, -4.0)
  assert_transform_close(linear.rotation_degrees, 30.0)
  assert_transform_close(linear.scale_x, 2.0)
  assert_transform_close(linear.scale_y, -3.0)
  assert_transform_close(linear.skew_x_degrees, 20.0)
  assert_affine_close(recompose_affine_transform(decomposition), matrix)
}

///|
test "canonical transform decomposition pins quadrant rotations" {
  let decomposition = decompose_affine_transform(AffineTransform::rotate(90.0))
  let linear = decomposition.linear.unwrap()
  assert_eq(linear.rotation_degrees, 90.0)
  assert_eq(linear.scale_x, 1.0)
  assert_eq(linear.scale_y, 1.0)
  assert_eq(linear.skew_x_degrees, 0.0)
}

///|
test "singular transform retains translation without invented linear components" {
  let decomposition = decompose_affine_transform(
    AffineTransform::translate(7.0, 8.0).multiply(
      AffineTransform::scale(0.0, 2.0),
    ),
  )
  assert_eq(decomposition.translation_x_css_px, 7.0)
  assert_eq(decomposition.translation_y_css_px, 8.0)
  assert_true(decomposition.linear is None)
}

///|
test "angular difference uses the shortest signed interval" {
  assert_eq(shortest_transform_angle_delta(179.0, -179.0), 2.0)
  assert_eq(shortest_transform_angle_delta(-179.0, 179.0), -2.0)
  assert_eq(shortest_transform_angle_delta(0.0, 180.0), -180.0)
  assert_eq(shortest_transform_angle_delta(45.0, 405.0), 0.0)
}

///|
test "skewY receives a deterministic canonical reconstruction" {
  let matrix = AffineTransform::skew_y(20.0)
  let decomposition = decompose_affine_transform(matrix)
  assert_true(decomposition.linear is Some(_))
  assert_affine_close(recompose_affine_transform(decomposition), matrix)
}
