///|
test "tiny geometry changes retain continuous magnitude independent of pixels" {
  let before = "<svg width='16' height='16'><rect id='box' x='1.0' y='2' width='8' height='8'/></svg>"
  let after = "<svg width='16' height='16'><rect id='box' x='0.99999' y='2' width='8' height='8'/></svg>"
  let report = @structured_report.compare(
    before,
    after,
    @structured_report.ComparisonProfile::v1_default(),
  )
  let difference = report.atomic_differences[0]
  match difference.magnitude.parameter_abs_user_units {
    Some(value) => assert_true((value - 0.00001).abs() < 0.000000001)
    None => fail("expected exact parameter magnitude")
  }
  assert_true(difference.magnitude.geometry_viewport_fraction is Some(_))
  assert_eq(difference.domain_ordering.policy_id, "v1_domain_lexicographic")
}

///|
test "paint and presence expose domain appropriate numeric evidence" {
  let paint = @structured_report.compare(
    "<svg width='16' height='16'><rect id='box' x='2' y='2' width='8' height='8' fill='red'/></svg>",
    "<svg width='16' height='16'><rect id='box' x='2' y='2' width='8' height='8' fill='blue'/></svg>",
    @structured_report.ComparisonProfile::v1_default(),
  )
  match paint.atomic_differences[0].magnitude.raster_rgba8_rmse {
    Some(value) => assert_true(value > 0.0)
    None => fail("expected raster RMSE")
  }
  let presence = @structured_report.compare(
    "<svg width='16' height='16'></svg>",
    "<svg width='16' height='16'><rect id='box' x='2' y='2' width='8' height='8' opacity='0'/></svg>",
    @structured_report.ComparisonProfile::v1_default(),
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
  let report = @structured_report.compare(
    before,
    after,
    @structured_report.ComparisonProfile::v1_default(),
  )
  assert_eq(report.atomic_differences.length(), 2)
  assert_eq(report.atomic_differences[0].domain, "geometry.position")
  assert_eq(report.atomic_differences[1].domain, "geometry.position")
  assert_true(
    report.atomic_differences[0].domain_ordering.components[0] >
    report.atomic_differences[1].domain_ordering.components[0],
  )
}
