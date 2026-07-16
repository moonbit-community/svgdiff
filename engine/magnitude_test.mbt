///|
test "tiny geometry changes retain continuous magnitude independent of pixels" {
  let before = "<svg width='16' height='16'><rect id='box' x='1.0' y='2' width='8' height='8'/></svg>"
  let after = "<svg width='16' height='16'><rect id='box' x='0.99999' y='2' width='8' height='8'/></svg>"
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  let difference = report.atomic_differences[0]
  match difference.magnitude.parameter_abs_user_units {
    Some(value) => assert_true((value - 0.00001).abs() < 0.000000001)
    None => fail("expected exact parameter magnitude")
  }
  assert_true(difference.magnitude.parameter_viewport_fraction is Some(_))
  assert_true(difference.magnitude.geometry_viewport_fraction is None)
  assert_eq(difference.domain_ordering.policy_id, "v2_domain_lexicographic")
}

///|
test "scalar geometry exposes local CSS viewport and entity parameter scales" {
  let report = @engine.compare(
    "<svg width='16' height='16'><rect id='box' x='1' y='1' width='3' height='4' transform='scale(2 3)'/></svg>",
    "<svg width='16' height='16'><rect id='box' x='2' y='1' width='3' height='4' transform='scale(2 3)'/></svg>",
    @engine.ComparisonProfile::v1_default(),
  )
  let difference = report.atomic_differences[0]
  assert_eq(difference.domain, "geometry.position")
  assert_eq(difference.magnitude.parameter_abs_user_units, Some(1.0))
  assert_eq(difference.magnitude.parameter_abs_css_px, Some(2.0))
  assert_eq(
    difference.magnitude.parameter_viewport_fraction,
    Some(0.08838834764831843),
  )
  assert_eq(
    difference.magnitude.parameter_entity_fraction,
    Some(0.14907119849998599),
  )
}

///|
test "zero-size geometry retains CSS scale without inventing an entity fraction" {
  let report = @engine.compare(
    "<svg width='16' height='16'><rect id='box' x='1' y='1' width='0' height='0'/></svg>",
    "<svg width='16' height='16'><rect id='box' x='2' y='1' width='0' height='0'/></svg>",
    @engine.ComparisonProfile::v1_default(),
  )
  let difference = report.atomic_differences[0]
  assert_eq(difference.magnitude.parameter_abs_user_units, Some(1.0))
  assert_eq(difference.magnitude.parameter_abs_css_px, Some(1.0))
  assert_eq(
    difference.magnitude.parameter_viewport_fraction,
    Some(0.044194173824159216),
  )
  assert_true(difference.magnitude.parameter_entity_fraction is None)
}

///|
test "non-spatial scalar parameters do not invent spatial scales" {
  let report = @engine.compare(
    "<svg width='16' height='16'><rect id='box' width='4' height='4' opacity='0.5'/></svg>",
    "<svg width='16' height='16'><rect id='box' width='4' height='4' opacity='0.75'/></svg>",
    @engine.ComparisonProfile::v1_default(),
  )
  let difference = report.atomic_differences[0]
  assert_true(
    (difference.magnitude.parameter_abs_user_units.unwrap() - 0.25).abs() <
    0.000000000000001,
  )
  assert_true(difference.magnitude.parameter_abs_css_px is None)
  assert_true(difference.magnitude.parameter_viewport_fraction is None)
  assert_true(difference.magnitude.parameter_entity_fraction is None)
}

///|
test "incomplete coordinate transforms keep spatial parameter scales unavailable" {
  let report = @engine.compare(
    "<svg width='16' height='16'><rect id='box' x='1' width='4' height='4' transform='translate(1,)'/></svg>",
    "<svg width='16' height='16'><rect id='box' x='2' width='4' height='4' transform='translate(1,)'/></svg>",
    @engine.ComparisonProfile::v1_default(),
  )
  let position = report.atomic_differences.filter(difference => {
      difference.domain == "geometry.position"
    })[0]
  assert_eq(position.magnitude.parameter_abs_user_units, Some(1.0))
  assert_true(position.magnitude.parameter_abs_css_px is None)
  assert_true(position.magnitude.parameter_viewport_fraction is None)
  assert_true(position.magnitude.parameter_entity_fraction is None)
}

///|
test "different coordinate mappings keep contextual parameter scales unavailable" {
  let report = @engine.compare(
    "<svg width='16' height='16'><rect id='box' x='1' width='4' height='4' transform='scale(2)'/></svg>",
    "<svg width='16' height='16'><rect id='box' x='2' width='4' height='4' transform='matrix(0 2 -2 0 0 0)'/></svg>",
    @engine.ComparisonProfile::v1_default(),
  )
  let position = report.atomic_differences.filter(difference => {
      difference.domain == "geometry.position"
    })[0]
  assert_eq(position.magnitude.parameter_abs_user_units, Some(1.0))
  assert_true(position.magnitude.parameter_abs_css_px is None)
  assert_true(position.magnitude.parameter_viewport_fraction is None)
  assert_true(position.magnitude.parameter_entity_fraction is None)
}

