///|
priv struct ViewBoxValue {
  min_x : Double
  min_y : Double
  width : Double
  height : Double
}

///|
priv enum ViewportAlignment {
  ViewportNone
  XMinYMin
  XMidYMin
  XMaxYMin
  XMinYMid
  XMidYMid
  XMaxYMid
  XMinYMax
  XMidYMax
  XMaxYMax
}

///|
priv enum ViewportFit {
  Meet
  Slice
}

///|
priv struct PreserveAspectRatioValue {
  alignment : ViewportAlignment
  fit : ViewportFit
}

///|
priv struct ResolvedViewportLength {
  value : Double
}

///|
priv struct ViewportContext {
  width : Double
  height : Double
}

///|
priv struct SourceViewportResolution {
  facts : Array[DeclaredVisualFact]
  invalid_facts : Array[DeclaredVisualFact]
  matrix : AffineTransform
  child_context : ViewportContext
  complete : Bool
}

///|
fn default_preserve_aspect_ratio() -> PreserveAspectRatioValue {
  { alignment: XMidYMid, fit: Meet }
}

///|
fn parse_view_box_value(source : String) -> ViewBoxValue? {
  let parser : NumberParser = { data: source, position: 0 }
  let values : Array[Double] = []
  ignore(parser.skip_whitespace())
  while parser.position < source.length() {
    guard parser.parse_number() is Some(value) else { return None }
    values.push(value)
    let had_whitespace = parser.skip_whitespace()
    if parser.position >= source.length() {
      break
    }
    if source[parser.position] == ',' {
      parser.position += 1
      ignore(parser.skip_whitespace())
      if parser.position >= source.length() || source[parser.position] == ',' {
        return None
      }
    } else if !had_whitespace &&
      source[parser.position] != '+' &&
      source[parser.position] != '-' {
      return None
    }
  }
  match values {
    [min_x, min_y, width, height] if width > 0.0 && height > 0.0 =>
      Some({ min_x, min_y, width, height })
    _ => None
  }
}

///|
fn normalized_viewport_tokens(source : String) -> Array[String] {
  let normalized = source
    .replace_all(old="\t", new=" ")
    .replace_all(old="\n", new=" ")
    .replace_all(old="\r", new=" ")
  [
    for token in normalized.split(" ") if token != "" => token.to_owned()
  ]
}

///|
fn viewport_alignment(value : String) -> ViewportAlignment? {
  match value {
    "none" => Some(ViewportNone)
    "xMinYMin" => Some(XMinYMin)
    "xMidYMin" => Some(XMidYMin)
    "xMaxYMin" => Some(XMaxYMin)
    "xMinYMid" => Some(XMinYMid)
    "xMidYMid" => Some(XMidYMid)
    "xMaxYMid" => Some(XMaxYMid)
    "xMinYMax" => Some(XMinYMax)
    "xMidYMax" => Some(XMidYMax)
    "xMaxYMax" => Some(XMaxYMax)
    _ => None
  }
}

///|
fn parse_preserve_aspect_ratio_value(
  source : String,
) -> PreserveAspectRatioValue? {
  match normalized_viewport_tokens(source) {
    [alignment] =>
      match viewport_alignment(alignment) {
        Some(ViewportNone) => Some({ alignment: ViewportNone, fit: Meet })
        Some(alignment) => Some({ alignment, fit: Meet })
        None => None
      }
    [alignment, fit] =>
      match viewport_alignment(alignment) {
        Some(ViewportNone) =>
          match fit {
            "meet" | "slice" => Some({ alignment: ViewportNone, fit: Meet })
            _ => None
          }
        Some(alignment) =>
          match fit {
            "meet" => Some({ alignment, fit: Meet })
            "slice" => Some({ alignment, fit: Slice })
            _ => None
          }
        None => None
      }
    _ => None
  }
}

///|
fn parse_viewport_length(
  source : String,
  direction : SvgLengthDirection,
  viewport : ViewportContext,
  profile : ComparisonProfile,
) -> ResolvedViewportLength? {
  match parse_svg_length(source, direction, viewport, profile) {
    Some(value) => Some({ value, })
    None => None
  }
}

///|
fn viewport_alignment_offset(
  alignment : ViewportAlignment,
  extra_x : Double,
  extra_y : Double,
) -> (Double, Double) {
  let x = match alignment {
    XMidYMin | XMidYMid | XMidYMax => extra_x / 2.0
    XMaxYMin | XMaxYMid | XMaxYMax => extra_x
    _ => 0.0
  }
  let y = match alignment {
    XMinYMid | XMidYMid | XMaxYMid => extra_y / 2.0
    XMinYMax | XMidYMax | XMaxYMax => extra_y
    _ => 0.0
  }
  (x, y)
}

