// Copyright 2026 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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
