///|
priv struct RectDeclaredFacts {
  subject_id : String
  facts : Array[DeclaredVisualFact]
  coverage_codes : Array[String]
}

///|
priv enum RectFactExtraction {
  Parsed(RectDeclaredFacts?)
  Failed
}

///|
priv struct InlineStyleFacts {
  facts : Array[DeclaredVisualFact]
  candidates : Array[CssCascadeCandidate]
  complete : Bool
}

///|
fn supported_rect_property(property : String) -> Bool {
  match property {
    "x"
    | "y"
    | "width"
    | "height"
    | "rx"
    | "ry"
    | "cx"
    | "cy"
    | "r"
    | "x1"
    | "y1"
    | "x2"
    | "y2"
    | "points"
    | "fill"
    | "stroke"
    | "stroke-width"
    | "stroke-linecap"
    | "stroke-linejoin"
    | "stroke-miterlimit"
    | "stroke-dasharray"
    | "stroke-dashoffset"
    | "vector-effect"
    | "marker"
    | "marker-start"
    | "marker-mid"
    | "marker-end"
    | "opacity" => true
    _ => false
  }
}

///|
fn rect_property_order() -> Array[String] {
  ["x", "y", "width", "height", "fill", "opacity"]
}

///|
fn source_range_slice(
  input : String,
  start_offset : Int,
  end_offset : Int,
) -> String {
  let view = input.view(start_offset~, end_offset~)
  view.to_owned()
}

///|
fn is_declaration_whitespace(code_unit : UInt16) -> Bool {
  code_unit == ' ' ||
  code_unit == '\t' ||
  code_unit == '\n' ||
  code_unit == '\r'
}

///|
fn trim_range(value : String, start : Int, end : Int) -> (Int, Int) {
  let mut trimmed_start = start
  let mut trimmed_end = end
  while trimmed_start < trimmed_end &&
        is_declaration_whitespace(value[trimmed_start]) {
    trimmed_start += 1
  }
  while trimmed_end > trimmed_start &&
        is_declaration_whitespace(value[trimmed_end - 1]) {
    trimmed_end -= 1
  }
  (trimmed_start, trimmed_end)
}

///|
fn push_unique(values : Array[String], value : String) -> Unit {
  if !values.contains(value) {
    values.push(value)
  }
}

///|
fn upsert_declared_fact(
  facts : Array[DeclaredVisualFact],
  fact : DeclaredVisualFact,
) -> Unit {
  for index, current in facts {
    if current.property == fact.property {
      facts[index] = fact
      return
    }
  }
  facts.push(fact)
}

///|
fn presentation_fact(
  input : String,
  property : String,
  attribute : @xml.NamespaceAttribute,
) -> DeclaredVisualFact {
  {
    property,
    authored_value: source_slice(input, attribute.value_span),
    declared_value: attribute.value.trim().to_owned(),
    origin: "presentation_attribute",
    source_span: {
      start_offset: attribute.value_span.start.offset,
      end_offset: attribute.value_span.end.offset,
    },
  }
}

///|
fn parse_css_declaration_segment(
  raw_style : String,
  attribute_start : Int,
  segment_start : Int,
  segment_end : Int,
  origin : String,
  specificity : CssSpecificity,
  candidates : Array[CssCascadeCandidate],
) -> Bool {
  let (start, end) = trim_range(raw_style, segment_start, segment_end)
  if start == end {
    return true
  }
  let mut colon = -1
  for index in start..<end {
    if raw_style[index] == ':' {
      colon = index
      break
    }
  }
  if colon < 0 {
    return false
  }
  let (name_start, name_end) = trim_range(raw_style, start, colon)
  let (value_start, initial_value_end) = trim_range(raw_style, colon + 1, end)
  let mut value_end = initial_value_end
  if name_start == name_end || value_start == value_end {
    return false
  }
  let raw_name = source_range_slice(raw_style, name_start, name_end)
  let property = raw_name.to_lower()
  if !supported_rect_property(property) {
    return false
  }
  let raw_value = source_range_slice(raw_style, value_start, value_end)
  let lower_value = raw_value.to_lower()
  let mut important = false
  if lower_value.has_suffix("!important") {
    important = true
    value_end -= "!important".length()
    let trimmed = trim_range(raw_style, value_start, value_end)
    value_end = trimmed.1
  } else if raw_value.find("!") is Some(_) {
    return false
  }
  if value_start == value_end {
    return false
  }
  let authored_value = source_range_slice(raw_style, value_start, value_end)
  if authored_value.to_lower().find("var(") is Some(_) {
    return false
  }
  let declared_value = try @xml.unescape(authored_value) catch {
    _ => return false
  } noraise {
    value => value.trim().to_owned()
  }
  let declaration : DeclaredVisualFact = {
    property,
    authored_value,
    declared_value,
    origin,
    source_span: {
      start_offset: attribute_start + value_start,
      end_offset: attribute_start + value_end,
    },
  }
  candidates.push(
    if origin == "inline_style" {
      inline_cascade_candidate(
        declaration,
        important,
        attribute_start + segment_start,
      )
    } else {
      stylesheet_cascade_candidate(
        declaration,
        important,
        specificity,
        attribute_start + segment_start,
      )
    },
  )
  true
}

