///|
priv enum CssSimpleSelector {
  TypeSelector(String)
  UniversalSelector
  IdSelector(String)
  ClassSelector(String)
  AttributePresenceSelector(String)
  AttributeEqualsSelector(String, String)
}

///|
priv enum CssCombinator {
  DescendantCombinator
  ChildCombinator
  AdjacentSiblingCombinator
  GeneralSiblingCombinator
}

///|
priv struct CssSelectorPart {
  simples : Array[CssSimpleSelector]
  combinator_to_left : CssCombinator?
}

///|
priv struct CssSelector {
  parts : Array[CssSelectorPart]
  specificity : CssSpecificity
}

///|
priv struct CssSelectorAttribute {
  local_name : String
  unprefixed : Bool
  value : String
}

///|
priv struct CssSelectorNode {
  local_name : String
  attributes : Array[CssSelectorAttribute]
  parent_index : Int?
  previous_sibling_index : Int?
  source_offset : Int
}

///|
priv struct CssStaticDocument {
  nodes : Array[CssSelectorNode]
  stylesheets : CssStylesheetParse
  complete : Bool
}

///|
priv struct CssStylesheetMatch {
  candidates : Array[CssCascadeCandidate]
  complete : Bool
}

///|
fn empty_css_stylesheet_match() -> CssStylesheetMatch {
  { candidates: [], complete: true }
}

///|
fn css_ascii_letter(code_unit : UInt16) -> Bool {
  (code_unit >= 'a' && code_unit <= 'z') ||
  (code_unit >= 'A' && code_unit <= 'Z')
}

///|
fn css_identifier_start(code_unit : UInt16) -> Bool {
  css_ascii_letter(code_unit) || code_unit == '_'
}

///|
fn css_identifier_continue(code_unit : UInt16) -> Bool {
  css_identifier_start(code_unit) ||
  (code_unit >= '0' && code_unit <= '9') ||
  code_unit == '-'
}

///|
fn parse_static_css_identifier(
  source : String,
  position : Int,
) -> (String, Int)? {
  if position >= source.length() {
    return None
  }
  let mut end = position
  if source[end] == '-' {
    end += 1
    if end >= source.length() || !css_identifier_start(source[end]) {
      return None
    }
  } else if !css_identifier_start(source[end]) {
    return None
  }
  end += 1
  while end < source.length() && css_identifier_continue(source[end]) {
    end += 1
  }
  Some((source_range_slice(source, position, end), end))
}

///|
fn skip_css_whitespace(source : String, position : Int) -> Int {
  let mut end = position
  while end < source.length() && is_declaration_whitespace(source[end]) {
    end += 1
  }
  end
}

///|
fn parse_static_attribute_selector(
  source : String,
  position : Int,
) -> (CssSimpleSelector, Int)? {
  let mut current = skip_css_whitespace(source, position + 1)
  guard parse_static_css_identifier(source, current) is Some((name, name_end)) else {
    return None
  }
  current = skip_css_whitespace(source, name_end)
  if current < source.length() && source[current] == ']' {
    return Some((AttributePresenceSelector(name), current + 1))
  }
  if current >= source.length() || source[current] != '=' {
    return None
  }
  current = skip_css_whitespace(source, current + 1)
  if current >= source.length() {
    return None
  }
  let mut value = ""
  if source[current] == '"' || source[current] == '\'' {
    let quote = source[current]
    let value_start = current + 1
    current = value_start
    while current < source.length() && source[current] != quote {
      if source[current] == '\\' ||
        source[current] == '{' ||
        source[current] == '}' ||
        source[current] == ',' {
        return None
      }
      current += 1
    }
    if current >= source.length() {
      return None
    }
    value = source_range_slice(source, value_start, current)
    current += 1
  } else {
    guard parse_static_css_identifier(source, current) is Some((parsed, end)) else {
      return None
    }
    value = parsed
    current = end
  }
  current = skip_css_whitespace(source, current)
  if current >= source.length() || source[current] != ']' {
    return None
  }
  Some((AttributeEqualsSelector(name, value), current + 1))
}

