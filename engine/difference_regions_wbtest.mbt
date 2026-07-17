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
test "side bounds preserve movement insertion and deletion before union" {
  let profile = ComparisonProfile::v1_default()
  let before = "<svg width='20' height='20'><rect id='box' x='1' y='2' width='4' height='5'/></svg>"
  let after = "<svg width='20' height='20'><rect id='box' x='7' y='2' width='4' height='5'/></svg>"
  let moved = compare(before, after, profile)
  guard moved.subject_alignments.filter(alignment => {
      alignment.before.any(reference => reference.authored_id == Some("box")) &&
      alignment.after.any(reference => reference.authored_id == Some("box"))
    })
    is [movement] else {
    fail("expected one box alignment")
  }
  let movement_sides = alignment_side_bounds(
    movement,
    extract_source_subjects_with_profile_or_raise(before, profile),
    extract_source_subjects_with_profile_or_raise(after, profile),
  )
  assert_true(
    movement_sides.before is Some({ x: 1.0, y: 2.0, width: 4.0, height: 5.0 }),
  )
  assert_true(
    movement_sides.after is Some({ x: 7.0, y: 2.0, width: 4.0, height: 5.0 }),
  )
  assert_true(
    side_bounds_union(movement_sides)
    is Some({ x: 1.0, y: 2.0, width: 10.0, height: 5.0 }),
  )

  let empty = "<svg width='20' height='20'/>"
  let inserted = compare(empty, after, profile)
  guard inserted.subject_alignments.filter(alignment => {
      alignment.relation == "insertion"
    })
    is [insertion] else {
    fail("expected one insertion alignment")
  }
  let insertion_sides = alignment_side_bounds(
    insertion,
    extract_source_subjects_with_profile_or_raise(empty, profile),
    extract_source_subjects_with_profile_or_raise(after, profile),
  )
  assert_true(insertion_sides.before is None)
  assert_true(
    insertion_sides.after is Some({ x: 7.0, y: 2.0, width: 4.0, height: 5.0 }),
  )

  let deleted = compare(before, empty, profile)
  guard deleted.subject_alignments.filter(alignment => {
      alignment.relation == "deletion"
    })
    is [deletion] else {
    fail("expected one deletion alignment")
  }
  let deletion_sides = alignment_side_bounds(
    deletion,
    extract_source_subjects_with_profile_or_raise(before, profile),
    extract_source_subjects_with_profile_or_raise(empty, profile),
  )
  assert_true(
    deletion_sides.before is Some({ x: 1.0, y: 2.0, width: 4.0, height: 5.0 }),
  )
  assert_true(deletion_sides.after is None)
}