///|
fn inline_style_facts(
  input : String,
  attribute : @xml.NamespaceAttribute,
) -> InlineStyleFacts {
  let raw_style = source_slice(input, attribute.value_span)
  let candidates : Array[CssCascadeCandidate] = []
  let mut complete = true
  let mut segment_start = 0
  let mut in_entity = false
  for index in 0..<raw_style.length() {
    let code_unit = raw_style[index]
    if code_unit == '&' {
      in_entity = true
    } else if code_unit == ';' {
      if in_entity {
        in_entity = false
      } else {
        if !parse_css_declaration_segment(
            raw_style,
            attribute.value_span.start.offset,
            segment_start,
            index,
            "inline_style",
            inline_specificity(),
            candidates,
          ) {
          complete = false
        }
        segment_start = index + 1
      }
    } else if code_unit == '"' || code_unit == '\'' {
      complete = false
    }
  }
  if in_entity {
    complete = false
  }
  if !parse_css_declaration_segment(
      raw_style,
      attribute.value_span.start.offset,
      segment_start,
      raw_style.length(),
      "inline_style",
      inline_specificity(),
      candidates,
    ) {
    complete = false
  }
  { facts: cascade_visual_declarations(candidates), candidates, complete }
}

///|
fn rect_declared_facts_from_element(
  input : String,
  element : @xml.NamespaceElement,
) -> RectDeclaredFacts {
  let candidates : Array[CssCascadeCandidate] = []
  let coverage_codes : Array[String] = []
  let mut subject_id = "rect:0"
  let mut style_attribute : @xml.NamespaceAttribute? = None
  for attribute in element.attributes {
    let name = attribute.name.local_name
    if name == "id" {
      let id = attribute.value.trim().to_owned()
      if id != "" {
        subject_id = id
      }
    } else if name == "class" {
      push_unique(coverage_codes, "css_cascade_unsupported")
    } else if name == "style" {
      style_attribute = Some(attribute)
    } else if supported_rect_property(name) {
      let fact = presentation_fact(input, name, attribute)
      candidates.push(
        presentation_cascade_candidate(fact, attribute.span.start.offset),
      )
    }
  }
  match style_attribute {
    Some(attribute) => {
      let parsed = inline_style_facts(input, attribute)
      candidates.push_iter(parsed.candidates.iter())
      if !parsed.complete {
        push_unique(coverage_codes, "css_cascade_unsupported")
      }
    }
    None => ()
  }
  { subject_id, facts: cascade_visual_declarations(candidates), coverage_codes }
}

///|
fn extract_rect_declared_facts_or_raise(
  input : String,
) -> RectDeclaredFacts? raise {
  let reader = @xml.NamespaceReader::from_string(input)
  let events = reader.read_events_until_eof()
  let mut rect : RectDeclaredFacts? = None
  let mut rect_count = 0
  for event in events {
    match event.kind {
      Start(element) | Empty(element) =>
        if element.name.local_name == "rect" {
          rect_count += 1
          if rect is None {
            rect = Some(rect_declared_facts_from_element(input, element))
          }
        }
      _ => ()
    }
  }
  match rect {
    Some(facts) => {
      let stylesheets = parse_document_stylesheets_or_raise(input)
      if stylesheet_requires_selector_matching(stylesheets) {
        push_unique(facts.coverage_codes, "css_cascade_unsupported")
      }
      if rect_count > 1 {
        push_unique(facts.coverage_codes, "multiple_rects_unsupported")
      }
      Some(facts)
    }
    None => None
  }
}

///|
fn extract_rect_declared_facts(input : String) -> RectFactExtraction {
  try extract_rect_declared_facts_or_raise(input) catch {
    _ => Failed
  } noraise {
    facts => Parsed(facts)
  }
}

///|
fn declared_fact(
  facts : RectDeclaredFacts,
  property : String,
) -> DeclaredVisualFact? {
  declared_fact_in_array(facts.facts, property)
}

///|
fn declared_fact_in_array(
  facts : Array[DeclaredVisualFact],
  property : String,
) -> DeclaredVisualFact? {
  for fact in facts {
    if fact.property == property {
      return Some(fact)
    }
  }
  None
}

///|
fn declared_fact_changed(
  before : DeclaredVisualFact?,
  after : DeclaredVisualFact?,
) -> Bool {
  match (before, after) {
    (None, None) => false
    (Some(before), Some(after)) =>
      before.declared_value != after.declared_value ||
      before.origin != after.origin
    _ => true
  }
}
