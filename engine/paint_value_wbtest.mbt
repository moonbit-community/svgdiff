///|
test "paint parser admits local URL fallbacks and normalizes fragments" {
  assert_true(
    parse_paint_value(" URL( '#tile%20one' ) currentColor ")
    is LocalPaintServer("tile one", Some(PaintFallbackColor("currentColor"))),
  )
  assert_true(
    parse_paint_value("url(#tile) none")
    is LocalPaintServer("tile", Some(PaintFallbackNone)),
  )
  assert_true(
    parse_paint_value("url(\"#tile\") rgba(255, 0, 0, .5)")
    is LocalPaintServer("tile", Some(PaintFallbackColor("rgba(255, 0, 0, .5)"))),
  )
}

///|
test "paint parser distinguishes solid, external, context, and invalid values" {
  assert_true(parse_paint_value("red") is SolidPaint("red"))
  assert_true(parse_paint_value("none") is NoPaint)
  assert_true(parse_paint_value("url(other.svg#g) blue") is ExternalPaintServer)
  assert_true(parse_paint_value("context-fill") is ContextPaint)
  for
    invalid in [
      "url() red", "url(#g) red blue", "url('#g) red", "url(#g x) red", "url('#g x') red",
    ] {
    assert_true(parse_paint_value(invalid) is InvalidPaint)
  }
}
