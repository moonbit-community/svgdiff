// Blackbox tests run against the package's public API. Use `@svgdiff` to import.
// Prefer high-level behaviors over implementation details.
// Run `moon test` to execute and `moon test --update` to refresh snapshots.

///|
test "root package exposes the stable comparison seam" {
  let before = "<svg width='16' height='16'><rect x='2' y='2' width='8' height='8' fill='red'/></svg>"
  let after = "<svg width='16' height='16'><rect x='2' y='2' width='8' height='8' fill='blue'/></svg>"
  let report = @svgdiff.compare(
    before,
    after,
    @svgdiff.ComparisonProfile::v1_default(),
  )
  assert_eq(report.schema_version, "1.33")
  assert_eq(report.atomic_differences.length(), 1)
  match @json.parse(report.to_json_string()) {
    { "schema_version": "1.33", "events": [_], .. } => ()
    _ => fail("root report did not serialize through the stable seam")
  }
  match @json.parse(report.to_compact_json_string()) {
    { "schema_version": "1.33", "events": [_], .. } => ()
    _ => fail("root report did not expose compact serialization")
  }
}

///|
test "root package keeps nonvisual source audit separate" {
  let before = "<svg data-build='a'><title>Before</title><rect width='8' height='8'/></svg>"
  let after = "<svg data-build='b'><title>After</title><rect width='8' height='8'/></svg>"
  let comparison = @svgdiff.compare(
    before,
    after,
    @svgdiff.ComparisonProfile::v1_default(),
  )
  assert_eq(comparison.analysis_status, "complete")
  assert_true(comparison.atomic_differences.is_empty())
  assert_true(!comparison.to_compact_json_string().contains("source-audit"))
  let audit : @svgdiff.SourceAuditReport = @svgdiff.audit_nonvisual_metadata(
    before, after,
  )
  assert_eq(audit.audit_schema_version, "1.0")
  assert_eq(audit.analysis_status, "complete")
  assert_eq(audit.differences.length(), 2)
  match @json.parse(audit.to_json_string()) {
    {
      "audit_schema_version": "1.0",
      "analysis_status": "complete",
      "differences": [_, _],
      ..
    } => ()
    _ => fail("source-only audit did not serialize through the root seam")
  }
}

///|
test "root package exposes typed transform magnitudes" {
  let translation : @svgdiff.TransformTranslationMagnitude = {
    before_x_css_px: 0.0,
    before_y_css_px: 0.0,
    after_x_css_px: 2.0,
    after_y_css_px: 0.0,
    delta_x_css_px: 2.0,
    delta_y_css_px: 0.0,
    norm_css_px: 2.0,
  }
  let effect : @svgdiff.TransformEffectMagnitude = TranslationEffect(
    translation,
  )
  match effect {
    TranslationEffect(value) => assert_eq(value.norm_css_px, 2.0)
    _ => fail("root transform effect constructor changed")
  }
}

///|
test "root package exposes explicit resource bundles without implicit loading" {
  let source = "<svg xmlns='http://www.w3.org/2000/svg'><image href='asset.png'/></svg>"
  let empty = @svgdiff.ResourceBundle::empty()
  let report = @svgdiff.compare_with_resources(
    source,
    source,
    @svgdiff.ComparisonProfile::v1_default(),
    empty,
    empty,
  )
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "resource_bundle_entry_missing" &&
      !diagnostic.source_locations.is_empty()
    }),
  )
  let entry : @svgdiff.ResourceBundleEntry = {
    locator: "asset.png",
    media_type: "image/png",
    bytes: Bytes::default(),
  }
  let invalid = @svgdiff.compare_with_resources(
    source,
    source,
    @svgdiff.ComparisonProfile::v1_default(),
    { entries: [entry] },
    empty,
  )
  assert_true(
    invalid.diagnostics.any(diagnostic => {
      diagnostic.code == "embedded_raster_data_invalid"
    }),
  )
}

