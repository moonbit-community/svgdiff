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
  assert_eq(report.schema_version, "1.46")
  assert_eq(report.atomic_differences.length(), 1)
  let impact : @svgdiff.ImpactAssessment = report.impact_assessment
  assert_eq(impact.policy_id, "event_rendered_pareto/v1")
  assert_eq(impact.status, "complete")
  assert_eq(impact.calibration_status, "not_calibrated")
  assert_eq(impact.candidate_event_count, 1)
  assert_eq(impact.frontier_relation, "unique")
  guard impact.frontier_groups is [group] else {
    fail("expected one public Impact frontier group")
  }
  let group : @svgdiff.ImpactFrontierGroup = group
  assert_eq(group.event_ids, [report.events[0].id])
  assert_eq(group.atomic_difference_ids, report.events[0].atomic_difference_ids)
  guard group.measurements is Some(measurements) else {
    fail("expected public Impact measurements")
  }
  let measurements : @svgdiff.ImpactMeasurement = measurements
  assert_true(measurements.changed_pixel_fraction > 0.0)
  assert_true(measurements.linear_premultiplied_rgba_rmse > 0.0)
  let witnesses : Array[@svgdiff.ImpactDominationWitness] = impact.domination_witnesses
  assert_true(witnesses.is_empty())
  match @json.parse(report.to_json_string()) {
    { "schema_version": "1.46", "events": [_], .. } => ()
    _ => fail("root report did not serialize through the stable seam")
  }
  match @json.parse(report.to_compact_json_string()) {
    { "schema_version": "1.46", "events": [_], .. } => ()
    _ => fail("root report did not expose compact serialization")
  }
}

///|
test "root comparison exposes exact parameter scales" {
  let report = @svgdiff.compare(
    "<svg width='16' height='16'><rect id='box' x='1' y='1' width='3' height='4' transform='scale(2 3)'/></svg>",
    "<svg width='16' height='16'><rect id='box' x='2' y='1' width='3' height='4' transform='scale(2 3)'/></svg>",
    @svgdiff.ComparisonProfile::v1_default(),
  )
  let magnitude = report.atomic_differences[0].magnitude
  assert_eq(magnitude.parameter_abs_user_units, Some(1.0))
  assert_eq(magnitude.parameter_abs_css_px, Some(2.0))
  assert_eq(magnitude.parameter_viewport_fraction, Some(0.08838834764831843))
  assert_eq(magnitude.parameter_entity_fraction, Some(0.14907119849998599))
  match magnitude.painted_boundary_displacement {
    Some(boundary) => {
      assert_eq(boundary.method_id, "symmetric_nearest_boundary_pixels/v1")
      assert_true(boundary.before_sample_count > 0)
      assert_true(boundary.after_sample_count > 0)
      assert_true(boundary.mean_css_px >= 0.0)
      assert_true(boundary.mean_css_px <= boundary.max_css_px)
      assert_true(boundary.p95_css_px >= 0.0)
      assert_true(boundary.p95_css_px <= boundary.max_css_px)
    }
    None => fail("expected painted-boundary displacement evidence")
  }
  match magnitude.painted_coverage_difference {
    Some(coverage) => {
      assert_eq(coverage.method_id, "symmetric_alpha_coverage_l1_over_union/v1")
      assert_true(coverage.before_coverage_css_px2 >= 0.0)
      assert_true(coverage.after_coverage_css_px2 >= 0.0)
      assert_true(
        coverage.absolute_difference_css_px2 <= coverage.union_coverage_css_px2,
      )
      assert_true(coverage.fraction >= 0.0 && coverage.fraction <= 1.0)
    }
    None => fail("expected painted-coverage evidence")
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
      { should_cancel: () => true, max_checkpoints: None },
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
    "svgdiff/residual-paint-normalizer@1+opacity-used-value-normalizer@1+length-unit-normalizer@1+shape-css-points-normalizer@1+stroke-length-normalizer@1+mask-edge-semantics-normalizer@1+isolated-group-compositor@1+static-mask-compositor@1+empty-filter-outcome-adapter@1+static-blend-compositor@1+Milky2018/svg@0.3.1",
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
    "svgdiff/residual-paint-normalizer@1+opacity-used-value-normalizer@1+length-unit-normalizer@1+shape-css-points-normalizer@1+stroke-length-normalizer@1+mask-edge-semantics-normalizer@1+isolated-group-compositor@1+static-mask-compositor@1+empty-filter-outcome-adapter@1+static-blend-compositor@1+Milky2018/svg@0.3.1",
  )
}