///|
test "paint and presence expose domain appropriate numeric evidence" {
  let paint = @engine.compare(
    "<svg width='16' height='16'><rect id='box' x='2' y='2' width='8' height='8' fill='red'/></svg>",
    "<svg width='16' height='16'><rect id='box' x='2' y='2' width='8' height='8' fill='blue'/></svg>",
    @engine.ComparisonProfile::v1_default(),
  )
  match paint.atomic_differences[0].magnitude.raster_rgba8_rmse {
    Some(value) => assert_true(value > 0.0)
    None => fail("expected raster RMSE")
  }
  let presence = @engine.compare(
    "<svg width='16' height='16'></svg>",
    "<svg width='16' height='16'><rect id='box' x='2' y='2' width='8' height='8' opacity='0'/></svg>",
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(
    presence.atomic_differences[0].magnitude.presence_painted_viewport_fraction,
    Some(0.0),
  )
}

///|
test "same-domain differences are ordered by descending magnitude" {
  let before = "<svg width='20' height='20'><rect x='1' y='1' width='2' height='2'/><rect x='10' y='10' width='2' height='2'/></svg>"
  let after = "<svg width='20' height='20'><rect x='2' y='1' width='2' height='2'/><rect x='16' y='10' width='2' height='2'/></svg>"
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.atomic_differences.length(), 2)
  assert_eq(report.atomic_differences[0].domain, "geometry.position")
  assert_eq(report.atomic_differences[1].domain, "geometry.position")
  assert_true(
    report.atomic_differences[0].domain_ordering.components[0] >
    report.atomic_differences[1].domain_ordering.components[0],
  )
}

///|
test "equal same-domain tuples use stable report-local IDs" {
  let before = "<svg width='20' height='20'><rect id='z' x='1' y='1' width='2' height='2'/><rect id='a' x='10' y='10' width='2' height='2'/></svg>"
  let after = "<svg width='20' height='20'><rect id='z' x='2' y='1' width='2' height='2'/><rect id='a' x='11' y='10' width='2' height='2'/></svg>"
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.atomic_differences.length(), 2)
  assert_eq(
    report.atomic_differences[0].domain_ordering.components,
    report.atomic_differences[1].domain_ordering.components,
  )
  assert_true(
    report.atomic_differences[0].id.compare(report.atomic_differences[1].id) < 0,
  )
}

///|
test "generic shape insertion and deletion expose numeric presence magnitude" {
  let base = "<svg width='16' height='16'><rect id='anchor' x='0' y='0' width='1' height='1'/></svg>"
  let with_circle = "<svg width='16' height='16'><rect id='anchor' x='0' y='0' width='1' height='1'/><circle id='dot' cx='8' cy='8' r='2' fill='red'/></svg>"
  for
    report in [
      @engine.compare(
        base,
        with_circle,
        @engine.ComparisonProfile::v1_default(),
      ),
      @engine.compare(
        with_circle,
        base,
        @engine.ComparisonProfile::v1_default(),
      ),
    ] {
    let presence_differences = [
      for difference in report.atomic_differences if difference.domain.find(
        "presence.",
      ) ==
      Some(0) => difference
    ]
    assert_eq(presence_differences.length(), 1)
    match presence_differences[0].presence_magnitude {
      Some(presence) => {
        assert_eq(presence.affected_entity_count, 1)
        assert_eq(presence.bounds_area_css_px2, 16.0)
        assert_true(presence.painted_area_css_px2 > 0.0)
        assert_true(presence.painted_viewport_fraction > 0.0)
      }
      None => fail("expected generic numeric presence magnitude")
    }
  }
}

///|
test "presence painted coverage remains nonzero when final pixels are equal" {
  let one = "<svg width='16' height='16'><rect x='2' y='2' width='4' height='4' fill='red'/></svg>"
  let duplicate = "<svg width='16' height='16'><rect x='2' y='2' width='4' height='4' fill='red'/><rect x='2' y='2' width='4' height='4' fill='red'/></svg>"
  let report = @engine.compare(
    one,
    duplicate,
    @engine.ComparisonProfile::v1_default(),
  )
  let presence = [
      for difference in report.atomic_differences if difference.domain ==
      "presence.insertion" => difference
    ][0]
  match presence.presence_magnitude {
    Some(magnitude) => assert_eq(magnitude.painted_area_css_px2, 16.0)
    None => fail("expected presence coverage")
  }
  assert_eq(presence.magnitude.raster_changed_pixel_fraction, Some(0.0))
}

///|
test "transparent presence does not inherit underlying scene coverage" {
  let base = "<svg width='16' height='16'><rect x='2' y='2' width='4' height='4' fill='red'/></svg>"
  let with_transparent = "<svg width='16' height='16'><rect x='2' y='2' width='4' height='4' fill='red'/><rect x='2' y='2' width='4' height='4' fill='blue' opacity='0'/></svg>"
  let report = @engine.compare(
    base,
    with_transparent,
    @engine.ComparisonProfile::v1_default(),
  )
  let presence = [
      for difference in report.atomic_differences if difference.domain ==
      "presence.insertion" => difference
    ][0]
  match presence.presence_magnitude {
    Some(magnitude) => assert_eq(magnitude.painted_area_css_px2, 0.0)
    None => fail("expected isolated presence coverage")
  }
}
