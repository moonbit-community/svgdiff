///|
fn ordering_test_magnitude(
  geometry_css_px? : Double,
  geometry_viewport_fraction? : Double,
  presence_viewport_fraction? : Double,
  changed_pixel_fraction? : Double,
  rgba8_rmse? : Double,
  linear_rmse? : Double,
) -> DifferenceMagnitude {
  {
    parameter_abs_user_units: None,
    parameter_signed_user_units: None,
    symmetric_relative: None,
    parameter_abs_css_px: None,
    parameter_viewport_fraction: None,
    parameter_entity_fraction: None,
    geometry_displacement_css_px: geometry_css_px,
    painted_boundary_displacement: None,
    geometry_viewport_fraction,
    presence_painted_viewport_fraction: presence_viewport_fraction,
    raster_changed_pixel_fraction: changed_pixel_fraction,
    raster_rgba8_rmse: rgba8_rmse,
    raster_linear_premultiplied_rgba_rmse: linear_rmse,
    intrinsic_raster: None,
    transform_effect: None,
  }
}

///|
test "v2 ordering preserves established domain family tuples" {
  let magnitude = ordering_test_magnitude(
    geometry_css_px=8.0,
    geometry_viewport_fraction=0.25,
    presence_viewport_fraction=0.5,
    changed_pixel_fraction=0.125,
    rgba8_rmse=0.2,
    linear_rmse=0.1,
  )
  for
    entry in [
      ("geometry.position", [8.0, 0.25, 0.125]),
      ("geometry.size", [8.0, 0.25, 0.125]),
      ("paint.fill", [0.1, 0.2, 0.125]),
      ("paint.stroke", [0.1, 0.2, 0.125]),
      ("presence.insertion", [0.5, 0.125]),
      ("presence.deletion", [0.5, 0.125]),
      ("compositing.opacity", [0.125, 0.1, 0.2]),
      ("resource.gradient.stop_color", [0.125, 0.1, 0.2]),
      ("text.content", [0.125, 0.1, 0.2]),
      ("document.structure", [0.125, 0.1, 0.2]),
    ] {
    let (domain, expected) = entry
    let ordering = ordering_for_magnitude(domain, magnitude)
    assert_eq(ordering.policy_id, "v2_domain_lexicographic")
    assert_eq(ordering.components, expected)
  }
}

///|
test "v2 ordering uses transform effect units only inside exact domains" {
  let base = ordering_test_magnitude()
  let translation = ordering_for_magnitude("geometry.transform.translation", {
    ..base,
    geometry_viewport_fraction: Some(0.25),
    raster_changed_pixel_fraction: Some(0.5),
    transform_effect: Some(
      TranslationEffect({
        before_x_css_px: 0.0,
        before_y_css_px: 0.0,
        after_x_css_px: 3.0,
        after_y_css_px: 4.0,
        delta_x_css_px: 3.0,
        delta_y_css_px: 4.0,
        norm_css_px: 5.0,
      }),
    ),
  })
  assert_eq(translation.components, [5.0, 0.25, 0.5])
  let rotation = ordering_for_magnitude("geometry.transform.rotation", {
    ..base,
    raster_changed_pixel_fraction: Some(0.5),
    transform_effect: Some(
      RotationEffect({
        before_degrees: 179.0,
        after_degrees: -179.0,
        signed_delta_degrees: 2.0,
        abs_delta_degrees: 2.0,
      }),
    ),
  })
  assert_eq(rotation.components, [2.0, 0.5])
  let scale = ordering_for_magnitude("geometry.transform.scale", {
    ..base,
    transform_effect: Some(
      ScaleEffect({
        before_x: 1.0,
        before_y: 1.0,
        after_x: 1.0,
        after_y: -1.0,
        max_abs_delta: 2.0,
      }),
    ),
  })
  assert_eq(scale.components, [2.0])
  let skew = ordering_for_magnitude("geometry.transform.skew", {
    ..base,
    transform_effect: Some(
      SkewEffect({
        before_degrees: 0.0,
        after_degrees: 20.0,
        signed_delta_degrees: 20.0,
        abs_delta_degrees: 20.0,
      }),
    ),
  })
  assert_eq(skew.components, [20.0])
}

///|
test "v2 ordering omits unavailable measurements instead of inventing zero" {
  let magnitude = ordering_test_magnitude(
    geometry_viewport_fraction=0.25,
    changed_pixel_fraction=0.0,
  )
  assert_eq(ordering_for_magnitude("geometry.position", magnitude).components, [
    0.25, 0.0,
  ])
  assert_eq(ordering_for_magnitude("paint.fill", magnitude).components, [0.0])
  assert_eq(
    ordering_for_magnitude("compositing.opacity", magnitude).components,
    [0.0],
  )
}

///|
test "v2 ordering compares descending then prefers a longer equal prefix" {
  assert_true(compare_ordering_components([2.0], [1.0]) < 0)
  assert_true(compare_ordering_components([1.0], [2.0]) > 0)
  assert_true(compare_ordering_components([1.0, 0.5], [1.0]) < 0)
  assert_true(compare_ordering_components([1.0], [1.0, 0.5]) > 0)
  assert_eq(compare_ordering_components([1.0, 0.5], [1.0, 0.5]), 0)
}