///|
test "explicit perceptual background is normalized and preserved independently" {
  guard @svgdiff.PerceptualBackground::parse_srgb("#336699") is Some(background) else {
    fail("expected an opaque deterministic sRGB background")
  }
  assert_eq(background.red(), 51)
  assert_eq(background.green(), 102)
  assert_eq(background.blue(), 153)
  assert_true(@svgdiff.PerceptualBackground::parse_srgb("transparent") is None)
  assert_true(@svgdiff.PerceptualBackground::parse_srgb("currentColor") is None)
  assert_true(@svgdiff.PerceptualBackground::parse_srgb("Canvas") is None)
  assert_true(
    @svgdiff.PerceptualBackground::parse_srgb("rgba(1,2,3,0.5)") is None,
  )
  assert_true(@svgdiff.PerceptualBackground::parse_srgb("invalid") is None)
  let before = "<svg width='16' height='16'><rect width='8' height='8' fill='red'/></svg>"
  let after = "<svg width='16' height='16'><rect width='8' height='8' fill='blue'/></svg>"
  let raw = @svgdiff.compare(
    before,
    after,
    @svgdiff.ComparisonProfile::v1_default(),
  )
  assert_true(raw.profile.perceptual_background is None)
  let with_background = @svgdiff.compare(before, after, {
    ..@svgdiff.ComparisonProfile::v1_default(),
    comparison_dpr: 2.0,
    perceptual_background: Some(background),
  })
  guard with_background.profile.perceptual_background is Some(recorded) else {
    fail("expected the explicit Perceptual Background in the report profile")
  }
  assert_eq(recorded.red(), 51)
  assert_eq(recorded.green(), 102)
  assert_eq(recorded.blue(), 153)
  assert_eq(with_background.profile.comparison_dpr, 1.0)
  let events : Array[@svgdiff.VisualEvent] = []
  for index, event in with_background.events {
    events.push({
      ..event,
      rendered_outcome: {
        ..event.rendered_outcome,
        perceptual_color: raw.events[index].rendered_outcome.perceptual_color,
      },
    })
  }
  let without_profile_background = {
    ..with_background,
    profile: { ..with_background.profile, perceptual_background: None },
    events,
  }
  assert_eq(
    without_profile_background.to_compact_json_string(),
    raw.to_compact_json_string(),
  )
}

///|
test "root package exposes event-local perceptual color evidence" {
  guard @svgdiff.PerceptualBackground::parse_srgb("white") is Some(background) else {
    fail("expected an opaque deterministic sRGB background")
  }
  let before = "<svg width='16' height='16'><rect width='8' height='8' fill='red'/></svg>"
  let after = "<svg width='16' height='16'><rect width='8' height='8' fill='blue'/></svg>"
  let report = @svgdiff.compare(before, after, {
    ..@svgdiff.ComparisonProfile::v1_default(),
    perceptual_background: Some(background),
  })
  assert_eq(
    report.events[0].rendered_outcome.perceptual_color.status,
    "computed",
  )
  guard report.events[0].rendered_outcome.perceptual_color.magnitude
    is Some(magnitude) else {
    fail("expected event-local perceptual color evidence")
  }
  assert_eq(magnitude.sample_count, 64)
  assert_true(magnitude.mean_delta_e_ok > 0.0)
  let without_background = @svgdiff.compare(
    before,
    after,
    @svgdiff.ComparisonProfile::v1_default(),
  )
  assert_eq(
    without_background.events[0].rendered_outcome.perceptual_color.reason_code,
    Some("perceptual_background_absent"),
  )
}

