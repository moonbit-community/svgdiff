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
  assert_eq(report.schema_version, "1.2")
  assert_eq(report.atomic_differences.length(), 1)
  match @json.parse(report.to_json_string()) {
    { "schema_version": "1.2", "events": [_], .. } => ()
    _ => fail("root report did not serialize through the stable seam")
  }
  match @json.parse(report.to_compact_json_string()) {
    { "schema_version": "1.2", "events": [_], .. } => ()
    _ => fail("root report did not expose compact serialization")
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
  assert_eq(report.profile.renderer_id, "mizchi/svg@0.2.1")
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
  assert_eq(report.profile.renderer_id, "mizchi/svg@0.2.1")
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
  assert_true(html.find("v1_domain_lexicographic") is Some(_))
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
