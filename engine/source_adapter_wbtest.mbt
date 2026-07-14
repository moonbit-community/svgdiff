///|
test "source adapter preserves authored attribute values" {
  let source = "<svg xmlns=\"http://www.w3.org/2000/svg\"><rect data-label='A&amp;B'/></svg>"
  assert_eq(
    source_attribute_value(source, "rect", "data-label"),
    Some("A&amp;B"),
  )
}

///|
test "source adapter resolves namespace-qualified element names" {
  let source = "<svg:svg xmlns:svg=\"http://www.w3.org/2000/svg\"><svg:rect fill=\"red\"/></svg:svg>"
  assert_eq(source_attribute_value(source, "rect", "fill"), Some("red"))
}

///|
test "source adapter preserves authored direct text" {
  let source = "<svg><text>A&amp;B</text></svg>"
  assert_eq(source_text_content(source), Some("A&amp;B"))
}

///|
test "source adapter rejects malformed XML" {
  assert_eq(
    source_attribute_value("<svg id='x'></svg>trailing", "svg", "id"),
    None,
  )
  assert_eq(source_text_content("<svg><text>x</text></svg>trailing"), None)
  assert_eq(source_text_content("<svg><text>missing end"), None)
}
