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
fn gradient_report(before : String, after : String) -> StructuredReport {
  compare(before, after, ComparisonProfile::v1_default())
}

///|
fn gradient_diff_domains(report : StructuredReport) -> Array[String] {
  report.atomic_differences.map(difference => difference.domain)
}

///|
test "gradient report separates geometry spread transform and every stop component" {
  let before = "<svg><defs><linearGradient id='g' x2='50%' spreadMethod='pad' gradientTransform='translate(1)'><stop offset='0' stop-color='red' stop-opacity='1'/><stop offset='50%' stop-color='green' stop-opacity='.5'/><stop offset='1' stop-color='blue'/></linearGradient></defs><rect id='box' width='8' height='8' fill='url(#g)'/></svg>"
  let after = "<svg><defs><linearGradient id='g' x2='75%' spreadMethod='reflect' gradientTransform='translate(2)'><stop offset='.1' stop-color='yellow' stop-opacity='.75'/><stop offset='60%' stop-color='lime' stop-opacity='.25'/><stop offset='.9' stop-color='navy'/></linearGradient></defs><rect id='box' width='8' height='8' fill='url(#g)'/></svg>"
  let report = gradient_report(before, after)
  let domains = gradient_diff_domains(report)
  assert_true(domains.contains("resource.gradient.geometry.x2"))
  assert_true(domains.contains("resource.gradient.spread_method"))
  assert_true(domains.contains("resource.gradient.transform.list"))
  assert_true(domains.contains("resource.gradient.transform.effective_matrix"))
  assert_eq(
    domains.filter(domain => domain == "resource.gradient.stop.offset").length(),
    3,
  )
  assert_eq(
    domains
    .filter(domain => domain == "resource.gradient.stop.stop_color")
    .length(),
    3,
  )
  assert_eq(
    domains
    .filter(domain => domain == "resource.gradient.stop.stop_opacity")
    .length(),
    2,
  )
  assert_true(
    report.atomic_differences.any(difference => {
      difference.domain == "paint.fill" &&
      difference.computed_relation.status == "different"
    }),
  )
}

///|
test "template and direct gradient spellings remain source-visible but computed-equivalent" {
  let before = "<svg><defs><linearGradient id='base' x2='75%' spreadMethod='repeat'><stop offset='0' stop-color='red'/><stop offset='1' stop-color='blue'/></linearGradient><linearGradient id='g' href='#base'/></defs><rect id='box' width='8' height='8' fill='url(#g)'/></svg>"
  let after = "<svg><defs><linearGradient id='base' x2='75%' spreadMethod='repeat'><stop offset='0' stop-color='red'/><stop offset='1' stop-color='blue'/></linearGradient><linearGradient id='g' x2='75%' spreadMethod='repeat'><stop offset='0' stop-color='red'/><stop offset='1' stop-color='blue'/></linearGradient></defs><rect id='box' width='8' height='8' fill='url(#g)'/></svg>"
  let report = gradient_report(before, after)
  assert_true(
    report.atomic_differences.any(difference => {
      difference.domain == "resource.gradient.template" &&
      difference.computed_relation.status == "equivalent"
    }),
  )
  assert_true(
    report.atomic_differences.any(difference => {
      difference.domain == "paint.fill" &&
      difference.computed_relation.status == "equivalent"
    }),
  )
}

///|
test "radial gradient reports geometry units spread and effective transform" {
  let before = "<svg><defs><radialGradient id='g' gradientUnits='objectBoundingBox' cx='.5' cy='.5' r='.5' fx='.5' fy='.5' fr='0' spreadMethod='pad' gradientTransform='scale(1)'><stop stop-color='red'/><stop offset='1' stop-color='blue'/></radialGradient></defs><circle id='dot' cx='8' cy='8' r='4' fill='url(#g)'/></svg>"
  let after = "<svg><defs><radialGradient id='g' gradientUnits='userSpaceOnUse' cx='4' cy='5' r='6' fx='2' fy='3' fr='1' spreadMethod='repeat' gradientTransform='translate(1)'><stop stop-color='red'/><stop offset='1' stop-color='blue'/></radialGradient></defs><circle id='dot' cx='8' cy='8' r='4' fill='url(#g)'/></svg>"
  let domains = gradient_diff_domains(gradient_report(before, after))
  for
    domain in [
      "resource.gradient.units", "resource.gradient.spread_method", "resource.gradient.transform.list",
      "resource.gradient.transform.effective_matrix", "resource.gradient.geometry.cx",
      "resource.gradient.geometry.cy", "resource.gradient.geometry.r", "resource.gradient.geometry.fx",
      "resource.gradient.geometry.fy", "resource.gradient.geometry.fr",
    ] {
    assert_true(domains.contains(domain))
  }
}

