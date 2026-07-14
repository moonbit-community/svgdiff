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
