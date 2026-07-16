///|
priv enum NormalizedPathSegment {
  MoveTo(Double, Double)
  LineTo(Double, Double)
  CubicTo(Double, Double, Double, Double, Double, Double)
  QuadraticTo(Double, Double, Double, Double)
  ArcTo(Double, Double, Double, Bool, Bool, Double, Double)
  ClosePath
}

///|
priv struct PathSegmentEvidence {
  authored_command : String
  explicit_command : Bool
  authored_value : String
  source_span : ReportSourceSpan
  normalized : NormalizedPathSegment
}

///|
priv struct NormalizedPathParameter {
  name : String
  value : String
  numeric_value : Double?
}

///|
priv enum PathDataParse {
  Valid(Array[PathSegmentEvidence])
  Invalid
}

///|
priv struct PathDataParser {
  data : String
  raw_data : String
  source_boundaries : Array[Int]
  base_offset : Int
  mut position : Int
  mut x : Double
  mut y : Double
  mut subpath_x : Double
  mut subpath_y : Double
  mut cubic_x : Double
  mut cubic_y : Double
  mut quadratic_x : Double
  mut quadratic_y : Double
  mut previous_kind : String
}

///|
fn PathDataParser::new(
  data : String,
  raw_data : String,
  source_boundaries : Array[Int],
  base_offset : Int,
) -> PathDataParser {
  {
    data,
    raw_data,
    source_boundaries,
    base_offset,
    position: 0,
    x: 0.0,
    y: 0.0,
    subpath_x: 0.0,
    subpath_y: 0.0,
    cubic_x: 0.0,
    cubic_y: 0.0,
    quadratic_x: 0.0,
    quadratic_y: 0.0,
    previous_kind: "none",
  }
}

///|
fn path_is_whitespace(unit : UInt16) -> Bool {
  unit == ' ' || unit == '\t' || unit == '\n' || unit == '\r'
}

///|
fn path_is_digit(unit : UInt16) -> Bool {
  unit >= '0' && unit <= '9'
}

///|
fn path_is_command(unit : UInt16) -> Bool {
  match unit {
    'M'
    | 'm'
    | 'Z'
    | 'z'
    | 'L'
    | 'l'
    | 'H'
    | 'h'
    | 'V'
    | 'v'
    | 'C'
    | 'c'
    | 'S'
    | 's'
    | 'Q'
    | 'q'
    | 'T'
    | 't'
    | 'A'
    | 'a' => true
    _ => false
  }
}

///|
fn PathDataParser::skip_whitespace(self : PathDataParser) -> Unit {
  while self.position < self.data.length() &&
        path_is_whitespace(self.data[self.position]) {
    self.position += 1
  }
}

///|
fn PathDataParser::prepare_argument(self : PathDataParser) -> Bool {
  self.skip_whitespace()
  if self.position < self.data.length() && self.data[self.position] == ',' {
    self.position += 1
    self.skip_whitespace()
    if self.position < self.data.length() && self.data[self.position] == ',' {
      return false
    }
  }
  true
}

///|
fn PathDataParser::parse_number(
  self : PathDataParser,
  prepared? : Bool = false,
) -> Double? {
  if !prepared && !self.prepare_argument() {
    return None
  }
  let start = self.position
  if self.position < self.data.length() &&
    (self.data[self.position] == '+' || self.data[self.position] == '-') {
    self.position += 1
  }
  let mut digits = 0
  while self.position < self.data.length() &&
        path_is_digit(self.data[self.position]) {
    self.position += 1
    digits += 1
  }
  if self.position < self.data.length() && self.data[self.position] == '.' {
    self.position += 1
    while self.position < self.data.length() &&
          path_is_digit(self.data[self.position]) {
      self.position += 1
      digits += 1
    }
  }
  if digits == 0 {
    self.position = start
    return None
  }
  if self.position < self.data.length() &&
    (self.data[self.position] == 'e' || self.data[self.position] == 'E') {
    self.position += 1
    if self.position < self.data.length() &&
      (self.data[self.position] == '+' || self.data[self.position] == '-') {
      self.position += 1
    }
    let exponent_start = self.position
    while self.position < self.data.length() &&
          path_is_digit(self.data[self.position]) {
      self.position += 1
    }
    if self.position == exponent_start {
      self.position = start
      return None
    }
  }
  let start_offset = start
  let end_offset = self.position
  let value = try
    @string.parse_double(self.data.view(start_offset~, end_offset~))
  catch {
    _ => {
      self.position = start
      return None
    }
  } noraise {
    value => value
  }
  if value.is_inf() || value.is_nan() {
    self.position = start
    None
  } else {
    Some(value)
  }
}

