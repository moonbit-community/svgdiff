///|
fn cascade_test_fact(
  property : String,
  value : String,
  origin : String,
  offset : Int,
) -> DeclaredVisualFact {
  {
    property,
    authored_value: value,
    declared_value: value,
    origin,
    source_span: { start_offset: offset, end_offset: offset + value.length() },
  }
}

///|
fn cascade_test_candidate(
  value : String,
  origin : String,
  important : Bool,
  specificity : CssSpecificity,
  source_order : Int,
) -> CssCascadeCandidate {
  {
    declaration: cascade_test_fact("fill", value, origin, source_order),
    important,
    specificity,
    cascade_source: if origin == "presentation_attribute" {
      0
    } else if origin == "stylesheet_rule" {
      1
    } else {
      2
    },
    source_order,
  }
}

///|
test "CSS cascade compares importance specificity and source order" {
  let candidates = [
    cascade_test_candidate(
      "red",
      "presentation_attribute",
      false,
      presentation_specificity(),
      1,
    ),
    cascade_test_candidate(
      "green",
      "stylesheet_rule",
      false,
      { inline_style: 0, ids: 0, classes: 1, types: 0 },
      2,
    ),
    cascade_test_candidate(
      "blue",
      "inline_style",
      false,
      inline_specificity(),
      3,
    ),
    cascade_test_candidate(
      "purple",
      "stylesheet_rule",
      true,
      { inline_style: 0, ids: 0, classes: 1, types: 0 },
      4,
    ),
  ]
  let declarations = cascade_visual_declarations(candidates)
  assert_eq(declarations.length(), 1)
  assert_eq(declarations[0].declared_value, "purple")
  assert_eq(declarations[0].origin, "stylesheet_rule")
}

///|
test "CSS cascade uses selector specificity before source order" {
  let candidates = [
    cascade_test_candidate(
      "red",
      "stylesheet_rule",
      false,
      { inline_style: 0, ids: 1, classes: 0, types: 0 },
      1,
    ),
    cascade_test_candidate(
      "blue",
      "stylesheet_rule",
      false,
      { inline_style: 0, ids: 0, classes: 3, types: 2 },
      20,
    ),
  ]
  assert_eq(cascade_visual_declarations(candidates)[0].declared_value, "red")
}

///|
test "CSS cascade uses later source order for equal priority" {
  let candidates = [
    cascade_test_candidate(
      "red",
      "inline_style",
      false,
      inline_specificity(),
      1,
    ),
    cascade_test_candidate(
      "blue",
      "inline_style",
      false,
      inline_specificity(),
      2,
    ),
  ]
  assert_eq(cascade_visual_declarations(candidates)[0].declared_value, "blue")
}

///|
test "stylesheet declarations are ordered after presentation attributes" {
  let presentation = presentation_cascade_candidate(
    cascade_test_fact("fill", "red", "presentation_attribute", 100),
    100,
  )
  let stylesheet = stylesheet_cascade_candidate(
    cascade_test_fact("fill", "blue", "stylesheet_rule", 1),
    false,
    presentation_specificity(),
    1,
  )
  assert_eq(
    cascade_visual_declarations([presentation, stylesheet])[0].declared_value,
    "blue",
  )
}

///|
test "inline specificity also wins among important author declarations" {
  let stylesheet = stylesheet_cascade_candidate(
    cascade_test_fact("fill", "blue", "stylesheet_rule", 20),
    true,
    { inline_style: 0, ids: 4, classes: 0, types: 0 },
    20,
  )
  let inline = inline_cascade_candidate(
    cascade_test_fact("fill", "red", "inline_style", 1),
    true,
    1,
  )
  assert_eq(
    cascade_visual_declarations([stylesheet, inline])[0].declared_value,
    "red",
  )
}

///|
test "CSS cascade keeps independent property winners in first-property order" {
  let candidates = [
    {
      declaration: cascade_test_fact("fill", "red", "presentation_attribute", 1),
      important: false,
      specificity: presentation_specificity(),
      cascade_source: 0,
      source_order: 1,
    },
    {
      declaration: cascade_test_fact(
        "stroke", "black", "presentation_attribute", 2,
      ),
      important: false,
      specificity: presentation_specificity(),
      cascade_source: 0,
      source_order: 2,
    },
    {
      declaration: cascade_test_fact("fill", "blue", "inline_style", 3),
      important: false,
      specificity: inline_specificity(),
      cascade_source: 2,
      source_order: 3,
    },
  ]
  let declarations = cascade_visual_declarations(candidates)
  assert_eq(declarations.length(), 2)
  assert_eq(declarations[0].property, "fill")
  assert_eq(declarations[0].declared_value, "blue")
  assert_eq(declarations[1].property, "stroke")
}

///|
test "stylesheet parser retains selector specificity declarations and spans" {
  let source = "<svg><style>rect, #box.hot { fill: red; stroke: blue !important; }</style><rect id='box'/></svg>"
  let parsed = parse_document_stylesheets_or_raise(source)
  assert_true(parsed.complete)
  assert_eq(parsed.rules.length(), 2)
  let type_rule = parsed.rules[0]
  assert_eq(type_rule.selector, "rect")
  assert_eq(type_rule.specificity.ids, 0)
  assert_eq(type_rule.specificity.classes, 0)
  assert_eq(type_rule.specificity.types, 1)
  assert_eq(
    source_range_slice(
      source,
      type_rule.selector_span.start_offset,
      type_rule.selector_span.end_offset,
    ),
    "rect",
  )
  assert_eq(type_rule.declarations.length(), 2)
  assert_eq(type_rule.declarations[0].declaration.origin, "stylesheet_rule")
  assert_eq(type_rule.declarations[0].declaration.authored_value, "red")
  assert_true(!type_rule.declarations[0].important)
  assert_eq(type_rule.declarations[1].declaration.authored_value, "blue")
  assert_true(type_rule.declarations[1].important)
  let compound_rule = parsed.rules[1]
  assert_eq(compound_rule.selector, "#box.hot")
  assert_eq(compound_rule.specificity.ids, 1)
  assert_eq(compound_rule.specificity.classes, 1)
  assert_eq(compound_rule.specificity.types, 0)
}

///|
test "specificity parser counts supported static selector syntax" {
  let specificity = css_specificity_for_selector(
    "svg g#layer.item[hidden] > rect:hover::before",
  ).unwrap()
  assert_eq(specificity.ids, 1)
  assert_eq(specificity.classes, 3)
  assert_eq(specificity.types, 4)
  assert_true(css_specificity_for_selector("rect:not(.disabled)") is None)
}

///|
test "stylesheet parser keeps unsupported syntax explicitly incomplete" {
  let parsed = parse_stylesheet_text("rect:not(.disabled) { fill: red; }", 0)
  assert_true(!parsed.complete)
  assert_eq(parsed.rules.length(), 0)
  assert_true(stylesheet_requires_selector_matching(parsed))
}
