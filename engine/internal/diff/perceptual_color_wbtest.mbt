///|
fn parsed_background(source : String) -> PerceptualBackground {
  match PerceptualBackground::parse_srgb(source) {
    Some(background) => background
    None => abort("expected an opaque sRGB background")
  }
}

///|
fn assert_close(actual : Double, expected : Double) -> Unit raise {
  assert_true((actual - expected).abs() < 0.00000001)
}

///|
test "DeltaEOK composites both colors over the same linear sRGB background" {
  let white = parsed_background("white")
  let black = @svg.Color::rgba(0, 0, 0, 255)
  let opaque_white = @svg.Color::rgba(255, 255, 255, 255)
  let transparent_red = @svg.Color::rgba(255, 0, 0, 0)
  let transparent_blue = @svg.Color::rgba(0, 0, 255, 0)
  assert_close(delta_e_ok_after_background(black, opaque_white, white), 1.0)
  assert_close(
    delta_e_ok_after_background(transparent_red, transparent_blue, white),
    0.0,
  )
  assert_close(
    delta_e_ok_after_background(transparent_red, opaque_white, white),
    0.0,
  )
  let forward = delta_e_ok_after_background(
    @svg.Color::rgba(0, 0, 0, 128),
    opaque_white,
    white,
  )
  let reverse = delta_e_ok_after_background(
    opaque_white,
    @svg.Color::rgba(0, 0, 0, 128),
    white,
  )
  assert_true(forward > 0.0 && forward < 1.0)
  assert_close(forward, reverse)
}

///|
test "event-local DeltaEOK distinguishes computed zero and unavailable states" {
  let red = "<svg width='16' height='16'><rect id='box' x='2' y='2' width='8' height='8' fill='red'/></svg>"
  let blue = "<svg width='16' height='16'><rect id='box' x='2' y='2' width='8' height='8' fill='blue'/></svg>"
  let background = parsed_background("white")
  let profile = {
    ..ComparisonProfile::v1_default(),
    perceptual_background: Some(background),
  }
  let changed = compare(red, blue, profile)
  guard changed.events is [event] else { fail("expected one event") }
  assert_eq(event.rendered_outcome.perceptual_color.status, "computed")
  assert_eq(event.rendered_outcome.perceptual_color.reason_code, None)
  guard event.rendered_outcome.perceptual_color.magnitude is Some(magnitude) else {
    fail("expected event-local DeltaEOK")
  }
  assert_eq(
    magnitude.method_id,
    "delta_e_ok_changed_pixels_after_linear_srgb_background/v1",
  )
  assert_eq(magnitude.sample_count, 64)
  assert_true(magnitude.mean_delta_e_ok > 0.0)

  let reversed = compare(blue, red, profile)
  guard reversed.events[0].rendered_outcome.perceptual_color.magnitude
    is Some(reversed_magnitude) else {
    fail("expected reversed event-local DeltaEOK")
  }
  assert_close(magnitude.mean_delta_e_ok, reversed_magnitude.mean_delta_e_ok)

  let equivalent = compare(red, red.replace(old="red", new="#ff0000"), profile)
  guard equivalent.events[0].rendered_outcome.perceptual_color.magnitude
    is Some(zero) else {
    fail("expected computed zero DeltaEOK")
  }
  assert_eq(zero.sample_count, 0)
  assert_eq(zero.mean_delta_e_ok, 0.0)

  let no_background = compare(red, blue, ComparisonProfile::v1_default())
  assert_eq(
    no_background.events[0].rendered_outcome.perceptual_color.status,
    "not_computed",
  )
  assert_eq(
    no_background.events[0].rendered_outcome.perceptual_color.reason_code,
    Some("perceptual_background_absent"),
  )

  let unsupported = compare(
    "<svg width='16' height='16'><image id='photo' width='8' height='8' href='data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg=='/></svg>",
    "<svg width='16' height='16'><image id='photo' width='8' height='8' href='data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYPj/HwADAgH/5ncLrgAAAABJRU5ErkJggg=='/></svg>",
    profile,
  )
  assert_true(
    unsupported.events.any(event => {
      event.rendered_outcome.perceptual_color.status == "not_computed" &&
      event.rendered_outcome.perceptual_color.reason_code ==
      Some("rendered_evidence_unavailable")
    }),
  )
}
