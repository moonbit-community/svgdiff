///|
test "source adapter preserves authored direct text" {
  let source = "<svg><text>A&amp;B</text></svg>"
  assert_eq(source_text_content(source), Some("A&amp;B"))
}

///|
test "source adapter rejects malformed XML" {
  assert_eq(source_text_content("<svg><text>x</text></svg>trailing"), None)
  assert_eq(source_text_content("<svg><text>missing end"), None)
}
