///|
fn flip_test_background() -> PerceptualBackground {
  match PerceptualBackground::parse_srgb("white") {
    Some(background) => background
    None => abort("expected white Perceptual Background")
  }
}

///|
fn flip_test_viewing(pixels_per_degree : Double) -> FlipViewingConditions {
  match FlipViewingConditions::from_pixels_per_degree(pixels_per_degree) {
    Some(viewing) => viewing
    None => abort("expected supported FLIP Viewing Conditions")
  }
}

///|
fn flip_test_profile() -> ComparisonProfile {
  {
    ..ComparisonProfile::v1_default(),
    perceptual_background: Some(flip_test_background()),
    flip_viewing_conditions: Some(flip_test_viewing(20.0)),
  }
}

///|
test "FLIP Viewing Conditions preserve only the supported explicit range" {
  for invalid in [0.0, 0.999, 4096.001, @double.infinity, @double.not_a_number] {
    assert_true(FlipViewingConditions::from_pixels_per_degree(invalid) is None)
  }
  guard FlipViewingConditions::from_pixels_per_degree(67.0) is Some(viewing) else {
    fail("expected ordinary viewing conditions")
  }
  assert_eq(viewing.pixels_per_degree(), 67.0)
  assert_true(ComparisonProfile::v1_default().flip_viewing_conditions is None)
}

///|
test "event-local FLIP emits bounded deterministic uint16 map evidence" {
  let before = "<svg width='16' height='16'><rect id='box' x='8' y='8' width='1' height='1' fill='red'/></svg>"
  let after = before.replace(old="red", new="blue")
  let report = compare(before, after, flip_test_profile())
  guard report.events is [event] else { fail("expected one event") }
  assert_eq(event.rendered_outcome.magnitude.unwrap().changed_pixels, 1)
  assert_eq(event.rendered_outcome.perceptual_flip.status, "computed")
  assert_eq(event.rendered_outcome.perceptual_flip.reason_code, None)
  guard event.rendered_outcome.perceptual_flip.map is Some(map) else {
    fail("expected FLIP map")
  }
  assert_eq(map.method_id, "nvlabs_ldr_flip/v1.7-b475eb4b")
  assert_eq(map.pixel_x, 2)
  assert_eq(map.pixel_y, 2)
  assert_eq(map.pixel_width, 13)
  assert_eq(map.pixel_height, 13)
  assert_eq(map.encoding, "uint16_be_base64")
  assert_eq(map.quantization_step, 1.0 / 65535.0)
  let bytes = @base64.decode(map.values_base64[:])
  assert_eq(bytes.length(), 13 * 13 * 2)
  let mut has_nonzero_byte = false
  for byte in bytes {
    if byte != b'\x00' {
      has_nonzero_byte = true
    }
  }
  assert_true(has_nonzero_byte)
  let repeated = compare(before, after, flip_test_profile())
  assert_eq(
    repeated.events[0].rendered_outcome.perceptual_flip.to_json(),
    event.rendered_outcome.perceptual_flip.to_json(),
  )
}

///|
test "event-local FLIP keeps distinct availability and zero states" {
  let red = "<svg width='16' height='16'><rect id='box' x='2' y='2' width='8' height='8' fill='red'/></svg>"
  let blue = red.replace(old="red", new="blue")
  let not_requested = compare(red, blue, {
    ..ComparisonProfile::v1_default(),
    perceptual_background: Some(flip_test_background()),
  })
  assert_eq(
    not_requested.events[0].rendered_outcome.perceptual_flip.reason_code,
    Some("flip_not_requested"),
  )
  let no_background = compare(red, blue, {
    ..ComparisonProfile::v1_default(),
    flip_viewing_conditions: Some(flip_test_viewing(20.0)),
  })
  assert_eq(
    no_background.events[0].rendered_outcome.perceptual_flip.reason_code,
    Some("perceptual_background_absent"),
  )
  let equivalent = compare(
    red,
    red.replace(old="red", new="#ff0000"),
    flip_test_profile(),
  )
  guard equivalent.events[0].rendered_outcome.perceptual_flip.map is Some(zero) else {
    fail("expected explicit zero FLIP map")
  }
  assert_eq(zero.pixel_width, 0)
  assert_eq(zero.pixel_height, 0)
  assert_eq(zero.values_base64, "")

  let unsupported = compare(
    "<svg width='16' height='16'><image id='photo' width='8' height='8' href='data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg=='/></svg>",
    "<svg width='16' height='16'><image id='photo' width='8' height='8' href='data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYPj/HwADAgH/5ncLrgAAAABJRU5ErkJggg=='/></svg>",
    flip_test_profile(),
  )
  assert_true(
    unsupported.events.any(event => {
      event.rendered_outcome.perceptual_flip.reason_code ==
      Some("rendered_evidence_unavailable")
    }),
  )
}

///|
test "event-local FLIP isolates separate event response bounds" {
  let before = "<svg width='32' height='16'><rect id='left' x='2' y='6' width='1' height='1' fill='red'/><rect id='right' x='28' y='6' width='1' height='1' fill='red'/></svg>"
  let after = before.replace_all(old="red", new="blue")
  let report = compare(before, after, {
    ..flip_test_profile(),
    viewport_width: 32,
  })
  let maps : Array[PerceptualFlipMap] = []
  for event in report.events {
    match event.rendered_outcome.perceptual_flip.map {
      Some(map) => maps.push(map)
      None => ()
    }
  }
  assert_eq(maps.length(), 2)
  maps.sort_by((left, right) => left.pixel_x.compare(right.pixel_x))
  assert_true(maps[0].pixel_x + maps[0].pixel_width < maps[1].pixel_x)
}

///|
test "event-local FLIP budget exhaustion does not alter other evidence" {
  let before = "<svg width='16' height='16'><rect id='box' x='2' y='2' width='8' height='8' fill='red'/></svg>"
  let after = before.replace(old="red", new="blue")
  let ordinary = compare(before, after, flip_test_profile())
  let limited = compare_with_resource_limits(
    before,
    after,
    flip_test_profile(),
    { ..default_resource_limits(), max_perceptual_map_pixels: 1 },
  )
  assert_eq(
    limited.events[0].rendered_outcome.perceptual_flip.reason_code,
    Some("perceptual_map_budget_exceeded"),
  )
  assert_eq(
    limited.events[0].rendered_outcome.magnitude.to_json(),
    ordinary.events[0].rendered_outcome.magnitude.to_json(),
  )
  assert_eq(
    limited.events[0].rendered_outcome.perceptual_color.to_json(),
    ordinary.events[0].rendered_outcome.perceptual_color.to_json(),
  )
  assert_eq(
    limited.events[0].difference_regions.to_json(),
    ordinary.events[0].difference_regions.to_json(),
  )
  assert_eq(limited.analysis_status, ordinary.analysis_status)
  assert_eq(limited.diagnostics.to_json(), ordinary.diagnostics.to_json())
}
