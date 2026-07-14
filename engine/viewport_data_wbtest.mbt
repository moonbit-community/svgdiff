///|
test "viewBox parser accepts SVG separators and rejects invalid dimensions" {
  for source in ["0 0 10 20", "0,0,10,20", " 0  0  10  20 ", "0,0 10,20"] {
    assert_true(parse_view_box_value(source) is Some(_))
  }
  for source in ["0 0 10", "0 0 10 20 trailing", "0 0 0 20", "0 0 -10 20"] {
    assert_true(parse_view_box_value(source) is None)
  }
}

///|
test "preserveAspectRatio parser covers alignments meet slice and none" {
  for
    alignment in [
      "xMinYMin", "xMidYMin", "xMaxYMin", "xMinYMid", "xMidYMid", "xMaxYMid", "xMinYMax",
      "xMidYMax", "xMaxYMax",
    ] {
    assert_true(parse_preserve_aspect_ratio_value(alignment) is Some(_))
    assert_true(
      parse_preserve_aspect_ratio_value("\{alignment} meet") is Some(_),
    )
    assert_true(
      parse_preserve_aspect_ratio_value("\{alignment} slice") is Some(_),
    )
  }
  assert_true(parse_preserve_aspect_ratio_value("none") is Some(_))
  assert_true(parse_preserve_aspect_ratio_value("none meet") is Some(_))
  assert_true(parse_preserve_aspect_ratio_value("none slice") is Some(_))
  for
    source in ["none unknown", "xMidYMid unknown", "xMidYMid meet trailing", ""] {
    assert_true(parse_preserve_aspect_ratio_value(source) is None)
  }
}

///|
test "viewport lengths resolve unitless px and percentages" {
  assert_eq(parse_viewport_length("12", 80.0).unwrap().value, 12.0)
  assert_eq(parse_viewport_length("12px", 80.0).unwrap().value, 12.0)
  assert_eq(parse_viewport_length("25%", 80.0).unwrap().value, 20.0)
  assert_true(parse_viewport_length("12pt", 80.0) is None)
}

///|
test "equivalent viewport transform covers none meet slice and offsets" {
  let view_box : ViewBoxValue = {
    min_x: 10.0,
    min_y: 20.0,
    width: 100.0,
    height: 50.0,
  }
  let none = equivalent_viewport_transform(view_box, 5.0, 7.0, 200.0, 200.0, {
    alignment: ViewportNone,
    fit: Meet,
  })
  assert_eq(none.signature(), "matrix(2,0,0,4,-15,-73)")
  let meet = equivalent_viewport_transform(
    view_box,
    5.0,
    7.0,
    200.0,
    200.0,
    default_preserve_aspect_ratio(),
  )
  assert_eq(meet.signature(), "matrix(2,0,0,2,-15,17)")
  let slice = equivalent_viewport_transform(view_box, 5.0, 7.0, 200.0, 200.0, {
    alignment: XMaxYMax,
    fit: Slice,
  })
  assert_eq(slice.signature(), "matrix(4,0,0,4,-235,-73)")
}
