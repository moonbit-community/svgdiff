///|
test "SVG lengths resolve absolute CSS units without losing precision" {
  let viewport : ViewportContext = { width: 200.0, height: 100.0 }
  let profile = {
    ..ComparisonProfile::v1_default(),
    viewport_width: 200,
    viewport_height: 100,
  }
  assert_eq(parse_svg_length("96", Horizontal, viewport, profile), Some(96.0))
  assert_eq(parse_svg_length("96px", Horizontal, viewport, profile), Some(96.0))
  assert_eq(parse_svg_length("1in", Horizontal, viewport, profile), Some(96.0))
  assert_eq(
    parse_svg_length("2.54cm", Horizontal, viewport, profile),
    Some(96.0),
  )
  assert_eq(
    parse_svg_length("25.4mm", Horizontal, viewport, profile),
    Some(96.0),
  )
  assert_eq(
    parse_svg_length("101.6Q", Horizontal, viewport, profile),
    Some(96.0),
  )
  assert_eq(parse_svg_length("72pt", Horizontal, viewport, profile), Some(96.0))
  assert_eq(parse_svg_length("6pc", Horizontal, viewport, profile), Some(96.0))
}

///|
test "SVG percentages use directional nearest viewport bases" {
  let viewport : ViewportContext = { width: 200.0, height: 100.0 }
  let profile = {
    ..ComparisonProfile::v1_default(),
    viewport_width: 800,
    viewport_height: 600,
  }
  assert_eq(parse_svg_length("25%", Horizontal, viewport, profile), Some(50.0))
  assert_eq(parse_svg_length("25%", Vertical, viewport, profile), Some(25.0))
  let diagonal = parse_svg_length("100%", Unspecified, viewport, profile).unwrap()
  assert_true((diagonal - 158.11388300841895).abs() < 0.000000000001)
}

///|
test "SVG viewport units use the explicit initial comparison viewport" {
  let nested : ViewportContext = { width: 20.0, height: 10.0 }
  let profile = {
    ..ComparisonProfile::v1_default(),
    viewport_width: 800,
    viewport_height: 600,
  }
  assert_eq(parse_svg_length("10vw", Horizontal, nested, profile), Some(80.0))
  assert_eq(parse_svg_length("10vh", Vertical, nested, profile), Some(60.0))
  assert_eq(
    parse_svg_length("10vmin", Unspecified, nested, profile),
    Some(60.0),
  )
  assert_eq(
    parse_svg_length("10vmax", Unspecified, nested, profile),
    Some(80.0),
  )
}

///|
test "environment-dependent and arithmetic SVG lengths remain unsupported" {
  let viewport : ViewportContext = { width: 200.0, height: 100.0 }
  let profile = {
    ..ComparisonProfile::v1_default(),
    viewport_width: 200,
    viewport_height: 100,
  }
  for
    source in [
      "1em", "1ex", "1rem", "1svw", "1dvh", "1vi", "calc(1px + 1%)", "1 px",
    ] {
    assert_true(parse_svg_length(source, Horizontal, viewport, profile) is None)
  }
}

///|
test "equivalent authored shape units remain source-visible and computed-equivalent" {
  let before =
    #|<svg xmlns="http://www.w3.org/2000/svg"><line id="edge" x1="1in" y1="25%" x2="12" y2="12"/></svg>
  let after =
    #|<svg xmlns="http://www.w3.org/2000/svg"><line id="edge" x1="96px" y1="4" x2="12" y2="12"/></svg>
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "complete")
  let geometry = report.atomic_differences.filter(fn(difference) {
    let property = difference.source_fact_before.map(fact => fact.property)
    property == Some("x1") || property == Some("y1")
  })
  assert_eq(geometry.length(), 2)
  for difference in geometry {
    assert_eq(difference.computed_relation.status, "equivalent")
    assert_eq(difference.parameter_delta_css_px, Some(0.0))
    assert_eq(
      difference.source_fact_before.unwrap().authored_value,
      if difference.source_fact_before.unwrap().property == "x1" {
        "1in"
      } else {
        "25%"
      },
    )
  }
}

///|
test "nested SVG percentages use the nearest viewBox user dimensions" {
  let source =
    #|<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16"><svg width="8" height="8" viewBox="0 0 200 100"><circle id="dot" cx="25%" cy="25%" r="10%" fill="red"/></svg></svg>
  let subject = extract_source_subjects_or_raise(source)[0]
  assert_eq(subject_value(subject, "cx"), Some("50"))
  assert_eq(subject_value(subject, "cy"), Some("25"))
  let radius = parse_shape_number(subject_value(subject, "r").unwrap()).unwrap()
  assert_true((radius - 15.811388300841896).abs() < 0.000000000001)
}

///|
test "stroke lengths share absolute percentage and viewport resolution" {
  let profile = {
    ..ComparisonProfile::v1_default(),
    viewport_width: 200,
    viewport_height: 100,
  }
  let viewport : ViewportContext = { width: 200.0, height: 100.0 }
  let resolution = resolve_stroke_geometry_with_context(
    [
      stroke_geometry_test_fact("stroke-width", "1in"),
      stroke_geometry_test_fact("stroke-dasharray", "10% 1cm"),
      stroke_geometry_test_fact("stroke-dashoffset", "10vw"),
    ],
    viewport,
    profile,
  )
  assert_true(resolution.complete)
  assert_eq(stroke_geometry_value(resolution, "stroke-width"), "96")
  let dash = stroke_geometry_value(resolution, "stroke-dasharray")
  assert_true(dash.find("15.811388300841") is Some(_))
  assert_true(dash.find("37.795275590551") is Some(_))
  assert_eq(stroke_geometry_value(resolution, "stroke-dashoffset"), "20")
}

