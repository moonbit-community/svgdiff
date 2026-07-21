///|
pub(all) struct AffineTransform {
  a : Double
  b : Double
  c : Double
  d : Double
  e : Double
  f : Double
} derive(Eq)

///|
pub(all) struct NormalizedTransformList {
  matrix : AffineTransform
  signature : String
}

///|
pub(all) enum TransformListParse {
  ValidTransformList(NormalizedTransformList)
  InvalidTransformList
}

///|
pub(all) struct TransformListParser {
  data : String
  mut position : Int
}

///|
pub fn AffineTransform::identity() -> AffineTransform {
  { a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 0.0, f: 0.0 }
}

///|
pub fn AffineTransform::is_identity(self : AffineTransform) -> Bool {
  self == AffineTransform::identity()
}

///|
pub fn AffineTransform::max_linear_scale(self : AffineTransform) -> Double {
  let squared_sum = self.a * self.a +
    self.b * self.b +
    self.c * self.c +
    self.d * self.d
  let determinant = self.a * self.d - self.b * self.c
  let discriminant = (squared_sum * squared_sum -
  4.0 * determinant * determinant).max(0.0)
  ((squared_sum + discriminant.sqrt()) / 2.0).sqrt()
}

///|
pub fn AffineTransform::translate(tx : Double, ty : Double) -> AffineTransform {
  { a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: tx, f: ty }
}

///|
pub fn AffineTransform::scale(sx : Double, sy : Double) -> AffineTransform {
  { a: sx, b: 0.0, c: 0.0, d: sy, e: 0.0, f: 0.0 }
}

///|
fn exact_rotation_components(degrees : Double) -> (Double, Double) {
  let turns = (degrees / 360.0).floor()
  let normalized = degrees - turns * 360.0
  if normalized == 0.0 || normalized == 360.0 {
    (1.0, 0.0)
  } else if normalized == 90.0 {
    (0.0, 1.0)
  } else if normalized == 180.0 {
    (-1.0, 0.0)
  } else if normalized == 270.0 {
    (0.0, -1.0)
  } else {
    let radians = degrees * 3.141592653589793 / 180.0
    (@math.cos(radians), @math.sin(radians))
  }
}

///|
pub fn AffineTransform::rotate(degrees : Double) -> AffineTransform {
  let (cosine, sine) = exact_rotation_components(degrees)
  { a: cosine, b: sine, c: -sine, d: cosine, e: 0.0, f: 0.0 }
}

///|
pub fn AffineTransform::skew_x(degrees : Double) -> AffineTransform {
  { a: 1.0, b: 0.0, c: exact_skew_tangent(degrees), d: 1.0, e: 0.0, f: 0.0 }
}

///|
pub fn AffineTransform::skew_y(degrees : Double) -> AffineTransform {
  { a: 1.0, b: exact_skew_tangent(degrees), c: 0.0, d: 1.0, e: 0.0, f: 0.0 }
}

///|
fn exact_skew_tangent(degrees : Double) -> Double {
  let turns = (degrees / 180.0).floor()
  let normalized = degrees - turns * 180.0
  if normalized == 0.0 || normalized == 180.0 {
    0.0
  } else {
    let radians = degrees * 3.141592653589793 / 180.0
    @math.tan(radians)
  }
}

///|
pub fn normalized_transform_component(value : Double) -> Double {
  if value == 0.0 {
    0.0
  } else {
    value
  }
}

///|
pub fn AffineTransform::multiply(
  self : AffineTransform,
  other : AffineTransform,
) -> AffineTransform {
  {
    a: normalized_transform_component(self.a * other.a + self.c * other.b),
    b: normalized_transform_component(self.b * other.a + self.d * other.b),
    c: normalized_transform_component(self.a * other.c + self.c * other.d),
    d: normalized_transform_component(self.b * other.c + self.d * other.d),
    e: normalized_transform_component(
      self.a * other.e + self.c * other.f + self.e,
    ),
    f: normalized_transform_component(
      self.b * other.e + self.d * other.f + self.f,
    ),
  }
}

///|
pub fn AffineTransform::apply_point(
  self : AffineTransform,
  x : Double,
  y : Double,
) -> (Double, Double) {
  (
    normalized_transform_component(self.a * x + self.c * y + self.e),
    normalized_transform_component(self.b * x + self.d * y + self.f),
  )
}

///|
pub fn AffineTransform::apply_direction_angle(
  self : AffineTransform,
  degrees : Double,
) -> Double {
  let radians = degrees * 3.141592653589793 / 180.0
  let x = @math.cos(radians)
  let y = @math.sin(radians)
  @math.atan2(self.b * x + self.d * y, self.a * x + self.c * y) *
  180.0 /
  3.141592653589793
}

///|
pub fn AffineTransform::signature(self : AffineTransform) -> String {
  "matrix(\{self.a},\{self.b},\{self.c},\{self.d},\{self.e},\{self.f})"
}

///|
fn transform_component_is_integer(value : Double) -> Bool {
  value == value.floor()
}

///|
pub fn AffineTransform::has_proven_renderer_conformance(
  self : AffineTransform,
) -> Bool {
  let axis_aligned = self.b == 0.0 && self.c == 0.0
  axis_aligned &&
  transform_component_is_integer(self.a) &&
  transform_component_is_integer(self.b) &&
  transform_component_is_integer(self.c) &&
  transform_component_is_integer(self.d) &&
  transform_component_is_integer(self.e) &&
  transform_component_is_integer(self.f)
}

///|
fn transform_is_whitespace(unit : UInt16) -> Bool {
  unit == ' ' || unit == '\t' || unit == '\n' || unit == '\r'
}

