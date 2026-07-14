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
fn canonical_renderer_inline_style(facts : Array[DeclaredVisualFact]) -> String {
  let mut result = ""
  for index, fact in facts {
    if index > 0 {
      result += ";"
    }
    result += fact.property + ":" + fact.declared_value
  }
  result
}

///|
fn renderer_inline_value_edits_for_element(
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
      edits.push({
        start_offset: attribute.value_span.start.offset,
        end_offset: attribute.value_span.end.offset,
        replacement: escape_renderer_attribute_value(
          canonical_renderer_inline_style(style.facts),
        ),
      })
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
fn renderer_cascade_value_edits_for_element(
  input : String,
  element : @xml.NamespaceElement,
  span : @xml.SourceSpan,
  stylesheet_match : CssStylesheetMatch,
  edits : Array[RendererValueEdit],
) -> Unit {
  if !stylesheet_match.complete {
    return
  }
  let presentations : Array[@xml.NamespaceAttribute] = []
  let candidates : Array[CssCascadeCandidate] = []
  let style_properties : Array[String] = []
  let mut style_attribute : @xml.NamespaceAttribute? = None
  for attribute in element.attributes {
    let name = attribute.name.local_name
    if name == "style" {
      style_attribute = Some(attribute)
    } else if supported_rect_property(name) {
      presentations.push(attribute)
      candidates.push(
        presentation_cascade_candidate(
          presentation_fact(input, name, attribute),
          attribute.span.start.offset,
        ),
      )
    }
  }
  match style_attribute {
    Some(attribute) => {
      let style = inline_style_facts(input, attribute)
      if !style.complete {
        return
      }
      candidates.push_iter(style.candidates.iter())
      for candidate in style.candidates {
        push_unique(style_properties, candidate.declaration.property)
      }
    }
    None => ()
  }
  candidates.push_iter(stylesheet_match.candidates.iter())
  for candidate in stylesheet_match.candidates {
    push_unique(style_properties, candidate.declaration.property)
  }
  let facts = cascade_visual_declarations(candidates)
  let style_facts = [
    for fact in facts if style_properties.contains(fact.property) => fact
  ]
  if style_attribute is Some(attribute) {
    edits.push({
      start_offset: attribute.value_span.start.offset,
      end_offset: attribute.value_span.end.offset,
      replacement: escape_renderer_attribute_value(
        canonical_renderer_inline_style(style_facts),
      ),
    })
  } else if !stylesheet_match.candidates.is_empty() {
    edits.push({
      start_offset: renderer_element_insert_offset(input, span),
      end_offset: renderer_element_insert_offset(input, span),
      replacement: " style=\"" +
      escape_renderer_attribute_value(
        canonical_renderer_inline_style(style_facts),
      ) +
      "\"",
    })
  }
  for fact in facts {
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

///|
fn normalize_renderer_style_precedence(input : String) -> String {
  let css_document = try parse_static_css_document_or_raise(input) catch {
    _ => return input
  } noraise {
    document => document
  }
  let reader = @xml.NamespaceReader::from_string(input)
  let events = reader.read_events_until_eof() catch { _ => return input }
  let edits : Array[RendererValueEdit] = []
  let mut in_stylesheet = false
  for event in events {
    match event.kind {
      Start(element) => {
        if element.name.local_name == "style" {
          in_stylesheet = true
        }
        if css_document.complete {
          renderer_cascade_value_edits_for_element(
            input,
            element,
            event.span,
            css_stylesheet_match_for_source(
              css_document,
              event.span.start.offset,
            ),
            edits,
          )
        } else {
          renderer_inline_value_edits_for_element(input, element, edits)
        }
      }
      Empty(element) =>
        if css_document.complete {
          renderer_cascade_value_edits_for_element(
            input,
            element,
            event.span,
            css_stylesheet_match_for_source(
              css_document,
              event.span.start.offset,
            ),
            edits,
          )
        } else {
          renderer_inline_value_edits_for_element(input, element, edits)
        }
      Text(_) if in_stylesheet && css_document.complete =>
        edits.push({
          start_offset: event.span.start.offset,
          end_offset: event.span.end.offset,
          replacement: "",
        })
      End(name) if name.local_name == "style" => in_stylesheet = false
      _ => ()
    }
  }
  apply_renderer_value_edits(input, edits)
}

///|
fn renderer_inherited_value_edits_for_element(
  input : String,
  element : @xml.NamespaceElement,
  span : @xml.SourceSpan,
  hierarchy : FillHierarchy,
  subject_id : String,
  edits : Array[RendererValueEdit],
) -> Unit {
  let overrides = renderer_computed_override_facts_for_subject(
    hierarchy, subject_id,
  )
  if overrides.is_empty() {
    return
  }
  let facts : Array[DeclaredVisualFact] = []
  match renderer_attribute(element, "style") {
    Some(attribute) => {
      let style = inline_style_facts(input, attribute)
      if !style.complete {
        return
      }
      facts.push_iter(style.facts.iter())
    }
    None => ()
  }
  for fact in overrides {
    upsert_declared_fact(facts, fact)
  }
  facts.sort_by(fn(left, right) { left.property.compare(right.property) })
  let replacement = escape_renderer_attribute_value(
    canonical_renderer_inline_style(facts),
  )
  match renderer_attribute(element, "style") {
    Some(attribute) =>
      edits.push({
        start_offset: attribute.value_span.start.offset,
        end_offset: attribute.value_span.end.offset,
        replacement,
      })
    None => {
      let offset = renderer_element_insert_offset(input, span)
      edits.push({
        start_offset: offset,
        end_offset: offset,
        replacement: " style=\"\{replacement}\"",
      })
    }
  }
}

///|
fn normalize_renderer_ordinary_inheritance(input : String) -> String {
  guard extract_fill_hierarchy(input) is ParsedFillHierarchy(hierarchy) else {
    return input
  }
  if hierarchy.coverage_codes.any(code => {
      code == "css_cascade_unsupported" ||
      code == "css_revert_layer_unsupported" ||
      code == "css_variable_syntax_unsupported" ||
      code == "css_variable_expansion_limit"
    }) {
    return input
  }
  let reader = @xml.NamespaceReader::from_string(input)
  let events = reader.read_events_until_eof() catch { _ => return input }
  let edits : Array[RendererValueEdit] = []
  let mut hierarchy_index = 0
  let mut marker_depth = 0
  for event in events {
    match event.kind {
      Start(element) => {
        let kind = element.name.local_name
        if kind == "marker" {
          marker_depth += 1
        }
        if marker_depth == 0 && fill_hierarchy_kind(kind) {
          match hierarchy.elements.get(hierarchy_index) {
            Some(source_element) if visual_subject_kind(kind) || kind == "stop" =>
              renderer_inherited_value_edits_for_element(
                input,
                element,
                event.span,
                hierarchy,
                source_element.subject_id,
                edits,
              )
            _ => ()
          }
          hierarchy_index += 1
        }
      }
      Empty(element) => {
        let kind = element.name.local_name
        if marker_depth == 0 && fill_hierarchy_kind(kind) {
          match hierarchy.elements.get(hierarchy_index) {
            Some(source_element) if visual_subject_kind(kind) || kind == "stop" =>
              renderer_inherited_value_edits_for_element(
                input,
                element,
                event.span,
                hierarchy,
                source_element.subject_id,
                edits,
              )
            _ => ()
          }
          hierarchy_index += 1
        }
      }
      End(name) if name.local_name == "marker" => marker_depth -= 1
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
fn renderer_canonical_fact_edits(
  element : @xml.NamespaceElement,
  facts : Array[DeclaredVisualFact],
  properties : Array[String],
  edits : Array[RendererValueEdit],
) -> Unit {
  for property in properties {
    match (renderer_attribute(element, property), shape_fact(facts, property)) {
      (Some(attribute), Some(fact)) =>
        edits.push({
          start_offset: attribute.value_span.start.offset,
          end_offset: attribute.value_span.end.offset,
          replacement: fact.declared_value,
        })
      _ => ()
    }
  }
}

///|
fn normalize_renderer_context_lengths_with_profile(
  input : String,
  profile : ComparisonProfile,
) -> String {
  let reader = @xml.NamespaceReader::from_string(input)
  let events = reader.read_events_until_eof() catch { _ => return input }
  let edits : Array[RendererValueEdit] = []
  let viewport_contexts : Array[ViewportContext] = []
  let mut node_index = 0
  for event in events {
    match event.kind {
      Start(element) => {
        if element.name.local_name == "svg" {
          let resolution = source_viewport_resolution(
            input,
            element,
            profile,
            viewport_contexts.last(),
          )
          if resolution.complete {
            renderer_canonical_fact_edits(
              element,
              resolution.facts,
              ["x", "y", "width", "height"],
              edits,
            )
          }
          viewport_contexts.push(resolution.child_context)
        } else if element.name.local_name == "marker" {
          let resource = marker_resource_from_element(
            input,
            element,
            node_index,
            event.span.end.offset,
            viewport_contexts
            .last()
            .unwrap_or({
              width: profile.viewport_width.to_double(),
              height: profile.viewport_height.to_double(),
            }),
            profile,
          )
          if resource.complete {
            renderer_canonical_fact_edits(
              element,
              resource.facts,
              ["markerWidth", "markerHeight", "refX", "refY"],
              edits,
            )
          }
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
          if resolution.complete {
            renderer_canonical_fact_edits(
              element,
              resolution.facts,
              ["x", "y", "width", "height"],
              edits,
            )
          }
        } else if element.name.local_name == "marker" {
          let resource = marker_resource_from_element(
            input,
            element,
            node_index,
            event.span.end.offset,
            viewport_contexts
            .last()
            .unwrap_or({
              width: profile.viewport_width.to_double(),
              height: profile.viewport_height.to_double(),
            }),
            profile,
          )
          if resource.complete {
            renderer_canonical_fact_edits(
              element,
              resource.facts,
              ["markerWidth", "markerHeight", "refX", "refY"],
              edits,
            )
          }
        }
        node_index += 1
      }
      End(name) if name.local_name == "svg" => ignore(viewport_contexts.pop())
      _ => ()
    }
  }
  apply_renderer_value_edits(input, edits)
}

///|
fn renderer_shape_geometry_edits(
  input : String,
  span : @xml.SourceSpan,
  element : @xml.NamespaceElement,
  edits : Array[RendererValueEdit],
  viewport : ViewportContext,
  profile : ComparisonProfile,
) -> Unit {
  let kind = element.name.local_name
  if !visual_subject_kind(kind) || kind == "path" {
    return
  }
  let facts = rect_declared_facts_from_element(
      input,
      element,
      empty_css_stylesheet_match(),
    ).facts
  let resolution = resolve_basic_shape_geometry_with_context(
    kind, facts, viewport, profile,
  )
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
fn normalize_renderer_shape_geometry_with_profile(
  input : String,
  profile : ComparisonProfile,
) -> String {
  let reader = @xml.NamespaceReader::from_string(input)
  let events = reader.read_events_until_eof() catch { _ => return input }
  let edits : Array[RendererValueEdit] = []
  let viewport_contexts : Array[ViewportContext] = []
  let mut node_index = 0
  for event in events {
    match event.kind {
      Start(element) => {
        if element.name.local_name == "svg" {
          let (_, child_viewport) = source_transform_site_with_viewport(
            input,
            element,
            node_index,
            profile,
            viewport_contexts.last(),
          )
          match child_viewport {
            Some(context) => viewport_contexts.push(context)
            None => ()
          }
        }
        renderer_shape_geometry_edits(
          input,
          event.span,
          element,
          edits,
          viewport_contexts
          .last()
          .unwrap_or({
            width: profile.viewport_width.to_double(),
            height: profile.viewport_height.to_double(),
          }),
          profile,
        )
        node_index += 1
      }
      Empty(element) => {
        renderer_shape_geometry_edits(
          input,
          event.span,
          element,
          edits,
          viewport_contexts
          .last()
          .unwrap_or({
            width: profile.viewport_width.to_double(),
            height: profile.viewport_height.to_double(),
          }),
          profile,
        )
        node_index += 1
      }
      End(name) if name.local_name == "svg" => ignore(viewport_contexts.pop())
      _ => ()
    }
  }
  apply_renderer_value_edits(input, edits)
}

///|
fn normalize_renderer_shape_geometry(input : String) -> String {
  normalize_renderer_shape_geometry_with_profile(
    input,
    ComparisonProfile::v1_default(),
  )
}

///|
fn renderer_stroke_geometry_edits(
  input : String,
  element : @xml.NamespaceElement,
  edits : Array[RendererValueEdit],
  viewport : ViewportContext,
  profile : ComparisonProfile,
) -> Unit {
  let facts = rect_declared_facts_from_element(
      input,
      element,
      empty_css_stylesheet_match(),
    ).facts
  let resolution = resolve_stroke_geometry_with_context(
    facts, viewport, profile,
  )
  if !resolution.complete {
    return
  }
  let has_local_dasharray = shape_fact(facts, "stroke-dasharray") is Some(_)
  for entry in resolution.values {
    let (property, value) = entry
    if property == "stroke-dashoffset" && !has_local_dasharray {
      continue
    }
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
}

///|
fn normalize_renderer_stroke_geometry_with_profile(
  input : String,
  profile : ComparisonProfile,
) -> String {
  let reader = @xml.NamespaceReader::from_string(input)
  let events = reader.read_events_until_eof() catch { _ => return input }
  let edits : Array[RendererValueEdit] = []
  let viewport_contexts : Array[ViewportContext] = []
  let mut node_index = 0
  for event in events {
    match event.kind {
      Start(element) => {
        if element.name.local_name == "svg" {
          let (_, child_viewport) = source_transform_site_with_viewport(
            input,
            element,
            node_index,
            profile,
            viewport_contexts.last(),
          )
          match child_viewport {
            Some(context) => viewport_contexts.push(context)
            None => ()
          }
        }
        renderer_stroke_geometry_edits(
          input,
          element,
          edits,
          viewport_contexts
          .last()
          .unwrap_or({
            width: profile.viewport_width.to_double(),
            height: profile.viewport_height.to_double(),
          }),
          profile,
        )
        node_index += 1
      }
      Empty(element) => {
        renderer_stroke_geometry_edits(
          input,
          element,
          edits,
          viewport_contexts
          .last()
          .unwrap_or({
            width: profile.viewport_width.to_double(),
            height: profile.viewport_height.to_double(),
          }),
          profile,
        )
        node_index += 1
      }
      End(name) if name.local_name == "svg" => ignore(viewport_contexts.pop())
      _ => ()
    }
  }
  apply_renderer_value_edits(input, edits)
}

///|
fn normalize_renderer_stroke_geometry(input : String) -> String {
  normalize_renderer_stroke_geometry_with_profile(
    input,
    ComparisonProfile::v1_default(),
  )
}

///|
fn normalize_renderer_input_with_profile(
  input : String,
  profile : ComparisonProfile,
) -> String {
  if profile.viewport_width == 16 && profile.viewport_height == 16 {
    return normalize_renderer_input(input)
  }
  normalize_renderer_shape_geometry_with_profile(
    normalize_renderer_stroke_geometry_with_profile(
      normalize_renderer_context_lengths_with_profile(
        normalize_renderer_ordinary_inheritance(
          normalize_renderer_style_precedence(input),
        ),
        profile,
      ),
      profile,
    ),
    profile,
  )
}

///|
fn normalize_renderer_input(input : String) -> String {
  normalize_renderer_shape_geometry(
    normalize_renderer_stroke_geometry(
      normalize_renderer_context_lengths_with_profile(
        normalize_renderer_ordinary_inheritance(
          normalize_renderer_style_precedence(input),
        ),
        ComparisonProfile::v1_default(),
      ),
    ),
  )
}