///|
fn PathDataParser::parse_flag(
  self : PathDataParser,
  prepared? : Bool = false,
) -> Bool? {
  if !prepared && !self.prepare_argument() {
    return None
  }
  if self.position >= self.data.length() {
    return None
  }
  match self.data[self.position] {
    '0' => {
      self.position += 1
      Some(false)
    }
    '1' => {
      self.position += 1
      Some(true)
    }
    _ => None
  }
}

///|
fn PathDataParser::finish_segment(
  self : PathDataParser,
  command : UInt16,
  explicit : Bool,
  start : Int,
  normalized : NormalizedPathSegment,
) -> PathSegmentEvidence {
  let source_start = self.source_boundaries[start]
  let source_end = self.source_boundaries[self.position]
  {
    authored_command: Int::unsafe_to_char(command.to_int()).to_string(),
    explicit_command: explicit,
    authored_value: source_range_slice(self.raw_data, source_start, source_end),
    source_span: {
      start_offset: self.base_offset + source_start,
      end_offset: self.base_offset + source_end,
    },
    normalized,
  }
}

///|
fn PathDataParser::reset_controls(self : PathDataParser) -> Unit {
  self.previous_kind = "other"
}

///|
fn PathDataParser::parse_group(
  self : PathDataParser,
  command : UInt16,
  explicit : Bool,
  start : Int,
  prepared : Bool,
) -> PathSegmentEvidence? {
  let relative = command >= 'a' && command <= 'z'
  match command {
    'M' | 'm' => {
      guard self.parse_number(prepared~) is Some(raw_x) else { return None }
      guard self.parse_number() is Some(raw_y) else { return None }
      let x = if relative { self.x + raw_x } else { raw_x }
      let y = if relative { self.y + raw_y } else { raw_y }
      self.x = x
      self.y = y
      self.subpath_x = x
      self.subpath_y = y
      self.reset_controls()
      Some(self.finish_segment(command, explicit, start, MoveTo(x, y)))
    }
    'L' | 'l' => {
      guard self.parse_number(prepared~) is Some(raw_x) else { return None }
      guard self.parse_number() is Some(raw_y) else { return None }
      let x = if relative { self.x + raw_x } else { raw_x }
      let y = if relative { self.y + raw_y } else { raw_y }
      self.x = x
      self.y = y
      self.reset_controls()
      Some(self.finish_segment(command, explicit, start, LineTo(x, y)))
    }
    'H' | 'h' => {
      guard self.parse_number(prepared~) is Some(raw_x) else { return None }
      self.x = if relative { self.x + raw_x } else { raw_x }
      self.reset_controls()
      Some(
        self.finish_segment(command, explicit, start, LineTo(self.x, self.y)),
      )
    }
    'V' | 'v' => {
      guard self.parse_number(prepared~) is Some(raw_y) else { return None }
      self.y = if relative { self.y + raw_y } else { raw_y }
      self.reset_controls()
      Some(
        self.finish_segment(command, explicit, start, LineTo(self.x, self.y)),
      )
    }
    'C' | 'c' => {
      guard self.parse_number(prepared~) is Some(a) else { return None }
      guard self.parse_number() is Some(b) else { return None }
      guard self.parse_number() is Some(c) else { return None }
      guard self.parse_number() is Some(d) else { return None }
      guard self.parse_number() is Some(e) else { return None }
      guard self.parse_number() is Some(f) else { return None }
      let x1 = if relative { self.x + a } else { a }
      let y1 = if relative { self.y + b } else { b }
      let x2 = if relative { self.x + c } else { c }
      let y2 = if relative { self.y + d } else { d }
      let x = if relative { self.x + e } else { e }
      let y = if relative { self.y + f } else { f }
      self.x = x
      self.y = y
      self.cubic_x = x2
      self.cubic_y = y2
      self.previous_kind = "cubic"
      Some(
        self.finish_segment(
          command,
          explicit,
          start,
          CubicTo(x1, y1, x2, y2, x, y),
        ),
      )
    }
    'S' | 's' => {
      guard self.parse_number(prepared~) is Some(a) else { return None }
      guard self.parse_number() is Some(b) else { return None }
      guard self.parse_number() is Some(c) else { return None }
      guard self.parse_number() is Some(d) else { return None }
      let x1 = if self.previous_kind == "cubic" {
        2.0 * self.x - self.cubic_x
      } else {
        self.x
      }
      let y1 = if self.previous_kind == "cubic" {
        2.0 * self.y - self.cubic_y
      } else {
        self.y
      }
      let x2 = if relative { self.x + a } else { a }
      let y2 = if relative { self.y + b } else { b }
      let x = if relative { self.x + c } else { c }
      let y = if relative { self.y + d } else { d }
      self.x = x
      self.y = y
      self.cubic_x = x2
      self.cubic_y = y2
      self.previous_kind = "cubic"
      Some(
        self.finish_segment(
          command,
          explicit,
          start,
          CubicTo(x1, y1, x2, y2, x, y),
        ),
      )
    }
    'Q' | 'q' => {
      guard self.parse_number(prepared~) is Some(a) else { return None }
      guard self.parse_number() is Some(b) else { return None }
      guard self.parse_number() is Some(c) else { return None }
      guard self.parse_number() is Some(d) else { return None }
      let x1 = if relative { self.x + a } else { a }
      let y1 = if relative { self.y + b } else { b }
      let x = if relative { self.x + c } else { c }
      let y = if relative { self.y + d } else { d }
      self.x = x
      self.y = y
      self.quadratic_x = x1
      self.quadratic_y = y1
      self.previous_kind = "quadratic"
      Some(
        self.finish_segment(command, explicit, start, QuadraticTo(x1, y1, x, y)),
      )
    }
    'T' | 't' => {
      guard self.parse_number(prepared~) is Some(a) else { return None }
      guard self.parse_number() is Some(b) else { return None }
      let x1 = if self.previous_kind == "quadratic" {
        2.0 * self.x - self.quadratic_x
      } else {
        self.x
      }
      let y1 = if self.previous_kind == "quadratic" {
        2.0 * self.y - self.quadratic_y
      } else {
        self.y
      }
      let x = if relative { self.x + a } else { a }
      let y = if relative { self.y + b } else { b }
      self.x = x
      self.y = y
      self.quadratic_x = x1
      self.quadratic_y = y1
      self.previous_kind = "quadratic"
      Some(
        self.finish_segment(command, explicit, start, QuadraticTo(x1, y1, x, y)),
      )
    }
    'A' | 'a' => {
      guard self.parse_number(prepared~) is Some(rx) else { return None }
      guard self.parse_number() is Some(ry) else { return None }
      guard self.parse_number() is Some(rotation) else { return None }
      guard self.parse_flag() is Some(large) else { return None }
      guard self.parse_flag() is Some(sweep) else { return None }
      guard self.parse_number() is Some(raw_x) else { return None }
      guard self.parse_number() is Some(raw_y) else { return None }
      if rx < 0.0 || ry < 0.0 {
        return None
      }
      let x = if relative { self.x + raw_x } else { raw_x }
      let y = if relative { self.y + raw_y } else { raw_y }
      self.x = x
      self.y = y
      self.reset_controls()
      let segment = if rx == 0.0 || ry == 0.0 {
        LineTo(x, y)
      } else {
        ArcTo(rx, ry, rotation, large, sweep, x, y)
      }
      Some(self.finish_segment(command, explicit, start, segment))
    }
    _ => None
  }
}

