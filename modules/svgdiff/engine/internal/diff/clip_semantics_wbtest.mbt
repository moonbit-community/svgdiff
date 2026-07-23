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
fn clip_test_difference(
  report : StructuredReport,
  domain : String,
) -> AtomicDifference? {
  for difference in report.atomic_differences {
    if difference.domain == domain {
      return Some(difference)
    }
  }
  None
}

///|
fn clip_test_event(report : StructuredReport, id : String) -> VisualEvent? {
  for event in report.events {
    if event.id == id {
      return Some(event)
    }
  }
  None
}

///|
test "clip-path cascade spelling is source-visible and computed-equivalent" {
  let before =
    #|<svg width="16" height="16">
    #|  <defs><clipPath id="Left"><rect id="cut" width="8" height="16"/></clipPath></defs>
    #|  <rect id="box" width="16" height="16" fill="red" clip-path="url( '#Left' )"/>
    #|</svg>
  let after =
    #|<svg width="16" height="16" style="--cut:url(#Left)">
    #|  <style>#box { clip-path: var(--cut); }</style>
    #|  <defs><clipPath id="Left"><rect id="cut" width="8" height="16"/></clipPath></defs>
    #|  <rect id="box" width="16" height="16" fill="red"/>
    #|</svg>
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "complete")
  guard clip_test_difference(report, "clipping.path") is Some(difference) else {
    fail("expected clip-path source difference")
  }
  assert_eq(difference.computed_relation.status, "equivalent")
  assert_eq(
    difference.source_fact_before.unwrap().origin,
    "presentation_attribute",
  )
  assert_eq(difference.source_fact_after.unwrap().origin, "stylesheet_rule")
  assert_true(
    report.source_resolutions.any(pair => {
      pair.subject_id == "box" &&
      pair.property == "clip-path" &&
      pair.before.map(value => value.resolved_value) == Some("url(#Left)") &&
      pair.after.map(value => value.resolved_value) == Some("url(#Left)")
    }),
  )
  assert_true(
    report.events.any(event => {
      event.atomic_difference_ids.contains(difference.id) &&
      event.rendered_outcome.magnitude.map(value => value.changed_pixels) ==
      Some(0)
    }),
  )
}

///|
test "custom clip-path changes retain the actual declaration cause" {
  let before =
    #|<svg width="16" height="16" style="--active-clip:url(#left)">
    #|  <defs><clipPath id="left"><rect id="left-cut" width="8" height="16"/></clipPath><clipPath id="right"><rect id="right-cut" x="8" width="8" height="16"/></clipPath></defs>
    #|  <rect id="box" width="16" height="16" fill="red" style="clip-path:var(--active-clip)"/>
    #|</svg>
  let after = before.replace_all(
    old="--active-clip:url(#left)",
    new="--active-clip:url(#right)",
  )
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "complete")
  guard clip_test_difference(report, "clipping.path") is Some(difference) else {
    fail("expected computed clip-path difference")
  }
  assert_eq(difference.computed_relation.status, "different")
  assert_true(
    report.changed_facts.any(fact => {
      fact.property == "--active-clip" &&
      fact.affected_subject_ids.contains("box") &&
      difference.changed_fact_ids.contains(fact.id)
    }),
  )
}

///|
test "rectangular clip resource changes retain consumers and rendered evidence" {
  let before =
    #|<svg width="16" height="16">
    #|  <defs><clipPath id="clip"><rect id="cut" x="0" width="8" height="16"/></clipPath></defs>
    #|  <rect id="box" width="16" height="16" fill="red" clip-path="url(#clip)"/>
    #|</svg>
  let after = before.replace_all(
    old="id=\"cut\" x=\"0\"",
    new="id=\"cut\" x=\"8\"",
  )
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "complete")
  guard clip_test_difference(report, "resource.clip.geometry")
    is Some(difference) else {
    fail("expected clip resource geometry difference")
  }
  assert_eq(difference.computed_relation.status, "different")
  assert_eq(difference.magnitude.parameter_signed_user_units, Some(8.0))
  assert_true(!difference.domain_ordering.components.is_empty())
  assert_true(
    difference.changed_fact_ids.any(id => {
      report.changed_facts.any(fact => {
        fact.id == id && fact.affected_subject_ids.contains("box")
      })
    }),
  )
  assert_true(
    report.events.any(event => {
      event.atomic_difference_ids.contains(difference.id) &&
      event.rendered_outcome.magnitude.map(value => value.changed_pixels) ==
      Some(256)
    }),
  )
}

