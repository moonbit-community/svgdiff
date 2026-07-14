///|
test "single-region magnitude scans its bounds and still excludes equal pixels" {
  let before = @svg.Image::new(5, 5)
  let after = @svg.Image::new(5, 5)
  let changed = @svg.Color::rgb(255, 0, 0)
  for point in [(1, 1), (2, 1), (3, 1), (1, 2), (3, 2), (1, 3), (2, 3), (3, 3)] {
    let (x, y) = point
    after.set_pixel(x, y, changed)
  }
  match pixel_difference_regions(before, after, 1) {
    Regions([region]) => {
      assert_eq(region.pixel_x, 1)
      assert_eq(region.pixel_y, 1)
      assert_eq(region.pixel_width, 3)
      assert_eq(region.pixel_height, 3)
      let magnitude = rendered_magnitude_for_regions(before, after, [region])
      assert_eq(magnitude.changed_pixels, 8)
      assert_eq(magnitude.changed_pixel_fraction, 8.0 / 25.0)
      assert_true(magnitude.rgba8_rmse > 0.0)
      assert_true(magnitude.linear_premultiplied_rgba_rmse > 0.0)
    }
    _ => fail("expected one connected ring region")
  }
}

///|
test "polygon bounds use the canonical point sequence" {
  let source = "<svg width='20' height='20'><polygon points='1 2,8 2,5 7'/></svg>"
  let subjects = extract_source_subjects_with_profile_or_raise(
    source,
    ComparisonProfile::v1_default(),
  )
  guard source_subject_bounds(subjects[0]) is Some(bounds) else {
    fail("valid polygon must have computed bounds")
  }
  assert_eq(bounds.x, 1.0)
  assert_eq(bounds.y, 2.0)
  assert_eq(bounds.width, 7.0)
  assert_eq(bounds.height, 5.0)
}
