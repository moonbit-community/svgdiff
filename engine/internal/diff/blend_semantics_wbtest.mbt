///|
fn blend_test_profile() -> ComparisonProfile {
  { ..ComparisonProfile::v1_default(), viewport_width: 8, viewport_height: 8 }
}

///|
fn render_blend_test_source(source : String) -> @svg.Image? {
  render_product_source_to_image(source, blend_test_profile())
}

///|
test "blend keywords cover the complete Level 1 set" {
  for
    keyword in [
      "normal", "multiply", "screen", "overlay", "darken", "lighten", "color-dodge",
      "color-burn", "hard-light", "soft-light", "difference", "exclusion", "hue",
      "saturation", "color", "luminosity",
    ] {
    assert_true(blend_mode_from_keyword(keyword) is Some(_))
  }
  assert_true(blend_mode_from_keyword("plus-lighter") is None)
}

///|
test "blend and isolation are non-inherited computed properties" {
  let source =
    #|<svg id="root" style="mix-blend-mode:multiply;isolation:isolate">
    #|  <style>#styled { mix-blend-mode: var(--mode); isolation: initial }</style>
    #|  <g id="parent" style="--mode:screen;mix-blend-mode:overlay;isolation:isolate">
    #|    <rect id="plain" width="4" height="4"/>
    #|    <rect id="styled" width="4" height="4"/>
    #|  </g>
    #|</svg>
  let hierarchy = extract_fill_hierarchy_or_raise(source)
  assert_eq(
    computed_visual_for_subject(hierarchy, "plain", "mix-blend-mode").unwrap().reported.resolved_value,
    "normal",
  )
  assert_eq(
    computed_visual_for_subject(hierarchy, "plain", "isolation").unwrap().reported.resolved_value,
    "auto",
  )
  assert_eq(
    computed_visual_for_subject(hierarchy, "styled", "mix-blend-mode").unwrap().reported.resolved_value,
    "screen",
  )
  assert_eq(
    computed_visual_for_subject(hierarchy, "styled", "isolation").unwrap().reported.resolved_value,
    "auto",
  )
}

///|
test "blend cascade covers presentation inline stylesheet CSS-wide and variables" {
  let source =
    #|<svg id="root" style="mix-blend-mode:multiply;isolation:isolate">
    #|  <style>#box { --chosen:screen; mix-blend-mode:var(--chosen)!important; isolation:unset }</style>
    #|  <rect id="box" width="4" height="4" mix-blend-mode="overlay" style="mix-blend-mode:color-burn"/>
    #|</svg>
  let hierarchy = extract_fill_hierarchy_or_raise(source)
  let root_blend = computed_visual_for_subject(
    hierarchy, "root", "mix-blend-mode",
  ).unwrap()
  let root_isolation = computed_visual_for_subject(
    hierarchy, "root", "isolation",
  ).unwrap()
  let box_blend = computed_visual_for_subject(
    hierarchy, "box", "mix-blend-mode",
  ).unwrap()
  let box_isolation = computed_visual_for_subject(hierarchy, "box", "isolation").unwrap()
  assert_eq(root_blend.reported.resolved_value, "multiply")
  assert_eq(
    root_blend.reported.declaration.map(fact => fact.origin),
    Some("inline_style"),
  )
  assert_eq(root_isolation.reported.resolved_value, "isolate")
  assert_eq(box_blend.reported.resolved_value, "screen")
  assert_eq(
    box_blend.reported.declaration.map(fact => fact.origin),
    Some("stylesheet_rule"),
  )
  assert_eq(box_isolation.reported.resolved_value, "auto")
}

///|
test "same-named SVG attributes do not enter the CSS cascade" {
  let source = "<svg id='root' mix-blend-mode='multiply' isolation='isolate'><rect id='box' width='4' height='4' mix-blend-mode='screen' isolation='isolate'/></svg>"
  let hierarchy = extract_fill_hierarchy_or_raise(source)
  for owner_id in ["root", "box"] {
    assert_eq(
      computed_visual_for_subject(hierarchy, owner_id, "mix-blend-mode").unwrap().reported.resolved_value,
      "normal",
    )
    assert_eq(
      computed_visual_for_subject(hierarchy, owner_id, "isolation").unwrap().reported.resolved_value,
      "auto",
    )
  }
}

