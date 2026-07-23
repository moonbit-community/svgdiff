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
fn marker_test_subject(source : String) -> SourceSubject raise {
  let subjects = extract_source_subjects_or_raise(source)
  guard subjects is [subject] else { fail("expected one marker subject") }
  subject
}

///|
fn assert_marker_angle(actual : Double, expected : Double) -> Unit raise {
  assert_true((actual - expected).abs() < 0.000001)
}

///|
test "marker attachment shorthand and longhands retain authored provenance" {
  let source = "<svg><path marker=' url(#base) ' style='marker-mid:url(#middle)' d='M0 0L1 0'/></svg>"
  let subject = marker_test_subject(source)
  assert_eq(subject_value(subject, "marker"), Some("url(#base)"))
  assert_eq(subject_value(subject, "marker-start"), Some("url(#base)"))
  assert_eq(subject_value(subject, "marker-mid"), Some("url(#middle)"))
  assert_eq(subject_value(subject, "marker-end"), Some("url(#base)"))
  guard shape_fact(subject.facts, "marker") is Some(shorthand) else {
    fail("marker shorthand fact must be retained")
  }
  assert_eq(shorthand.authored_value, " url(#base) ")
  assert_eq(shorthand.origin, "presentation_attribute")
  assert_eq(
    source
    .view(
      start_offset=shorthand.source_span.start_offset,
      end_offset=shorthand.source_span.end_offset,
    )
    .to_owned(),
    " url(#base) ",
  )
  guard shape_fact(subject.facts, "marker-mid") is Some(mid) else {
    fail("marker longhand fact must be retained")
  }
  assert_eq(mid.origin, "inline_style")
  for
    spelling in ["url(#base)", "URL( #base )", "url('#base')", "url(\"#base\")"] {
    assert_eq(canonical_marker_reference(spelling), Some("url(#base)"))
  }
}

///|
test "marker attachments inherit and a local longhand overrides the shorthand" {
  let source = "<svg><defs><marker id='base'/><marker id='end'/></defs><g marker='url(#base)'><line id='edge' x1='0' y1='0' x2='1' y2='0' marker-end='url(#end)'/></g></svg>"
  let subject = marker_test_subject(source)
  assert_eq(subject_value(subject, "marker-start"), Some("url(#base)"))
  assert_eq(subject_value(subject, "marker-mid"), Some("url(#base)"))
  assert_eq(subject_value(subject, "marker-end"), Some("url(#end)"))
  guard shape_fact(subject.marker_effective_facts, "marker-start")
    is Some(start) else {
    fail("inherited marker start fact must be materialized")
  }
  assert_eq(start.origin, "presentation_attribute")
  assert_eq(start.authored_value, "url(#base)")
  assert_eq(
    source
    .view(
      start_offset=start.source_span.start_offset,
      end_offset=start.source_span.end_offset,
    )
    .to_owned(),
    "url(#base)",
  )
}

///|
test "marker resources resolve defaults and canonical values" {
  let source = "<svg><defs><marker id='m' markerWidth='3.0' markerHeight='4' refX='center' refY='bottom' orient='.5turn' viewBox='0 0 10 20' preserveAspectRatio='none' overflow='hidden'/></defs></svg>"
  let resources = extract_marker_resources_or_raise(
    source,
    ComparisonProfile::v1_default(),
  )
  guard resources is [resource] else { fail("expected one marker resource") }
  assert_eq(resource.authored_id, Some("m"))
  assert_eq(resource.marker_units, "strokeWidth")
  assert_eq(resource.marker_width, 3.0)
  assert_eq(resource.marker_height, 4.0)
  assert_eq(resource.ref_x, 5.0)
  assert_eq(resource.ref_y, 20.0)
  assert_eq(resource.orient_kind, "angle")
  assert_eq(resource.orient_angle, 180.0)
  assert_eq(resource.overflow, "hidden")
  assert_true(resource.complete)
  guard shape_fact(resource.facts, "markerWidth") is Some(width) else {
    fail("authored marker width must be retained")
  }
  assert_eq(width.authored_value, "3.0")
  assert_eq(width.declared_value, "3")
  assert_eq(
    source
    .view(
      start_offset=width.source_span.start_offset,
      end_offset=width.source_span.end_offset,
    )
    .to_owned(),
    "3.0",
  )
}

