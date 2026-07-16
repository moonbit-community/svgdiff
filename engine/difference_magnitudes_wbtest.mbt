///|
test "painted boundary budget exhaustion remains explicit absence" {
  let before = extract_source_subjects_or_raise(
    "<svg width='16' height='16'><rect id='box' x='1' y='1' width='4' height='4'/></svg>",
  )
  let after = extract_source_subjects_or_raise(
    "<svg width='16' height='16'><rect id='box' x='2' y='1' width='4' height='4'/></svg>",
  )
  let cache : PaintedBoundaryMeasurementCache = {
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
