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
    geometry_displacement_css_px: geometry_css_px,
    geometry_viewport_fraction,
    presence_painted_viewport_fraction: presence_viewport_fraction,
    raster_changed_pixel_fraction: changed_pixel_fraction,
    raster_rgba8_rmse: rgba8_rmse,
    raster_linear_premultiplied_rgba_rmse: linear_rmse,
  }
}

///|
test "v1 ordering constructs every current domain family tuple" {
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
    assert_eq(ordering.policy_id, "v1_domain_lexicographic")
    assert_eq(ordering.components, expected)
  }
}

///|
test "v1 ordering omits unavailable measurements instead of inventing zero" {
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
test "v1 ordering compares descending then prefers a longer equal prefix" {
  assert_true(compare_ordering_components([2.0], [1.0]) < 0)
  assert_true(compare_ordering_components([1.0], [2.0]) > 0)
  assert_true(compare_ordering_components([1.0, 0.5], [1.0]) < 0)
  assert_true(compare_ordering_components([1.0], [1.0, 0.5]) > 0)
  assert_eq(compare_ordering_components([1.0, 0.5], [1.0, 0.5]), 0)
}