///|
test "clip geometry separates spelling equality from small numeric change" {
  let before =
    #|<svg width="16" height="16"><defs><clipPath id="clip"><rect id="cut" width="1.0" height="16"/></clipPath></defs><rect id="box" width="16" height="16" clip-path="url(#clip)"/></svg>
  let equivalent = before.replace_all(old="width=\"1.0\"", new="width=\"1\"")
  let equivalent_report = compare(
    before,
    equivalent,
    ComparisonProfile::v1_default(),
  )
  guard clip_test_difference(equivalent_report, "resource.clip.geometry")
    is Some(equivalent_difference) else {
    fail("expected source-visible clip width rewrite")
  }
  assert_eq(equivalent_difference.computed_relation.status, "equivalent")
  assert_true(
    equivalent_report.events.any(event => {
      event.atomic_difference_ids.contains(equivalent_difference.id) &&
      event.rendered_outcome.magnitude.map(value => value.changed_pixels) ==
      Some(0)
    }),
  )

  let small_change = before.replace_all(
    old="width=\"1.0\"",
    new="width=\"0.99999\"",
  )
  let changed_report = compare(
    before,
    small_change,
    ComparisonProfile::v1_default(),
  )
  guard clip_test_difference(changed_report, "resource.clip.geometry")
    is Some(changed_difference) else {
    fail("expected small clip width difference")
  }
  assert_eq(changed_difference.computed_relation.status, "different")
  guard changed_difference.magnitude.parameter_signed_user_units is Some(delta) else {
    fail("expected numeric clip parameter delta")
  }
  assert_true((delta + 0.00001).abs() < 0.000000001)
  assert_true(
    changed_difference.magnitude.symmetric_relative is Some(value) &&
    value > 0.0,
  )
}

///|
test "clip resource regions exclude unrelated scene changes" {
  let before =
    #|<svg width="16" height="16">
    #|  <defs><clipPath id="clip"><rect id="cut" x="0" width="4" height="8"/></clipPath></defs>
    #|  <rect id="box" width="10" height="8" fill="red" clip-path="url(#clip)"/>
    #|  <rect id="outside" x="12" y="12" width="3" height="3" fill="red"/>
    #|</svg>
  let after = before
    .replace_all(old="id=\"cut\" x=\"0\"", new="id=\"cut\" x=\"4\"")
    .replace_all(
      old="id=\"outside\" x=\"12\" y=\"12\" width=\"3\" height=\"3\" fill=\"red\"",
      new="id=\"outside\" x=\"12\" y=\"12\" width=\"3\" height=\"3\" fill=\"blue\"",
    )
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "complete")
  guard clip_test_event(report, "event:clip:clip") is Some(event) else {
    fail("expected clip resource event")
  }
  assert_true(!event.difference_regions.is_empty())
  assert_true(
    event.difference_regions.all(region => {
      region.css_x + region.css_width <= 8.0
    }),
  )
  assert_true(
    event.difference_regions.all(region => {
      region.cause_envelope.guarantee == "sound_overapproximation" &&
      region.cause_envelope.candidate_changed_fact_ids.any(id => {
        id.has_prefix("fact:clip:clip:")
      })
    }),
  )
}

