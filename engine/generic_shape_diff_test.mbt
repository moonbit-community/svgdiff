///|
fn shape_svg(body : String) -> String {
  "<svg width='20' height='20'>\{body}</svg>"
}

///|
test "all changed facts across aligned subjects are enumerated" {
  let before = shape_svg(
    "<rect x='1' y='1' width='4' height='4' fill='red'/><rect x='10' y='1' width='4' height='4' opacity='1'/>",
  )
  let after = shape_svg(
    "<rect x='2' y='1' width='4' height='4' fill='blue'/><rect x='10' y='1' width='5' height='4' opacity='0.5'/>",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.atomic_differences.length(), 4)
  assert_eq(report.changed_facts.length(), 4)
  assert_true(
    report.atomic_differences.all(difference => {
      difference.subject_alignment_id is Some(_)
    }),
  )
  assert_eq(report.events.length(), 2)
  assert_true(
    report.events.all(event => event.atomic_difference_ids.length() == 2),
  )
  for difference in report.atomic_differences {
    let mut owner_count = 0
    for event in report.events {
      if event.atomic_difference_ids.contains(difference.id) {
        owner_count += 1
        assert_eq(
          difference.subject_alignment_id,
          Some(event.primary_subject_id),
        )
      }
    }
    assert_eq(owner_count, 1)
  }
}

///|
test "circle geometry uses the generic aligned-subject engine" {
  let before = shape_svg("<circle id='old' cx='8' cy='8' r='2' fill='red'/>")
  let after = shape_svg("<circle id='new' cx='9' cy='8' r='3' fill='red'/>")
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "partial")
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "renderer_curved_shape_raster_unproven"
    }),
  )
  assert_eq(report.atomic_differences.length(), 2)
  assert_true(
    report.atomic_differences.any(difference => {
      difference.domain == "geometry.position"
    }),
  )
  assert_true(
    report.atomic_differences.any(difference => {
      difference.domain == "geometry.size"
    }),
  )
}

///|
test "ordinary fill inheritance applies to non-rect subjects" {
  let before = shape_svg(
    "<g id='theme' fill='red'><circle id='dot' cx='8' cy='8' r='2'/></g>",
  )
  let after = shape_svg(
    "<g id='theme' fill='blue'><circle id='dot' cx='8' cy='8' r='2'/></g>",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.changed_facts.length(), 1)
  assert_eq(report.atomic_differences.length(), 1)
  assert_eq(report.atomic_differences[0].domain, "paint.fill")
  assert_true(report.atomic_differences[0].subject_alignment_id is Some(_))
  assert_eq(report.changed_facts[0].affected_subject_ids, ["dot"])
}

///|
test "unsupported path semantics remain partial and diagnosed" {
  let source = shape_svg("<path d='M0 0 L10 10' stroke='black'/>")
  let report = @engine.compare(
    source,
    source,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "partial")
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "unsupported_visual_subject"
    }),
  )
}

///|
test "ellipse line polyline and polygon share generic enumeration" {
  let before = shape_svg(
    "<ellipse cx='4' cy='4' rx='2' ry='1'/><line x1='0' y1='0' x2='2' y2='2'/><polyline points='0,0 1,1'/><polygon points='4,4 5,5 6,4'/>",
  )
  let after = shape_svg(
    "<ellipse cx='5' cy='4' rx='3' ry='1'/><line x1='0' y1='0' x2='3' y2='2'/><polyline points='0,0 2,2'/><polygon points='4,4 5,6 6,4'/>",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "partial")
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "renderer_point_shape_raster_unproven"
    }),
  )
  assert_eq(report.atomic_differences.length(), 5)
}

///|
test "basic shape rewrites retain source facts and compare canonical geometry" {
  let before = shape_svg(
    "<rect id='round' width='10' height='6' rx='8'/><polyline id='route' points='0,0 4,4'/>",
  )
  let after = shape_svg(
    "<rect id='round' width='10' height='6' rx='5' ry='3'/><polyline id='route' points='0 0,4 4'/>",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "partial")
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "renderer_curved_shape_raster_unproven"
    }),
  )
  assert_true(report.atomic_differences.length() >= 3)
  assert_true(
    report.atomic_differences.all(difference => {
      difference.computed_relation.status == "equivalent"
    }),
  )
  assert_true(
    report.events.all(event => {
      event.rendered_outcome.magnitude.unwrap().changed_pixels == 0
    }),
  )
}