///|
fn parse_mapped_path_data(
  data : String,
  raw_data : String,
  source_boundaries : Array[Int],
  base_offset : Int,
) -> PathDataParse {
  let parser = PathDataParser::new(
    data, raw_data, source_boundaries, base_offset,
  )
  let segments : Array[PathSegmentEvidence] = []
  let mut command : UInt16? = None
  let mut first = true
  while parser.position <= data.length() {
    parser.skip_whitespace()
    if parser.position == data.length() {
      return Valid(segments)
    }
    let mut explicit = false
    let mut start = parser.position
    if path_is_command(data[parser.position]) {
      command = Some(data[parser.position])
      parser.position += 1
      explicit = true
    }
    guard command is Some(current) else { return Invalid }
    if first && current != 'M' && current != 'm' {
      return Invalid
    }
    first = false
    if current == 'Z' || current == 'z' {
      if !explicit {
        return Invalid
      }
      parser.x = parser.subpath_x
      parser.y = parser.subpath_y
      parser.reset_controls()
      segments.push(parser.finish_segment(current, true, start, ClosePath))
      command = None
      continue
    }
    let prepared = true
    if explicit {
      parser.skip_whitespace()
    } else {
      if !parser.prepare_argument() {
        return Invalid
      }
      start = parser.position
    }
    guard parser.parse_group(current, explicit, start, prepared)
      is Some(segment) else {
      return Invalid
    }
    segments.push(segment)
    if current == 'M' {
      command = Some('L')
    }
    if current == 'm' {
      command = Some('l')
    }
  }
  Invalid
}

///|
fn parse_path_data(data : String, base_offset : Int) -> PathDataParse {
  let boundaries : Array[Int] = []
  for offset in 0..<=data.length() {
    boundaries.push(offset)
  }
  parse_mapped_path_data(data, data, boundaries, base_offset)
}

