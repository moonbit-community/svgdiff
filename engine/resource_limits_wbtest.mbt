///|
fn has_resource_limit(report : StructuredReport, subject_id : String) -> Bool {
  report.analysis_status == "failed" &&
  report.diagnostics.any(diagnostic => {
    diagnostic.code == "resource_limit_exceeded" &&
    diagnostic.subject_id == subject_id
  })
}

///|
fn assert_not_resource_failure(report : StructuredReport) -> Unit raise {
  assert_true(
    !report.diagnostics.any(diagnostic => {
      diagnostic.code == "resource_limit_exceeded"
    }),
  )
}

///|
test "production resource limits match the versioned contract" {
  let limits = default_resource_limits()
  assert_eq(limits.max_input_bytes, 8_388_608)
  assert_eq(limits.max_elements, 100_000)
  assert_eq(limits.max_path_data_units, 1_000_000)
  assert_eq(limits.max_nesting_depth, 256)
  assert_eq(limits.max_references, 100_000)
  assert_eq(limits.max_raster_dimension, 8_192)
  assert_eq(limits.max_raster_pixels, 16_777_216)
  assert_eq(limits.max_regions, 65_536)
  assert_eq(limits.max_report_bytes, 33_554_432)
}

///|
test "input byte limit uses UTF-8 bytes at the exact boundary" {
  let source = "<svg><!--中😀--></svg>"
  assert_eq(utf8_byte_length("中😀"), 7)
  let exact = utf8_byte_length(source)
  let limits = { ..default_resource_limits(), max_input_bytes: exact }
  assert_not_resource_failure(
    compare_with_resource_limits(
      source,
      source,
      ComparisonProfile::v1_default(),
      limits,
    ),
  )
  let report = compare_with_resource_limits(
    source,
    source + " ",
    ComparisonProfile::v1_default(),
    limits,
  )
  assert_true(has_resource_limit(report, "input_bytes.after"))
  assert_true(report.atomic_differences.is_empty())
  let both = compare_with_resource_limits(
    source + " ",
    source + " ",
    ComparisonProfile::v1_default(),
    limits,
  )
  assert_eq(both.diagnostics.length(), 2)
  assert_eq(both.coverage_matrix.map(row => row.feature_id), [
    "resource.input_bytes.after", "resource.input_bytes.before",
  ])
}

///|
test "element count limit rejects the first extra element" {
  let exact = "<svg><rect/></svg>"
  let exceeded = "<svg><rect/><circle/></svg>"
  let limits = { ..default_resource_limits(), max_elements: 2 }
  assert_not_resource_failure(
    compare_with_resource_limits(
      exact,
      exact,
      ComparisonProfile::v1_default(),
      limits,
    ),
  )
  let report = compare_with_resource_limits(
    exact,
    exceeded,
    ComparisonProfile::v1_default(),
    limits,
  )
  assert_true(has_resource_limit(report, "elements.after"))
  assert_eq(report.diagnostics[0].source_locations.length(), 1)
}

///|
test "nesting depth limit rejects the first extra level" {
  let exact = "<svg><g></g></svg>"
  let exceeded = "<svg><g><g></g></g></svg>"
  let limits = { ..default_resource_limits(), max_nesting_depth: 2 }
  assert_not_resource_failure(
    compare_with_resource_limits(
      exact,
      exact,
      ComparisonProfile::v1_default(),
      limits,
    ),
  )
  let report = compare_with_resource_limits(
    exact,
    exceeded,
    ComparisonProfile::v1_default(),
    limits,
  )
  assert_true(has_resource_limit(report, "nesting_depth.after"))
  assert_eq(report.diagnostics[0].source_locations.length(), 1)
}