///|
fn equivalent_viewport_transform(
  view_box : ViewBoxValue,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  preserve : PreserveAspectRatioValue,
) -> AffineTransform {
  let raw_scale_x = width / view_box.width
  let raw_scale_y = height / view_box.height
  let (scale_x, scale_y) = match preserve.alignment {
    ViewportNone => (raw_scale_x, raw_scale_y)
    _ => {
      let scale = match preserve.fit {
        Meet => raw_scale_x.min(raw_scale_y)
        Slice => raw_scale_x.max(raw_scale_y)
      }
      (scale, scale)
    }
  }
  let extra_x = width - view_box.width * scale_x
  let extra_y = height - view_box.height * scale_y
  let (align_x, align_y) = viewport_alignment_offset(
    preserve.alignment,
    extra_x,
    extra_y,
  )
  AffineTransform::translate(
    x - view_box.min_x * scale_x + align_x,
    y - view_box.min_y * scale_y + align_y,
  ).multiply(AffineTransform::scale(scale_x, scale_y))
}

///|
fn preserve_aspect_ratio_signature(value : PreserveAspectRatioValue) -> String {
  let alignment = match value.alignment {
    ViewportNone => "none"
    XMinYMin => "xMinYMin"
    XMidYMin => "xMidYMin"
    XMaxYMin => "xMaxYMin"
    XMinYMid => "xMinYMid"
    XMidYMid => "xMidYMid"
    XMaxYMid => "xMaxYMid"
    XMinYMax => "xMinYMax"
    XMidYMax => "xMidYMax"
    XMaxYMax => "xMaxYMax"
  }
  match value.alignment {
    ViewportNone => alignment
    _ => {
      let fit = match value.fit {
        Meet => "meet"
        Slice => "slice"
      }
      "\{alignment} \{fit}"
    }
  }
}

///|
fn normalized_view_box_signature(value : ViewBoxValue) -> String {
  "\{value.min_x},\{value.min_y},\{value.width},\{value.height}"
}

///|
fn normalized_viewport_fact(
  input : String,
  property : String,
  attribute : @xml.NamespaceAttribute,
  normalized : String,
) -> DeclaredVisualFact {
  {
    ..presentation_fact(input, property, attribute),
    declared_value: normalized,
  }
}

///|
fn source_viewport_resolution(
  input : String,
  element : @xml.NamespaceElement,
  profile : ComparisonProfile,
  parent_context : ViewportContext?,
) -> SourceViewportResolution {
  let facts : Array[DeclaredVisualFact] = []
  let invalid_facts : Array[DeclaredVisualFact] = []
  let mut x_attribute : @xml.NamespaceAttribute? = None
  let mut y_attribute : @xml.NamespaceAttribute? = None
  let mut width_attribute : @xml.NamespaceAttribute? = None
  let mut height_attribute : @xml.NamespaceAttribute? = None
  let mut view_box_attribute : @xml.NamespaceAttribute? = None
  let mut preserve_attribute : @xml.NamespaceAttribute? = None
  for attribute in element.attributes {
    match attribute.name.local_name {
      "x" => x_attribute = Some(attribute)
      "y" => y_attribute = Some(attribute)
      "width" => width_attribute = Some(attribute)
      "height" => height_attribute = Some(attribute)
      "viewBox" => view_box_attribute = Some(attribute)
      "preserveAspectRatio" => preserve_attribute = Some(attribute)
      _ => ()
    }
  }
  let root_context : ViewportContext = {
    width: profile.viewport_width.to_double(),
    height: profile.viewport_height.to_double(),
  }
  let reference = parent_context.unwrap_or(root_context)
  let is_root = parent_context is None
  let mut complete = true
  fn resolve_length(
    attribute : @xml.NamespaceAttribute?,
    property : String,
    direction : SvgLengthDirection,
    default_value : Double,
    positive : Bool,
  ) -> Double {
    match attribute {
      Some(attribute) =>
        match
          parse_viewport_length(attribute.value, direction, reference, profile) {
          Some(resolved) if !positive || resolved.value > 0.0 => {
            facts.push(
              normalized_viewport_fact(
                input,
                property,
                attribute,
                resolved.value.to_string(),
              ),
            )
            resolved.value
          }
          _ => {
            complete = false
            let fact = presentation_fact(input, property, attribute)
            facts.push(fact)
            invalid_facts.push(fact)
            default_value
          }
        }
      None => default_value
    }
  }
  let declared_x = resolve_length(x_attribute, "x", Horizontal, 0.0, false)
  let declared_y = resolve_length(y_attribute, "y", Vertical, 0.0, false)
  let declared_width = resolve_length(
    width_attribute,
    "width",
    Horizontal,
    reference.width,
    true,
  )
  let declared_height = resolve_length(
    height_attribute,
    "height",
    Vertical,
    reference.height,
    true,
  )
  let view_box = match view_box_attribute {
    Some(attribute) =>
      match parse_view_box_value(attribute.value) {
        Some(value) => {
          facts.push(
            normalized_viewport_fact(
              input,
              "viewBox",
              attribute,
              normalized_view_box_signature(value),
            ),
          )
          Some(value)
        }
        None => {
          complete = false
          let fact = presentation_fact(input, "viewBox", attribute)
          facts.push(fact)
          invalid_facts.push(fact)
          None
        }
      }
    None => None
  }
  let preserve = match preserve_attribute {
    Some(attribute) =>
      match parse_preserve_aspect_ratio_value(attribute.value) {
        Some(value) => {
          facts.push(
            normalized_viewport_fact(
              input,
              "preserveAspectRatio",
              attribute,
              preserve_aspect_ratio_signature(value),
            ),
          )
          value
        }
        None => {
          complete = false
          let fact = presentation_fact(input, "preserveAspectRatio", attribute)
          facts.push(fact)
          invalid_facts.push(fact)
          default_preserve_aspect_ratio()
        }
      }
    None => default_preserve_aspect_ratio()
  }
  facts.sort_by(fn(left, right) { left.property.compare(right.property) })
  let x = if is_root { 0.0 } else { declared_x }
  let y = if is_root { 0.0 } else { declared_y }
  let width = if is_root { root_context.width } else { declared_width }
  let height = if is_root { root_context.height } else { declared_height }
  let matrix = if complete {
    match view_box {
      Some(view_box) =>
        equivalent_viewport_transform(view_box, x, y, width, height, preserve)
      None => AffineTransform::translate(x, y)
    }
  } else {
    AffineTransform::identity()
  }
  let child_context = match view_box {
    Some(view_box) if complete =>
      { width: view_box.width, height: view_box.height }
    _ => { width, height }
  }
  { facts, invalid_facts, matrix, child_context, complete }
}