///|
fn parse_path_attribute_data(
  raw_data : String,
  base_offset : Int,
) -> PathDataParse {
  if raw_data.find("&") is None {
    return parse_path_data(raw_data, base_offset)
  }
  let decoded = StringBuilder::new()
  let boundaries : Array[Int] = [0]
  let mut position = 0
  while position < raw_data.length() {
    if raw_data[position] != '&' {
      decoded.write_string(source_range_slice(raw_data, position, position + 1))
      position += 1
      boundaries.push(position)
      continue
    }
    let entity_start = position
    position += 1
    while position < raw_data.length() && raw_data[position] != ';' {
      position += 1
    }
    if position == raw_data.length() {
      return Invalid
    }
    position += 1
    let entity = source_range_slice(raw_data, entity_start, position)
    let value = try @xml.unescape(entity) catch {
      _ => return Invalid
    } noraise {
      value => value
    }
    if value == "" {
      return Invalid
    }
    decoded.write_string(value)
    for index in 0..<value.length() {
      boundaries.push(
        if index + 1 == value.length() {
          position
        } else {
          entity_start
        },
      )
    }
  }
  parse_mapped_path_data(decoded.to_string(), raw_data, boundaries, base_offset)
}

///|
fn normalized_path_segment_signature(segment : NormalizedPathSegment) -> String {
  match segment {
    MoveTo(x, y) => "M \{x} \{y}"
    LineTo(x, y) => "L \{x} \{y}"
    CubicTo(x1, y1, x2, y2, x, y) => "C \{x1} \{y1} \{x2} \{y2} \{x} \{y}"
    QuadraticTo(x1, y1, x, y) => "Q \{x1} \{y1} \{x} \{y}"
    ArcTo(rx, ry, rotation, large, sweep, x, y) =>
      "A \{rx} \{ry} \{rotation} \{large} \{sweep} \{x} \{y}"
    ClosePath => "Z"
  }
}

///|
fn normalized_path_segment_kind(segment : NormalizedPathSegment) -> String {
  match segment {
    MoveTo(_, _) => "move"
    LineTo(_, _) => "line"
    CubicTo(_, _, _, _, _, _) => "cubic"
    QuadraticTo(_, _, _, _) => "quadratic"
    ArcTo(_, _, _, _, _, _, _) => "arc"
    ClosePath => "close"
  }
}

///|
fn numeric_path_parameter(
  name : String,
  value : Double,
) -> NormalizedPathParameter {
  { name, value: value.to_string(), numeric_value: Some(value) }
}

///|
fn flag_path_parameter(name : String, value : Bool) -> NormalizedPathParameter {
  { name, value: value.to_string(), numeric_value: None }
}

///|
fn normalized_path_segment_parameters(
  segment : NormalizedPathSegment,
) -> Array[NormalizedPathParameter] {
  match segment {
    MoveTo(x, y) | LineTo(x, y) =>
      [numeric_path_parameter("x", x), numeric_path_parameter("y", y)]
    CubicTo(x1, y1, x2, y2, x, y) =>
      [
        numeric_path_parameter("x1", x1),
        numeric_path_parameter("y1", y1),
        numeric_path_parameter("x2", x2),
        numeric_path_parameter("y2", y2),
        numeric_path_parameter("x", x),
        numeric_path_parameter("y", y),
      ]
    QuadraticTo(x1, y1, x, y) =>
      [
        numeric_path_parameter("x1", x1),
        numeric_path_parameter("y1", y1),
        numeric_path_parameter("x", x),
        numeric_path_parameter("y", y),
      ]
    ArcTo(rx, ry, rotation, large, sweep, x, y) =>
      [
        numeric_path_parameter("rx", rx),
        numeric_path_parameter("ry", ry),
        numeric_path_parameter("rotation", rotation),
        flag_path_parameter("large_arc", large),
        flag_path_parameter("sweep", sweep),
        numeric_path_parameter("x", x),
        numeric_path_parameter("y", y),
      ]
    ClosePath => []
  }
}

///|
fn path_segments_signature(segments : Array[PathSegmentEvidence]) -> String {
  let mut signature = ""
  for segment in segments {
    if segment.authored_command == "" ||
      segment.authored_value == "" ||
      segment.source_span.end_offset <= segment.source_span.start_offset ||
      (
        segment.explicit_command &&
        segment.authored_value.find(segment.authored_command) != Some(0)
      ) {
      return "invalid-provenance"
    }
    let normalized = normalized_path_segment_signature(segment.normalized)
    signature = if signature == "" {
      normalized
    } else {
      "\{signature};\{normalized}"
    }
  }
  signature
}