///|
fn transform_is_digit(unit : UInt16) -> Bool {
  unit >= '0' && unit <= '9'
}

///|
pub fn TransformListParser::skip_whitespace(self : TransformListParser) -> Bool {
  let start = self.position
  while self.position < self.data.length() &&
        transform_is_whitespace(self.data[self.position]) {
    self.position += 1
  }
  self.position > start
}

///|
pub fn TransformListParser::parse_number(self : TransformListParser) -> Double? {
  let start = self.position
  if self.position < self.data.length() &&
    (self.data[self.position] == '+' || self.data[self.position] == '-') {
    self.position += 1
  }
  let mut digits = 0
  while self.position < self.data.length() &&
        transform_is_digit(self.data[self.position]) {
    self.position += 1
    digits += 1
  }
  if self.position < self.data.length() && self.data[self.position] == '.' {
    self.position += 1
    while self.position < self.data.length() &&
          transform_is_digit(self.data[self.position]) {
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
          transform_is_digit(self.data[self.position]) {
      self.position += 1
    }
    if self.position == exponent_start {
      self.position = start
      return None
    }
  }
  let value = try
    @string.parse_double(
      self.data.view(start_offset=start, end_offset=self.position),
    )
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
fn TransformListParser::parse_name(self : TransformListParser) -> String? {
  let start = self.position
  while self.position < self.data.length() {
    let unit = self.data[self.position]
    if (unit >= 'a' && unit <= 'z') || (unit >= 'A' && unit <= 'Z') {
      self.position += 1
    } else {
      break
    }
  }
  if self.position == start {
    None
  } else {
    Some(
      self.data.view(start_offset=start, end_offset=self.position).to_owned(),
    )
  }
}

///|
fn TransformListParser::parse_arguments(
  self : TransformListParser,
) -> Array[Double]? {
  let arguments : Array[Double] = []
  ignore(self.skip_whitespace())
  if self.position < self.data.length() && self.data[self.position] == ')' {
    self.position += 1
    return Some(arguments)
  }
  while self.position < self.data.length() {
    guard self.parse_number() is Some(value) else { return None }
    arguments.push(value)
    let had_whitespace = self.skip_whitespace()
    if self.position >= self.data.length() {
      return None
    }
    if self.data[self.position] == ')' {
      self.position += 1
      return Some(arguments)
    }
    if self.data[self.position] == ',' {
      self.position += 1
      ignore(self.skip_whitespace())
      if self.position >= self.data.length() ||
        self.data[self.position] == ',' ||
        self.data[self.position] == ')' {
        return None
      }
    } else if !had_whitespace &&
      self.data[self.position] != '+' &&
      self.data[self.position] != '-' {
      return None
    }
  }
  None
}

///|
fn normalized_argument_signature(arguments : Array[Double]) -> String {
  let result = StringBuilder::new()
  for index, argument in arguments {
    if index > 0 {
      result.write_char(',')
    }
    result.write_string(argument.to_string())
  }
  result.to_string()
}

///|
fn transform_function_matrix(
  name : String,
  arguments : Array[Double],
) -> AffineTransform? {
  match (name, arguments) {
    ("matrix", [a, b, c, d, e, f]) => Some({ a, b, c, d, e, f })
    ("translate", [tx]) => Some(AffineTransform::translate(tx, 0.0))
    ("translate", [tx, ty]) => Some(AffineTransform::translate(tx, ty))
    ("scale", [scale]) => Some(AffineTransform::scale(scale, scale))
    ("scale", [sx, sy]) => Some(AffineTransform::scale(sx, sy))
    ("rotate", [degrees]) => Some(AffineTransform::rotate(degrees))
    ("rotate", [degrees, cx, cy]) =>
      Some(
        AffineTransform::translate(cx, cy)
        .multiply(AffineTransform::rotate(degrees))
        .multiply(AffineTransform::translate(-cx, -cy)),
      )
    ("skewX", [degrees]) => Some(AffineTransform::skew_x(degrees))
    ("skewY", [degrees]) => Some(AffineTransform::skew_y(degrees))
    _ => None
  }
}

///|
pub fn parse_transform_list(value : String) -> TransformListParse {
  let parser = { data: value, position: 0 }
  let mut matrix = AffineTransform::identity()
  let signature = StringBuilder::new()
  let mut function_count = 0
  ignore(parser.skip_whitespace())
  while parser.position < value.length() {
    guard parser.parse_name() is Some(name) else { return InvalidTransformList }
    ignore(parser.skip_whitespace())
    guard parser.position < value.length() && value[parser.position] == '(' else {
      return InvalidTransformList
    }
    parser.position += 1
    guard parser.parse_arguments() is Some(arguments) else {
      return InvalidTransformList
    }
    guard transform_function_matrix(name, arguments) is Some(function_matrix) else {
      return InvalidTransformList
    }
    if function_count > 0 {
      signature.write_char(' ')
    }
    signature.write_string(name)
    signature.write_char('(')
    signature.write_string(normalized_argument_signature(arguments))
    signature.write_char(')')
    matrix = matrix.multiply(function_matrix)
    function_count += 1
    let had_whitespace = parser.skip_whitespace()
    if parser.position >= value.length() {
      break
    }
    if value[parser.position] == ',' {
      parser.position += 1
      ignore(parser.skip_whitespace())
      if parser.position >= value.length() {
        return InvalidTransformList
      }
    } else if !had_whitespace {
      return InvalidTransformList
    }
  }
  ValidTransformList({ matrix, signature: signature.to_string() })
}