///|
fn source_transform_site_with_viewport(
  input : String,
  element : @xml.NamespaceElement,
  node_index : Int,
  profile : ComparisonProfile,
  parent_context : ViewportContext?,
) -> (SourceTransformSite, ViewportContext?) {
  let site = source_transform_site(input, element, node_index)
  if element.name.local_name != "svg" {
    return (site, parent_context)
  }
  let viewport = source_viewport_resolution(
    input, element, profile, parent_context,
  )
  (
    {
      ..site,
      viewport_facts: viewport.facts,
      viewport_matrix: viewport.matrix,
      viewport_complete: viewport.complete,
    },
    Some(viewport.child_context),
  )
}

///|
fn viewport_diagnostic_locations(
  source_role : String,
  facts : Array[DeclaredVisualFact],
) -> Array[DiagnosticSourceLocation] {
  facts.map(fn(fact) { diagnostic_location(source_role, fact.source_span) })
}

///|
fn append_viewport_resolution_diagnostic(
  diagnostics : Array[Diagnostic],
  source_role : String,
  subject_id : String,
  code : String,
  layers : Array[String],
  facts : Array[DeclaredVisualFact],
) -> Unit {
  merge_diagnostic_into(diagnostics, {
    ..unlocated_diagnostic(
      "diagnostic:\{code}:\{subject_id}",
      code,
      subject_id,
      layers,
    ),
    source_locations: viewport_diagnostic_locations(source_role, facts),
  })
}

///|
fn append_viewport_preflight_diagnostics(
  input : String,
  profile : ComparisonProfile,
  source_role : String,
  diagnostics : Array[Diagnostic],
) -> Unit raise {
  let viewport_contexts : Array[ViewportContext] = []
  let mut node_index = 0
  let reader = @xml.NamespaceReader::from_string(input)
  for event in reader.read_events_until_eof() {
    match event.kind {
      Start(element) => {
        if element.name.local_name == "svg" {
          let resolution = source_viewport_resolution(
            input,
            element,
            profile,
            viewport_contexts.last(),
          )
          let subject_id = authored_subject_id(element).unwrap_or(
            generated_subject_id("svg", node_index),
          )
          if !resolution.complete {
            append_viewport_resolution_diagnostic(
              diagnostics,
              source_role,
              subject_id,
              "viewport_semantics_unsupported",
              ["source_semantics", "computed_appearance", "rendered_evidence"],
              resolution.invalid_facts,
            )
          } else if !resolution.matrix.is_identity() &&
            !resolution.matrix.has_proven_renderer_conformance() {
            append_viewport_resolution_diagnostic(
              diagnostics,
              source_role,
              subject_id,
              "renderer_viewport_raster_unproven",
              ["rendered_evidence"],
              resolution.facts,
            )
          }
          viewport_contexts.push(resolution.child_context)
        }
        node_index += 1
      }
      Empty(element) => {
        if element.name.local_name == "svg" {
          let resolution = source_viewport_resolution(
            input,
            element,
            profile,
            viewport_contexts.last(),
          )
          let subject_id = authored_subject_id(element).unwrap_or(
            generated_subject_id("svg", node_index),
          )
          if !resolution.complete {
            append_viewport_resolution_diagnostic(
              diagnostics,
              source_role,
              subject_id,
              "viewport_semantics_unsupported",
              ["source_semantics", "computed_appearance", "rendered_evidence"],
              resolution.invalid_facts,
            )
          } else if !resolution.matrix.is_identity() &&
            !resolution.matrix.has_proven_renderer_conformance() {
            append_viewport_resolution_diagnostic(
              diagnostics,
              source_role,
              subject_id,
              "renderer_viewport_raster_unproven",
              ["rendered_evidence"],
              resolution.facts,
            )
          }
        }
        node_index += 1
      }
      End(name) if name.local_name == "svg" => ignore(viewport_contexts.pop())
      _ => ()
    }
  }
}
