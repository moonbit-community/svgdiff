///|
priv enum PaintFallbackValue {
  PaintFallbackNone
  PaintFallbackColor(String)
}

///|
priv enum ParsedPaintValue {
  NoPaint
  SolidPaint(String)
  LocalPaintServer(String, PaintFallbackValue?)
  ExternalPaintServer
  ContextPaint
  InvalidPaint
}

///|
fn paint_fallback_value(source : String) -> PaintFallbackValue? {
  let value = source.trim().to_owned()
  if value.to_lower() == "none" {
    return Some(PaintFallbackNone)
  }
  match @css_color.parse_solid_color(value) {
    Resolved(_) | CurrentColor | SystemColor(_) =>
      Some(PaintFallbackColor(value))
    Invalid => None
  }
}

///|
fn parse_paint_url(source : String) -> ParsedPaintValue {
  let value = source.trim().to_owned()
  if !ascii_url_start(value, 0) {
    return InvalidPaint
  }
  let mut cursor = 4
  while cursor < value.length() &&
        ascii_reference_whitespace(value[cursor].unsafe_to_char()) {
    cursor += 1
  }
  if cursor >= value.length() {
    return InvalidPaint
  }
  let quote = if value[cursor].unsafe_to_char() == '\'' ||
    value[cursor].unsafe_to_char() == '"' {
    let quote = Some(value[cursor].unsafe_to_char())
    cursor += 1
    quote
  } else {
    None
  }
  let target_start = cursor
  let mut target_end = cursor
  match quote {
    Some(quote) => {
      while cursor < value.length() && value[cursor].unsafe_to_char() != quote {
        if value[cursor].unsafe_to_char() == '\\' {
          return InvalidPaint
        }
        cursor += 1
      }
      if cursor >= value.length() {
        return InvalidPaint
      }
      target_end = cursor
      cursor += 1
      while cursor < value.length() &&
            ascii_reference_whitespace(value[cursor].unsafe_to_char()) {
        cursor += 1
      }
    }
    None => {
      while cursor < value.length() &&
            value[cursor].unsafe_to_char() != ')' &&
            !ascii_reference_whitespace(value[cursor].unsafe_to_char()) {
        if value[cursor].unsafe_to_char() == '\'' ||
          value[cursor].unsafe_to_char() == '"' ||
          value[cursor].unsafe_to_char() == '\\' {
          return InvalidPaint
        }
        cursor += 1
      }
      target_end = cursor
      while cursor < value.length() &&
            ascii_reference_whitespace(value[cursor].unsafe_to_char()) {
        cursor += 1
      }
    }
  }
  if target_start == target_end ||
    cursor >= value.length() ||
    value[cursor].unsafe_to_char() != ')' {
    return InvalidPaint
  }
  let target = value
    .view(start_offset=target_start, end_offset=target_end)
    .to_owned()
  if target.any(character => ascii_reference_whitespace(character)) {
    return InvalidPaint
  }
  cursor += 1
  let remainder = value
    .view(start_offset=cursor, end_offset=value.length())
    .to_owned()
    .trim()
    .to_owned()
  let fallback = if remainder == "" {
    None
  } else {
    match paint_fallback_value(remainder) {
      Some(fallback) => Some(fallback)
      None => return InvalidPaint
    }
  }
  if target.length() > 1 && target.has_prefix("#") {
    let id = target.view(start_offset=1, end_offset=target.length()).to_owned()
    if id.find("#") is Some(_) {
      return InvalidPaint
    }
    LocalPaintServer(decode_local_fragment(id), fallback)
  } else {
    ExternalPaintServer
  }
}

///|
fn parse_paint_value(source : String) -> ParsedPaintValue {
  let value = source.trim().to_owned()
  let normalized = value.to_lower()
  if normalized == "none" {
    return NoPaint
  }
  if normalized == "context-fill" || normalized == "context-stroke" {
    return ContextPaint
  }
  if ascii_url_start(value, 0) {
    return parse_paint_url(value)
  }
  match @css_color.parse_solid_color(value) {
    Resolved(_) | CurrentColor | SystemColor(_) => SolidPaint(value)
    Invalid => InvalidPaint
  }
}

///|
fn paint_server_reference(value : String) -> String? {
  match parse_paint_value(value) {
    LocalPaintServer(id, _) => Some(id)
    _ => None
  }
}

///|
fn paint_value_uses_url(value : String) -> Bool {
  match parse_paint_value(value) {
    LocalPaintServer(_, _) | ExternalPaintServer => true
    _ => false
  }
}

///|
fn authored_paint_server_reference(
  subject : SourceSubject,
  property : String,
) -> String? {
  match source_subject_fact(subject, property) {
    Some(fact) => paint_server_reference(fact.declared_value)
    None =>
      paint_server_reference(subject_value(subject, property).unwrap_or(""))
  }
}
