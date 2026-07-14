///|
priv struct RendererValueEdit {
  start_offset : Int
  end_offset : Int
  replacement : String
}

///|
fn escape_renderer_attribute_value(value : String) -> String {
  value
  .replace_all(old="&", new="&amp;")
  .replace_all(old="\"", new="&quot;")
  .replace_all(old="'", new="&apos;")
  .replace_all(old="<", new="&lt;")
}

///|
fn renderer_value_edits_for_element(
  input : String,
  element : @xml.NamespaceElement,
  edits : Array[RendererValueEdit],
) -> Unit {
  let presentations : Array[@xml.NamespaceAttribute] = []
  let mut style_attribute : @xml.NamespaceAttribute? = None
  for attribute in element.attributes {
    let name = attribute.name.local_name
    if name == "style" {
      style_attribute = Some(attribute)
    } else if supported_rect_property(name) {
      presentations.push(attribute)
    }
  }
  match style_attribute {
    Some(attribute) => {
      let style = inline_style_facts(input, attribute)
      if !style.complete {
        return
      }
      for fact in style.facts {
        for presentation in presentations {
          if presentation.name.local_name == fact.property {
            edits.push({
              start_offset: presentation.value_span.start.offset,
              end_offset: presentation.value_span.end.offset,
              replacement: escape_renderer_attribute_value(fact.declared_value),
            })
          }
        }
      }
    }
    None => ()
  }
}

///|
fn normalize_renderer_style_precedence(input : String) -> String {
  let reader = @xml.NamespaceReader::from_string(input)
  let events = reader.read_events_until_eof() catch { _ => return input }
  let edits : Array[RendererValueEdit] = []
  for event in events {
    match event.kind {
      Start(element) | Empty(element) =>
        renderer_value_edits_for_element(input, element, edits)
      _ => ()
    }
  }
  apply_renderer_value_edits(input, edits)
}

///|
fn apply_renderer_value_edits(
  input : String,
  edits : Array[RendererValueEdit],
) -> String {
  edits.sort_by(fn(left, right) {
    left.start_offset.compare(right.start_offset)
  })
  let mut normalized = input
  let mut remaining = edits.length()
  while remaining > 0 {
    remaining -= 1
    let edit = edits[remaining]
    normalized = source_range_slice(normalized, 0, edit.start_offset) +
      edit.replacement +
      source_range_slice(normalized, edit.end_offset, normalized.length())
  }
  normalized
}

///|
fn renderer_attribute(
  element : @xml.NamespaceElement,
  property : String,
) -> @xml.NamespaceAttribute? {
  for attribute in element.attributes {
    if attribute.name.local_name == property {
      return Some(attribute)
    }
  }
  None
}

///|
fn renderer_element_insert_offset(
  input : String,
  span : @xml.SourceSpan,
) -> Int {
  let mut offset = span.end.offset - 1
  while offset > span.start.offset && input[offset] != '>' {
    offset -= 1
  }
  if offset > span.start.offset && input[offset - 1] == '/' {
    offset - 1
  } else {
    offset
  }
}

///|
fn renderer_shape_geometry_edits(
  input : String,
  span : @xml.SourceSpan,
  element : @xml.NamespaceElement,
  edits : Array[RendererValueEdit],
) -> Unit {
  let kind = element.name.local_name
  if !visual_subject_kind(kind) || kind == "path" {
    return
  }
  let facts = rect_declared_facts_from_element(input, element).facts
  let resolution = resolve_basic_shape_geometry(kind, facts)
  if !resolution.complete {
    return
  }
  for entry in resolution.values {
    let (property, value) = entry
    match shape_fact(facts, property) {
      Some(fact) if fact.origin == "inline_style" =>
        edits.push({
          start_offset: fact.source_span.start_offset,
          end_offset: fact.source_span.end_offset,
          replacement: value,
        })
      _ => ()
    }
    match renderer_attribute(element, property) {
      Some(attribute) =>
        edits.push({
          start_offset: attribute.value_span.start.offset,
          end_offset: attribute.value_span.end.offset,
          replacement: value,
        })
      None => ()
    }
  }
  if kind == "rect" || kind == "ellipse" {
    let has_radius = shape_fact(facts, "rx") is Some(_) ||
      shape_fact(facts, "ry") is Some(_)
    if has_radius {
      let additions : Array[String] = []
      for property in ["rx", "ry"] {
        if renderer_attribute(element, property) is None {
          additions.push(
            " \{property}=\"\{shape_geometry_value_for_renderer(resolution, property)}\"",
          )
        }
      }
      if !additions.is_empty() {
        let offset = renderer_element_insert_offset(input, span)
        edits.push({
          start_offset: offset,
          end_offset: offset,
          replacement: additions.join(""),
        })
      }
    }
  }
}

///|
fn shape_geometry_value_for_renderer(
  resolution : BasicShapeGeometryResolution,
  property : String,
) -> String {
  for entry in resolution.values {
    let (name, value) = entry
    if name == property {
      return value
    }
  }
  "0"
}

///|
fn normalize_renderer_shape_geometry(input : String) -> String {
  let reader = @xml.NamespaceReader::from_string(input)
  let events = reader.read_events_until_eof() catch { _ => return input }
  let edits : Array[RendererValueEdit] = []
  for event in events {
    match event.kind {
      Start(element) | Empty(element) =>
        renderer_shape_geometry_edits(input, event.span, element, edits)
      _ => ()
    }
  }
  apply_renderer_value_edits(input, edits)
}

///|
fn normalize_renderer_input(input : String) -> String {
  normalize_renderer_shape_geometry(normalize_renderer_style_precedence(input))
}