///|
test "root controlled resource API preserves typed cancellation" {
  let source = "<svg xmlns='http://www.w3.org/2000/svg'><image href='asset.png'/></svg>"
  try
    @svgdiff.compare_with_control_and_resources(
      source,
      source,
      @svgdiff.ComparisonProfile::v1_default(),
      @svgdiff.ResourceBundle::empty(),
      @svgdiff.ResourceBundle::empty(),
      { should_cancel: () => true, max_elapsed_milliseconds: None },
    )
  catch {
    Cancelled => ()
    _ => fail("expected cancellation")
  } noraise {
    _ => fail("cancelled resource comparison returned a report")
  }
}

///|
test "v1 profile records canonical rendering conditions" {
  let report = @svgdiff.compare(
    "<svg width='16' height='16'><rect width='8' height='8' fill='red' opacity='0.5'/></svg>",
    "<svg width='16' height='16'><rect width='8' height='8' fill='blue' opacity='0.5'/></svg>",
    @svgdiff.ComparisonProfile::v1_default(),
  )
  assert_eq(report.profile.comparison_dpr, 1.0)
  assert_eq(report.profile.color_interpretation, "srgb")
  assert_eq(
    report.profile.raster_representation,
    "linear_srgb_premultiplied_rgba_f64",
  )
  assert_eq(
    report.profile.renderer_id,
    "svgdiff/style-precedence-normalizer@3+ordinary-inheritance-normalizer@1+css-computed-value-normalizer@3+css-color3-opacity-normalizer@1+length-used-value-normalizer@1+stroke-used-geometry-normalizer@1+basic-shape-used-geometry-normalizer@1+isolated-group-compositor@1+static-mask-normalizer@1+static-mask-compositor@1+static-filter-graph-compositor@1+static-blend-compositor@1+mizchi/svg@0.2.1",
  )
  match report.events[0].rendered_outcome.magnitude {
    Some(magnitude) =>
      assert_true(magnitude.linear_premultiplied_rgba_rmse > 0.0)
    None => fail("expected canonical rendered magnitude")
  }
}

///|
test "comparison normalizes fixed v1 rendering conditions" {
  let requested = {
    ..@svgdiff.ComparisonProfile::v1_default(),
    comparison_dpr: 2.0,
    color_interpretation: "display-p3",
    raster_representation: "invented",
    renderer_id: "another-renderer",
  }
  let report = @svgdiff.compare(
    "<svg width='16' height='16'/>", "<svg width='16' height='16'/>", requested,
  )
  assert_eq(report.profile.comparison_dpr, 1.0)
  assert_eq(report.profile.color_interpretation, "srgb")
  assert_eq(
    report.profile.renderer_id,
    "svgdiff/style-precedence-normalizer@3+ordinary-inheritance-normalizer@1+css-computed-value-normalizer@3+css-color3-opacity-normalizer@1+length-used-value-normalizer@1+stroke-used-geometry-normalizer@1+basic-shape-used-geometry-normalizer@1+isolated-group-compositor@1+static-mask-normalizer@1+static-mask-compositor@1+static-filter-graph-compositor@1+static-blend-compositor@1+mizchi/svg@0.2.1",
  )
}

///|
fn controlled_comparison_sources() -> (String, String) {
  (
    "<svg width='32' height='32'><rect x='2' y='2' width='8' height='8' fill='red'/><rect x='18' y='18' width='8' height='8' fill='red'/></svg>",
    "<svg width='32' height='32'><rect x='2' y='2' width='8' height='8' fill='blue'/><rect x='18' y='18' width='8' height='8' fill='blue'/></svg>",
  )
}

///|
test "controlled comparison cancels immediately without a report" {
  let (before, after) = controlled_comparison_sources()
  let should_cancel : () -> Bool = () => true
  let control : @svgdiff.ComparisonControl = {
    should_cancel,
    max_elapsed_milliseconds: None,
  }
  try
    @svgdiff.compare_with_control(
      before,
      after,
      @svgdiff.ComparisonProfile::v1_default(),
      control,
    )
  catch {
    Cancelled => ()
    _ => fail("expected cancellation")
  } noraise {
    _ => fail("cancelled comparison returned a report")
  }
}

