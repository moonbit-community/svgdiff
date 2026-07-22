///|
pub fn blend_mode_from_keyword(value : String) -> @svg.BlendMode? {
  match value.trim().to_owned().to_lower() {
    "normal" => Some(Normal)
    "multiply" => Some(Multiply)
    "screen" => Some(Screen)
    "overlay" => Some(Overlay)
    "darken" => Some(Darken)
    "lighten" => Some(Lighten)
    "color-dodge" => Some(ColorDodge)
    "color-burn" => Some(ColorBurn)
    "hard-light" => Some(HardLight)
    "soft-light" => Some(SoftLight)
    "difference" => Some(Difference)
    "exclusion" => Some(Exclusion)
    "hue" => Some(Hue)
    "saturation" => Some(Saturation)
    "color" => Some(ColorMode)
    "luminosity" => Some(Luminosity)
    _ => None
  }
}
