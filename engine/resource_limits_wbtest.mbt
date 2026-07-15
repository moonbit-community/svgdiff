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
fn has_reference_failure(
  report : StructuredReport,
  code : String,
  subject_id : String,
) -> Bool {
  report.analysis_status == "failed" &&
  report.diagnostics.any(diagnostic => {
    diagnostic.code == code && diagnostic.subject_id == subject_id
  })
}

///|
test "production resource limits match the versioned contract" {
  let limits = default_resource_limits()
  assert_eq(limits.max_input_bytes, 8_388_608)
  assert_eq(limits.max_elements, 100_000)
  assert_eq(limits.max_path_data_units, 1_000_000)
  assert_eq(limits.max_nesting_depth, 256)
  assert_eq(limits.max_references, 100_000)
  assert_eq(limits.max_reference_graph_edges, 1_000_000)
  assert_eq(limits.max_expanded_elements, 1_000_000)
  assert_eq(limits.max_raster_dimension, 8_192)
  assert_eq(limits.max_raster_pixels, 16_777_216)
  assert_eq(limits.max_regions, 65_536)
  assert_eq(limits.max_report_bytes, 33_554_432)
}

///|
test "local reference tokens preserve case and decode href fragments" {
  assert_eq(local_href_target("#a%20b"), Some("a b"))
  assert_eq(local_href_target("other.svg#a"), None)
  let targets : Array[String] = []
  for
    locator in resource_url_locators(
      "fill:URL( '#Gradient' );clip-path:url(#a%20b)",
    ) {
    match locator.target_id {
      Some(target) => targets.push(target)
      None => ()
    }
  }
  assert_eq(targets, ["Gradient", "a b"])
}

///|
test "self and multi-node use cycles fail with source locations" {
  let self_cycle = "<svg><defs><symbol id='a'><use href='#a'/></symbol></defs></svg>"
  let report = compare_with_resource_limits(
    self_cycle,
    self_cycle,
    ComparisonProfile::v1_default(),
    default_resource_limits(),
  )
  assert_true(
    has_reference_failure(
      report, "reference_cycle_detected", "reference_cycle.before",
    ),
  )
  assert_eq(report.diagnostics.length(), 2)
  assert_eq(report.diagnostics[0].source_locations.length(), 1)
  assert_eq(report.diagnostics[0].source_locations[0].source_role, "before")
  assert_true(report.atomic_differences.is_empty())
  assert_true(report.events.is_empty())
  let multi_cycle = "<svg><defs><symbol id='a'><use href='#b'/></symbol><symbol id='b'><use href='#a'/></symbol></defs></svg>"
  let multi_report = compare_with_resource_limits(
    multi_cycle,
    "<svg></svg>",
    ComparisonProfile::v1_default(),
    default_resource_limits(),
  )
  assert_true(
    has_reference_failure(
      multi_report, "reference_cycle_detected", "reference_cycle.before",
    ),
  )
  assert_eq(multi_report.diagnostics[0].source_locations.length(), 2)
}

///|
test "resource cycles and conservative duplicate scopes are detected" {
  let resource_cycle = "<svg><defs><linearGradient id='a' href='#b'/><linearGradient id='b' href='#a'/></defs></svg>"
  let resource_report = compare_with_resource_limits(
    resource_cycle,
    "<svg></svg>",
    ComparisonProfile::v1_default(),
    default_resource_limits(),
  )
  assert_true(
    has_reference_failure(
      resource_report, "reference_cycle_detected", "reference_cycle.before",
    ),
  )
  let duplicate_scope = "<svg><defs><symbol id='outer'><g id='inner'><use href='#outer'/></g></symbol></defs></svg>"
  let duplicate_report = compare_with_resource_limits(
    duplicate_scope,
    "<svg></svg>",
    ComparisonProfile::v1_default(),
    default_resource_limits(),
  )
  assert_true(
    has_reference_failure(
      duplicate_report, "reference_cycle_detected", "reference_cycle.before",
    ),
  )
  let duplicate_ids = "<svg><defs><rect id='a'/><linearGradient id='a' href='#b'/><linearGradient id='b' href='#a'/></defs></svg>"
  let duplicate_id_report = compare_with_resource_limits(
    duplicate_ids,
    "<svg></svg>",
    ComparisonProfile::v1_default(),
    default_resource_limits(),
  )
  assert_true(
    has_reference_failure(
      duplicate_id_report, "reference_cycle_detected", "reference_cycle.before",
    ),
  )
}

///|
test "missing external and non-resource targets do not fabricate cycles" {
  let source = "<svg><defs><symbol id='a'><use href='#missing'/><use href='other.svg#a'/></symbol></defs><rect id='box' fill='url(#box)'/></svg>"
  let graph = build_resource_dependency_graph(
    source,
    default_resource_limits().max_reference_graph_edges,
  )
  assert_true(reference_cycle_diagnostic(graph, "before") is None)
  assert_true(
    reference_expansion_diagnostic(graph, "before", 1_000_000) is None,
  )
}

///|
test "repeated acyclic use expansion accepts exact budget and rejects one less" {
  let source = "<svg><defs><symbol id='leaf'><rect/></symbol><symbol id='branch'><use href='#leaf'/><use href='#leaf'/></symbol></defs><use href='#branch'/></svg>"
  let graph = build_resource_dependency_graph(
    source,
    default_resource_limits().max_reference_graph_edges,
  )
  assert_true(reference_cycle_diagnostic(graph, "before") is None)
  assert_true(reference_expansion_diagnostic(graph, "before", 19) is None)
  let diagnostic = reference_expansion_diagnostic(graph, "before", 18)
  assert_true(diagnostic is Some(_))
  guard diagnostic is Some(diagnostic) else { fail("expected Diagnostic") }
  assert_eq(diagnostic.code, "reference_expansion_limit_exceeded")
  assert_eq(diagnostic.subject_id, "reference_expansion.before")
  assert_eq(diagnostic.source_locations.length(), 1)
  let report = compare_with_resource_limits(
    source,
    "<svg></svg>",
    ComparisonProfile::v1_default(),
    { ..default_resource_limits(), max_expanded_elements: 18 },
  )
  assert_true(
    has_reference_failure(
      report, "reference_expansion_limit_exceeded", "reference_expansion.before",
    ),
  )
  assert_true(report.atomic_differences.is_empty())
}

///|
test "propagated reference graph edges reject one-past before allocation" {
  let source = "<svg id='outer'><g id='inner'><use href='#target'/></g><g id='target'/></svg>"
  let exact = build_resource_dependency_graph(source, 2)
  assert_eq(exact.edge_instances, 2)
  assert_true(exact.edge_limit_span is None)
  let exceeded = compare_with_resource_limits(
    source,
    "<svg></svg>",
    ComparisonProfile::v1_default(),
    { ..default_resource_limits(), max_reference_graph_edges: 1 },
  )
  assert_true(has_resource_limit(exceeded, "reference_graph_edges.before"))
  assert_eq(exceeded.diagnostics[0].source_locations.length(), 1)
  assert_true(exceeded.atomic_differences.is_empty())
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