///|
test "root package exposes optional event-local LDR-FLIP maps" {
  assert_true(
    @svgdiff.FlipViewingConditions::from_pixels_per_degree(0.0) is None,
  )
  assert_true(
    @svgdiff.FlipViewingConditions::from_pixels_per_degree(4097.0) is None,
  )
  guard @svgdiff.FlipViewingConditions::from_pixels_per_degree(20.0)
    is Some(viewing) else {
    fail("expected supported FLIP Viewing Conditions")
  }
  assert_eq(viewing.pixels_per_degree(), 20.0)
  assert_true(@svgdiff.FlipErrorThreshold::from_value(-0.001) is None)
  guard @svgdiff.FlipErrorThreshold::from_value(0.05) is Some(threshold) else {
    fail("expected supported FLIP error threshold")
  }
  assert_eq(threshold.value(), 0.05)
  guard @svgdiff.PerceptualBackground::parse_srgb("white") is Some(background) else {
    fail("expected an opaque deterministic sRGB background")
  }
  let before = "<svg width='16' height='16'><rect id='box' x='8' y='8' width='1' height='1' fill='red'/></svg>"
  let after = before.replace(old="red", new="blue")
  let profile = {
    ..@svgdiff.ComparisonProfile::v1_default(),
    perceptual_background: Some(background),
  }
  let without_flip = @svgdiff.compare(before, after, profile)
  assert_eq(
    without_flip.events[0].rendered_outcome.perceptual_flip.reason_code,
    Some("flip_not_requested"),
  )
  let report = @svgdiff.compare(before, after, {
    ..profile,
    flip_viewing_conditions: Some(viewing),
    flip_error_threshold: Some(threshold),
  })
  guard report.profile.flip_viewing_conditions is Some(recorded) else {
    fail("expected FLIP Viewing Conditions in the report profile")
  }
  assert_eq(recorded.pixels_per_degree(), 20.0)
  guard report.events[0].rendered_outcome.perceptual_flip.map is Some(map) else {
    fail("expected event-local FLIP map")
  }
  assert_eq(map.method_id, "nvlabs_ldr_flip/v1.7-b475eb4b")
  assert_eq(map.pixel_x, 2)
  assert_eq(map.pixel_y, 2)
  assert_eq(map.pixel_width, 13)
  assert_eq(map.pixel_height, 13)
  assert_eq(map.encoding, "uint16_be_base64")
  assert_eq(map.quantization_step, 1.0 / 65535.0)
  assert_true(!map.values_base64.is_empty())
  guard report.events[0].rendered_outcome.perceptual_flip.statistics
    is Some(statistics) else {
    fail("expected event-local FLIP statistics")
  }
  assert_eq(statistics.canvas_pixel_count, 256)
  assert_eq(statistics.event_region_sample_count, 1)
  assert_eq(statistics.response_sample_count, 169)
  assert_true(statistics.canvas_mean > 0.0)
  assert_true(statistics.event_region_mean > 0.0)
  assert_true(statistics.response_maximum >= statistics.response_p95)
  guard statistics.area_above_threshold is Some(area) else {
    fail("expected explicit threshold-area statistics")
  }
  assert_eq(area.threshold, 0.05)
  assert_true(area.pixel_count > 0)
  assert_true(area.canvas_fraction > 0.0)
  let events : Array[@svgdiff.VisualEvent] = []
  for index, event in report.events {
    events.push({
      ..event,
      rendered_outcome: {
        ..event.rendered_outcome,
        perceptual_flip: without_flip.events[index].rendered_outcome.perceptual_flip,
      },
    })
  }
  let without_flip_profile = {
    ..report,
    profile: {
      ..report.profile,
      flip_viewing_conditions: None,
      flip_error_threshold: None,
    },
    canvas_outcome: {
      ..report.canvas_outcome,
      perceptual_flip: without_flip.canvas_outcome.perceptual_flip,
    },
    events,
  }
  assert_eq(
    without_flip_profile.to_compact_json_string(),
    without_flip.to_compact_json_string(),
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
    max_checkpoints: None,
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
    max_checkpoints: None,
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
test "zero checkpoint budget expires before comparison" {
  let (before, after) = controlled_comparison_sources()
  let should_cancel : () -> Bool = () => false
  let control : @svgdiff.ComparisonControl = {
    should_cancel,
    max_checkpoints: Some(0),
  }
  try
    @svgdiff.compare_with_control(
      before,
      after,
      @svgdiff.ComparisonProfile::v1_default(),
      control,
    )
  catch {
    CheckpointBudgetExceeded(max_checkpoints=0) => ()
    _ => fail("expected zero-budget expiry")
  } noraise {
    _ => fail("expired comparison returned a report")
  }
}

///|
test "checkpoint budget counts deterministic engine work" {
  let (before, after) = controlled_comparison_sources()
  let mut checkpoints = 0
  let should_cancel : () -> Bool = () => {
    checkpoints += 1
    false
  }
  try
    @svgdiff.compare_with_control(
      before,
      after,
      @svgdiff.ComparisonProfile::v1_default(),
      { should_cancel, max_checkpoints: Some(1) },
    )
  catch {
    CheckpointBudgetExceeded(max_checkpoints=1) => ()
    _ => fail("expected deterministic checkpoint-budget exhaustion")
  } noraise {
    _ => fail("checkpoint-budgeted comparison returned a report")
  }
  assert_eq(checkpoints, 2)
}

///|
test "cancellation precedes expiry at the same checkpoint" {
  let (before, after) = controlled_comparison_sources()
  let should_cancel : () -> Bool = () => true
  let control : @svgdiff.ComparisonControl = {
    should_cancel,
    max_checkpoints: Some(0),
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
    max_checkpoints: Some(10_000),
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
  assert_true(html.find("&lt;g&gt;&lt;svg") is None)
  assert_true(html.find("&quot;regions&quot;") is Some(_))
  assert_true(html.find("v2_domain_lexicographic") is None)
  assert_true(html.find("id=\"impact\"") is Some(_))
  assert_true(html.find("Changed area") is Some(_))
  assert_true(html.find("Linear RGBA error") is Some(_))
  assert_true(html.find("Perceptual difference") is Some(_))
  assert_true(html.find("data-difference-canvas") is Some(_))
  assert_true(
    html.find("RGB channel difference; black pixels are equal") is Some(_),
  )
  assert_true(html.find("before[index]===after[index]?0:255") is Some(_))
  assert_true(html.find("(value*100).toFixed(2)") is Some(_))
  assert_true(html.find("Not measured") is Some(_))
  assert_true(html.find("Visual Events") is Some(_))
  assert_true(html.find("Same effective value") is Some(_))
  assert_true(html.find("Different effective value") is Some(_))
  assert_true(html.find("Effective value unknown") is Some(_))
  assert_true(html.find("Reported values") is Some(_))
  assert_true(html.find("effective_relation") is Some(_))
  assert_true(html.find("Atomic relation") is None)
  assert_true(html.find("Magnitude") is Some(_))
  assert_true(html.find("Canvas Response") is Some(_))
  assert_true(html.find("Possible Causes & Limitations") is Some(_))
  assert_true(html.find("data-locate-event") is Some(_))
  assert_true(html.find("aria-pressed") is Some(_))
  assert_true(html.find("labelRegions") is None)
  assert_true(html.find("box.append(node('span','region-label'") is None)
  assert_true(html.find("innerHTML") is None)
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

///|
test "HTML report presents partial analysis without serialized impact internals" {
  let base = @svgdiff.compare(
    "<svg width='16' height='16'><rect width='8' height='8' fill='red'/></svg>",
    "<svg width='16' height='16'><rect width='8' height='8' fill='blue'/></svg>",
    @svgdiff.ComparisonProfile::v1_default(),
  )
  let report = {
    ..base,
    analysis_status: "partial",
    impact_assessment: {
      ..base.impact_assessment,
      status: "partial",
      frontier_relation: "incomparable",
      frontier_groups: [
        {
          event_ids: ["event-a"],
          atomic_difference_ids: [base.atomic_differences[0].id],
          measurements: Some({
            changed_pixel_fraction: 0.25,
            linear_premultiplied_rgba_rmse: 0.5,
          }),
        },
        {
          event_ids: ["event-b"],
          atomic_difference_ids: [],
          measurements: None,
        },
      ],
    },
  }
  let html = @svgdiff.render_html_report("<svg/>", "<svg/>", report)
  assert_true(
    html.find("&quot;analysis_status&quot;: &quot;partial&quot;") is Some(_),
  )
  assert_true(html.find("&quot;frontier_relation&quot;") is None)
  assert_true(html.find("universal severity ranking") is Some(_))
  assert_true(
    html.find("empty evidence inventories do not establish equality") is Some(_),
  )
}
