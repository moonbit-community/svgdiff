// Copyright 2026 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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
  guard difference.magnitude.painted_boundary_displacement is Some(boundary) else {
    fail("expected a measured painted-boundary distribution")
  }
  assert_true(boundary.before_sample_count > 0)
  assert_eq(boundary.before_sample_count, boundary.after_sample_count)
  assert_true(boundary.mean_css_px >= 0.0)
  assert_true(boundary.mean_css_px <= boundary.max_css_px)
  assert_true(boundary.p95_css_px >= 0.0)
  assert_true(boundary.p95_css_px <= boundary.max_css_px)
  assert_eq(difference.domain_ordering.policy_id, "v2_domain_lexicographic")
}

///|
test "basic geometry exposes a painted-boundary distribution" {
  let report = @engine.compare(
    "<svg width='16' height='16'><rect id='box' x='1' y='1' width='1' height='1'/></svg>",
    "<svg width='16' height='16'><rect id='box' x='3' y='1' width='1' height='1'/></svg>",
    @engine.ComparisonProfile::v1_default(),
  )
  let difference = report.atomic_differences.filter(difference => {
      difference.domain == "geometry.position"
    })[0]
  guard difference.magnitude.painted_boundary_displacement is Some(boundary) else {
    fail("expected a painted-boundary distribution")
  }
  assert_eq(boundary.before_sample_count, 1)
  assert_eq(boundary.after_sample_count, 1)
  assert_eq(boundary.mean_css_px, 2.0)
  assert_eq(boundary.p95_css_px, 2.0)
  assert_eq(boundary.max_css_px, 2.0)
  guard difference.magnitude.painted_coverage_difference is Some(coverage) else {
    fail("expected a painted-coverage difference")
  }
  assert_eq(coverage.method_id, "symmetric_alpha_coverage_l1_over_union/v1")
  assert_eq(coverage.before_coverage_css_px2, 1.0)
  assert_eq(coverage.after_coverage_css_px2, 1.0)
  assert_eq(coverage.absolute_difference_css_px2, 2.0)
  assert_eq(coverage.union_coverage_css_px2, 2.0)
  assert_eq(coverage.fraction, 1.0)
  assert_true(difference.evidence_layers.contains("rendered_evidence"))
}

///|
test "one aligned boundary observation is shared by related geometry differences" {
  let report = @engine.compare(
    "<svg width='16' height='16'><rect id='box' x='1' y='1' width='2' height='2'/></svg>",
    "<svg width='16' height='16'><rect id='box' x='2' y='1' width='3' height='2'/></svg>",
    @engine.ComparisonProfile::v1_default(),
  )
  let geometry = report.atomic_differences.filter(difference => {
    difference.domain == "geometry.position" ||
    difference.domain == "geometry.size"
  })
  assert_eq(geometry.length(), 2)
  guard (
      geometry[0].magnitude.painted_boundary_displacement,
      geometry[1].magnitude.painted_boundary_displacement,
    )
    is (Some(first), Some(second)) else {
    fail("expected shared painted-boundary observations")
  }
  assert_eq(first.before_sample_count, second.before_sample_count)
  assert_eq(first.after_sample_count, second.after_sample_count)
  assert_eq(first.mean_css_px, second.mean_css_px)
  assert_eq(first.p95_css_px, second.p95_css_px)
  assert_eq(first.max_css_px, second.max_css_px)
  guard (
      geometry[0].magnitude.painted_coverage_difference,
      geometry[1].magnitude.painted_coverage_difference,
    )
    is (Some(first_coverage), Some(second_coverage)) else {
    fail("expected shared painted-coverage observations")
  }
  assert_eq(
    first_coverage.before_coverage_css_px2,
    second_coverage.before_coverage_css_px2,
  )
  assert_eq(
    first_coverage.after_coverage_css_px2,
    second_coverage.after_coverage_css_px2,
  )
  assert_eq(first_coverage.fraction, second_coverage.fraction)
}

