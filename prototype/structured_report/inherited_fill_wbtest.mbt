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
      match resolved_fill_for_subject(hierarchy, "box") {
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
      match resolved_fill_for_subject(hierarchy, "local") {
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
      match resolved_fill_for_subject(hierarchy, "box") {
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
