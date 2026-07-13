///|
priv suberror ParserFailure {
  Error(ParseError)
}

///|
priv struct Parser {
  chars : Array[Char]
  positions : Array[SourcePosition]
  mut index : Int
}

///|
fn build_positions(chars : ArrayView[Char]) -> Array[SourcePosition] {
  let positions : Array[SourcePosition] = []
  let mut offset = 0
  let mut line = 1
  let mut column = 1
  for char in chars {
    positions.push({ offset, line, column })
    offset += char.utf16_len()
    if char == '\n' {
      line += 1
      column = 1
    } else {
      column += 1
    }
  }
  positions.push({ offset, line, column })
  positions
}

///|
fn Parser::new(source : String) -> Parser {
  let chars = source.to_array()
  { chars, positions: build_positions(chars), index: 0 }
}

///|
fn Parser::span(self : Parser, start : Int, end : Int) -> SourceSpan {
  { start: self.positions[start], end: self.positions[end] }
}

///|
fn Parser::point_span(self : Parser) -> SourceSpan {
  self.span(self.index, self.index)
}

///|
fn Parser::fail(
  self : Parser,
  code : String,
  message : String,
  span? : SourceSpan,
) -> Unit raise ParserFailure {
  raise Error({ code, message, span: span.unwrap_or(self.point_span()) })
}

///|
fn Parser::is_at_end(self : Parser) -> Bool {
  self.index >= self.chars.length()
}

///|
fn Parser::peek(self : Parser) -> Char? {
  self.chars.get(self.index)
}

///|
fn Parser::starts_with(self : Parser, text : String) -> Bool {
  let expected = text.to_array()
  if self.index + expected.length() > self.chars.length() {
    return false
  }
  for offset in 0..<expected.length() {
    if self.chars[self.index + offset] != expected[offset] {
      return false
    }
  }
  true
}

///|
fn Parser::advance(self : Parser) -> Char? {
  match self.peek() {
    Some(char) => {
      self.index += 1
      Some(char)
    }
    None => None
  }
}

///|
fn Parser::consume_literal(
  self : Parser,
  text : String,
) -> Unit raise ParserFailure {
  if !self.starts_with(text) {
    self.fail("unexpected_token", "Expected `\{text}`.")
  }
  self.index += text.to_array().length()
}

///|
fn Parser::skip_whitespace(self : Parser) -> Unit {
  for ;; {
    match self.peek() {
      Some(char) if char.is_whitespace() => self.index += 1
      _ => break
    }
  }
}

///|
fn is_name_start(char : Char) -> Bool {
  char.is_ascii_alphabetic() ||
  char == '_' ||
  char == ':' ||
  (!char.is_ascii() && !char.is_whitespace() && !char.is_control())
}

///|
fn is_name_continue(char : Char) -> Bool {
  is_name_start(char) || char.is_ascii_digit() || char == '-' || char == '.'
}

///|
fn chars_to_string(chars : ArrayView[Char]) -> String {
  chars.iter().fold(init="", fn(text, char) { text + char.to_string() })
}

///|
fn Parser::parse_name(
  self : Parser,
) -> (String, SourceSpan) raise ParserFailure {
  let start = self.index
  match self.peek() {
    Some(char) if is_name_start(char) => self.index += 1
    Some(_) => self.fail("invalid_name", "Expected an XML name.")
    None =>
      self.fail("unexpected_end", "Expected an XML name before end of input.")
  }
  for ;; {
    match self.peek() {
      Some(char) if is_name_continue(char) => self.index += 1
      _ => break
    }
  }
  (chars_to_string(self.chars[start:self.index]), self.span(start, self.index))
}

///|
fn Parser::parse_attribute(self : Parser) -> Attribute raise ParserFailure {
  let start = self.index
  let (name, name_span) = self.parse_name()
  self.skip_whitespace()
  if self.advance() != Some('=') {
    self.fail("unexpected_token", "Expected `=` after attribute `\{name}`.")
  }
  self.skip_whitespace()
  let quote = match self.advance() {
    Some('\'') => '\''
    Some('"') => '"'
    _ => {
      self.fail("unquoted_attribute", "Attribute `\{name}` must use quotes.")
      '"'
    }
  }
  let value_start = self.index
  for ;; {
    match self.peek() {
      Some(char) if char == quote => break
      Some('<') =>
        self.fail(
          "invalid_attribute_value",
          "Attribute `\{name}` contains `<`.",
        )
      Some(_) => self.index += 1
      None =>
        self.fail(
          "unexpected_end",
          "Attribute `\{name}` is missing its closing quote.",
        )
    }
  }
  let value_end = self.index
  ignore(self.advance())
  {
    name,
    value: chars_to_string(self.chars[value_start:value_end]),
    span: self.span(start, self.index),
    name_span,
    value_span: self.span(value_start, value_end),
  }
}

///|
fn Parser::scan_until(
  self : Parser,
  terminator : String,
  description : String,
) -> (Int, Int) raise ParserFailure {
  let start = self.index
  for ;; {
    if self.starts_with(terminator) {
      let end = self.index
      self.consume_literal(terminator)
      return (start, end)
    }
    if self.is_at_end() {
      self.fail("unexpected_end", "Unterminated \{description}.")
    }
    self.index += 1
  }
}

