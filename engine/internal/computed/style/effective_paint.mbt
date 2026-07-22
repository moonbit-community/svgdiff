///|
pub fn generic_default_value(property : String) -> String? {
  match property {
    "x"
    | "y"
    | "cx"
    | "cy"
    | "x1"
    | "y1"
    | "x2"
    | "y2"
    | "width"
    | "height"
    | "rx"
    | "ry"
    | "r" => Some("0")
    "fill" => Some("rgba(0,0,0,1)")
    "fill-rule" | "clip-rule" => Some("nonzero")
    "stroke" => Some("none")
    "stroke-width" | "opacity" | "fill-opacity" | "stroke-opacity" => Some("1")
    "stroke-linecap" => Some("butt")
    "stroke-linejoin" => Some("miter")
    "stroke-miterlimit" => Some("4")
    "stroke-dasharray" => Some("none")
    "stroke-dashoffset" => Some("0")
    "vector-effect" => Some("none")
    "marker" | "marker-start" | "marker-mid" | "marker-end" => Some("none")
    "paint-order" => Some("fill stroke markers")
    "clip-path" => Some("none")
    "mask" => Some("none")
    "mask-mode" => Some("match-source")
    _ => None
  }
}

///|
pub fn generic_computed_value(
  property : String,
  fact : DeclaredVisualFact?,
) -> String? {
  match fact {
    Some(fact) => Some(generic_computed_string(property, fact.declared_value))
    None => generic_default_value(property)
  }
}

///|
pub fn generic_computed_string(property : String, source : String) -> String {
  let value = source.trim().to_owned().to_lower()
  match property {
    "fill" | "stroke" | "color" | "stop-color" =>
      match @css_color.parse_solid_color(value) {
        Resolved(color) => color.signature()
        _ => value
      }
    "opacity" | "fill-opacity" | "stroke-opacity" | "stop-opacity" =>
      match @css_color.parse_alpha_value(value) {
        Some(alpha) => alpha.to_string()
        None => value
      }
    "clip-path" => canonical_clip_path_reference(value).unwrap_or(value)
    "mask" => canonical_mask_reference(value).unwrap_or(value)
    _ => value
  }
}

///|
pub fn generic_subject_alpha(
  subject : SourceSubject,
  property : String,
) -> Double? {
  @css_color.parse_alpha_value(subject_value(subject, property).unwrap_or("1"))
}

///|
pub fn generic_effective_paint(
  subject : SourceSubject,
  property : String,
  fact : DeclaredVisualFact?,
) -> String? {
  let value = match subject_value(subject, property) {
    Some(value) => value
    None => return generic_computed_value(property, fact)
  }
  guard @css_color.parse_solid_color(value) is Resolved(color) else {
    return Some(generic_computed_string(property, value))
  }
  let paint_opacity_property = if property == "fill" {
    "fill-opacity"
  } else {
    "stroke-opacity"
  }
  guard generic_subject_alpha(subject, paint_opacity_property)
    is Some(paint_opacity) else {
    return Some(color.signature())
  }
  guard generic_subject_alpha(subject, "opacity") is Some(opacity) else {
    return Some(color.signature())
  }
  Some({ ..color, alpha: color.alpha * paint_opacity * opacity }.signature())
}

///|
pub fn local_property_declaration(
  hierarchy : FillHierarchy,
  subject_id : String,
  property : String,
) -> DeclaredVisualFact? {
  match fill_source_element(hierarchy, subject_id) {
    Some((_, element)) => local_visual_declaration(element, property)
    None => None
  }
}

///|
pub fn resolution_source_changed(
  before : ResolvedVisualFact?,
  after : ResolvedVisualFact?,
) -> Bool {
  match (before, after) {
    (Some(before), Some(after)) => {
      let origin_changed = match (before.declaration, after.declaration) {
        (Some(before), Some(after)) => before.origin != after.origin
        (None, None) => false
        _ => true
      }
      before.resolved_value != after.resolved_value ||
      before.resolution != after.resolution ||
      before.declaration_owner_id != after.declaration_owner_id ||
      origin_changed
    }
    (None, None) => false
    _ => true
  }
}