///|
test "marker resources reject unsupported lengths values and overflow" {
  let source = "<svg><marker id='m' markerUnits='objectBoundingBox' markerWidth='2em' markerHeight='-1' refX='left' orient='sideways' viewBox='0 0 0 2' preserveAspectRatio='stretch' overflow='visible'/></svg>"
  let resources = extract_marker_resources_or_raise(
    source,
    ComparisonProfile::v1_default(),
  )
  guard resources is [resource] else { fail("expected one marker resource") }
  assert_false(resource.complete)
  assert_eq(resource.invalid_facts.map(fact => fact.property), [
    "viewBox", "preserveAspectRatio", "markerWidth", "markerHeight", "markerUnits",
    "orient", "refX", "overflow",
  ])
  assert_true(
    resource.invalid_facts.all(fact => {
      fact.source_span.end_offset > fact.source_span.start_offset
    }),
  )
}

///|
test "line polyline and closed polygon produce SVG marker vertices" {
  let line = marker_vertices_for_subject(
    marker_test_subject("<svg><line x1='1' y1='2' x2='9' y2='2'/></svg>"),
  )
  assert_eq(line.length(), 2)
  assert_eq((line[0].x, line[0].y), (1.0, 2.0))
  assert_marker_angle(line[0].auto_angle, 0.0)
  assert_marker_angle(line[1].auto_angle, 0.0)

  let polyline = marker_vertices_for_subject(
    marker_test_subject("<svg><polyline points='0 0 10 0 10 10'/></svg>"),
  )
  assert_eq(polyline.length(), 3)
  assert_marker_angle(polyline[0].auto_angle, 0.0)
  assert_marker_angle(polyline[1].auto_angle, 45.0)
  assert_marker_angle(polyline[2].auto_angle, 90.0)

  let polygon = marker_vertices_for_subject(
    marker_test_subject("<svg><polygon points='0 0 10 0 10 10'/></svg>"),
  )
  assert_eq(polygon.length(), 4)
  assert_eq((polygon[0].x, polygon[0].y), (0.0, 0.0))
  assert_eq((polygon[3].x, polygon[3].y), (0.0, 0.0))
  assert_marker_angle(polygon[0].auto_angle, 0.0)
  assert_marker_angle(polygon[3].auto_angle, -135.0)
}

///|
test "rounded rectangles and ellipses use equivalent arc path tangents" {
  let rounded = marker_vertices_for_subject(
    marker_test_subject(
      "<svg><rect x='0' y='0' width='20' height='10' rx='2' ry='3'/></svg>",
    ),
  )
  assert_eq(rounded.length(), 9)
  assert_eq((rounded[0].x, rounded[0].y), (2.0, 0.0))
  assert_marker_angle(rounded[0].auto_angle, 0.0)
  assert_marker_angle(rounded[1].auto_angle, 0.0)
  assert_marker_angle(rounded[2].auto_angle, 90.0)
  assert_marker_angle(rounded[8].auto_angle, 0.0)

  let ellipse = marker_vertices_for_subject(
    marker_test_subject("<svg><ellipse cx='10' cy='20' rx='4' ry='2'/></svg>"),
  )
  assert_eq(ellipse.length(), 5)
  assert_eq((ellipse[0].x, ellipse[0].y), (14.0, 20.0))
  assert_eq((ellipse[4].x, ellipse[4].y), (14.0, 20.0))
  assert_marker_angle(ellipse[0].auto_angle, 90.0)
  assert_marker_angle(ellipse[1].auto_angle, 180.0)
  assert_marker_angle(ellipse[4].auto_angle, 90.0)
}

///|
test "path marker directions include curves arcs zero lengths and subpaths" {
  let curve = marker_vertices_for_subject(
    marker_test_subject(
      "<svg><path d='M0 0C0 10 10 10 10 0Q20 0 20 10'/></svg>",
    ),
  )
  assert_eq(curve.length(), 3)
  assert_marker_angle(curve[0].auto_angle, 90.0)
  assert_marker_angle(curve[2].auto_angle, 90.0)

  let arc = marker_vertices_for_subject(
    marker_test_subject("<svg><path d='M10 0A10 10 0 0 1 0 10'/></svg>"),
  )
  assert_eq(arc.length(), 2)
  assert_marker_angle(arc[0].auto_angle, 90.0)
  assert_marker_angle(arc[1].auto_angle, 180.0)

  let zero = marker_vertices_for_subject(
    marker_test_subject("<svg><path d='M0 0L0 0L10 0M20 0L20 0'/></svg>"),
  )
  assert_eq(zero.length(), 5)
  assert_marker_angle(zero[0].auto_angle, 0.0)
  assert_marker_angle(zero[1].auto_angle, 0.0)
  assert_marker_angle(zero[4].auto_angle, 0.0)
}