///|
test "opaque blend formulas and transparent backdrop are exact" {
  let expected = [
    (100, 150, 200),
    (78, 59, 39),
    (222, 191, 211),
    (188, 118, 78),
    (100, 100, 50),
    (200, 150, 200),
    (255, 243, 232),
    (115, 0, 0),
    (157, 127, 167),
    (191, 111, 86),
    (100, 50, 150),
    (143, 132, 172),
    (64, 139, 214),
    (175, 108, 75),
    (84, 134, 184),
    (216, 116, 66),
  ]
  for
    index, keyword in [
      "normal", "multiply", "screen", "overlay", "darken", "lighten", "color-dodge",
      "color-burn", "hard-light", "soft-light", "difference", "exclusion", "hue",
      "saturation", "color", "luminosity",
    ] {
    let source = "<svg width='8' height='8'><rect id='back' width='4' height='4' fill='#c86432'/><rect id='front' x='2' y='2' width='4' height='4' fill='#6496c8' style='mix-blend-mode:\{keyword}'/></svg>"
    guard render_blend_test_source(source) is Some(image) else {
      fail("expected product render for {keyword}")
    }
    let overlap = group_compositor_test_pixel(image, 2, 2)
    assert_eq(overlap.r, expected[index].0)
    assert_eq(overlap.g, expected[index].1)
    assert_eq(overlap.b, expected[index].2)
    assert_eq(overlap.a, 255)
    assert_group_compositor_pixel(image, 5, 5, 100, 150, 200, 255)
  }
  let multiply = "<svg width='8' height='8'><rect id='back' width='4' height='4' fill='#c86432'/><rect id='front' x='2' y='2' width='4' height='4' fill='#6496c8' style='mix-blend-mode:multiply'/></svg>"
  guard render_blend_test_source(multiply) is Some(image) else {
    fail("expected multiply product render")
  }
  assert_group_compositor_pixel(image, 2, 2, 78, 59, 39, 255)
}

///|
test "ordinary groups expose and isolated groups reset the backdrop" {
  let automatic =
    #|<svg width="8" height="8">
    #|  <rect id="back" width="8" height="8" fill="lime"/>
    #|  <g id="layer"><rect id="front" width="4" height="4" fill="red" style="mix-blend-mode:multiply"/></g>
    #|</svg>
  let isolated =
    #|<svg width="8" height="8">
    #|  <rect id="back" width="8" height="8" fill="lime"/>
    #|  <g id="layer" style="isolation:isolate"><rect id="front" width="4" height="4" fill="red" style="mix-blend-mode:multiply"/></g>
    #|</svg>
  guard render_blend_test_source(automatic) is Some(auto_image) &&
    render_blend_test_source(isolated) is Some(isolated_image) else {
    fail("expected group product renders")
  }
  assert_group_compositor_pixel(auto_image, 1, 1, 0, 0, 0, 255)
  assert_group_compositor_pixel(isolated_image, 1, 1, 255, 0, 0, 255)
  assert_group_compositor_pixel(isolated_image, 6, 6, 0, 255, 0, 255)
}

///|
test "blend reports categorical values and conservative backdrop causes" {
  let before = "<svg width='8' height='8'><rect id='back' width='8' height='8' fill='#c86432'/><rect id='front' width='4' height='4' fill='#6496c8' style='mix-blend-mode:multiply'/></svg>"
  let after = "<svg width='8' height='8'><rect id='back' width='8' height='8' fill='#c86432'/><rect id='front' width='4' height='4' fill='#6496c8' style='mix-blend-mode:screen'/></svg>"
  let report = compare(before, after, blend_test_profile())
  assert_eq(report.analysis_status, "complete")
  guard report.atomic_differences.filter(difference => {
      difference.domain == "compositing.blend_mode"
    })
    is [difference] else {
    fail("expected one blend-mode difference")
  }
  assert_eq(difference.computed_relation.status, "different")
  assert_eq(difference.magnitude.parameter_abs_user_units, None)
  assert_eq(difference.magnitude.parameter_signed_user_units, None)
  guard report.changed_facts.filter(fact => {
      fact.id == difference.changed_fact_ids[0]
    })
    is [fact] else {
    fail("expected blend changed fact")
  }
  assert_true(fact.affected_subject_ids.contains("front"))
  assert_true(fact.affected_subject_ids.contains("back"))
  guard report.events.filter(event => {
      event.atomic_difference_ids.contains(difference.id)
    })
    is [event] else {
    fail("expected blend event")
  }
  assert_eq(event.rendered_outcome.status, "computed")
  assert_true(
    event.rendered_outcome.magnitude
    .map(value => value.changed_pixels > 0)
    .unwrap_or(false),
  )
  assert_true(
    event.difference_regions.all(region => {
      report.changed_facts.all(changed => {
        region.cause_envelope.candidate_changed_fact_ids.contains(changed.id)
      })
    }),
  )
}