///|
test "invalid basic shape geometry cannot produce complete equality" {
  let source = shape_svg("<circle id='dot' cx='4' cy='4' r='-1'/>")
  let report = @engine.compare(
    source,
    source,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "partial")
  let diagnostics = [
    for diagnostic in report.diagnostics if diagnostic.code ==
    "basic_shape_geometry_unsupported" => diagnostic
  ]
  assert_eq(diagnostics.length(), 1)
  assert_eq(
    diagnostics[0].source_locations.map(location => location.source_role),
    ["before", "after"],
  )
  assert_true(
    diagnostics[0].source_locations.all(location => {
      location.source_span.end_offset > location.source_span.start_offset
    }),
  )
}

///|
test "valid zero geometry remains numeric and contributes no pixels" {
  let before = shape_svg("<circle id='dot' cx='4' cy='4' r='0' fill='red'/>")
  let after = shape_svg("<circle id='dot' cx='4' cy='4' fill='red'/>")
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "complete")
  assert_eq(report.atomic_differences.length(), 1)
  assert_eq(report.atomic_differences[0].source_before, "0")
  assert_eq(report.atomic_differences[0].source_after, "")
  assert_eq(report.atomic_differences[0].computed_relation.status, "equivalent")
  assert_eq(
    report.events[0].rendered_outcome.magnitude.unwrap().changed_pixels,
    0,
  )
  assert_true(report.events[0].difference_regions.is_empty())
}

///|
test "rectangle auto dimension resolves to explicit zero" {
  let before = shape_svg("<rect id='box' width='auto' height='6' fill='red'/>")
  let after = shape_svg("<rect id='box' width='0' height='6' fill='red'/>")
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "complete")
  assert_eq(report.atomic_differences.length(), 1)
  assert_eq(report.atomic_differences[0].computed_relation.status, "equivalent")
  assert_eq(
    report.events[0].rendered_outcome.magnitude.unwrap().changed_pixels,
    0,
  )
}

///|
test "odd point coordinate is recovered but remains a diagnosed error" {
  let source = shape_svg(
    "<polygon id='area' points='0,0 4,0 4,4 99' fill='red'/>",
  )
  let report = @engine.compare(
    source,
    source,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "partial")
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "basic_shape_geometry_unsupported"
    }),
  )
}

///|
test "line fill differences are source-visible and computed neutral" {
  let before = shape_svg(
    "<line id='edge' x1='1' y1='1' x2='8' y2='8' fill='red'/>",
  )
  let after = shape_svg(
    "<line id='edge' x1='1' y1='1' x2='8' y2='8' fill='blue'/>",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "complete")
  assert_eq(report.atomic_differences.length(), 1)
  assert_eq(report.atomic_differences[0].domain, "paint.fill")
  assert_eq(report.atomic_differences[0].computed_relation.status, "equivalent")
  assert_eq(
    report.events[0].rendered_outcome.magnitude.unwrap().changed_pixels,
    0,
  )
}

///|
test "polyline fill differences use implicit subpath closure" {
  let before = shape_svg(
    "<polyline id='area' points='2,2 14,2 8,14' fill='red'/>",
  )
  let after = shape_svg(
    "<polyline id='area' points='2,2 14,2 8,14' fill='blue'/>",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "partial")
  assert_eq(report.atomic_differences.length(), 1)
  assert_eq(report.atomic_differences[0].computed_relation.status, "different")
  assert_eq(
    report.events[0].rendered_outcome.magnitude.unwrap().changed_pixels,
    0,
  )
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "renderer_point_shape_raster_unproven"
    }),
  )
}

///|
test "unsupported visual attributes reduce subject coverage" {
  let source = shape_svg("<circle cx='8' cy='8' r='2' class='unresolved'/>")
  let report = @engine.compare(
    source,
    source,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "partial")
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "unsupported_visual_attribute"
    }),
  )
}

///|
test "ordinary inherited stroke changes are reported" {
  let before = shape_svg(
    "<g stroke='red'><line id='edge' x1='1' y1='1' x2='15' y2='15'/></g>",
  )
  let after = shape_svg(
    "<g stroke='blue'><line id='edge' x1='1' y1='1' x2='15' y2='15'/></g>",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_true(
    report.atomic_differences.any(difference => {
      difference.domain == "paint.stroke" &&
      difference.source_before == "red" &&
      difference.source_after == "blue"
    }),
  )
}

///|
test "incomplete inline style cannot produce complete equality" {
  let source = shape_svg(
    "<rect x='1' y='1' width='8' height='8' style='fill:red;unknown-paint:blue'/>",
  )
  let report = @engine.compare(
    source,
    source,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "partial")
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "css_cascade_unsupported"
    }),
  )
}