///|
test "a one-vertex path receives both start and end marker roles" {
  let source = "<svg><defs><marker id='s' markerUnits='userSpaceOnUse' markerWidth='1' markerHeight='1'/><marker id='e' markerUnits='userSpaceOnUse' markerWidth='1' markerHeight='1'/></defs><path d='M5 5' marker-start='url(#s)' marker-end='url(#e)'/></svg>"
  let subject = marker_test_subject(source)
  assert_eq(subject.marker_placements.map(placement => placement.resource_id), [
    "s", "e",
  ])
}

///|
test "marker instance bounds compose orientation units viewport reference and transforms" {
  let reverse = marker_test_subject(
    "<svg><defs><marker id='m' markerUnits='userSpaceOnUse' markerWidth='2' markerHeight='1' orient='auto-start-reverse'/></defs><line x1='10' y1='0' x2='20' y2='0' marker-start='url(#m)' marker-end='url(#m)'/></svg>",
  )
  assert_eq(reverse.marker_placements.length(), 2)
  assert_true(
    reverse.marker_placements[0].bounds
    is { x: 8.0, y: -1.0, width: 2.0, height: 1.0 },
  )
  assert_true(
    reverse.marker_placements[1].bounds
    is { x: 20.0, y: 0.0, width: 2.0, height: 1.0 },
  )

  let viewport = marker_test_subject(
    "<svg><defs><marker id='m' markerUnits='userSpaceOnUse' markerWidth='10' markerHeight='10' viewBox='0 0 100 100' refX='center' refY='center'/></defs><path d='M20 20' marker-start='url(#m)'/></svg>",
  )
  assert_true(
    viewport.marker_placements[0].bounds
    is { x: 15.0, y: 15.0, width: 10.0, height: 10.0 },
  )

  let scaled = marker_test_subject(
    "<svg><defs><marker id='m' markerWidth='2' markerHeight='1'/></defs><line x1='1' y1='2' x2='3' y2='2' stroke='black' stroke-width='3' transform='translate(10 5)' marker-start='url(#m)'/></svg>",
  )
  assert_true(
    scaled.marker_placements[0].bounds
    is { x: 11.0, y: 7.0, width: 6.0, height: 3.0 },
  )
}

///|
test "missing wrong-kind and malformed marker references stay incomplete" {
  for
    source in [
      "<svg><path marker-start='url(#missing)' d='M0 0L1 0'/></svg>", "<svg><defs><linearGradient id='m'/></defs><path marker-start='url(#m)' d='M0 0L1 0'/></svg>",
      "<svg><path marker-start='url(https://example.com/m.svg#m)' d='M0 0L1 0'/></svg>",
    ] {
    let subject = marker_test_subject(source)
    assert_false(subject.marker_complete)
    assert_false(subject.marker_active)
    assert_true(!subject.marker_invalid_facts.is_empty())
    let report = compare(source, source, ComparisonProfile::v1_default())
    assert_eq(report.analysis_status, "partial")
    assert_true(
      report.diagnostics.any(diagnostic => {
        diagnostic.code == "marker_semantics_unsupported"
      }),
    )
  }
}

///|
test "marker child shapes are resources rather than ordinary subjects" {
  let source = "<svg><defs><marker id='m'><path d='M0 0L1 1'/></marker></defs><line x1='0' y1='0' x2='2' y2='0' marker-end='url(#m)'/></svg>"
  let subjects = extract_source_subjects_or_raise(source)
  assert_eq(subjects.length(), 1)
  assert_eq(subjects[0].kind, "line")
}

///|
test "cyclic marker content references fail admission" {
  let source = "<svg><defs><marker id='m'><path d='M0 0L1 0' marker-end='url(#m)'/></marker></defs><line x1='0' y1='0' x2='2' y2='0' marker-end='url(#m)'/></svg>"
  let report = compare(source, source, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "failed")
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "reference_cycle_detected"
    }),
  )
}