///|
test "equivalent authored stroke units retain a source-only distinction" {
  let before =
    #|<svg xmlns="http://www.w3.org/2000/svg"><line id="edge" x1="1" y1="8" x2="15" y2="8" stroke="black" stroke-width="1in"/></svg>
  let after =
    #|<svg xmlns="http://www.w3.org/2000/svg"><line id="edge" x1="1" y1="8" x2="15" y2="8" stroke="black" stroke-width="96px"/></svg>
  let report = compare(before, after, ComparisonProfile::v1_default())
  let difference = report.atomic_differences.filter(fn(difference) {
      difference.domain == "geometry.stroke_width"
    })[0]
  assert_eq(difference.computed_relation.status, "equivalent")
  assert_eq(difference.parameter_delta_css_px, Some(0.0))
  assert_eq(difference.source_fact_before.unwrap().authored_value, "1in")
  assert_eq(difference.source_fact_after.unwrap().authored_value, "96px")
}

///|
test "marker lengths use containing SVG and initial viewport contexts" {
  let profile = {
    ..ComparisonProfile::v1_default(),
    viewport_width: 200,
    viewport_height: 100,
  }
  let source =
    #|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 200"><defs><marker id="m" markerWidth="25%" markerHeight="25%" refX="1in" refY="10vh"/></defs></svg>
  let resource = extract_marker_resources_or_raise(source, profile)[0]
  assert_true(resource.complete)
  assert_eq(resource.marker_width, 100.0)
  assert_eq(resource.marker_height, 50.0)
  assert_eq(resource.ref_x, 96.0)
  assert_eq(resource.ref_y, 10.0)
}

///|
test "equivalent authored marker units remain source-visible" {
  let before =
    #|<svg xmlns="http://www.w3.org/2000/svg"><defs><marker id="m" markerWidth="1in"/></defs></svg>
  let after =
    #|<svg xmlns="http://www.w3.org/2000/svg"><defs><marker id="m" markerWidth="96px"/></defs></svg>
  let report = compare(before, after, ComparisonProfile::v1_default())
  let difference = report.atomic_differences.filter(fn(difference) {
      difference.domain == "resource.marker.viewport_size"
    })[0]
  assert_eq(difference.computed_relation.status, "equivalent")
  assert_eq(difference.parameter_delta_css_px, Some(0.0))
  assert_eq(difference.source_fact_before.unwrap().authored_value, "1in")
  assert_eq(difference.source_fact_after.unwrap().authored_value, "96px")
}

///|
test "equivalent nested viewport units preserve the authored distinction" {
  let before =
    #|<svg xmlns="http://www.w3.org/2000/svg"><svg width="1in" height="16"><line id="edge" x1="0" y1="0" x2="16" y2="16"/></svg></svg>
  let after =
    #|<svg xmlns="http://www.w3.org/2000/svg"><svg width="96px" height="16"><line id="edge" x1="0" y1="0" x2="16" y2="16"/></svg></svg>
  let report = compare(before, after, ComparisonProfile::v1_default())
  let difference = report.atomic_differences.filter(fn(difference) {
      difference.domain == "document.viewport" &&
      difference.source_fact_before.map(fact => fact.property) == Some("width")
    })[0]
  assert_eq(difference.computed_relation.status, "equivalent")
  assert_eq(difference.source_fact_before.unwrap().authored_value, "1in")
  assert_eq(difference.source_fact_after.unwrap().authored_value, "96px")
}

///|
test "resolved unit changes retain transform-aware CSS displacement" {
  let before =
    #|<svg xmlns="http://www.w3.org/2000/svg"><line id="edge" transform="scale(2)" x1="1in" y1="4" x2="100" y2="4"/></svg>
  let after =
    #|<svg xmlns="http://www.w3.org/2000/svg"><line id="edge" transform="scale(2)" x1="97px" y1="4" x2="100" y2="4"/></svg>
  let report = compare(before, after, ComparisonProfile::v1_default())
  let difference = report.atomic_differences.filter(fn(difference) {
      difference.source_fact_before.map(fact => fact.property) == Some("x1")
    })[0]
  assert_eq(difference.computed_relation.status, "different")
  assert_eq(difference.parameter_delta_css_px, Some(1.0))
  assert_eq(difference.magnitude.geometry_displacement_css_px, Some(2.0))
}

///|
test "single rectangles use canonical length semantics instead of raw renderer facts" {
  let before =
    #|<svg xmlns="http://www.w3.org/2000/svg"><rect id="box" x="1in" y="4" width="1in" height="4" fill="red"/></svg>
  let after =
    #|<svg xmlns="http://www.w3.org/2000/svg"><rect id="box" x="96px" y="4" width="96px" height="4" fill="red"/></svg>
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "complete")
  let differences = report.atomic_differences.filter(fn(difference) {
    difference.domain == "geometry.position" ||
    difference.domain == "geometry.size"
  })
  assert_eq(differences.length(), 2)
  assert_true(
    differences.all(difference => {
      difference.computed_relation.status == "equivalent" &&
      difference.parameter_delta_css_px == Some(0.0)
    }),
  )
}
