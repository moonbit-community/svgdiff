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
