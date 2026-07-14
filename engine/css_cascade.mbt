///|
priv struct CssSpecificity {
  inline_style : Int
  ids : Int
  classes : Int
  types : Int
}

///|
priv struct CssCascadeCandidate {
  declaration : DeclaredVisualFact
  important : Bool
  specificity : CssSpecificity
  cascade_source : Int
  source_order : Int
}

///|
priv struct CssStylesheetRule {
  selector : String
  selector_span : ReportSourceSpan
  specificity : CssSpecificity
  declarations : Array[CssCascadeCandidate]
}

///|
priv struct CssStylesheetParse {
  rules : Array[CssStylesheetRule]
  complete : Bool
}

///|
fn presentation_specificity() -> CssSpecificity {
  { inline_style: 0, ids: 0, classes: 0, types: 0 }
}

///|
fn inline_specificity() -> CssSpecificity {
  { inline_style: 1, ids: 0, classes: 0, types: 0 }
}

///|
fn presentation_cascade_candidate(
  declaration : DeclaredVisualFact,
  source_order : Int,
) -> CssCascadeCandidate {
  {
    declaration,
    important: false,
    specificity: presentation_specificity(),
    cascade_source: 0,
    source_order,
  }
}

///|
fn inline_cascade_candidate(
  declaration : DeclaredVisualFact,
  important : Bool,
  source_order : Int,
) -> CssCascadeCandidate {
  {
    declaration,
    important,
    specificity: inline_specificity(),
    cascade_source: 2,
    source_order,
  }
}

///|
fn stylesheet_cascade_candidate(
  declaration : DeclaredVisualFact,
  important : Bool,
  specificity : CssSpecificity,
  source_order : Int,
) -> CssCascadeCandidate {
  { declaration, important, specificity, cascade_source: 1, source_order }
}

///|
fn compare_css_specificity(
  left : CssSpecificity,
  right : CssSpecificity,
) -> Int {
  let inline_order = left.inline_style.compare(right.inline_style)
  if inline_order != 0 {
    return inline_order
  }
  let id_order = left.ids.compare(right.ids)
  if id_order != 0 {
    return id_order
  }
  let class_order = left.classes.compare(right.classes)
  if class_order != 0 {
    return class_order
  }
  left.types.compare(right.types)
}

///|
fn css_candidate_outranks(
  candidate : CssCascadeCandidate,
  current : CssCascadeCandidate,
) -> Bool {
  if candidate.important != current.important {
    return candidate.important
  }
  let specificity_order = compare_css_specificity(
    candidate.specificity,
    current.specificity,
  )
  if specificity_order != 0 {
    return specificity_order > 0
  }
  let source_order = candidate.cascade_source.compare(current.cascade_source)
  if source_order != 0 {
    return source_order > 0
  }
  candidate.source_order >= current.source_order
}

///|
fn cascade_visual_declarations(
  candidates : Array[CssCascadeCandidate],
) -> Array[DeclaredVisualFact] {
  let winners : Array[CssCascadeCandidate] = []
  for candidate in candidates {
    let mut found = false
    for index, current in winners {
      if current.declaration.property == candidate.declaration.property {
        if css_candidate_outranks(candidate, current) {
          winners[index] = candidate
        }
        found = true
        break
      }
    }
    if !found {
      winners.push(candidate)
    }
  }
  [
    for winner in winners => winner.declaration
  ]
}

///|
fn parse_stylesheet_declarations(
  source : String,
  source_start : Int,
  specificity : CssSpecificity,
) -> (Array[CssCascadeCandidate], Bool) {
  let candidates : Array[CssCascadeCandidate] = []
  let mut complete = true
  let mut segment_start = 0
  for index in 0..<source.length() {
    let code_unit = source[index]
    if code_unit == ';' {
      if !parse_css_declaration_segment(
          source, source_start, segment_start, index, "stylesheet_rule", specificity,
          candidates,
        ) {
        complete = false
      }
      segment_start = index + 1
    } else if code_unit == '{' ||
      code_unit == '}' ||
      code_unit == '"' ||
      code_unit == '\'' {
      complete = false
    } else if code_unit == '/' &&
      index + 1 < source.length() &&
      source[index + 1] == '*' {
      complete = false
    }
  }
  if !parse_css_declaration_segment(
      source,
      source_start,
      segment_start,
      source.length(),
      "stylesheet_rule",
      specificity,
      candidates,
    ) {
    complete = false
  }
  (candidates, complete)
}

///|
fn parse_stylesheet_text(
  source : String,
  source_start : Int,
) -> CssStylesheetParse {
  let rules : Array[CssStylesheetRule] = []
  let mut complete = true
  let mut position = 0
  while position < source.length() {
    while position < source.length() &&
          is_declaration_whitespace(source[position]) {
      position += 1
    }
    if position == source.length() {
      break
    }
    let selector_start = position
    while position < source.length() && source[position] != '{' {
      if source[position] == '}' || source[position] == '@' {
        complete = false
      }
      position += 1
    }
    if position == source.length() {
      complete = false
      break
    }
    let selector_end = position
    position += 1
    let body_start = position
    while position < source.length() && source[position] != '}' {
      if source[position] == '{' {
        complete = false
      }
      position += 1
    }
    if position == source.length() {
      complete = false
      break
    }
    let body_end = position
    position += 1
    let mut selector_part_start = selector_start
    let mut selector_position = selector_start
    while selector_position <= selector_end {
      if selector_position == selector_end || source[selector_position] == ',' {
        let trimmed = trim_range(source, selector_part_start, selector_position)
        let part_start = trimmed.0
        let part_end = trimmed.1
        let selector = source_range_slice(source, part_start, part_end)
        match css_specificity_for_selector(selector) {
          Some(specificity) => {
            let body = source_range_slice(source, body_start, body_end)
            let parsed = parse_stylesheet_declarations(
              body,
              source_start + body_start,
              specificity,
            )
            if !parsed.1 {
              complete = false
            }
            rules.push({
              selector,
              selector_span: {
                start_offset: source_start + part_start,
                end_offset: source_start + part_end,
              },
              specificity,
              declarations: parsed.0,
            })
          }
          None => complete = false
        }
        selector_part_start = selector_position + 1
      }
      selector_position += 1
    }
  }
  { rules, complete }
}

///|
fn parse_document_stylesheets_or_raise(
  input : String,
) -> CssStylesheetParse raise {
  let rules : Array[CssStylesheetRule] = []
  let mut complete = true
  let mut in_stylesheet = false
  let reader = @xml.NamespaceReader::from_string(input)
  for event in reader.read_events_until_eof() {
    match event.kind {
      Start(element) if element.name.local_name == "style" =>
        in_stylesheet = true
      Text(_) if in_stylesheet => {
        let parsed = parse_stylesheet_text(
          source_slice(input, event.span),
          event.span.start.offset,
        )
        rules.push_iter(parsed.rules.iter())
        if !parsed.complete {
          complete = false
        }
      }
      CData(_) if in_stylesheet => complete = false
      End(name) if name.local_name == "style" => in_stylesheet = false
      _ => ()
    }
  }
  { rules, complete }
}