///|
fn Parser::parse_comment(self : Parser) -> SourceText raise ParserFailure {
  let start = self.index
  self.consume_literal("<!--")
  let (value_start, value_end) = self.scan_until("-->", "comment")
  {
    value: chars_to_string(self.chars[value_start:value_end]),
    span: self.span(start, self.index),
    value_span: self.span(value_start, value_end),
  }
}

///|
fn Parser::parse_cdata(self : Parser) -> SourceText raise ParserFailure {
  let start = self.index
  self.consume_literal("<![CDATA[")
  let (value_start, value_end) = self.scan_until("]]>", "CDATA section")
  {
    value: chars_to_string(self.chars[value_start:value_end]),
    span: self.span(start, self.index),
    value_span: self.span(value_start, value_end),
  }
}

///|
fn Parser::parse_processing_instruction(
  self : Parser,
) -> SourceText raise ParserFailure {
  let start = self.index
  self.consume_literal("<?")
  let (value_start, value_end) = self.scan_until("?>", "processing instruction")
  {
    value: chars_to_string(self.chars[value_start:value_end]),
    span: self.span(start, self.index),
    value_span: self.span(value_start, value_end),
  }
}

///|
fn Parser::parse_text(self : Parser) -> SourceText {
  let start = self.index
  for ;; {
    match self.peek() {
      Some('<') | None => break
      Some(_) => self.index += 1
    }
  }
  let span = self.span(start, self.index)
  {
    value: chars_to_string(self.chars[start:self.index]),
    span,
    value_span: span,
  }
}

///|
fn has_attribute(attributes : ArrayView[Attribute], name : String) -> Bool {
  for attribute in attributes {
    if attribute.name == name {
      return true
    }
  }
  false
}

///|
fn Parser::parse_element(self : Parser) -> Element raise ParserFailure {
  let element_start = self.index
  self.consume_literal("<")
  let (name, _) = self.parse_name()
  let attributes : Array[Attribute] = []
  for ;; {
    self.skip_whitespace()
    if self.starts_with("/>") {
      self.consume_literal("/>")
      let open_tag_span = self.span(element_start, self.index)
      return {
        name,
        attributes,
        children: [],
        span: open_tag_span,
        open_tag_span,
        close_tag_span: None,
      }
    }
    if self.starts_with(">") {
      self.consume_literal(">")
      break
    }
    if self.is_at_end() {
      self.fail(
        "unexpected_end",
        "Element `<\{name}>` has no closing delimiter.",
      )
    }
    let attribute = self.parse_attribute()
    if has_attribute(attributes, attribute.name) {
      self.fail(
        "duplicate_attribute",
        "Attribute `\{attribute.name}` appears more than once on `<\{name}>`.",
        span=attribute.name_span,
      )
    }
    attributes.push(attribute)
  }
  let open_tag_span = self.span(element_start, self.index)
  let children : Array[Node] = []
  for ;; {
    if self.starts_with("</") {
      let close_start = self.index
      self.consume_literal("</")
      let (close_name, close_name_span) = self.parse_name()
      self.skip_whitespace()
      self.consume_literal(">")
      let close_tag_span = self.span(close_start, self.index)
      if close_name != name {
        self.fail(
          "mismatched_tag",
          "Element `<\{name}>` is closed by `</\{close_name}>`.",
          span=close_name_span,
        )
      }
      return {
        name,
        attributes,
        children,
        span: self.span(element_start, self.index),
        open_tag_span,
        close_tag_span: Some(close_tag_span),
      }
    }
    if self.starts_with("<!--") {
      children.push(Comment(self.parse_comment()))
    } else if self.starts_with("<![CDATA[") {
      children.push(CData(self.parse_cdata()))
    } else if self.starts_with("<?") {
      children.push(ProcessingInstruction(self.parse_processing_instruction()))
    } else if self.starts_with("<") {
      children.push(Element(self.parse_element()))
    } else if self.is_at_end() {
      self.fail("unexpected_end", "Element `<\{name}>` has no closing tag.")
    } else {
      children.push(Text(self.parse_text()))
    }
  }
}

///|
fn Parser::skip_document_misc(self : Parser) -> Unit raise ParserFailure {
  for ;; {
    self.skip_whitespace()
    if self.starts_with("<!--") {
      ignore(self.parse_comment())
    } else if self.starts_with("<?") {
      ignore(self.parse_processing_instruction())
    } else {
      break
    }
  }
}

///|
fn Parser::parse_document(
  self : Parser,
  source : String,
) -> Document raise ParserFailure {
  self.skip_document_misc()
  if self.is_at_end() {
    self.fail("missing_root", "The document has no root element.")
  }
  let root = self.parse_element()
  self.skip_document_misc()
  if !self.is_at_end() {
    self.fail(
      "trailing_content",
      "Unexpected content after the root element.",
      span=self.span(self.index, self.chars.length()),
    )
  }
  { source, root }
}

///|
pub fn parse(source : String) -> Result[Document, ParseError] {
  let parser = Parser::new(source)
  Ok(parser.parse_document(source)) catch {
    Error(error) => Err(error)
  }
}
