///|
/// A deterministic sRGB solid color with straight alpha.
pub(all) struct SrgbaColor {
  red : Int
  green : Int
  blue : Int
  alpha : Double
} derive(Eq, Debug)

///|
/// The strict result of parsing one supported SVG solid-color token.
pub(all) enum SolidColorParse {
  Resolved(SrgbaColor)
  CurrentColor
  SystemColor(String)
  Invalid
} derive(Eq, Debug)

///|
fn clamp_unit(value : Double) -> Double {
  if value < 0.0 {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}

///|
fn clamp_byte(value : Double) -> Int {
  let clamped = if value < 0.0 {
    0.0
  } else if value > 255.0 {
    255.0
  } else {
    value
  }
  clamped.round().to_int()
}

///|
fn strict_number(source : String) -> Double? {
  let value = source.trim().to_owned()
  if value == "" {
    return None
  }
  let mut position = 0
  if value[position] == '+' || value[position] == '-' {
    position += 1
  }
  let mut integer_digits = 0
  while position < value.length() &&
        value[position] >= '0' &&
        value[position] <= '9' {
    position += 1
    integer_digits += 1
  }
  let mut fractional_digits = 0
  if position < value.length() && value[position] == '.' {
    position += 1
    while position < value.length() &&
          value[position] >= '0' &&
          value[position] <= '9' {
      position += 1
      fractional_digits += 1
    }
  }
  if integer_digits == 0 && fractional_digits == 0 {
    return None
  }
  if position < value.length() &&
    (value[position] == 'e' || value[position] == 'E') {
    position += 1
    if position < value.length() &&
      (value[position] == '+' || value[position] == '-') {
      position += 1
    }
    let exponent_start = position
    while position < value.length() &&
          value[position] >= '0' &&
          value[position] <= '9' {
      position += 1
    }
    if position == exponent_start {
      return None
    }
  }
  if position != value.length() {
    return None
  }
  try @string.parse_double(value) catch {
    _ => None
  } noraise {
    number => Some(number)
  }
}

///|
fn percentage(source : String) -> Double? {
  let value = source.trim().to_owned()
  if !value.has_suffix("%") {
    return None
  }
  strict_number(
    value.view(start_offset=0, end_offset=value.length() - 1).to_owned(),
  ).map(number => number / 100.0)
}

///|
/// Parse an SVG/CSS alpha value and clamp its computed value to `[0,1]`.
pub fn parse_alpha_value(source : String) -> Double? {
  match percentage(source) {
    Some(value) => Some(clamp_unit(value))
    None => strict_number(source).map(clamp_unit)
  }
}

///|
fn hex_digit(code : UInt16) -> Int? {
  if code >= '0' && code <= '9' {
    Some(code.to_int() - '0'.to_int())
  } else if code >= 'a' && code <= 'f' {
    Some(code.to_int() - 'a'.to_int() + 10)
  } else if code >= 'A' && code <= 'F' {
    Some(code.to_int() - 'A'.to_int() + 10)
  } else {
    None
  }
}

///|
fn parse_hex_pair(source : String, start : Int) -> Int? {
  guard hex_digit(source[start]) is Some(high) else { return None }
  guard hex_digit(source[start + 1]) is Some(low) else { return None }
  Some(high * 16 + low)
}

///|
fn parse_hex_color(source : String) -> SrgbaColor? {
  guard source.has_prefix("#") else { return None }
  match source.length() {
    4 | 5 => {
      guard hex_digit(source[1]) is Some(red) else { return None }
      guard hex_digit(source[2]) is Some(green) else { return None }
      guard hex_digit(source[3]) is Some(blue) else { return None }
      let alpha = if source.length() == 5 {
        guard hex_digit(source[4]) is Some(value) else { return None }
        (value * 17).to_double() / 255.0
      } else {
        1.0
      }
      Some({ red: red * 17, green: green * 17, blue: blue * 17, alpha })
    }
    7 | 9 => {
      guard parse_hex_pair(source, 1) is Some(red) else { return None }
      guard parse_hex_pair(source, 3) is Some(green) else { return None }
      guard parse_hex_pair(source, 5) is Some(blue) else { return None }
      let alpha = if source.length() == 9 {
        guard parse_hex_pair(source, 7) is Some(value) else { return None }
        value.to_double() / 255.0
      } else {
        1.0
      }
      Some({ red, green, blue, alpha })
    }
    _ => None
  }
}

///|
fn comma_arguments(source : String, name : String) -> Array[String]? {
  if !source.has_prefix(name + "(") || !source.has_suffix(")") {
    return None
  }
  let body = source
    .view(start_offset=name.length() + 1, end_offset=source.length() - 1)
    .to_owned()
  if body.find("(") is Some(_) || body.find(")") is Some(_) {
    return None
  }
  let arguments : Array[String] = []
  for argument in body.split(",") {
    let argument = argument.trim().to_owned()
    if argument == "" {
      return None
    }
    arguments.push(argument)
  }
  Some(arguments)
}

///|
fn parse_rgb_component(source : String, percentage_mode : Bool) -> Double? {
  if percentage_mode {
    percentage(source).map(value => value * 255.0)
  } else {
    strict_number(source)
  }
}

///|
fn parse_rgb_color(source : String, alpha_required : Bool) -> SrgbaColor? {
  let name = if alpha_required { "rgba" } else { "rgb" }
  guard comma_arguments(source, name) is Some(arguments) else { return None }
  if arguments.length() != (if alpha_required { 4 } else { 3 }) {
    return None
  }
  let percentage_mode = arguments[0].has_suffix("%")
  if arguments[1].has_suffix("%") != percentage_mode ||
    arguments[2].has_suffix("%") != percentage_mode {
    return None
  }
  guard parse_rgb_component(arguments[0], percentage_mode) is Some(red) else {
    return None
  }
  guard parse_rgb_component(arguments[1], percentage_mode) is Some(green) else {
    return None
  }
  guard parse_rgb_component(arguments[2], percentage_mode) is Some(blue) else {
    return None
  }
  let alpha = if alpha_required {
    guard parse_alpha_value(arguments[3]) is Some(value) else { return None }
    value
  } else {
    1.0
  }
  Some({
    red: clamp_byte(red),
    green: clamp_byte(green),
    blue: clamp_byte(blue),
    alpha,
  })
}

///|
fn hue_component(m1 : Double, m2 : Double, source_hue : Double) -> Double {
  let hue = if source_hue < 0.0 {
    source_hue + 1.0
  } else if source_hue > 1.0 {
    source_hue - 1.0
  } else {
    source_hue
  }
  if hue * 6.0 < 1.0 {
    m1 + (m2 - m1) * hue * 6.0
  } else if hue * 2.0 < 1.0 {
    m2
  } else if hue * 3.0 < 2.0 {
    m1 + (m2 - m1) * (2.0 / 3.0 - hue) * 6.0
  } else {
    m1
  }
}

///|
fn normalized_hue(degrees : Double) -> Double {
  let turns = degrees / 360.0
  turns - turns.floor()
}

///|
fn parse_hsl_color(source : String, alpha_required : Bool) -> SrgbaColor? {
  let name = if alpha_required { "hsla" } else { "hsl" }
  guard comma_arguments(source, name) is Some(arguments) else { return None }
  if arguments.length() != (if alpha_required { 4 } else { 3 }) {
    return None
  }
  guard strict_number(arguments[0]) is Some(hue_degrees) else { return None }
  guard percentage(arguments[1]) is Some(saturation) else { return None }
  guard percentage(arguments[2]) is Some(lightness) else { return None }
  let saturation = clamp_unit(saturation)
  let lightness = clamp_unit(lightness)
  let alpha = if alpha_required {
    guard parse_alpha_value(arguments[3]) is Some(value) else { return None }
    value
  } else {
    1.0
  }
  if saturation == 0.0 {
    let channel = clamp_byte(lightness * 255.0)
    return Some({ red: channel, green: channel, blue: channel, alpha })
  }
  let m2 = if lightness <= 0.5 {
    lightness * (saturation + 1.0)
  } else {
    lightness + saturation - lightness * saturation
  }
  let m1 = lightness * 2.0 - m2
  let hue = normalized_hue(hue_degrees)
  Some({
    red: clamp_byte(hue_component(m1, m2, hue + 1.0 / 3.0) * 255.0),
    green: clamp_byte(hue_component(m1, m2, hue) * 255.0),
    blue: clamp_byte(hue_component(m1, m2, hue - 1.0 / 3.0) * 255.0),
    alpha,
  })
}

///|
fn system_color_keyword(name : String) -> Bool {
  match name {
    "activeborder"
    | "activecaption"
    | "appworkspace"
    | "background"
    | "buttonface"
    | "buttonhighlight"
    | "buttonshadow"
    | "buttontext"
    | "captiontext"
    | "graytext"
    | "highlight"
    | "highlighttext"
    | "inactiveborder"
    | "inactivecaption"
    | "inactivecaptiontext"
    | "infobackground"
    | "infotext"
    | "menu"
    | "menutext"
    | "scrollbar"
    | "threeddarkshadow"
    | "threedface"
    | "threedhighlight"
    | "threedlightshadow"
    | "threedshadow"
    | "window"
    | "windowframe"
    | "windowtext" => true
    _ => false
  }
}

///|
fn named_color_hex(name : String) -> String? {
  match name {
    "aliceblue" => Some("#f0f8ff")
    "antiquewhite" => Some("#faebd7")
    "aqua" => Some("#00ffff")
    "aquamarine" => Some("#7fffd4")
    "azure" => Some("#f0ffff")
    "beige" => Some("#f5f5dc")
    "bisque" => Some("#ffe4c4")
    "black" => Some("#000000")
    "blanchedalmond" => Some("#ffebcd")
    "blue" => Some("#0000ff")
    "blueviolet" => Some("#8a2be2")
    "brown" => Some("#a52a2a")
    "burlywood" => Some("#deb887")
    "cadetblue" => Some("#5f9ea0")
    "chartreuse" => Some("#7fff00")
    "chocolate" => Some("#d2691e")
    "coral" => Some("#ff7f50")
    "cornflowerblue" => Some("#6495ed")
    "cornsilk" => Some("#fff8dc")
    "crimson" => Some("#dc143c")
    "cyan" => Some("#00ffff")
    "darkblue" => Some("#00008b")
    "darkcyan" => Some("#008b8b")
    "darkgoldenrod" => Some("#b8860b")
    "darkgray" => Some("#a9a9a9")
    "darkgreen" => Some("#006400")
    "darkgrey" => Some("#a9a9a9")
    "darkkhaki" => Some("#bdb76b")
    "darkmagenta" => Some("#8b008b")
    "darkolivegreen" => Some("#556b2f")
    "darkorange" => Some("#ff8c00")
    "darkorchid" => Some("#9932cc")
    "darkred" => Some("#8b0000")
    "darksalmon" => Some("#e9967a")
    "darkseagreen" => Some("#8fbc8f")
    "darkslateblue" => Some("#483d8b")
    "darkslategray" => Some("#2f4f4f")
    "darkslategrey" => Some("#2f4f4f")
    "darkturquoise" => Some("#00ced1")
    "darkviolet" => Some("#9400d3")
    "deeppink" => Some("#ff1493")
    "deepskyblue" => Some("#00bfff")
    "dimgray" => Some("#696969")
    "dimgrey" => Some("#696969")
    "dodgerblue" => Some("#1e90ff")
    "firebrick" => Some("#b22222")
    "floralwhite" => Some("#fffaf0")
    "forestgreen" => Some("#228b22")
    "fuchsia" => Some("#ff00ff")
    "gainsboro" => Some("#dcdcdc")
    "ghostwhite" => Some("#f8f8ff")
    "gold" => Some("#ffd700")
    "goldenrod" => Some("#daa520")
    "gray" => Some("#808080")
    "green" => Some("#008000")
    "greenyellow" => Some("#adff2f")
    "grey" => Some("#808080")
    "honeydew" => Some("#f0fff0")
    "hotpink" => Some("#ff69b4")
    "indianred" => Some("#cd5c5c")
    "indigo" => Some("#4b0082")
    "ivory" => Some("#fffff0")
    "khaki" => Some("#f0e68c")
    "lavender" => Some("#e6e6fa")
    "lavenderblush" => Some("#fff0f5")
    "lawngreen" => Some("#7cfc00")
    "lemonchiffon" => Some("#fffacd")
    "lightblue" => Some("#add8e6")
    "lightcoral" => Some("#f08080")
    "lightcyan" => Some("#e0ffff")
    "lightgoldenrodyellow" => Some("#fafad2")
    "lightgray" => Some("#d3d3d3")
    "lightgreen" => Some("#90ee90")
    "lightgrey" => Some("#d3d3d3")
    "lightpink" => Some("#ffb6c1")
    "lightsalmon" => Some("#ffa07a")
    "lightseagreen" => Some("#20b2aa")
    "lightskyblue" => Some("#87cefa")
    "lightslategray" => Some("#778899")
    "lightslategrey" => Some("#778899")
    "lightsteelblue" => Some("#b0c4de")
    "lightyellow" => Some("#ffffe0")
    "lime" => Some("#00ff00")
    "limegreen" => Some("#32cd32")
    "linen" => Some("#faf0e6")
    "magenta" => Some("#ff00ff")
    "maroon" => Some("#800000")
    "mediumaquamarine" => Some("#66cdaa")
    "mediumblue" => Some("#0000cd")
    "mediumorchid" => Some("#ba55d3")
    "mediumpurple" => Some("#9370db")
    "mediumseagreen" => Some("#3cb371")
    "mediumslateblue" => Some("#7b68ee")
    "mediumspringgreen" => Some("#00fa9a")
    "mediumturquoise" => Some("#48d1cc")
    "mediumvioletred" => Some("#c71585")
    "midnightblue" => Some("#191970")
    "mintcream" => Some("#f5fffa")
    "mistyrose" => Some("#ffe4e1")
    "moccasin" => Some("#ffe4b5")
    "navajowhite" => Some("#ffdead")
    "navy" => Some("#000080")
    "oldlace" => Some("#fdf5e6")
    "olive" => Some("#808000")
    "olivedrab" => Some("#6b8e23")
    "orange" => Some("#ffa500")
    "orangered" => Some("#ff4500")
    "orchid" => Some("#da70d6")
    "palegoldenrod" => Some("#eee8aa")
    "palegreen" => Some("#98fb98")
    "paleturquoise" => Some("#afeeee")
    "palevioletred" => Some("#db7093")
    "papayawhip" => Some("#ffefd5")
    "peachpuff" => Some("#ffdab9")
    "peru" => Some("#cd853f")
    "pink" => Some("#ffc0cb")
    "plum" => Some("#dda0dd")
    "powderblue" => Some("#b0e0e6")
    "purple" => Some("#800080")
    "red" => Some("#ff0000")
    "rosybrown" => Some("#bc8f8f")
    "royalblue" => Some("#4169e1")
    "saddlebrown" => Some("#8b4513")
    "salmon" => Some("#fa8072")
    "sandybrown" => Some("#f4a460")
    "seagreen" => Some("#2e8b57")
    "seashell" => Some("#fff5ee")
    "sienna" => Some("#a0522d")
    "silver" => Some("#c0c0c0")
    "skyblue" => Some("#87ceeb")
    "slateblue" => Some("#6a5acd")
    "slategray" => Some("#708090")
    "slategrey" => Some("#708090")
    "snow" => Some("#fffafa")
    "springgreen" => Some("#00ff7f")
    "steelblue" => Some("#4682b4")
    "tan" => Some("#d2b48c")
    "teal" => Some("#008080")
    "thistle" => Some("#d8bfd8")
    "tomato" => Some("#ff6347")
    "turquoise" => Some("#40e0d0")
    "violet" => Some("#ee82ee")
    "wheat" => Some("#f5deb3")
    "white" => Some("#ffffff")
    "whitesmoke" => Some("#f5f5f5")
    "yellow" => Some("#ffff00")
    "yellowgreen" => Some("#9acd32")
    _ => None
  }
}

///|
/// Parse the deterministic SVG 2 solid-color slice.
pub fn parse_solid_color(source : String) -> SolidColorParse {
  let value = source.trim().to_owned().to_lower()
  if value == "currentcolor" {
    return CurrentColor
  }
  if value == "transparent" {
    return Resolved({ red: 0, green: 0, blue: 0, alpha: 0.0 })
  }
  if system_color_keyword(value) {
    return SystemColor(value)
  }
  match parse_hex_color(value) {
    Some(color) => return Resolved(color)
    None => ()
  }
  match parse_rgb_color(value, false) {
    Some(color) => return Resolved(color)
    None => ()
  }
  match parse_rgb_color(value, true) {
    Some(color) => return Resolved(color)
    None => ()
  }
  match parse_hsl_color(value, false) {
    Some(color) => return Resolved(color)
    None => ()
  }
  match parse_hsl_color(value, true) {
    Some(color) => return Resolved(color)
    None => ()
  }
  match named_color_hex(value) {
    Some(hex) =>
      match parse_hex_color(hex) {
        Some(color) => Resolved(color)
        None => Invalid
      }
    None => Invalid
  }
}

///|
fn hex_character(value : Int) -> String {
  let digit = value % 16
  if digit < 10 {
    digit.to_string()
  } else {
    match digit {
      10 => "a"
      11 => "b"
      12 => "c"
      13 => "d"
      14 => "e"
      _ => "f"
    }
  }
}

///|
fn hex_byte(value : Int) -> String {
  hex_character(value / 16) + hex_character(value)
}

///|
/// Return the canonical opaque renderer color without folding alpha into RGB.
pub fn SrgbaColor::renderer_hex(self : SrgbaColor) -> String {
  "#\{hex_byte(self.red)}\{hex_byte(self.green)}\{hex_byte(self.blue)}"
}

///|
/// Return a deterministic computed-value signature.
pub fn SrgbaColor::signature(self : SrgbaColor) -> String {
  "rgba(\{self.red},\{self.green},\{self.blue},\{self.alpha})"
}
