///|
fn color_rect(fill : String, extra : String) -> String {
  "<svg width='16' height='16'><rect id='box' x='2' y='2' width='8' height='8' fill='\{fill}' \{extra}/></svg>"
}

///|
test "solid color spellings resolve to one visual value" {
  for
    equivalent in [
      "#f00", "#ff0000", "rgb(255,0,0)", "rgb(100%,0%,0%)", "rgba(255,0,0,1)", "hsl(0,100%,50%)",
      "hsla(360,100%,50%,100%)",
    ] {
    let report = @engine.compare(
      color_rect("red", ""),
      color_rect(equivalent, ""),
      @engine.ComparisonProfile::v1_default(),
    )
    assert_eq(report.analysis_status, "complete")
    assert_eq(report.atomic_differences.length(), 1)
    assert_eq(
      report.atomic_differences[0].computed_relation.status,
      "equivalent",
    )
    assert_eq(report.atomic_differences[0].source_before, "red")
    assert_eq(report.atomic_differences[0].source_after, equivalent)
    assert_eq(
      report.atomic_differences[0].source_fact_after.unwrap().authored_value,
      equivalent,
    )
    assert_true(
      report.atomic_differences[0].source_fact_after.unwrap().source_span.end_offset >
      report.atomic_differences[0].source_fact_after.unwrap().source_span.start_offset,
    )
    assert_eq(
      report.events[0].rendered_outcome.magnitude.unwrap().changed_pixels,
      0,
    )
  }
  let transparent = @engine.compare(
    color_rect("transparent", ""),
    color_rect("rgba(0,0,0,0)", ""),
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(
    transparent.atomic_differences[0].computed_relation.status,
    "equivalent",
  )
}

///|
test "effective fill alpha multiplies while opacity deltas stay numeric" {
  let report = @engine.compare(
    color_rect("rgba(255,0,0,0.5)", "fill-opacity='0.5' opacity='0.5'"),
    color_rect("rgba(255,0,0,0.25)", "fill-opacity='1' opacity='0.5'"),
    @engine.ComparisonProfile::v1_default(),
  )
  let fill = [
    for difference in report.atomic_differences if difference.domain ==
    "paint.fill" => difference
  ]
  let fill_opacity = [
    for difference in report.atomic_differences if difference.domain ==
    "paint.fill_opacity" => difference
  ]
  assert_eq(fill.length(), 1)
  assert_eq(fill[0].computed_relation.status, "equivalent")
  assert_eq(fill_opacity.length(), 1)
  assert_eq(fill_opacity[0].parameter_delta_css_px, None)
  assert_eq(fill_opacity[0].magnitude.parameter_signed_user_units, Some(0.5))
  assert_eq(
    report.events[0].rendered_outcome.magnitude.unwrap().changed_pixels,
    0,
  )
}

///|
test "opacity values clamp and inherited paint opacity resolves" {
  let clamped = @engine.compare(
    color_rect("red", "opacity='-1' fill-opacity='200%'"),
    color_rect("red", "opacity='0' fill-opacity='1'"),
    @engine.ComparisonProfile::v1_default(),
  )
  assert_true(
    clamped.atomic_differences.all(difference => {
      difference.computed_relation.status == "equivalent"
    }),
  )
  let inherited = @engine.compare(
    "<svg width='16' height='16'><g fill-opacity='25%' stroke-opacity='75%'><rect id='box' x='2' y='2' width='8' height='8' fill='red' stroke='blue'/></g></svg>",
    "<svg width='16' height='16'><rect id='box' x='2' y='2' width='8' height='8' fill='red' fill-opacity='0.25' stroke='blue' stroke-opacity='0.75'/></svg>",
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(inherited.analysis_status, "partial")
  assert_true(
    inherited.atomic_differences.all(difference => {
      difference.computed_relation.status == "equivalent"
    }),
  )
  assert_eq(
    inherited.events[0].rendered_outcome.magnitude.unwrap().changed_pixels,
    0,
  )
}

///|
test "gradient stop color and opacity retain separate numeric evidence" {
  let before = "<svg width='16' height='16'><defs><linearGradient id='gradient'><stop offset='0' stop-color='rgba(255,0,0,0.5)' stop-opacity='0.5'/><stop offset='1' stop-color='black'/></linearGradient></defs><rect id='box' width='8' height='8' fill='url(#gradient)'/></svg>"
  let after = "<svg width='16' height='16'><defs><linearGradient id='gradient'><stop offset='0' stop-color='rgba(255,0,0,0.25)' stop-opacity='1'/><stop offset='1' stop-color='black'/></linearGradient></defs><rect id='box' width='8' height='8' fill='url(#gradient)'/></svg>"
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  let stop_opacity = [
    for difference in report.atomic_differences if difference.domain ==
    "resource.gradient.stop.stop_opacity" => difference
  ]
  let entity = [
    for difference in report.atomic_differences if difference.domain ==
    "paint.fill" => difference
  ]
  assert_eq(stop_opacity.length(), 1)
  assert_eq(stop_opacity[0].parameter_delta_css_px, None)
  assert_eq(stop_opacity[0].magnitude.parameter_signed_user_units, Some(0.5))
  assert_eq(entity.length(), 1)
  assert_eq(entity[0].computed_relation.status, "equivalent")
}

///|
test "unsupported color classes have precise located diagnostics" {
  for
    entry in [
      ("ButtonFace", "system_color_environment_unsupported"),
      ("color(display-p3 1 0 0)", "color_profile_unsupported"),
      ("rgb(1,2)", "solid_color_syntax_unsupported"),
    ] {
    let (value, code) = entry
    let report = @engine.compare(
      color_rect("red", ""),
      color_rect(value, ""),
      @engine.ComparisonProfile::v1_default(),
    )
    let diagnostics : Array[@engine.Diagnostic] = []
    for diagnostic in report.diagnostics {
      if diagnostic.code == code {
        diagnostics.push(diagnostic)
      }
    }
    assert_eq(diagnostics.length(), 1)
    assert_false(diagnostics[0].source_locations.is_empty())
    assert_eq(report.analysis_status, "partial")
  }
  let invalid_opacity = @engine.compare(
    color_rect("red", "opacity='1'"),
    color_rect("red", "opacity='wat'"),
    @engine.ComparisonProfile::v1_default(),
  )
  let opacity_diagnostics : Array[@engine.Diagnostic] = []
  for diagnostic in invalid_opacity.diagnostics {
    if diagnostic.code == "opacity_syntax_unsupported" {
      opacity_diagnostics.push(diagnostic)
    }
  }
  assert_eq(opacity_diagnostics.length(), 1)
  assert_false(opacity_diagnostics[0].source_locations.is_empty())
}
