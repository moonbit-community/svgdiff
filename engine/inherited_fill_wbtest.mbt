///|
fn resolved_fill_declaration_slice(
  source : String,
  resolution : ResolvedVisualFact,
) -> String? {
  match resolution.declaration {
    Some(fact) =>
      Some(
        source_range_slice(
          source,
          fact.source_span.start_offset,
          fact.source_span.end_offset,
        ),
      )
    None => None
  }
}

///|
fn canonical_test_visual_value(property : String, value : String) -> String {
  if ["color", "fill", "stroke", "stop-color"].contains(property) {
    match @css_color.parse_solid_color(value) {
      Resolved(color) => color.signature()
      _ => value
    }
  } else if property == "paint-order" {
    canonical_paint_order(value).unwrap_or(value)
  } else if property == "fill-rule" || property == "clip-rule" {
    canonical_winding_rule(value).unwrap_or(value)
  } else {
    value
  }
}

///|
test "fill resolves through the nearest authored ancestor" {
  let source = "<svg id='root' fill='black'><g id='outer' fill='red'><g id='inner' fill='yellow' style='fill: blue'><rect id='box'/><rect id='local' fill='green'/></g></g></svg>"
  match extract_fill_hierarchy(source) {
    ParsedFillHierarchy(hierarchy) => {
      match resolved_visual_for_subject(hierarchy, "box", "fill") {
        Some(resolution) => {
          assert_eq(resolution.resolved_value, "rgba(0,0,255,1)")
          assert_eq(resolution.resolution, "inherited")
          assert_eq(resolution.declaration_owner_id, Some("inner"))
          assert_eq(resolution.inheritance_depth, 1)
          match resolution.declaration {
            Some(fact) => assert_eq(fact.origin, "inline_style")
            None => fail("expected the inherited declaration")
          }
          assert_eq(
            resolved_fill_declaration_slice(source, resolution),
            Some("blue"),
          )
        }
        None => fail("expected an inherited fill")
      }
      match resolved_visual_for_subject(hierarchy, "local", "fill") {
        Some(resolution) => {
          assert_eq(resolution.resolved_value, "rgba(0,128,0,1)")
          assert_eq(resolution.resolution, "local")
          assert_eq(resolution.declaration_owner_id, Some("local"))
          assert_eq(resolution.inheritance_depth, 0)
        }
        None => fail("expected a local fill")
      }
    }
    _ => fail("expected the source hierarchy")
  }
}

///|
test "undeclared fill resolves to the SVG initial value" {
  let source = "<svg><g><rect id='box'/></g></svg>"
  match extract_fill_hierarchy(source) {
    ParsedFillHierarchy(hierarchy) =>
      match resolved_visual_for_subject(hierarchy, "box", "fill") {
        Some(resolution) => {
          assert_eq(resolution.resolved_value, "rgba(0,0,0,1)")
          assert_eq(resolution.resolution, "initial")
          assert_eq(resolution.declaration_owner_id, None)
          assert_eq(resolution.inheritance_depth, 0)
          assert_true(resolution.declaration is None)
        }
        None => fail("expected the initial fill")
      }
    _ => fail("expected the source hierarchy")
  }
}

///|
test "every admitted ordinary inherited property uses the nearest ancestor" {
  let source = "<svg id='root' color='green' fill='red' fill-opacity='0.5' fill-rule='evenodd' stroke='black' stroke-opacity='0.75' stroke-width='2' stroke-linecap='round' stroke-linejoin='bevel' stroke-miterlimit='3' stroke-dasharray='2 1' stroke-dashoffset='4' marker-start='url(#start)' marker-mid='url(#mid)' marker-end='url(#end)' paint-order='stroke fill' clip-rule='evenodd'><g id='near' stroke-width='5'><path id='edge' d='M0 0 L8 8'/></g></svg>"
  match extract_fill_hierarchy(source) {
    ParsedFillHierarchy(hierarchy) =>
      for property in inherited_visual_properties() {
        let resolution = resolved_visual_for_subject(
          hierarchy, "edge", property,
        ).unwrap()
        assert_eq(resolution.resolution, "inherited")
        assert_eq(
          resolution.declaration_owner_id,
          Some(if property == "stroke-width" { "near" } else { "root" }),
        )
        assert_eq(
          resolution.inheritance_depth,
          if property == "stroke-width" {
            1
          } else {
            2
          },
        )
        assert_true(resolution.declaration is Some(_))
      }
    _ => fail("expected the source hierarchy")
  }
}

