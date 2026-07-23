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
fn declared_fact_span_slice(
  source : String,
  fact : DeclaredVisualFact,
) -> String {
  source_range_slice(
    source,
    fact.source_span.start_offset,
    fact.source_span.end_offset,
  )
}

///|
test "declared rect facts cover the supported solid slice" {
  let source = "<svg><rect id='box' x='1' y='2' width='8' height='9' fill='red' opacity='0.5'/></svg>"
  match extract_rect_declared_facts(source) {
    Parsed(Some(rect)) => {
      assert_eq(rect.subject_id, "box")
      assert_eq(rect.facts.length(), 6)
      for property in rect_property_order() {
        assert_true(declared_fact(rect, property) is Some(_))
      }
      match declared_fact(rect, "fill") {
        Some(fact) => {
          assert_eq(fact.authored_value, "red")
          assert_eq(fact.declared_value, "red")
          assert_eq(fact.origin, "presentation_attribute")
          assert_eq(declared_fact_span_slice(source, fact), "red")
        }
        None => fail("expected a declared fill fact")
      }
    }
    _ => fail("expected one extracted rect")
  }
}

///|
test "inline style overrides presentation facts and keeps exact value spans" {
  let source = "<svg><rect id='box' x='1' fill='blue' style=' x : 2 ; fill : r&#101;d ; opacity: 1 '/></svg>"
  match extract_rect_declared_facts(source) {
    Parsed(Some(rect)) => {
      assert_eq(rect.coverage_codes, [])
      match declared_fact(rect, "fill") {
        Some(fact) => {
          assert_eq(fact.authored_value, "r&#101;d")
          assert_eq(fact.declared_value, "red")
          assert_eq(fact.origin, "inline_style")
          assert_eq(declared_fact_span_slice(source, fact), "r&#101;d")
        }
        None => fail("expected the inline fill fact")
      }
      match declared_fact(rect, "x") {
        Some(fact) => {
          assert_eq(fact.declared_value, "2")
          assert_eq(fact.origin, "inline_style")
        }
        None => fail("expected the inline x fact")
      }
    }
    _ => fail("expected one extracted rect")
  }
}

///|
test "inline cascade resolves important and duplicate declarations" {
  let source = "<svg><rect id='box' fill='black' style='fill: red !IMPORTANT; fill: blue; stroke:black!important; stroke: green !important'/></svg>"
  match extract_rect_declared_facts(source) {
    Parsed(Some(rect)) => {
      assert_eq(rect.coverage_codes, [])
      let fill = declared_fact(rect, "fill").unwrap()
      assert_eq(fill.authored_value, "red")
      assert_eq(fill.declared_value, "red")
      assert_eq(fill.origin, "inline_style")
      assert_eq(declared_fact_span_slice(source, fill), "red")
      let stroke = declared_fact(rect, "stroke").unwrap()
      assert_eq(stroke.authored_value, "green")
      assert_eq(stroke.declared_value, "green")
      assert_eq(declared_fact_span_slice(source, stroke), "green")
    }
    _ => fail("expected cascaded inline declarations")
  }
}

///|
test "matched stylesheet declarations retain provenance and enter the cascade" {
  let source = "<svg><style>rect { fill: green; } .paint { fill: blue; } #box { fill: red !important; }</style><rect id='box' class='paint' fill='black' style='fill:purple'/></svg>"
  match extract_rect_declared_facts(source) {
    Parsed(Some(rect)) => {
      assert_eq(rect.coverage_codes, [])
      let fill = declared_fact(rect, "fill").unwrap()
      assert_eq(fill.authored_value, "red")
      assert_eq(fill.declared_value, "red")
      assert_eq(fill.origin, "stylesheet_rule")
      assert_eq(declared_fact_span_slice(source, fill), "red")
    }
    _ => fail("expected matched stylesheet declaration")
  }
}

///|
test "matched stylesheet source order breaks equal-specificity ties" {
  let source = "<svg><style>.paint { fill: red; } .paint { fill: blue; }</style><rect id='box' class='paint'/></svg>"
  match extract_rect_declared_facts(source) {
    Parsed(Some(rect)) => {
      assert_eq(rect.coverage_codes, [])
      let fill = declared_fact(rect, "fill").unwrap()
      assert_eq(fill.declared_value, "blue")
      assert_eq(fill.origin, "stylesheet_rule")
    }
    _ => fail("expected later matched stylesheet declaration")
  }
}