///|
test "clip and filter localization retain distinct effect bounds by side" {
  let profile = ComparisonProfile::v1_default()
  let clip_before =
    #|<svg width="20" height="20"><defs><clipPath id="clip"><rect x="1" y="2" width="4" height="5"/></clipPath></defs><rect id="box" width="20" height="20" clip-path="url(#clip)"/></svg>
  let clip_after =
    #|<svg width="20" height="20"><defs><clipPath id="clip"><rect x="7" y="2" width="4" height="5"/></clipPath></defs><rect id="box" width="20" height="20" clip-path="url(#clip)"/></svg>
  let clip_report = compare(clip_before, clip_after, profile)
  guard clip_report.subject_alignments.filter(alignment => {
      alignment.before.any(reference => reference.authored_id == Some("box")) &&
      alignment.after.any(reference => reference.authored_id == Some("box"))
    })
    is [clip_alignment] else {
    fail("expected one clipped box alignment")
  }
  let clip_sides = alignment_side_bounds(
    clip_alignment,
    extract_source_subjects_with_profile_or_raise(clip_before, profile),
    extract_source_subjects_with_profile_or_raise(clip_after, profile),
  )
  assert_true(
    clip_sides.before is Some({ x: 1.0, y: 2.0, width: 4.0, height: 5.0 }),
  )
  assert_true(
    clip_sides.after is Some({ x: 7.0, y: 2.0, width: 4.0, height: 5.0 }),
  )

  let filter_before =
    #|<svg width="20" height="20"><defs><filter id="shift" x="-100%" y="-100%" width="400%" height="400%"><feOffset dx="1"/></filter></defs><rect id="box" x="2" y="2" width="4" height="5" filter="url(#shift)"/></svg>
  let filter_after =
    #|<svg width="20" height="20"><defs><filter id="shift" x="-100%" y="-100%" width="400%" height="400%"><feOffset dx="3"/></filter></defs><rect id="box" x="2" y="2" width="4" height="5" filter="url(#shift)"/></svg>
  let filter_report = compare(filter_before, filter_after, profile)
  guard filter_report.events.filter(event => event.id == "event:filter:shift")
    is [filter_event] else {
    fail("expected one filter resource event")
  }
  let (_, before_hosts) = resolve_filter_hosts_or_raise(filter_before, profile)
  let (_, after_hosts) = resolve_filter_hosts_or_raise(filter_after, profile)
  guard filter_event_side_bounds(filter_event, before_hosts, after_hosts)
    is Some(filter_sides) else {
    fail("expected filter side bounds")
  }
  assert_true(
    filter_sides.before is Some({ x: 3.0, y: 2.0, width: 4.0, height: 5.0 }),
  )
  assert_true(
    filter_sides.after is Some({ x: 5.0, y: 2.0, width: 4.0, height: 5.0 }),
  )
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
test "painted coverage difference uses alpha only and normalizes CSS area" {
  let before = @svg.Image::new(2, 1)
  let after = @svg.Image::new(2, 1)
  before.set_pixel(0, 0, @svg.Color::rgba(255, 0, 0, 255))
  before.set_pixel(1, 0, @svg.Color::rgba(0, 0, 255, 128))
  after.set_pixel(0, 0, @svg.Color::rgba(0, 255, 0, 255))
  after.set_pixel(1, 0, @svg.Color::rgba(0, 0, 0, 64))
  guard painted_coverage_difference(before, after, 2.0) is Some(coverage) else {
    fail("expected a painted-coverage difference")
  }
  assert_eq(coverage.method_id, "symmetric_alpha_coverage_l1_over_union/v1")
  assert_eq(coverage.before_coverage_css_px2, 383.0 / 255.0 / 4.0)
  assert_eq(coverage.after_coverage_css_px2, 319.0 / 255.0 / 4.0)
  assert_eq(coverage.absolute_difference_css_px2, 64.0 / 255.0 / 4.0)
  assert_eq(coverage.union_coverage_css_px2, 383.0 / 255.0 / 4.0)
  assert_eq(coverage.fraction, 64.0 / 383.0)
  guard painted_coverage_difference(after, before, 2.0) is Some(reverse) else {
    fail("expected a reversed painted-coverage difference")
  }
  assert_eq(reverse.before_coverage_css_px2, coverage.after_coverage_css_px2)
  assert_eq(reverse.after_coverage_css_px2, coverage.before_coverage_css_px2)
  assert_eq(
    reverse.absolute_difference_css_px2,
    coverage.absolute_difference_css_px2,
  )
  assert_eq(reverse.union_coverage_css_px2, coverage.union_coverage_css_px2)
  assert_eq(reverse.fraction, coverage.fraction)
}

///|
test "painted coverage difference distinguishes equal empty and disjoint support" {
  let empty = @svg.Image::new(2, 1)
  let before = @svg.Image::new(2, 1)
  let after = @svg.Image::new(2, 1)
  before.set_pixel(0, 0, @svg.Color::rgb(255, 0, 0))
  after.set_pixel(1, 0, @svg.Color::rgb(0, 255, 0))
  guard painted_coverage_difference(empty, empty, 1.0) is Some(equal) else {
    fail("expected measured empty coverage equality")
  }
  assert_eq(equal.before_coverage_css_px2, 0.0)
  assert_eq(equal.after_coverage_css_px2, 0.0)
  assert_eq(equal.absolute_difference_css_px2, 0.0)
  assert_eq(equal.union_coverage_css_px2, 0.0)
  assert_eq(equal.fraction, 0.0)
  guard painted_coverage_difference(before, after, 1.0) is Some(disjoint) else {
    fail("expected disjoint coverage evidence")
  }
  assert_eq(disjoint.before_coverage_css_px2, 1.0)
  assert_eq(disjoint.after_coverage_css_px2, 1.0)
  assert_eq(disjoint.absolute_difference_css_px2, 2.0)
  assert_eq(disjoint.union_coverage_css_px2, 2.0)
  assert_eq(disjoint.fraction, 1.0)
  guard painted_coverage_difference(before, empty, 1.0) is Some(one_empty) else {
    fail("expected one-empty coverage evidence")
  }
  assert_eq(one_empty.fraction, 1.0)
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