///|
test "clip unit and transform changes retain every reused consumer" {
  let before =
    #|<svg width="16" height="16">
    #|  <defs><clipPath id="clip" transform="translate(0 0)"><rect id="cut" width="4" height="8"/></clipPath></defs>
    #|  <rect id="left" width="8" height="8" fill="red" clip-path="url(#clip)"/>
    #|  <rect id="right" x="8" width="8" height="8" fill="blue" clip-path="url(#clip)"/>
    #|</svg>
  let after = before.replace_all(
    old="id=\"clip\" transform=\"translate(0 0)\"",
    new="id=\"clip\" clipPathUnits=\"objectBoundingBox\" transform=\"matrix(1 0 0 1 0 0)\"",
  )
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "complete")
  guard clip_test_difference(report, "resource.clip.units") is Some(units) else {
    fail("expected clip units difference")
  }
  guard clip_test_difference(report, "resource.clip.transform")
    is Some(transform) else {
    fail("expected clip transform difference")
  }
  assert_eq(units.computed_relation.status, "different")
  assert_eq(transform.computed_relation.status, "equivalent")
  for difference in [units, transform] {
    assert_true(
      difference.changed_fact_ids.any(id => {
        report.changed_facts.any(fact => {
          fact.id == id && fact.affected_subject_ids == ["left", "right"]
        })
      }),
    )
  }
}

///|
test "full and empty clips separate semantic change from rendered contribution" {
  let full =
    #|<svg width="16" height="16"><defs><clipPath id="clip"><rect id="cut" width="16" height="16"/></clipPath></defs><rect id="box" width="16" height="16" fill="red"/></svg>
  let clipped_full = full.replace_all(
    old="fill=\"red\"/>",
    new="fill=\"red\" clip-path=\"url(#clip)\"/>",
  )
  let full_report = compare(full, clipped_full, ComparisonProfile::v1_default())
  assert_eq(full_report.analysis_status, "complete")
  guard clip_test_difference(full_report, "clipping.path")
    is Some(full_difference) else {
    fail("expected full clip attachment difference")
  }
  assert_eq(full_difference.computed_relation.status, "different")
  assert_true(
    full_report.events.any(event => {
      event.atomic_difference_ids.contains(full_difference.id) &&
      event.rendered_outcome.magnitude.map(value => value.changed_pixels) ==
      Some(0)
    }),
  )

  let empty = clipped_full.replace_all(
    old="id=\"cut\" width=\"16\" height=\"16\"/>",
    new="id=\"cut\" width=\"0\" height=\"0\"/>",
  )
  let empty_report = compare(full, empty, ComparisonProfile::v1_default())
  assert_eq(empty_report.analysis_status, "complete")
  guard clip_test_difference(empty_report, "clipping.path")
    is Some(empty_difference) else {
    fail("expected empty clip attachment difference")
  }
  assert_true(
    empty_report.events.any(event => {
      event.atomic_difference_ids.contains(empty_difference.id) &&
      event.rendered_outcome.magnitude.map(value => value.changed_pixels) ==
      Some(256)
    }),
  )
}

///|
test "object bounding box and container clips compute intersected effect bounds" {
  let object_bbox =
    #|<svg width="16" height="16">
    #|  <defs><clipPath id="clip" clipPathUnits="objectBoundingBox"><rect id="cut" x="0.25" y="0.25" width="0.5" height="0.5"/></clipPath></defs>
    #|  <rect id="box" x="2" y="2" width="8" height="8" fill="red" clip-path="url(#clip)"/>
    #|</svg>
  let object_subjects = extract_source_subjects_with_profile_or_raise(
    object_bbox,
    ComparisonProfile::v1_default(),
  )
  guard object_subjects is [subject] &&
    subject.clip_effect_bounds is Some(bounds) else {
    fail("expected one object-bounding-box clipped subject")
  }
  assert_eq(
    (bounds.x, bounds.y, bounds.width, bounds.height),
    (4.0, 4.0, 4.0, 4.0),
  )

  let container =
    #|<svg width="16" height="16">
    #|  <defs><clipPath id="clip"><rect id="cut" x="4" y="3" width="5" height="6"/></clipPath></defs>
    #|  <g id="layer" clip-path="url(#clip)"><rect id="box" width="12" height="12" fill="red"/></g>
    #|</svg>
  let container_subjects = extract_source_subjects_with_profile_or_raise(
    container,
    ComparisonProfile::v1_default(),
  )
  guard container_subjects is [subject] &&
    subject.clip_effect_bounds is Some(bounds) else {
    fail("expected one container-clipped subject")
  }
  assert_eq(
    (bounds.x, bounds.y, bounds.width, bounds.height),
    (4.0, 3.0, 5.0, 6.0),
  )
}