///|
fn parse_static_css_selector(source : String) -> CssSelector? {
  let selector = source.trim().to_owned()
  if selector == "" {
    return None
  }
  let parts : Array[CssSelectorPart] = []
  let mut ids = 0
  let mut classes = 0
  let mut types = 0
  let mut position = 0
  let mut combinator_to_left : CssCombinator? = None
  while position < selector.length() {
    let simples : Array[CssSimpleSelector] = []
    if selector[position] == '*' {
      simples.push(UniversalSelector)
      position += 1
    } else {
      match parse_static_css_identifier(selector, position) {
        Some((name, end)) => {
          simples.push(TypeSelector(name))
          types += 1
          position = end
        }
        None => ()
      }
    }
    let mut parsing_compound = true
    while parsing_compound && position < selector.length() {
      match selector[position] {
        '#' =>
          match parse_static_css_identifier(selector, position + 1) {
            Some((name, end)) => {
              simples.push(IdSelector(name))
              ids += 1
              position = end
            }
            None => return None
          }
        '.' =>
          match parse_static_css_identifier(selector, position + 1) {
            Some((name, end)) => {
              simples.push(ClassSelector(name))
              classes += 1
              position = end
            }
            None => return None
          }
        '[' =>
          match parse_static_attribute_selector(selector, position) {
            Some((simple, end)) => {
              simples.push(simple)
              classes += 1
              position = end
            }
            None => return None
          }
        _ => parsing_compound = false
      }
    }
    if simples.is_empty() {
      return None
    }
    parts.push({ simples, combinator_to_left })
    let whitespace_end = skip_css_whitespace(selector, position)
    let had_whitespace = whitespace_end > position
    position = whitespace_end
    if position == selector.length() {
      break
    }
    match selector[position] {
      '>' => combinator_to_left = Some(ChildCombinator)
      '+' => combinator_to_left = Some(AdjacentSiblingCombinator)
      '~' => combinator_to_left = Some(GeneralSiblingCombinator)
      _ =>
        if had_whitespace {
          combinator_to_left = Some(DescendantCombinator)
          continue
        } else {
          return None
        }
    }
    position = skip_css_whitespace(selector, position + 1)
    if position == selector.length() {
      return None
    }
  }
  Some({ parts, specificity: { inline_style: 0, ids, classes, types } })
}

///|
fn css_specificity_for_selector(source : String) -> CssSpecificity? {
  match parse_static_css_selector(source) {
    Some(selector) => Some(selector.specificity)
    None => None
  }
}

///|
fn css_selector_attribute(node : CssSelectorNode, name : String) -> String? {
  for attribute in node.attributes {
    if attribute.unprefixed && attribute.local_name == name {
      return Some(attribute.value)
    }
  }
  None
}

///|
fn css_class_whitespace(code_unit : UInt16) -> Bool {
  is_declaration_whitespace(code_unit) || code_unit.to_int() == 12
}

///|
fn css_class_contains(value : String, expected : String) -> Bool {
  let mut position = 0
  while position < value.length() {
    while position < value.length() && css_class_whitespace(value[position]) {
      position += 1
    }
    let start = position
    while position < value.length() && !css_class_whitespace(value[position]) {
      position += 1
    }
    if start < position &&
      source_range_slice(value, start, position) == expected {
      return true
    }
  }
  false
}

///|
fn css_compound_matches(part : CssSelectorPart, node : CssSelectorNode) -> Bool {
  for simple in part.simples {
    match simple {
      TypeSelector(name) => if node.local_name != name { return false }
      UniversalSelector => ()
      IdSelector(id) =>
        if css_selector_attribute(node, "id") != Some(id) {
          return false
        }
      ClassSelector(class_name) =>
        match css_selector_attribute(node, "class") {
          Some(value) =>
            if !css_class_contains(value, class_name) {
              return false
            }
          None => return false
        }
      AttributePresenceSelector(name) =>
        if css_selector_attribute(node, name) is None {
          return false
        }
      AttributeEqualsSelector(name, expected) =>
        if css_selector_attribute(node, name) != Some(expected) {
          return false
        }
    }
  }
  true
}

