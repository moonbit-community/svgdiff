///|
pub fn visual_subject_kind(kind : String) -> Bool {
  match kind {
    "rect" | "circle" | "ellipse" | "line" | "polyline" | "polygon" | "path" =>
      true
    _ => false
  }
}

///|
pub fn fill_hierarchy_kind(kind : String) -> Bool {
  match kind {
    "svg"
    | "g"
    | "defs"
    | "symbol"
    | "use"
    | "pattern"
    | "clipPath"
    | "mask"
    | "filter"
    | "linearGradient"
    | "radialGradient"
    | "stop"
    | "rect"
    | "circle"
    | "ellipse"
    | "line"
    | "polyline"
    | "polygon"
    | "path" => true
    _ => false
  }
}

///|
pub fn known_source_element(kind : String) -> Bool {
  match kind {
    "svg"
    | "g"
    | "rect"
    | "circle"
    | "ellipse"
    | "line"
    | "polyline"
    | "polygon"
    | "defs"
    | "symbol"
    | "use"
    | "linearGradient"
    | "radialGradient"
    | "pattern"
    | "clipPath"
    | "mask"
    | "filter"
    | "feOffset"
    | "marker"
    | "image"
    | "stop"
    | "text"
    | "title"
    | "desc"
    | "metadata"
    | "style" => true
    _ => false
  }
}

///|
pub fn group_opacity_container(kind : String) -> Bool {
  kind == "svg" || kind == "g" || kind == "symbol" || kind == "use"
}