///|
test "admitted clip slices render exact rectangular pixels" {
  let object_bbox =
    #|<svg width="16" height="16">
    #|  <defs><clipPath id="clip" clipPathUnits="objectBoundingBox"><rect id="cut" x="0.25" y="0.25" width="0.5" height="0.5"/></clipPath></defs>
    #|  <rect id="box" x="2" y="2" width="8" height="8" fill="red" clip-path="url(#clip)"/>
    #|</svg>
  guard render_group_compositor_test_source(
      object_bbox,
      ComparisonProfile::v1_default(),
    )
    is Some(object_image) else {
    fail("expected object-bounding-box clip render")
  }
  assert_group_compositor_pixel(object_image, 3, 3, 0, 0, 0, 0)
  assert_group_compositor_pixel(object_image, 4, 4, 255, 0, 0, 255)
  assert_group_compositor_pixel(object_image, 7, 7, 255, 0, 0, 255)
  assert_group_compositor_pixel(object_image, 8, 8, 0, 0, 0, 0)

  let transformed =
    #|<svg width="16" height="16">
    #|  <defs><clipPath id="clip" transform="translate(2 1)"><rect id="cut" x="2" y="2" width="4" height="5"/></clipPath></defs>
    #|  <rect id="box" width="12" height="12" fill="blue" clip-path="url(#clip)"/>
    #|</svg>
  guard render_group_compositor_test_source(
      transformed,
      ComparisonProfile::v1_default(),
    )
    is Some(transformed_image) else {
    fail("expected transformed clip render")
  }
  assert_group_compositor_pixel(transformed_image, 3, 3, 0, 0, 0, 0)
  assert_group_compositor_pixel(transformed_image, 4, 3, 0, 0, 255, 255)
  assert_group_compositor_pixel(transformed_image, 7, 7, 0, 0, 255, 255)
  assert_group_compositor_pixel(transformed_image, 8, 8, 0, 0, 0, 0)
}

///|
test "unsupported clip content and locators remain precise partial coverage" {
  let polygon =
    #|<svg><defs><clipPath id="clip"><polygon id="cut" points="0,0 8,0 4,8"/></clipPath></defs><rect id="box" width="8" height="8" clip-path="url(#clip)"/></svg>
  let polygon_report = compare(
    polygon,
    polygon,
    ComparisonProfile::v1_default(),
  )
  assert_eq(polygon_report.analysis_status, "partial")
  assert_true(
    polygon_report.diagnostics.any(diagnostic => {
      diagnostic.code == "clip_path_content_unsupported"
    }),
  )

  let missing =
    #|<svg><rect id="box" width="8" height="8" clip-path="url(#missing)"/></svg>
  let missing_report = compare(
    missing,
    missing,
    ComparisonProfile::v1_default(),
  )
  assert_eq(missing_report.analysis_status, "partial")
  assert_true(
    missing_report.diagnostics.any(diagnostic => {
      diagnostic.code == "clip_path_target_missing" &&
      !diagnostic.source_locations.is_empty()
    }),
  )
}