///|
test "controlled comparison observes cancellation at a later checkpoint" {
  let (before, after) = controlled_comparison_sources()
  let mut checkpoints = 0
  let should_cancel : () -> Bool = () => {
    checkpoints += 1
    checkpoints >= 24
  }
  let control : @svgdiff.ComparisonControl = {
    should_cancel,
    max_elapsed_milliseconds: None,
  }
  try
    @svgdiff.compare_with_control(
      before,
      after,
      @svgdiff.ComparisonProfile::v1_default(),
      control,
    )
  catch {
    Cancelled => ()
    _ => fail("expected later cancellation")
  } noraise {
    _ => fail("later cancellation returned a report")
  }
  assert_eq(checkpoints, 24)
}

///|
test "zero elapsed-time budget expires before comparison" {
  let (before, after) = controlled_comparison_sources()
  let should_cancel : () -> Bool = () => false
  let control : @svgdiff.ComparisonControl = {
    should_cancel,
    max_elapsed_milliseconds: Some(0),
  }
  try
    @svgdiff.compare_with_control(
      before,
      after,
      @svgdiff.ComparisonProfile::v1_default(),
      control,
    )
  catch {
    TimeBudgetExceeded(max_elapsed_milliseconds=0) => ()
    _ => fail("expected zero-budget expiry")
  } noraise {
    _ => fail("expired comparison returned a report")
  }
}

///|
test "cancellation precedes expiry at the same checkpoint" {
  let (before, after) = controlled_comparison_sources()
  let should_cancel : () -> Bool = () => true
  let control : @svgdiff.ComparisonControl = {
    should_cancel,
    max_elapsed_milliseconds: Some(0),
  }
  try
    @svgdiff.compare_with_control(
      before,
      after,
      @svgdiff.ComparisonProfile::v1_default(),
      control,
    )
  catch {
    Cancelled => ()
    _ => fail("expected cancellation to win")
  } noraise {
    _ => fail("cancelled and expired comparison returned a report")
  }
}

///|
test "sufficiently budgeted comparison is byte-identical" {
  let (before, after) = controlled_comparison_sources()
  let profile = @svgdiff.ComparisonProfile::v1_default()
  let expected = @svgdiff.compare(before, after, profile)
  let unlimited = @svgdiff.compare_with_control(
    before,
    after,
    profile,
    @svgdiff.ComparisonControl::unlimited(),
  )
  let should_cancel : () -> Bool = () => false
  let actual = @svgdiff.compare_with_control(before, after, profile, {
    should_cancel,
    max_elapsed_milliseconds: Some(10_000),
  })
  assert_eq(unlimited.to_json_string(), expected.to_json_string())
  assert_eq(
    unlimited.to_compact_json_string(),
    expected.to_compact_json_string(),
  )
  assert_eq(actual.to_json_string(), expected.to_json_string())
  assert_eq(actual.to_compact_json_string(), expected.to_compact_json_string())
}

///|
test "HTML report is self contained and binds report regions" {
  let before = "<svg width='16' height='16'><rect x='2' y='2' width='8' height='8' fill='red'/><script>alert('unsafe')</script></svg>"
  let after = "<svg width='16' height='16'><rect x='2' y='2' width='8' height='8' fill='blue'/></svg>"
  let report = @svgdiff.compare(
    before,
    after,
    @svgdiff.ComparisonProfile::v1_default(),
  )
  let html = @svgdiff.render_html_report(before, after, report)
  assert_true(html.find("<!doctype html>") is Some(_))
  assert_true(html.find("sandbox=\"\"") is Some(_))
  assert_true(html.find("default-src &#39;none&#39;") is Some(_))
  assert_true(html.find("difference_regions") is Some(_))
  assert_true(html.find("v2_domain_lexicographic") is Some(_))
  assert_true(html.find("<script>alert('unsafe')</script>") is None)
  assert_true(html.find("<details class=\"json-panel\">") is Some(_))
}

///|
test "HTML report escapes textarea termination in source evidence" {
  let source = "<svg width='16' height='16'><rect data-note='</textarea><script>bad()</script>'/></svg>"
  let report = @svgdiff.compare(
    source,
    source,
    @svgdiff.ComparisonProfile::v1_default(),
  )
  let html = @svgdiff.render_html_report(source, source, report)
  assert_true(html.find("</textarea><script>bad()") is None)
  assert_true(html.find("&lt;/textarea&gt;") is Some(_))
}
