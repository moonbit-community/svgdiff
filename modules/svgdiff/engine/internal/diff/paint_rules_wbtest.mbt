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
