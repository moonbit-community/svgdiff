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
test "fill resolves through the nearest authored ancestor" {
  let source = "<svg id='root' fill='black'><g id='outer' fill='red'><g id='inner' fill='yellow' style='fill: blue'><rect id='box'/><rect id='local' fill='green'/></g></g></svg>"
  match extract_fill_hierarchy(source) {
    ParsedFillHierarchy(hierarchy) => {
      match resolved_visual_for_subject(hierarchy, "box", "fill") {
        Some(resolution) => {
          assert_eq(resolution.resolved_value, "blue")
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
          assert_eq(resolution.resolved_value, "green")
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
          assert_eq(resolution.resolved_value, "black")
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
  let source = "<svg id='root' fill='red' stroke='black' stroke-width='2' stroke-linecap='round' stroke-linejoin='bevel' stroke-miterlimit='3' stroke-dasharray='2 1' stroke-dashoffset='4' marker-start='url(#start)' marker-mid='url(#mid)' marker-end='url(#end)'><g id='near' stroke-width='5'><path id='edge' d='M0 0 L8 8'/></g></svg>"
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
