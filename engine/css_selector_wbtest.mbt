///|
fn selector_test_node_by_id(
  document : CssStaticDocument,
  id : String,
) -> Int raise {
  for index, node in document.nodes {
    if css_selector_attribute(node, "id") == Some(id) {
      return index
    }
  }
  fail("missing selector test node: " + id)
}

///|
fn selector_test_matches(
  document : CssStaticDocument,
  source : String,
  node_index : Int,
) -> Bool raise {
  guard parse_static_css_selector(source) is Some(selector) else {
    fail("selector should parse: " + source)
  }
  css_selector_matches(document, selector, node_index)
}

///|
test "static selector matcher covers simple and compound selectors" {
  let source = "<svg><g id='layer'><rect id='target' class='hot selected' data-kind='primary'/></g></svg>"
  let document = parse_static_css_document_or_raise(source)
  assert_true(document.complete)
  let target = selector_test_node_by_id(document, "target")
  assert_true(selector_test_matches(document, "rect", target))
  assert_true(selector_test_matches(document, "*", target))
  assert_true(selector_test_matches(document, "#target", target))
  assert_true(selector_test_matches(document, ".hot", target))
  assert_true(selector_test_matches(document, "[data-kind]", target))
  assert_true(selector_test_matches(document, "[data-kind='primary']", target))
  assert_true(
    selector_test_matches(
      document, "rect#target.hot.selected[data-kind=primary]", target,
    ),
  )
  assert_true(!selector_test_matches(document, "RECT", target))
  assert_true(!selector_test_matches(document, ".selectedly", target))
  assert_true(!selector_test_matches(document, "[data-kind=Primary]", target))
}

///|
test "static selector matcher covers four structural combinators" {
  let source = "<svg><g id='group'><rect id='first'/><circle id='middle'/><rect id='last'/></g></svg>"
  let document = parse_static_css_document_or_raise(source)
  let last = selector_test_node_by_id(document, "last")
  assert_true(selector_test_matches(document, "svg rect", last))
  assert_true(selector_test_matches(document, "g > rect", last))
  assert_true(selector_test_matches(document, "circle + rect", last))
  assert_true(selector_test_matches(document, "rect ~ rect", last))
  assert_true(!selector_test_matches(document, "svg > rect", last))
  assert_true(!selector_test_matches(document, "rect + rect", last))
  assert_true(!selector_test_matches(document, "circle ~ #first", last))
}

///|
test "unsupported selector syntax cannot become static applicability" {
  for
    source in [
      "rect:hover", "rect::before", "rect:not(.disabled)", "svg|rect", ".escaped\\ class",
      "[data-kind~=primary]", "#123", "rect, circle",
    ] {
    assert_true(parse_static_css_selector(source) is None)
  }
}

///|
test "stylesheet matching supplies exact rule candidates by element source" {
  let source = "<svg><style>rect { fill: red; } #target { fill: blue !important; }</style><rect id='target'/></svg>"
  let document = parse_static_css_document_or_raise(source)
  assert_true(document.complete)
  let target = selector_test_node_by_id(document, "target")
  let matched = css_stylesheet_match_for_source(
    document,
    document.nodes[target].source_offset,
  )
  assert_true(matched.complete)
  assert_eq(matched.candidates.length(), 2)
  assert_eq(matched.candidates[0].declaration.declared_value, "red")
  assert_eq(matched.candidates[1].declaration.declared_value, "blue")
  assert_true(matched.candidates[1].important)
}

///|
test "stylesheet selector lists provide alternative applicability" {
  let source = "<svg><style>circle, #target { fill: red; }</style><rect id='target'/></svg>"
  let document = parse_static_css_document_or_raise(source)
  assert_true(document.complete)
  let target = selector_test_node_by_id(document, "target")
  let matched = css_stylesheet_match_for_source(
    document,
    document.nodes[target].source_offset,
  )
  assert_true(matched.complete)
  assert_eq(matched.candidates.length(), 1)
  assert_eq(matched.candidates[0].declaration.declared_value, "red")
}

///|
test "quoted exact attribute selectors remain complete in stylesheets" {
  let source = "<svg><style>[data-kind='primary'] { fill: red; }</style><rect id='target' data-kind='primary'/></svg>"
  let document = parse_static_css_document_or_raise(source)
  assert_true(document.complete)
  let target = selector_test_node_by_id(document, "target")
  let matched = css_stylesheet_match_for_source(
    document,
    document.nodes[target].source_offset,
  )
  assert_true(matched.complete)
  assert_eq(matched.candidates.length(), 1)
}