///|
test "equivalent blend spellings retain source evidence without visual change" {
  let before = "<svg width='8' height='8'><rect id='back' width='8' height='8' fill='lime'/><rect id='front' width='4' height='4' fill='red' style='mix-blend-mode:multiply'/></svg>"
  let after = "<svg width='8' height='8'><rect id='back' width='8' height='8' fill='lime'/><rect id='front' width='4' height='4' fill='red' style='mix-blend-mode: MULTIPLY'/></svg>"
  let report = compare(before, after, blend_test_profile())
  assert_eq(report.analysis_status, "complete")
  guard report.atomic_differences.filter(difference => {
      difference.domain == "compositing.blend_mode"
    })
    is [difference] else {
    fail("expected equivalent blend source difference")
  }
  assert_eq(difference.computed_relation.status, "equivalent")
  guard report.events.filter(event => {
      event.atomic_difference_ids.contains(difference.id)
    })
    is [event] else {
    fail("expected equivalent blend event")
  }
  assert_eq(
    event.rendered_outcome.magnitude.map(value => value.changed_pixels),
    Some(0),
  )
}

///|
test "isolation changes are typed and structural stacking uses blend pixels" {
  let automatic = "<svg width='8' height='8'><rect id='back' width='8' height='8' fill='lime'/><g id='layer' style='isolation:auto'><rect id='front' width='4' height='4' fill='red' style='mix-blend-mode:multiply'/></g></svg>"
  let isolated = "<svg width='8' height='8'><rect id='back' width='8' height='8' fill='lime'/><g id='layer' style='isolation:isolate'><rect id='front' width='4' height='4' fill='red' style='mix-blend-mode:multiply'/></g></svg>"
  let isolation_report = compare(automatic, isolated, blend_test_profile())
  assert_eq(isolation_report.analysis_status, "complete")
  assert_true(
    isolation_report.atomic_differences.any(difference => {
      difference.domain == "compositing.isolation" &&
      difference.computed_relation.status == "different"
    }),
  )

  let before = "<svg width='8' height='8'><rect id='back' width='8' height='8' fill='lime'/><rect id='front' width='4' height='4' fill='red' style='mix-blend-mode:multiply'/></svg>"
  let after = "<svg width='8' height='8'><rect id='front' width='4' height='4' fill='red' style='mix-blend-mode:multiply'/><rect id='back' width='8' height='8' fill='lime'/></svg>"
  let stacking = compare(before, after, blend_test_profile())
  assert_eq(stacking.analysis_status, "complete")
  assert_true(
    stacking.atomic_differences.any(difference => {
      difference.domain == "document.structure.stacking_order"
    }),
  )
}

///|
test "unsupported blend boundaries retain precise diagnostics" {
  let cases = [
    (
      "<svg><circle id='front' cx='4' cy='4' r='3' style='mix-blend-mode:multiply'/></svg>",
      "blend_backdrop_unsupported",
    ),
    (
      "<svg><rect id='back' width='8' height='8' fill='red' fill-opacity='0.5'/><rect id='front' width='4' height='4' style='mix-blend-mode:multiply'/></svg>",
      "blend_alpha_unsupported",
    ),
    (
      "<svg><rect id='back' width='8' height='8' fill='rgba(255,0,0,0.5)'/><rect id='front' width='4' height='4' style='mix-blend-mode:multiply'/></svg>",
      "blend_alpha_unsupported",
    ),
    (
      "<svg><g id='layer' style='mix-blend-mode:multiply'><rect id='front' width='4' height='4'/></g></svg>",
      "blend_container_mode_unsupported",
    ),
    (
      "<svg><g style='isolation:isolate'><rect id='front' width='4' height='4' style='mix-blend-mode:multiply'/></g></svg>",
      "isolation_host_unsupported",
    ),
    (
      "<svg><rect id='front' width='4' height='4' style='mix-blend-mode:plus-lighter'/></svg>",
      "blend_mode_invalid",
    ),
    (
      "<svg><rect id='front' width='4' height='4' transform='translate(1 0)' style='mix-blend-mode:multiply'/></svg>",
      "blend_transform_unproven",
    ),
  ]
  for case in cases {
    let diagnostics : Array[Diagnostic] = []
    append_blend_diagnostics(
      case.0,
      blend_test_profile(),
      "before",
      diagnostics,
    )
    assert_true(diagnostics.any(diagnostic => diagnostic.code == case.1))
  }
}

///|
test "blend intermediate work has a fixed aggregate pixel budget" {
  let source = "<svg width='8193' height='8192'><rect id='front' width='4' height='4' style='mix-blend-mode:multiply'/></svg>"
  let diagnostics : Array[Diagnostic] = []
  append_blend_diagnostics(
    source,
    {
      ..ComparisonProfile::v1_default(),
      viewport_width: 8193,
      viewport_height: 8192,
    },
    "before",
    diagnostics,
  )
  assert_true(
    diagnostics.any(diagnostic => {
      diagnostic.code == "blend_surface_budget_exceeded"
    }),
  )
}