///|
test "path data limit uses non-separator lexical units" {
  let exact = "<svg><path d='M0'/></svg>"
  let exceeded = "<svg><path d='M00'/></svg>"
  assert_eq(path_data_units("M 0,0\nL1"), 5)
  let limits = { ..default_resource_limits(), max_path_data_units: 2 }
  assert_not_resource_failure(
    compare_with_resource_limits(
      exact,
      exact,
      ComparisonProfile::v1_default(),
      limits,
    ),
  )
  let report = compare_with_resource_limits(
    exact,
    exceeded,
    ComparisonProfile::v1_default(),
    limits,
  )
  assert_true(has_resource_limit(report, "path_data_units.after"))
  assert_eq(report.diagnostics[0].source_locations.length(), 1)
}

///|
test "reference limit counts href and every CSS url token" {
  let exact = "<svg><rect href='#a' fill='url(#a)'/></svg>"
  let exceeded = "<svg><rect href='#a' fill='url(#a)' stroke='URL(#b)'/></svg>"
  let limits = { ..default_resource_limits(), max_references: 2 }
  assert_not_resource_failure(
    compare_with_resource_limits(
      exact,
      exact,
      ComparisonProfile::v1_default(),
      limits,
    ),
  )
  let report = compare_with_resource_limits(
    exact,
    exceeded,
    ComparisonProfile::v1_default(),
    limits,
  )
  assert_true(has_resource_limit(report, "references.after"))
  assert_eq(report.diagnostics[0].source_locations.length(), 1)
}

///|
test "raster limits reject excess dimension and pixel area before rendering" {
  let source = "<svg></svg>"
  let exact_profile = {
    ..ComparisonProfile::v1_default(),
    viewport_width: 16,
    viewport_height: 16,
  }
  let exact_limits = {
    ..default_resource_limits(),
    max_raster_dimension: 16,
    max_raster_pixels: 256,
  }
  assert_not_resource_failure(
    compare_with_resource_limits(source, source, exact_profile, exact_limits),
  )
  let wide_profile = { ..exact_profile, viewport_width: 17 }
  assert_true(
    has_resource_limit(
      compare_with_resource_limits(source, source, wide_profile, exact_limits),
      "raster_dimensions",
    ),
  )
  let area_limits = { ..exact_limits, max_raster_dimension: 17 }
  assert_true(
    has_resource_limit(
      compare_with_resource_limits(source, source, wide_profile, area_limits),
      "raster_dimensions",
    ),
  )
}

///|
test "region limit rejects a report instead of truncating its inventory" {
  let before = "<svg width='16' height='16'><rect id='box' x='2' y='2' width='8' height='8' fill='red'/></svg>"
  let after = before.replace_all(old="red", new="blue")
  let exact_limits = { ..default_resource_limits(), max_regions: 1 }
  let exact = compare_with_resource_limits(
    before,
    after,
    ComparisonProfile::v1_default(),
    exact_limits,
  )
  assert_not_resource_failure(exact)
  assert_eq(total_region_count(exact), 1)
  let report = compare_with_resource_limits(
    before,
    after,
    ComparisonProfile::v1_default(),
    { ..exact_limits, max_regions: 0 },
  )
  assert_true(has_resource_limit(report, "regions"))
  assert_true(report.atomic_differences.is_empty())
  assert_true(report.events.is_empty())
}

///|
test "report byte limit covers both built-in JSON serializations" {
  let source = "<svg width='16' height='16'></svg>"
  let baseline = compare_with_resource_limits(
    source,
    source,
    ComparisonProfile::v1_default(),
    default_resource_limits(),
  )
  let exact_bytes = serialized_report_bytes(baseline)
  assert_not_resource_failure(
    compare_with_resource_limits(
      source,
      source,
      ComparisonProfile::v1_default(),
      { ..default_resource_limits(), max_report_bytes: exact_bytes },
    ),
  )
  let report = compare_with_resource_limits(
    source,
    source,
    ComparisonProfile::v1_default(),
    { ..default_resource_limits(), max_report_bytes: exact_bytes - 1 },
  )
  assert_true(has_resource_limit(report, "report_bytes"))
  assert_true(
    serialized_report_bytes(report) < default_resource_limits().max_report_bytes,
  )
}