///|
test "resource-backed paint keeps isolated boundary distribution unavailable" {
  let report = @engine.compare(
    "<svg width='16' height='16'><defs><linearGradient id='g'><stop offset='0' stop-color='red'/><stop offset='1' stop-color='blue'/></linearGradient></defs><rect id='box' x='1' y='1' width='4' height='4' fill='url(#g)'/></svg>",
    "<svg width='16' height='16'><defs><linearGradient id='g'><stop offset='0' stop-color='red'/><stop offset='1' stop-color='blue'/></linearGradient></defs><rect id='box' x='2' y='1' width='4' height='4' fill='url(#g)'/></svg>",
    @engine.ComparisonProfile::v1_default(),
  )
  let position = report.atomic_differences.filter(difference => {
      difference.domain == "geometry.position"
    })[0]
  assert_true(position.magnitude.painted_boundary_displacement is None)
  assert_true(position.magnitude.painted_coverage_difference is None)
}

///|
test "solid color changes retain measured zero painted-coverage difference" {
  let report = @engine.compare(
    "<svg width='16' height='16'><rect id='box' x='1' y='1' width='4' height='4' fill='red'/></svg>",
    "<svg width='16' height='16'><rect id='box' x='1' y='1' width='4' height='4' fill='blue'/></svg>",
    @engine.ComparisonProfile::v1_default(),
  )
  let difference = report.atomic_differences[0]
  assert_eq(difference.domain, "paint.fill")
  guard difference.magnitude.painted_coverage_difference is Some(coverage) else {
    fail("expected alpha-only coverage evidence")
  }
  assert_eq(coverage.before_coverage_css_px2, 16.0)
  assert_eq(coverage.after_coverage_css_px2, 16.0)
  assert_eq(coverage.absolute_difference_css_px2, 0.0)
  assert_eq(coverage.union_coverage_css_px2, 16.0)
  assert_eq(coverage.fraction, 0.0)
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
    "<svg width='16' height='16'><rect id='box' x='0' width='4' height='4' transform='translate(1,)'/></svg>",
    @engine.ComparisonProfile::v1_default(),
  )
  let position = report.atomic_differences.filter(difference => {
      difference.domain == "geometry.position"
    })[0]
  assert_eq(position.magnitude.parameter_abs_user_units, Some(1.0))
  assert_eq(position.magnitude.parameter_signed_user_units, Some(-1.0))
  assert_true(position.magnitude.parameter_abs_css_px is None)
  assert_true(position.magnitude.parameter_viewport_fraction is None)
  assert_true(position.magnitude.parameter_entity_fraction is None)
  guard @json.parse(report.to_compact_json_string()) is Object(root) &&
    root["difference_groups"] is Array(groups) else {
    fail("compact report must contain difference groups")
  }
  let mut found = false
  for group in groups {
    guard group is Object(group) && group["items"] is Array(items) else {
      continue
    }
    for item in items {
      guard item is Object(item) &&
        item["id"] is String(id) &&
        id == position.id else {
        continue
      }
      guard item["magnitude"] is Object(magnitude) else {
        fail("position difference must retain its available magnitudes")
      }
      assert_false(magnitude.contains("parameter_abs_css_px"))
      found = true
    }
  }
  assert_true(found)
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
  assert_true(
    paint.atomic_differences[0].magnitude.painted_boundary_displacement is None,
  )
  let presence = @engine.compare(
    "<svg width='16' height='16'></svg>",
    "<svg width='16' height='16'><rect id='box' x='2' y='2' width='8' height='8' opacity='0'/></svg>",
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(
    presence.atomic_differences[0].magnitude.presence_painted_viewport_fraction,
    Some(0.0),
  )
  assert_true(
    presence.atomic_differences[0].magnitude.painted_boundary_displacement
    is None,
  )
  assert_true(
    presence.atomic_differences[0].magnitude.painted_coverage_difference is None,
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
