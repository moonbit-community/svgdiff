///|
fn parse_success(source : String) -> @svgdiff_source_semantics.Document raise {
  match @svgdiff_source_semantics.parse(source) {
    Ok(document) => document
    Err(error) => fail("unexpected parse error \{error.code}: \{error.message}")
  }
}

///|
fn assert_parse_error(source : String, expected_code : String) -> Unit raise {
  match @svgdiff_source_semantics.parse(source) {
    Err(error) => assert_eq(error.code, expected_code)
    Ok(_) => fail("expected parse error \{expected_code}")
  }
}

///|
test "preserve authored attribute spelling and source spans" {
  let source =
    #|<svg xmlns="http://www.w3.org/2000/svg">
    #|  <rect id="box" fill="red"/>
    #|</svg>
  let document = parse_success(source)
  let rect = document.elements_named("rect")[0]
  let fill = rect.attribute("fill").unwrap()
  assert_eq(fill.value, "red")
  assert_eq(document.slice(fill.value_span), "red")
  assert_eq(document.slice(fill.span), "fill=\"red\"")
  assert_eq(document.slice(rect.span), "<rect id=\"box\" fill=\"red\"/>")
  assert_eq(fill.value_span.start.line, 2)
}

///|
test "parse SVG hierarchy namespaces quotes and entity spelling" {
  let source =
    #|<?xml version="1.0"?>
    #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
    #|  <defs>
    #|    <linearGradient id="gradient">
    #|      <stop offset="0" stop-color="red"/>
    #|      <stop offset="1" stop-color="#0000ff"/>
    #|    </linearGradient>
    #|  </defs>
    #|  <use id='copy' xlink:href='#shape' data-label="A&amp;B"/>
    #|</svg>
  let document = parse_success(source)
  let stops = document.elements_named("stop")
  assert_eq(stops.length(), 2)
  assert_eq(stops[0].attribute("stop-color").unwrap().value, "red")
  assert_eq(stops[1].attribute("stop-color").unwrap().value, "#0000ff")
  let use_element = document.elements_named("use")[0]
  assert_eq(use_element.attribute("id").unwrap().value, "copy")
  assert_eq(use_element.attribute("xlink:href").unwrap().value, "#shape")
  assert_eq(use_element.attribute("data-label").unwrap().value, "A&amp;B")
}

///|
test "preserve comment CDATA and processing-instruction nodes" {
  let source = "<svg><!--note--><![CDATA[<not-an-element>]]><?target value?></svg>"
  let document = parse_success(source)
  assert_eq(document.root.children.length(), 3)
  match document.root.children[0] {
    Comment(text) => assert_eq(text.value, "note")
    _ => fail("expected comment")
  }
  match document.root.children[1] {
    CData(text) => assert_eq(text.value, "<not-an-element>")
    _ => fail("expected CDATA")
  }
  match document.root.children[2] {
    ProcessingInstruction(text) => assert_eq(text.value, "target value")
    _ => fail("expected processing instruction")
  }
}

///|
test "reject content after the root element" {
  assert_parse_error("<svg></svg>trailing", "trailing_content")
  assert_parse_error("<svg></svg><svg/>", "trailing_content")
}

///|
test "reject mismatched tags" {
  assert_parse_error("<svg></not-svg>", "mismatched_tag")
  assert_parse_error("<svg><g></svg>", "mismatched_tag")
}

///|
test "reject duplicate attributes" {
  assert_parse_error("<svg width=\"16\" width=\"32\"/>", "duplicate_attribute")
}

///|
test "reject unclosed and unquoted syntax" {
  assert_parse_error("<svg><rect/></svg", "unexpected_token")
  assert_parse_error("<svg width=16/>", "unquoted_attribute")
}
