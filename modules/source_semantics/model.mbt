///|
pub(all) struct SourcePosition {
  offset : Int
  line : Int
  column : Int
} derive(Eq)

///|
pub(all) struct SourceSpan {
  start : SourcePosition
  end : SourcePosition
} derive(Eq)

///|
pub(all) struct Attribute {
  name : String
  value : String
  span : SourceSpan
  name_span : SourceSpan
  value_span : SourceSpan
}

///|
pub(all) struct SourceText {
  value : String
  span : SourceSpan
  value_span : SourceSpan
}

///|
pub(all) enum Node {
  Element(Element)
  Text(SourceText)
  Comment(SourceText)
  CData(SourceText)
  ProcessingInstruction(SourceText)
}

///|
pub(all) struct Element {
  name : String
  attributes : Array[Attribute]
  children : Array[Node]
  span : SourceSpan
  open_tag_span : SourceSpan
  close_tag_span : SourceSpan?
}

///|
pub(all) struct Document {
  source : String
  root : Element
}

///|
pub(all) struct ParseError {
  code : String
  message : String
  span : SourceSpan
}

///|
pub fn Element::attribute(self : Element, name : String) -> Attribute? {
  for attribute in self.attributes {
    if attribute.name == name {
      return Some(attribute)
    }
  }
  None
}

///|
pub fn Element::direct_text(self : Element) -> String {
  let mut text = ""
  for child in self.children {
    if child is Text(source_text) {
      text += source_text.value
    }
  }
  text
}

///|
fn collect_elements(
  element : Element,
  name : String,
  output : Array[Element],
) -> Unit {
  if element.name == name {
    output.push(element)
  }
  for child in element.children {
    if child is Element(element) {
      collect_elements(element, name, output)
    }
  }
}

///|
pub fn Document::elements_named(
  self : Document,
  name : String,
) -> Array[Element] {
  let elements : Array[Element] = []
  collect_elements(self.root, name, elements)
  elements
}

///|
pub fn Document::slice(self : Document, span : SourceSpan) -> String {
  "\{self.source.view(start_offset=span.start.offset, end_offset=span.end.offset)}"
}