///|
test "clip resource insertion deletion and inactivity retain provenance" {
  let missing =
    #|<svg width="16" height="16"><rect id="box" width="16" height="16" fill="red" clip-path="url(#clip)"/></svg>
  let present =
    #|<svg width="16" height="16"><defs><clipPath id="clip"><rect id="cut" width="8" height="16"/></clipPath></defs><rect id="box" width="16" height="16" fill="red" clip-path="url(#clip)"/></svg>
  let inserted = compare(missing, present, ComparisonProfile::v1_default())
  assert_eq(inserted.analysis_status, "partial")
  guard clip_test_difference(inserted, "resource.clip.presence")
    is Some(insertion) else {
    fail("expected clip resource insertion")
  }
  assert_eq(insertion.computed_relation.missing_side, Some("before"))
  assert_true(
    insertion.source_fact_after is Some(fact) &&
    fact.authored_value.has_prefix("<clipPath"),
  )
  assert_true(
    insertion.changed_fact_ids.any(id => {
      inserted.changed_facts.any(fact => {
        fact.id == id && fact.affected_subject_ids.contains("box")
      })
    }),
  )
  guard clip_test_event(inserted, "event:clip:clip") is Some(inserted_event) else {
    fail("expected clip insertion event")
  }
  assert_eq(
    inserted_event.rendered_outcome.magnitude.map(value => value.changed_pixels),
    Some(128),
  )

  let deleted = compare(present, missing, ComparisonProfile::v1_default())
  guard clip_test_difference(deleted, "resource.clip.presence")
    is Some(deletion) else {
    fail("expected clip resource deletion")
  }
  assert_eq(deletion.computed_relation.missing_side, Some("after"))
  assert_true(deletion.source_fact_before is Some(_))

  let unused_before = "<svg width='16' height='16'><rect id='box' width='4' height='4'/></svg>"
  let unused_after = "<svg width='16' height='16'><defs><clipPath id='clip'><rect id='cut' width='8' height='8'/></clipPath></defs><rect id='box' width='4' height='4'/></svg>"
  let unused = compare(
    unused_before,
    unused_after,
    ComparisonProfile::v1_default(),
  )
  assert_eq(unused.analysis_status, "complete")
  guard clip_test_difference(unused, "resource.clip.presence")
    is Some(unused_difference) else {
    fail("expected unused clip resource insertion")
  }
  assert_eq(unused_difference.computed_relation.status, "equivalent")
  assert_true(
    unused.events.any(event => {
      event.atomic_difference_ids.contains(unused_difference.id) &&
      event.rendered_outcome.magnitude.map(value => value.changed_pixels) ==
      Some(0)
    }),
  )
}