///|
test "one changed gradient reaches every fill and stroke consumer" {
  let before = "<svg><defs><linearGradient id='g'><stop stop-color='red'/><stop offset='1' stop-color='blue'/></linearGradient></defs><rect id='a' width='4' height='4' fill='url(#g)' stroke='url(#g)'/><rect id='b' x='8' width='6' height='6' fill='url(#g)'/></svg>"
  let after = before.replace_all(
    old="stop-color='red'",
    new="stop-color='green'",
  )
  let report = gradient_report(before, after)
  assert_eq(
    report.atomic_differences
    .filter(difference => difference.domain == "paint.fill")
    .length(),
    2,
  )
  assert_eq(
    report.atomic_differences
    .filter(difference => difference.domain == "paint.stroke")
    .length(),
    1,
  )
  let mut resource_fact : ChangedFact? = None
  for fact in report.changed_facts {
    if fact.property == "stop:0:color" {
      resource_fact = Some(fact)
    }
  }
  guard resource_fact is Some(resource_fact) else {
    fail("missing gradient resource fact")
  }
  assert_true(resource_fact.affected_subject_ids.contains("a"))
  assert_true(resource_fact.affected_subject_ids.contains("b"))
}

///|
test "gradient resource insertion replaces the active paint fallback" {
  let before = "<svg><rect id='box' width='8' height='8' fill='url(#g) red'/></svg>"
  let after = "<svg><defs><linearGradient id='g'><stop stop-color='blue'/></linearGradient></defs><rect id='box' width='8' height='8' fill='url(#g) red'/></svg>"
  let report = gradient_report(before, after)
  assert_true(
    report.atomic_differences.any(difference => {
      difference.domain == "resource.gradient.presence" &&
      difference.computed_relation.missing_side == Some("before")
    }),
  )
  assert_true(
    report.atomic_differences.any(difference => {
      difference.domain == "paint.fill" &&
      difference.computed_relation.status == "different" &&
      difference.computed_relation.missing_side is None
    }),
  )
}

///|
test "invalid gradient semantics are located and indeterminate" {
  let before = "<svg><defs><linearGradient id='a' href='external.svg#g' x2='bad'><stop stop-color='red'/></linearGradient></defs><rect id='box' width='8' height='8' fill='url(#a)'/></svg>"
  let after = before.replace_all(old="x2='bad'", new="x2='worse'")
  let report = gradient_report(before, after)
  assert_eq(report.analysis_status, "partial")
  for
    code in [
      "gradient_external_reference_unsupported", "gradient_length_syntax_unsupported",
    ] {
    assert_true(
      report.diagnostics.any(diagnostic => {
        diagnostic.code == code && !diagnostic.source_locations.is_empty()
      }),
    )
  }
  assert_true(
    report.atomic_differences.any(difference => {
      difference.domain == "paint.fill" &&
      difference.computed_relation.status == "indeterminate" &&
      !difference.computed_relation.diagnostic_ids.is_empty()
    }),
  )
  let cycle = "<svg><defs><linearGradient id='a' href='#b'/><linearGradient id='b' href='#a'/></defs></svg>"
  let cycle_report = gradient_report(cycle, cycle)
  assert_eq(cycle_report.analysis_status, "failed")
  assert_true(
    cycle_report.diagnostics.any(diagnostic => {
      diagnostic.code == "reference_cycle_detected"
    }),
  )
}

///|
test "non-srgb gradient interpolation stays behind a precise guard" {
  let before = "<svg color-interpolation='linearRGB'><defs><linearGradient id='g'><stop stop-color='red'/><stop offset='1' stop-color='blue'/></linearGradient></defs><rect id='box' width='8' height='8' fill='url(#g)'/></svg>"
  let after = before.replace_all(
    old="stop-color='red'",
    new="stop-color='green'",
  )
  let report = gradient_report(before, after)
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "gradient_color_interpolation_unsupported" &&
      !diagnostic.source_locations.is_empty()
    }),
  )
  assert_true(
    report.atomic_differences.any(difference => {
      difference.domain == "paint.fill" &&
      difference.computed_relation.status == "indeterminate"
    }),
  )
}
