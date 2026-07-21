///|
test "one isolated render pair supplies cached boundary and coverage observations" {
  let before = extract_source_subjects_or_raise(
    "<svg width='16' height='16'><rect id='box' x='1' y='1' width='1' height='1'/></svg>",
  )
  let after = extract_source_subjects_or_raise(
    "<svg width='16' height='16'><rect id='box' x='3' y='1' width='1' height='1'/></svg>",
  )
  let cache = IsolatedPaintMeasurementCache::new()
  guard cache.measure(
      "alignment:box",
      before,
      after,
      ComparisonProfile::v1_default(),
    )
    is Some(first) else {
    fail("expected isolated paint measurements")
  }
  assert_eq(
    first.boundary_displacement.map(value => value.max_css_px),
    Some(2.0),
  )
  assert_eq(first.coverage_difference.fraction, 1.0)
  assert_eq(cache.comparisons, 1)
  guard cache.measure(
      "alignment:box",
      before,
      after,
      ComparisonProfile::v1_default(),
    )
    is Some(second) else {
    fail("expected cached isolated paint measurements")
  }
  // TODO: use assert_eq when public magnitude records expose Debug.
  assert_true(second.boundary_displacement == first.boundary_displacement)
  assert_true(second.coverage_difference == first.coverage_difference)
  assert_eq(cache.comparisons, 1)
  assert_eq(cache.entries.length(), 1)
}

///|
test "isolated paint budget exhaustion remains explicit absence" {
  let before = extract_source_subjects_or_raise(
    "<svg width='16' height='16'><rect id='box' x='1' y='1' width='4' height='4'/></svg>",
  )
  let after = extract_source_subjects_or_raise(
    "<svg width='16' height='16'><rect id='box' x='2' y='1' width='4' height='4'/></svg>",
  )
  let cache : IsolatedPaintMeasurementCache = {
    comparisons: 64,
    raster_pixels: 0,
    entries: [],
  }
  assert_true(
    cache.measure(
      "alignment:box",
      before,
      after,
      ComparisonProfile::v1_default(),
    )
    is None,
  )
  assert_eq(cache.comparisons, 64)
  assert_eq(cache.entries.length(), 1)
  assert_true(
    cache.measure(
      "alignment:box",
      before,
      after,
      ComparisonProfile::v1_default(),
    )
    is None,
  )
  assert_eq(cache.entries.length(), 1)
}