///|
test "group opacity is compositing rather than inherited child opacity" {
  let before = shape_svg(
    "<g opacity='1'><rect id='a' x='1' y='1' width='4' height='4'/><rect id='b' x='3' y='3' width='4' height='4'/></g>",
  )
  let after = shape_svg(
    "<g opacity='0.5'><rect id='a' x='1' y='1' width='4' height='4'/><rect id='b' x='3' y='3' width='4' height='4'/></g>",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "partial")
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "group_opacity_compositing_unsupported"
    }),
  )
  assert_true(
    report.atomic_differences.any(difference => {
      difference.domain == "compositing.opacity" &&
      difference.computed_relation.status == "indeterminate"
    }),
  )
  assert_true(
    report.events.any(event => {
      event.atomic_difference_ids.any(id => id.find("group-opacity") is Some(_)) &&
      event.difference_regions.is_empty()
    }),
  )
}

///|
test "inline group opacity is diagnosed and reported at source level" {
  let before = shape_svg(
    "<g id='layer' style='opacity:1'><rect x='1' y='1' width='4' height='4'/></g>",
  )
  let after = shape_svg(
    "<g id='layer' style='opacity:0.5'><rect x='1' y='1' width='4' height='4'/></g>",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "partial")
  assert_true(
    report.atomic_differences.any(difference => {
      difference.domain == "compositing.opacity"
    }),
  )
}

///|
test "root svg opacity is preserved as a source difference" {
  let before = "<svg width='20' height='20' opacity='1'><rect x='1' y='1' width='4' height='4'/></svg>"
  let after = "<svg width='20' height='20' opacity='0.5'><rect x='1' y='1' width='4' height='4'/></svg>"
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "partial")
  assert_true(
    report.atomic_differences.any(difference => {
      difference.domain == "compositing.opacity" &&
      difference.source_before == "1" &&
      difference.source_after == "0.5"
    }),
  )
}

///|
test "unsupported local paint values reduce coverage" {
  let source = shape_svg(
    "<rect x='1' y='1' width='8' height='8' fill='url(#gradient)'/>",
  )
  let report = @engine.compare(
    source,
    source,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "partial")
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "paint_value_semantics_unsupported"
    }),
  )
}

///|
test "gradient references outside the proven slice reduce coverage" {
  let before = shape_svg(
    "<defs><linearGradient id='paint'><stop offset='0' stop-color='red'/></linearGradient></defs><circle id='dot' cx='8' cy='8' r='3' fill='url(#paint)'/>",
  )
  let after = shape_svg(
    "<defs><linearGradient id='paint'><stop offset='0' stop-color='blue'/></linearGradient></defs><circle id='dot' cx='8' cy='8' r='3' fill='url(#paint)'/>",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "partial")
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "paint_server_analysis_unsupported"
    }),
  )
}

///|
test "equivalent stroke dash spellings retain source differences" {
  let before = shape_svg(
    "<line id='edge' x1='2' y1='10' x2='18' y2='10' stroke='black' stroke-width='2' stroke-dasharray='5,3,2' stroke-dashoffset='-1'/>",
  )
  let after = shape_svg(
    "<line id='edge' x1='2' y1='10' x2='18' y2='10' stroke='black' stroke-width='2' stroke-dasharray='5 3 2 5 3 2' stroke-dashoffset='19'/>",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.atomic_differences.length(), 2)
  assert_true(
    report.atomic_differences.all(difference => {
      difference.computed_relation.status == "equivalent"
    }),
  )
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "renderer_stroke_dash_raster_unproven"
    }),
  )
  assert_true(
    report.events.all(event => {
      event.rendered_outcome.magnitude.unwrap().changed_pixels == 0
    }),
  )
}

///|
test "inactive stroke geometry remains source visible and computed neutral" {
  let before = shape_svg(
    "<line id='edge' x1='2' y1='10' x2='18' y2='10' stroke='none' stroke-linecap='butt'/>",
  )
  let after = shape_svg(
    "<line id='edge' x1='2' y1='10' x2='18' y2='10' stroke='none' stroke-linecap='round'/>",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "complete")
  assert_eq(report.atomic_differences.length(), 1)
  assert_eq(report.atomic_differences[0].domain, "geometry.stroke_cap")
  assert_eq(report.atomic_differences[0].computed_relation.status, "equivalent")
  assert_eq(
    report.events[0].rendered_outcome.magnitude.unwrap().changed_pixels,
    0,
  )
}