///|
fn css_selector_matches_from(
  document : CssStaticDocument,
  selector : CssSelector,
  part_index : Int,
  node_index : Int,
) -> Bool {
  if !css_compound_matches(
      selector.parts[part_index],
      document.nodes[node_index],
    ) {
    return false
  }
  if part_index == 0 {
    return true
  }
  match selector.parts[part_index].combinator_to_left {
    Some(ChildCombinator) =>
      match document.nodes[node_index].parent_index {
        Some(parent) =>
          css_selector_matches_from(document, selector, part_index - 1, parent)
        None => false
      }
    Some(AdjacentSiblingCombinator) =>
      match document.nodes[node_index].previous_sibling_index {
        Some(sibling) =>
          css_selector_matches_from(document, selector, part_index - 1, sibling)
        None => false
      }
    Some(DescendantCombinator) => {
      let mut ancestor = document.nodes[node_index].parent_index
      while ancestor is Some(index) {
        if css_selector_matches_from(document, selector, part_index - 1, index) {
          return true
        }
        ancestor = document.nodes[index].parent_index
      }
      false
    }
    Some(GeneralSiblingCombinator) => {
      let mut sibling = document.nodes[node_index].previous_sibling_index
      while sibling is Some(index) {
        if css_selector_matches_from(document, selector, part_index - 1, index) {
          return true
        }
        sibling = document.nodes[index].previous_sibling_index
      }
      false
    }
    None => false
  }
}

///|
fn css_selector_matches(
  document : CssStaticDocument,
  selector : CssSelector,
  node_index : Int,
) -> Bool {
  !selector.parts.is_empty() &&
  css_selector_matches_from(
    document,
    selector,
    selector.parts.length() - 1,
    node_index,
  )
}

///|
fn css_selector_node(
  element : @xml.NamespaceElement,
  parent_index : Int?,
  previous_sibling_index : Int?,
  source_offset : Int,
) -> CssSelectorNode {
  let attributes : Array[CssSelectorAttribute] = []
  for attribute in element.attributes {
    attributes.push({
      local_name: attribute.name.local_name,
      unprefixed: attribute.name.prefix is None,
      value: attribute.value,
    })
  }
  {
    local_name: element.name.local_name,
    attributes,
    parent_index,
    previous_sibling_index,
    source_offset,
  }
}

///|
fn add_css_selector_node(
  element : @xml.NamespaceElement,
  source_offset : Int,
  stack : Array[Int],
  nodes : Array[CssSelectorNode],
  last_children : Array[Int?],
  root_previous : Int?,
) -> (Int, Int?) {
  let parent_index = stack.last()
  let previous_sibling_index = match parent_index {
    Some(parent) => last_children[parent]
    None => root_previous
  }
  let index = nodes.length()
  nodes.push(
    css_selector_node(
      element, parent_index, previous_sibling_index, source_offset,
    ),
  )
  last_children.push(None)
  let next_root_previous = match parent_index {
    Some(parent) => {
      last_children[parent] = Some(index)
      root_previous
    }
    None => Some(index)
  }
  (index, next_root_previous)
}

///|
fn parse_static_css_document_or_raise(
  input : String,
) -> CssStaticDocument raise {
  let stylesheets = parse_document_stylesheets_or_raise(input)
  let nodes : Array[CssSelectorNode] = []
  let last_children : Array[Int?] = []
  let stack : Array[Int] = []
  let mut root_previous : Int? = None
  let reader = @xml.NamespaceReader::from_string(input)
  for event in reader.read_events_until_eof() {
    match event.kind {
      Start(element) => {
        let added = add_css_selector_node(
          element,
          event.span.start.offset,
          stack,
          nodes,
          last_children,
          root_previous,
        )
        root_previous = added.1
        stack.push(added.0)
      }
      Empty(element) => {
        let added = add_css_selector_node(
          element,
          event.span.start.offset,
          stack,
          nodes,
          last_children,
          root_previous,
        )
        root_previous = added.1
      }
      End(_) => ignore(stack.pop())
      _ => ()
    }
  }
  { nodes, stylesheets, complete: stylesheets.complete }
}

///|
fn css_stylesheet_match_for_source(
  document : CssStaticDocument,
  source_offset : Int,
) -> CssStylesheetMatch {
  let candidates : Array[CssCascadeCandidate] = []
  let mut complete = document.complete
  let mut node_index = -1
  for index, node in document.nodes {
    if node.source_offset == source_offset {
      node_index = index
      break
    }
  }
  if node_index < 0 {
    return { candidates, complete: false }
  }
  for rule in document.stylesheets.rules {
    match parse_static_css_selector(rule.selector) {
      Some(selector) => {
        let specificity_matches = selector.specificity.ids ==
          rule.specificity.ids &&
          selector.specificity.classes == rule.specificity.classes &&
          selector.specificity.types == rule.specificity.types
        if rule.selector_span.start_offset >= rule.selector_span.end_offset ||
          !specificity_matches {
          complete = false
        } else if css_selector_matches(document, selector, node_index) {
          candidates.push_iter(rule.declarations.iter())
        }
      }
      None => complete = false
    }
  }
  { candidates, complete }
}
