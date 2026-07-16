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
test "painted boundary distribution reports symmetric nearest-rank statistics" {
  let before = @svg.Image::new(40, 3)
  let after = @svg.Image::new(40, 3)
  let painted = @svg.Color::rgb(255, 0, 0)
  for x in 1..<21 {
    before.set_pixel(x, 1, painted)
  }
  for x in 1..<20 {
    after.set_pixel(x, 1, painted)
  }
  after.set_pixel(30, 1, painted)
  guard painted_boundary_displacement_distribution(before, after, 1.0)
    is Some(distribution) else {
    fail("expected a boundary distribution")
  }
  assert_eq(distribution.method_id, "symmetric_nearest_boundary_pixels/v1")
  assert_eq(distribution.before_sample_count, 20)
  assert_eq(distribution.after_sample_count, 20)
  assert_eq(distribution.mean_css_px, 0.275)
  assert_eq(distribution.p95_css_px, 0.0)
  assert_eq(distribution.max_css_px, 10.0)
  guard painted_boundary_displacement_distribution(after, before, 1.0)
    is Some(reverse) else {
    fail("expected a reversed boundary distribution")
  }
  assert_eq(reverse.mean_css_px, distribution.mean_css_px)
  assert_eq(reverse.p95_css_px, distribution.p95_css_px)
  assert_eq(reverse.max_css_px, distribution.max_css_px)
  guard painted_boundary_displacement_distribution(before, after, 2.0)
    is Some(high_dpr) else {
    fail("expected a DPR-normalized boundary distribution")
  }
  assert_eq(high_dpr.mean_css_px, 0.1375)
  assert_eq(high_dpr.p95_css_px, 0.0)
  assert_eq(high_dpr.max_css_px, 5.0)
}

///|
test "painted boundary distribution distinguishes both-empty from one-empty" {
  let empty = @svg.Image::new(4, 4)
  let painted = @svg.Image::new(4, 4)
  painted.set_pixel(1, 1, @svg.Color::rgb(255, 0, 0))
  guard painted_boundary_displacement_distribution(empty, empty, 1.0)
    is Some(distribution) else {
    fail("expected explicit empty-boundary equality")
  }
  assert_eq(distribution.before_sample_count, 0)
  assert_eq(distribution.after_sample_count, 0)
  assert_eq(distribution.mean_css_px, 0.0)
  assert_eq(distribution.p95_css_px, 0.0)
  assert_eq(distribution.max_css_px, 0.0)
  assert_true(
    painted_boundary_displacement_distribution(empty, painted, 1.0) is None,
  )
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

///|
test "stroke bounds distinguish ordinary and non-scaling expansion" {
  let ordinary = extract_source_subjects_or_raise(
      "<svg width='40' height='40'><line x1='10' y1='10' x2='20' y2='10' stroke='black' stroke-width='4' stroke-linecap='round' transform='scale(2)'/></svg>",
    )[0]
  let non_scaling = extract_source_subjects_or_raise(
      "<svg width='40' height='40'><line x1='10' y1='10' x2='20' y2='10' stroke='black' stroke-width='4' stroke-linecap='round' transform='scale(2)' vector-effect='non-scaling-stroke'/></svg>",
    )[0]
  assert_true(
    source_subject_bounds(ordinary)
    is Some({ x: 16.0, y: 16.0, width: 28.0, height: 8.0 }),
  )
  assert_true(
    source_subject_bounds(non_scaling)
    is Some({ x: 18.0, y: 18.0, width: 24.0, height: 4.0 }),
  )
}

///|
test "complete non-arc path bounds use a transformed conservative control hull" {
  let subject = extract_source_subjects_or_raise(
      "<svg><path d='M1 2 C3 10 7 -2 9 4' transform='translate(5 6)'/></svg>",
    )[0]
  guard source_subject_bounds(subject) is Some(bounds) else {
    fail("expected conservative path bounds")
  }
  assert_eq(bounds.x, 6.0)
  assert_eq(bounds.y, 4.0)
  assert_eq(bounds.width, 8.0)
  assert_eq(bounds.height, 12.0)
  let arc = extract_source_subjects_or_raise(
      "<svg><path d='M1 2 A4 5 0 0 1 9 4'/></svg>",
    )[0]
  assert_true(source_subject_bounds(arc) is None)
}