///|
test "closed solid shapes ignore cap changes but retain stroke provenance" {
  let before = shape_svg(
    "<rect id='box' x='2' y='2' width='12' height='12' fill='none' stroke='black' stroke-width=' 2 ' stroke-linecap='butt'/>",
  )
  let after = shape_svg(
    "<rect id='box' x='2' y='2' width='12' height='12' fill='none' stroke='black' stroke-width='4' stroke-linecap='round'/>",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  let cap = [
      for difference in report.atomic_differences if difference.domain ==
      "geometry.stroke_cap" => difference
    ][0]
  assert_eq(cap.computed_relation.status, "equivalent")
  let width = [
      for difference in report.atomic_differences if difference.domain ==
      "geometry.stroke_width" => difference
    ][0]
  let before_fact = width.source_fact_before.unwrap()
  assert_eq(before_fact.authored_value, " 2 ")
  assert_eq(before_fact.declared_value, "2")
  assert_eq(before_fact.origin, "presentation_attribute")
  assert_true(
    before_fact.source_span.end_offset > before_fact.source_span.start_offset,
  )
  assert_eq(width.computed_relation.status, "different")
}

///|
test "zero width keeps paint changes source visible and computed neutral" {
  let before = shape_svg(
    "<line id='edge' x1='2' y1='10' x2='18' y2='10' stroke='red' stroke-width='0'/>",
  )
  let after = shape_svg(
    "<line id='edge' x1='2' y1='10' x2='18' y2='10' stroke='blue' stroke-width='0'/>",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "complete")
  assert_eq(report.atomic_differences.length(), 1)
  assert_eq(report.atomic_differences[0].domain, "paint.stroke")
  assert_eq(report.atomic_differences[0].computed_relation.status, "equivalent")
  assert_eq(
    report.events[0].rendered_outcome.magnitude.unwrap().changed_pixels,
    0,
  )
}

///|
test "invalid stroke geometry cannot produce complete equality" {
  let source = shape_svg(
    "<line id='edge' x1='2' y1='10' x2='18' y2='10' stroke='black' stroke-width='-1'/>",
  )
  let report = @engine.compare(
    source,
    source,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "partial")
  let diagnostics = [
    for diagnostic in report.diagnostics if diagnostic.code ==
    "stroke_geometry_unsupported" => diagnostic
  ]
  assert_eq(diagnostics.length(), 1)
  assert_eq(
    diagnostics[0].source_locations.map(location => location.source_role),
    ["before", "after"],
  )
}

///|
test "non-scaling stroke is a distinct computed transform effect" {
  let before = shape_svg(
    "<line id='edge' x1='2' y1='10' x2='8' y2='10' stroke='black' stroke-width='2' transform='scale(2)' vector-effect='none'/>",
  )
  let after = shape_svg(
    "<line id='edge' x1='2' y1='10' x2='8' y2='10' stroke='black' stroke-width='2' transform='scale(2)' vector-effect='non-scaling-stroke'/>",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_true(
    report.atomic_differences.any(difference => {
      difference.domain == "geometry.stroke_vector_effect" &&
      difference.computed_relation.status == "different"
    }),
  )
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "renderer_non_scaling_stroke_unproven"
    }),
  )
}

///|
test "stroke width reports parameter and transform-aware boundary magnitude" {
  let cases = [
    ("", Some(1.0)),
    (" transform='scale(2)'", Some(2.0)),
    (" transform='scale(2)' vector-effect='non-scaling-stroke'", Some(1.0)),
  ]
  for case in cases {
    let (attributes, expected_displacement) = case
    let before = shape_svg(
      "<line id='edge' x1='2' y1='10' x2='18' y2='10' stroke='black' stroke-width='2'\{attributes}/>",
    )
    let after = shape_svg(
      "<line id='edge' x1='2' y1='10' x2='18' y2='10' stroke='black' stroke-width='4'\{attributes}/>",
    )
    let report = @engine.compare(
      before,
      after,
      @engine.ComparisonProfile::v1_default(),
    )
    let differences = [
      for difference in report.atomic_differences if difference.domain ==
      "geometry.stroke_width" => difference
    ]
    assert_eq(differences.length(), 1)
    assert_eq(differences[0].magnitude.parameter_signed_user_units, Some(2.0))
    assert_eq(differences[0].magnitude.parameter_abs_user_units, Some(2.0))
    assert_eq(
      differences[0].magnitude.geometry_displacement_css_px,
      expected_displacement,
    )
  }
}

///|
test "stroke scalar controls do not masquerade as spatial displacement" {
  let before = shape_svg(
    "<polyline id='edge' points='2,14 8,2 14,14' fill='none' stroke='black' stroke-dasharray='2 2' stroke-dashoffset='0'/>",
  )
  let after = shape_svg(
    "<polyline id='edge' points='2,14 8,2 14,14' fill='none' stroke='black' stroke-dasharray='2 2' stroke-dashoffset='1'/>",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  let difference = report.atomic_differences[0]
  assert_eq(difference.domain, "geometry.stroke_dash_offset")
  assert_eq(difference.magnitude.parameter_abs_user_units, Some(1.0))
  assert_true(difference.magnitude.geometry_displacement_css_px is None)
}