///|
test "CSS-wide keywords cover every supported computed property" {
  let samples = [
    ("x", "3"),
    ("y", "3"),
    ("width", "3"),
    ("height", "3"),
    ("rx", "3"),
    ("ry", "3"),
    ("cx", "3"),
    ("cy", "3"),
    ("r", "3"),
    ("x1", "3"),
    ("y1", "3"),
    ("x2", "3"),
    ("y2", "3"),
    ("points", "1 1 2 2"),
    ("color", "red"),
    ("fill", "red"),
    ("fill-rule", "evenodd"),
    ("stroke", "red"),
    ("stroke-width", "3"),
    ("stroke-linecap", "round"),
    ("stroke-linejoin", "bevel"),
    ("stroke-miterlimit", "5"),
    ("stroke-dasharray", "2 1"),
    ("stroke-dashoffset", "3"),
    ("vector-effect", "non-scaling-stroke"),
    ("opacity", "0.5"),
    ("marker", "url(#m)"),
    ("marker-start", "url(#m)"),
    ("marker-mid", "url(#m)"),
    ("marker-end", "url(#m)"),
    ("paint-order", "stroke fill"),
    ("clip-rule", "evenodd"),
  ]
  for entry in samples {
    let (property, parent_value) = entry
    for keyword in ["inherit", "initial", "unset", "revert"] {
      let source = "<svg id='root' style='\{property}:\{parent_value}'><rect id='box' style='\{property}:\{keyword}'/></svg>"
      guard extract_fill_hierarchy(source) is ParsedFillHierarchy(hierarchy) else {
        fail("expected hierarchy for \{property}:\{keyword}")
      }
      let resolution = resolved_visual_for_subject(hierarchy, "box", property).unwrap()
      let inherited = inherited_visual_properties().contains(property)
      let expected = if keyword == "inherit" ||
        ((keyword == "unset" || keyword == "revert") && inherited) {
        parent_value
      } else {
        initial_visual_value(property)
      }
      assert_eq(
        resolution.resolved_value,
        canonical_test_visual_value(property, expected),
      )
      assert_eq(
        resolution.resolution,
        if keyword == "inherit" ||
          ((keyword == "unset" || keyword == "revert") && inherited) {
          "explicit_\{keyword}_inherit"
        } else {
          "explicit_\{keyword}_initial"
        },
      )
      assert_eq(resolution.declaration_owner_id, Some("box"))
      assert_eq(resolution.declaration.unwrap().declared_value, keyword)
    }
    let root_source = "<svg id='root' style='\{property}:inherit'/>"
    guard extract_fill_hierarchy(root_source) is ParsedFillHierarchy(root) else {
      fail("expected root hierarchy for \{property}:inherit")
    }
    let root_resolution = resolved_visual_for_subject(root, "root", property).unwrap()
    assert_eq(root_resolution.resolved_value, initial_visual_value(property))
    assert_eq(root_resolution.resolution, "explicit_inherit_initial")
    assert_eq(root_resolution.declaration_owner_id, Some("root"))
  }
}

///|
test "custom properties feed every supported computed property" {
  let samples = [
    ("x", "3"),
    ("y", "3"),
    ("width", "3"),
    ("height", "3"),
    ("rx", "3"),
    ("ry", "3"),
    ("cx", "3"),
    ("cy", "3"),
    ("r", "3"),
    ("x1", "3"),
    ("y1", "3"),
    ("x2", "3"),
    ("y2", "3"),
    ("points", "1 1 2 2"),
    ("color", "red"),
    ("fill", "red"),
    ("fill-rule", "evenodd"),
    ("stroke", "red"),
    ("stroke-width", "3"),
    ("stroke-linecap", "round"),
    ("stroke-linejoin", "bevel"),
    ("stroke-miterlimit", "5"),
    ("stroke-dasharray", "2 1"),
    ("stroke-dashoffset", "3"),
    ("vector-effect", "non-scaling-stroke"),
    ("opacity", "0.5"),
    ("marker", "url(#m)"),
    ("marker-start", "url(#m)"),
    ("marker-mid", "url(#m)"),
    ("marker-end", "url(#m)"),
    ("paint-order", "stroke fill"),
    ("clip-rule", "evenodd"),
  ]
  for entry in samples {
    let (property, value) = entry
    let source = "<svg style='--value:\{value}'><rect id='box' style='\{property}:var(--value)'/></svg>"
    guard extract_fill_hierarchy(source) is ParsedFillHierarchy(hierarchy) else {
      fail("expected hierarchy for \{property}:var(--value)")
    }
    let resolution = resolved_visual_for_subject(hierarchy, "box", property).unwrap()
    assert_eq(
      resolution.resolved_value,
      canonical_test_visual_value(property, value),
    )
    assert_eq(resolution.declaration.unwrap().declared_value, "var(--value)")
  }
}

///|
test "currentColor resolves supported stroke paint" {
  let source = "<svg color='red'><rect id='box' stroke='currentColor'/></svg>"
  guard extract_fill_hierarchy(source) is ParsedFillHierarchy(hierarchy) else {
    fail("expected currentColor hierarchy")
  }
  let stroke = resolved_visual_for_subject(hierarchy, "box", "stroke").unwrap()
  assert_eq(stroke.resolved_value, "rgba(255,0,0,1)")
  assert_eq(stroke.declaration.unwrap().declared_value, "currentColor")
}

///|
test "marker resource children are not scene inheritance subjects" {
  let source = "<svg><defs><marker id='tip'><path id='resource-path' d='M0 0 L1 1'/></marker></defs><g fill='red'><path id='host' d='M0 0 L8 8'/></g></svg>"
  match extract_fill_hierarchy(source) {
    ParsedFillHierarchy(hierarchy) =>
      assert_eq(hierarchy.rect_subject_ids, ["host"])
    _ => fail("expected the source hierarchy")
  }
}

///|
test "ordinary inheritance keeps non-inherited properties local" {
  let source = "<svg opacity='0.25' vector-effect='non-scaling-stroke'><g opacity='0.5' vector-effect='non-scaling-stroke'><rect id='box'/></g></svg>"
  match extract_fill_hierarchy(source) {
    ParsedFillHierarchy(hierarchy) => {
      assert_eq(
        resolved_visual_for_subject(hierarchy, "box", "opacity").unwrap().resolved_value,
        "1",
      )
      assert_eq(
        resolved_visual_for_subject(hierarchy, "box", "vector-effect").unwrap().resolved_value,
        "none",
      )
    }
    _ => fail("expected the source hierarchy")
  }
}