///|
test "unsupported clip boundary reports the responsible source" {
  let cases = [
    (
      "<svg><rect id='box' width='8' height='8' clip-path='url(asset.svg#clip)'/></svg>",
      "clip_path_external_reference_unsupported",
    ),
    (
      "<svg><rect id='box' width='8' height='8' clip-path='red'/></svg>", "clip_path_reference_invalid",
    ),
    (
      "<svg><defs><linearGradient id='clip'/></defs><rect id='box' width='8' height='8' clip-path='url(#clip)'/></svg>",
      "clip_path_target_kind_unsupported",
    ),
    (
      "<svg><defs><clipPath id='clip'><rect width='4' height='4'/><rect x='4' width='4' height='4'/></clipPath></defs><rect width='8' height='8' clip-path='url(#clip)'/></svg>",
      "clip_path_content_unsupported",
    ),
    (
      "<svg><defs><clipPath id='clip'><rect width='4' height='4' rx='1'/></clipPath></defs><rect width='8' height='8' clip-path='url(#clip)'/></svg>",
      "clip_path_geometry_unsupported",
    ),
    (
      "<svg><defs><clipPath id='clip' clipPathUnits='invalid'><rect width='4' height='4'/></clipPath></defs><rect width='8' height='8' clip-path='url(#clip)'/></svg>",
      "clip_path_units_invalid",
    ),
    (
      "<svg><defs><clipPath id='clip' clipPathUnits='objectBoundingBox'><rect width='50%' height='50%'/></clipPath></defs><rect width='8' height='8' clip-path='url(#clip)'/></svg>",
      "clip_path_geometry_unsupported",
    ),
    (
      "<svg><defs><clipPath id='clip'><rect width='4' height='4'><animate attributeName='width' to='8'/></rect></clipPath></defs><rect width='8' height='8' clip-path='url(#clip)'/></svg>",
      "clip_path_dynamic_unsupported",
    ),
    (
      "<svg><defs><clipPath id='base'><rect width='4' height='4'/></clipPath><clipPath id='clip' href='#base'><rect width='4' height='4'/></clipPath></defs><rect width='8' height='8' clip-path='url(#clip)'/></svg>",
      "clip_path_nested_reference_unsupported",
    ),
    (
      "<svg><defs><clipPath id='clip' transform='rotate(45)'><rect width='4' height='4'/></clipPath></defs><rect width='8' height='8' clip-path='url(#clip)'/></svg>",
      "clip_path_transform_unproven",
    ),
    (
      "<svg><defs><clipPath id='clip' clipPathUnits='objectBoundingBox'><rect width='.5' height='.5'/></clipPath></defs><g clip-path='url(#clip)'><rect width='8' height='8'/></g></svg>",
      "clip_path_object_bbox_container_unsupported",
    ),
    (
      "<svg><defs><clipPath id='clip'><rect width='4' height='4'/></clipPath></defs><rect width='calc(8)' height='8' clip-path='url(#clip)'/></svg>",
      "clip_path_effect_bounds_unavailable",
    ),
    (
      "<svg><defs><clipPath id='clip'><rect width='4' height='4'/></clipPath><rect id='shape' width='8' height='8'/></defs><use href='#shape' clip-path='url(#clip)'/></svg>",
      "clip_path_instance_unsupported",
    ),
    (
      "<svg><defs><clipPath id='clip'><rect width='4' height='4'/></clipPath><symbol id='shape' clip-path='url(#clip)'><rect width='8' height='8'/></symbol></defs><use href='#shape'/></svg>",
      "clip_path_instance_unsupported",
    ),
  ]
  for entry in cases {
    let (source, code) = entry
    let report = compare(source, source, ComparisonProfile::v1_default())
    assert_eq(report.analysis_status, "partial")
    if !report.diagnostics.any(diagnostic => {
        diagnostic.code == code && !diagnostic.source_locations.is_empty()
      }) {
      fail("expected located diagnostic \{code}")
    }
  }
}

///|
test "clip-path stays non-inherited while ancestor clipping remains active" {
  let source =
    #|<svg width="16" height="16">
    #|  <style>#box { clip-path: unset; }</style>
    #|  <defs><clipPath id="clip"><rect width="8" height="16"/></clipPath></defs>
    #|  <g id="layer" clip-path="url(#clip)"><rect id="box" width="16" height="16" fill="red"/></g>
    #|</svg>
  let subjects = extract_source_subjects_with_profile_or_raise(
    source,
    ComparisonProfile::v1_default(),
  )
  guard subjects is [subject] else { fail("expected one clipped leaf") }
  assert_eq(
    source_subject_resolution(subject, "clip-path").map(value => {
      value.resolved_value
    }),
    Some("none"),
  )
  assert_eq(subject.clip_resource_id, Some("clip"))
  assert_true(subject.clip_effect_bounds is Some(_))
}

///|
test "clip rule rewrites are equivalent for the admitted rectangle contour" {
  let before =
    #|<svg width="16" height="16"><defs><clipPath id="clip" clip-rule="nonzero"><rect id="cut" width="8" height="16"/></clipPath></defs><rect id="box" width="16" height="16" clip-path="url(#clip)"/></svg>
  let after = before.replace_all(
    old="clip-rule=\"nonzero\"",
    new="clip-rule=\"evenodd\"",
  )
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "complete")
  guard clip_test_difference(report, "resource.clip.rule") is Some(difference) else {
    fail("expected clip resource rule difference")
  }
  assert_eq(difference.computed_relation.status, "equivalent")
  assert_true(
    report.events.any(event => {
      event.atomic_difference_ids.contains(difference.id) &&
      event.rendered_outcome.magnitude.map(value => value.changed_pixels) ==
      Some(0)
    }),
  )
}
