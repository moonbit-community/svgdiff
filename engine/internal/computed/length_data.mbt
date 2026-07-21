///|
pub(all) enum SvgLengthDirection {
  Horizontal
  Vertical
  Unspecified
} derive(Eq)

///|
pub fn svg_length_percentage_basis(
  direction : SvgLengthDirection,
  viewport : ViewportContext,
) -> Double {
  match direction {
    Horizontal => viewport.width
    Vertical => viewport.height
    Unspecified => @math.hypot(viewport.width, viewport.height) / 2.0.sqrt()
  }
}

///|
pub fn parse_svg_length(
  source : String,
  direction : SvgLengthDirection,
  viewport : ViewportContext,
  profile : ComparisonProfile,
) -> Double? {
  let value = source.trim().to_owned()
  if value == "" {
    return None
  }
  let parser : NumberParser = { data: value, position: 0 }
  guard parser.parse_number() is Some(number) else { return None }
  if number.is_nan() || number.is_inf() {
    return None
  }
  let unit = value.view(start_offset=parser.position).to_owned().to_lower()
  let multiplier = match unit {
    "" | "px" => 1.0
    "in" => 96.0
    "cm" => 96.0 / 2.54
    "mm" => 96.0 / 25.4
    "q" => 96.0 / 101.6
    "pt" => 96.0 / 72.0
    "pc" => 16.0
    "%" => svg_length_percentage_basis(direction, viewport) / 100.0
    "vw" => profile.viewport_width.to_double() / 100.0
    "vh" => profile.viewport_height.to_double() / 100.0
    "vmin" =>
      profile.viewport_width.min(profile.viewport_height).to_double() / 100.0
    "vmax" =>
      profile.viewport_width.max(profile.viewport_height).to_double() / 100.0
    _ => return None
  }
  Some(normalized_transform_component(number * multiplier))
}

///|
pub fn parse_svg_length_at(
  parser : NumberParser,
  direction : SvgLengthDirection,
  viewport : ViewportContext,
  profile : ComparisonProfile,
) -> Double? {
  let start = parser.position
  guard parser.parse_number() is Some(_) else { return None }
  while parser.position < parser.data.length() {
    let code_unit = parser.data[parser.position]
    if (code_unit >= 'a' && code_unit <= 'z') ||
      (code_unit >= 'A' && code_unit <= 'Z') ||
      code_unit == '%' {
      parser.position += 1
    } else {
      break
    }
  }
  parse_svg_length(
    parser.data.view(start_offset=start, end_offset=parser.position).to_owned(),
    direction,
    viewport,
    profile,
  )
}
