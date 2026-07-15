///|
test "paint order expands omitted operations in default order" {
  assert_eq(canonical_paint_order("normal"), Some("fill stroke markers"))
  assert_eq(canonical_paint_order("fill"), Some("fill stroke markers"))
  assert_eq(
    canonical_paint_order(" stroke\tmarkers "),
    Some("stroke markers fill"),
  )
  assert_eq(canonical_paint_order("markers fill"), Some("markers fill stroke"))
}

///|
test "paint order rejects empty duplicate and unknown operations" {
  for value in ["", "normal stroke", "stroke stroke", "fill over stroke"] {
    assert_true(canonical_paint_order(value) is None)
  }
}

///|
test "winding rules admit only nonzero and evenodd" {
  assert_eq(canonical_winding_rule(" NONZERO "), Some("nonzero"))
  assert_eq(canonical_winding_rule("EvenOdd"), Some("evenodd"))
  assert_true(canonical_winding_rule("positive") is None)
}
