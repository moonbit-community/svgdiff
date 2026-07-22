///|
pub fn subject_from_element(
  input : String,
  element : @xml.NamespaceElement,
  stylesheet_match : CssStylesheetMatch,
  source_index : Int,
  hierarchy_signature : String,
  structural_parent_path_signature : String,
  instance_resolution_signature : String,
  transform_chain : Array[SourceTransformSite],
  computed_visual_facts : Array[DeclaredVisualFact],
  resolved_visual_facts : Array[ResolvedVisualFact],
  inherited_marker_facts : Array[DeclaredVisualFact],
  viewport : ViewportContext,
  profile : ComparisonProfile,
  resource_owner_id : String?,
  clip_path_owner_id : String?,
  source_offset : Int,
  instance_context : SubjectInstanceContext?,
) -> SourceSubject {
  let facts : Array[DeclaredVisualFact] = []
  let candidates : Array[CssCascadeCandidate] = []
  let path_segments : Array[PathSegmentEvidence] = []
  let mut path_data_complete = true
  let mut authored_id : String? = None
  let mut style_attribute : @xml.NamespaceAttribute? = None
  for attribute in element.attributes {
    let name = attribute.name.local_name
    if name == "id" {
      let value = attribute.value.trim().to_owned()
      if value != "" {
        authored_id = Some(value)
      }
    } else if name == "style" {
      style_attribute = Some(attribute)
    } else if name == "transform" {
      upsert_declared_fact(facts, presentation_fact(input, name, attribute))
    } else if element.name.local_name == "path" && name == "d" {
      upsert_declared_fact(facts, presentation_fact(input, name, attribute))
      let authored = source_slice(input, attribute.value_span)
      match
        parse_path_attribute_data(authored, attribute.value_span.start.offset) {
        Valid(segments) => {
          path_segments.push_iter(segments.iter())
          path_data_complete = true
        }
        Invalid => path_data_complete = false
      }
    } else if alignment_property_order().contains(name) {
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
      for candidate in style.candidates {
        if alignment_property_order().contains(candidate.declaration.property) {
          candidates.push(candidate)
        }
      }
    }
    None => ()
  }
  for candidate in stylesheet_match.candidates {
    if alignment_property_order().contains(candidate.declaration.property) {
      candidates.push(candidate)
    }
  }
  for fact in cascade_visual_declarations(candidates) {
    upsert_declared_fact(facts, fact)
  }
  let computed_facts = facts.copy()
  for fact in computed_visual_facts {
    upsert_declared_fact(computed_facts, fact)
  }
  let geometry = resolve_basic_shape_geometry_with_context(
    element.name.local_name,
    computed_facts,
    viewport,
    profile,
  )
  let stroke = resolve_stroke_geometry_with_context(
    computed_facts, viewport, profile,
  )
  let marker = resolve_marker_attachments(
    computed_facts, inherited_marker_facts,
  )
  let values : Array[(String, String)] = []
  for fact in computed_facts {
    if fact.property == "transform" {
      continue
    }
    if !basic_shape_geometry_property(element.name.local_name, fact.property) &&
      !stroke_geometry_property(fact.property) &&
      !marker_attachment_property(fact.property) {
      values.push(
        (
          fact.property,
          if fact.property == "d" {
            fact.declared_value
          } else {
            fact.declared_value.to_lower()
          },
        ),
      )
    }
  }
  for value in geometry.values {
    values.push(value)
  }
  for value in stroke.values {
    values.push(value)
  }
  for value in marker.values {
    values.push(value)
  }
  let stroke_paint_present = resolved_stroke_paint_present(computed_facts)
  let stroke_path_present = resolved_stroke_path_present(
    element.name.local_name,
    geometry,
    path_segments,
    stroke,
  )
  let stroke_width = stroke_geometry_number(stroke, "stroke-width")
  let (cumulative_transform, transform_complete, has_transform) = cumulative_transform(
    transform_chain,
  )
  if transform_complete && has_transform {
    values.push(("transform", cumulative_transform.signature()))
  }
  values.sort_by(fn(left, right) { left.0.compare(right.0) })
  let mut signature = "\{element.name.local_name}|hierarchy=\{hierarchy_signature}"
  for item in values {
    let (name, value) = item
    if name != "d" && name != "transform" {
      signature = "\{signature}|\{name}=\{value}"
    }
  }
  if element.name.local_name == "path" {
    signature = "\{signature}|path=\{path_segments_signature(path_segments)}|path-complete=\{path_data_complete}"
  }
  {
    reference: {
      source_index,
      kind: element.name.local_name,
      authored_id,
      instance_context,
    },
    signature,
    hierarchy_signature,
    structural_parent_path_signature,
    instance_resolution_signature,
    kind: element.name.local_name,
    values,
    facts,
    resolved_visual_facts,
    geometry_invalid_facts: geometry.invalid_facts,
    geometry_complete: geometry.complete,
    fillable_interior: geometry.fillable_interior,
    renders_geometry: geometry.renders_geometry,
    stroke_invalid_facts: stroke.invalid_facts,
    stroke_complete: stroke.complete,
    stroke_paint_present,
    stroke_path_present,
    stroke_active: stroke_paint_present &&
    stroke_path_present &&
    stroke_width > 0.0,
    stroke_conservative_expansion: resolved_stroke_expansion(
      element.name.local_name,
      geometry,
      stroke,
    ),
    stroke_non_scaling: resolved_stroke_value(stroke, "vector-effect") ==
    "non-scaling-stroke",
    marker_invalid_facts: marker.invalid_facts,
    marker_effective_facts: marker.effective_facts,
    marker_complete: marker.complete,
    marker_active: false,
    marker_placements: [],
    path_segments,
    path_data_complete,
    transform_chain,
    cumulative_transform,
    transform_complete,
    viewport,
    resource_owner_id,
    clip_path_owner_id,
    clip_resource_id: None,
    clip_complete: true,
    clip_effect_bounds: None,
    clip_issue_codes: [],
    mask_owner_id: None,
    mask_resource_id: None,
    mask_mode: None,
    mask_outcome: None,
    mask_complete: true,
    mask_effect_bounds: None,
    mask_issue_codes: [],
    source_offset,
  }
}

///|
pub fn alignment_property_order() -> Array[String] {
  [
    "x", "y", "width", "height", "rx", "ry", "cx", "cy", "r", "x1", "y1", "x2", "y2",
    "points", "fill", "fill-opacity", "fill-rule", "stroke", "stroke-opacity", "stroke-width",
    "stroke-linecap", "stroke-linejoin", "stroke-miterlimit", "stroke-dasharray",
    "stroke-dashoffset", "vector-effect", "marker", "marker-start", "marker-mid",
    "marker-end", "paint-order", "clip-rule", "opacity", "clip-path", "mask", "mask-mode",
  ]
}

///|
pub fn hierarchy_element_signature(
  input : String,
  element : @xml.NamespaceElement,
  stylesheet_match : CssStylesheetMatch,
) -> String {
  let facts = hierarchy_visual_declarations(input, element, stylesheet_match)
  facts.sort_by(fn(left, right) { left.property.compare(right.property) })
  let mut signature = element.name.local_name
  for fact in facts {
    signature = "\{signature}|\{fact.property}=\{fact.declared_value.to_lower()}"
  }
  signature
}

///|
pub fn hierarchy_visual_declarations(
  input : String,
  element : @xml.NamespaceElement,
  stylesheet_match : CssStylesheetMatch,
) -> Array[DeclaredVisualFact] {
  let candidates : Array[CssCascadeCandidate] = []
  let mut style_attribute : @xml.NamespaceAttribute? = None
  for attribute in element.attributes {
    let property = attribute.name.local_name
    if property == "style" {
      style_attribute = Some(attribute)
    } else if inherited_visual_properties().contains(property) {
      candidates.push(
        presentation_cascade_candidate(
          presentation_fact(input, property, attribute),
          attribute.span.start.offset,
        ),
      )
    }
  }
  match style_attribute {
    Some(attribute) => {
      let style = inline_style_facts(input, attribute)
      for candidate in style.candidates {
        if inherited_visual_properties().contains(
            candidate.declaration.property,
          ) {
          candidates.push(candidate)
        }
      }
    }
    None => ()
  }
  for candidate in stylesheet_match.candidates {
    if inherited_visual_properties().contains(candidate.declaration.property) {
      candidates.push(candidate)
    }
  }
  cascade_visual_declarations(candidates)
}

///|
pub fn effective_hierarchy_visual_facts(
  parent : Array[DeclaredVisualFact],
  local_facts : Array[DeclaredVisualFact],
) -> Array[DeclaredVisualFact] {
  let effective = parent.copy()
  for fact in local_facts {
    upsert_declared_fact(effective, fact)
  }
  effective
}

///|
pub fn joined_hierarchy_signature(stack : Array[String]) -> String {
  let mut signature = ""
  for segment in stack {
    if signature == "" {
      signature = segment
    } else {
      signature = "\{signature}/\{segment}"
    }
  }
  signature
}

///|
pub fn extract_source_subjects_streaming_internal_or_raise(
  input : String,
  profile : ComparisonProfile,
  include_pattern_children : Bool,
) -> Array[SourceSubject] raise {
  let css_document = parse_static_css_document_or_raise(input)
  let computed_hierarchy = extract_fill_hierarchy_or_raise(input)
  let subjects : Array[SourceSubject] = []
  let hierarchy : Array[String] = []
  let transforms : Array[SourceTransformSite] = []
  let viewport_contexts : Array[ViewportContext] = []
  let inherited_visuals : Array[Array[DeclaredVisualFact]] = []
  let inherited_markers : Array[Array[DeclaredVisualFact]] = []
  let mut node_index = 0
  let mut marker_depth = 0
  let pattern_owners : Array[String] = []
  let clip_path_owners : Array[String] = []
  let reader = @xml.NamespaceReader::from_string(input)
  for event in reader.read_events_until_eof() {
    match event.kind {
      Start(element) => {
        let kind = element.name.local_name
        let parent_viewport = viewport_contexts.last()
        let (transform, child_viewport) = source_transform_site_with_viewport(
          input, element, node_index, profile, parent_viewport,
        )
        node_index += 1
        transforms.push(transform)
        if kind == "marker" {
          marker_depth += 1
        }
        if kind == "pattern" {
          pattern_owners.push(
            authored_subject_id(element).unwrap_or(
              generated_subject_id("pattern", event.span.start.offset),
            ),
          )
        }
        if kind == "clipPath" {
          clip_path_owners.push(
            authored_subject_id(element).unwrap_or(
              generated_subject_id("clipPath", event.span.start.offset),
            ),
          )
        }
        if kind == "svg" || kind == "g" {
          let stylesheet_match = css_stylesheet_match_for_source(
            css_document,
            event.span.start.offset,
          )
          let local_visuals = hierarchy_visual_declarations(
            input, element, stylesheet_match,
          )
          hierarchy.push(
            hierarchy_element_signature(input, element, stylesheet_match),
          )
          inherited_visuals.push(
            effective_hierarchy_visual_facts(
              inherited_visuals.last().unwrap_or([]),
              local_visuals,
            ),
          )
          inherited_markers.push(
            marker_inherited_facts_for_element(
              input,
              element,
              stylesheet_match,
              inherited_markers.last().unwrap_or([]),
            ),
          )
        }
        if kind == "svg" {
          match child_viewport {
            Some(context) => viewport_contexts.push(context)
            None => ()
          }
        }
        if visual_subject_kind(kind) && marker_depth == 0 {
          let computed_visual_facts = match
            computed_hierarchy.all_entity_subject_ids.get(subjects.length()) {
            Some(subject_id) =>
              computed_visual_facts_for_subject(computed_hierarchy, subject_id)
            None => []
          }
          let resolved_visual_facts = match
            computed_hierarchy.all_entity_subject_ids.get(subjects.length()) {
            Some(subject_id) =>
              resolved_visual_facts_for_subject(computed_hierarchy, subject_id)
            None => []
          }
          subjects.push(
            subject_from_element(
              input,
              element,
              css_stylesheet_match_for_source(
                css_document,
                event.span.start.offset,
              ),
              subjects.length(),
              joined_hierarchy_signature(hierarchy),
              "",
              "",
              transforms.copy(),
              computed_visual_facts,
              resolved_visual_facts,
              inherited_markers.last().unwrap_or([]),
              viewport_contexts
              .last()
              .unwrap_or({
                width: profile.viewport_width.to_double(),
                height: profile.viewport_height.to_double(),
              }),
              profile,
              pattern_owners.last(),
              clip_path_owners.last(),
              event.span.start.offset,
              None,
            ),
          )
        }
      }
      Empty(element) => {
        let transform_chain = transforms.copy()
        let (transform, _) = source_transform_site_with_viewport(
          input,
          element,
          node_index,
          profile,
          viewport_contexts.last(),
        )
        transform_chain.push(transform)
        node_index += 1
        if visual_subject_kind(element.name.local_name) && marker_depth == 0 {
          let computed_visual_facts = match
            computed_hierarchy.all_entity_subject_ids.get(subjects.length()) {
            Some(subject_id) =>
              computed_visual_facts_for_subject(computed_hierarchy, subject_id)
            None => []
          }
          let resolved_visual_facts = match
            computed_hierarchy.all_entity_subject_ids.get(subjects.length()) {
            Some(subject_id) =>
              resolved_visual_facts_for_subject(computed_hierarchy, subject_id)
            None => []
          }
          subjects.push(
            subject_from_element(
              input,
              element,
              css_stylesheet_match_for_source(
                css_document,
                event.span.start.offset,
              ),
              subjects.length(),
              joined_hierarchy_signature(hierarchy),
              "",
              "",
              transform_chain,
              computed_visual_facts,
              resolved_visual_facts,
              inherited_markers.last().unwrap_or([]),
              viewport_contexts
              .last()
              .unwrap_or({
                width: profile.viewport_width.to_double(),
                height: profile.viewport_height.to_double(),
              }),
              profile,
              pattern_owners.last(),
              clip_path_owners.last(),
              event.span.start.offset,
              None,
            ),
          )
        }
      }
      End(name) => {
        ignore(transforms.pop())
        if name.local_name == "marker" {
          marker_depth -= 1
        }
        if name.local_name == "pattern" {
          ignore(pattern_owners.pop())
        }
        if name.local_name == "clipPath" {
          ignore(clip_path_owners.pop())
        }
        if name.local_name == "svg" || name.local_name == "g" {
          ignore(hierarchy.pop())
          ignore(inherited_visuals.pop())
          ignore(inherited_markers.pop())
        }
        if name.local_name == "svg" {
          ignore(viewport_contexts.pop())
        }
      }
      _ => ()
    }
  }
  let resolved = resolve_marker_subjects_or_raise(input, subjects, profile)
  if include_pattern_children {
    resolved
  } else {
    [
      for subject in resolved if subject.resource_owner_id is None => subject
    ]
  }
}

///|
pub fn source_subject_from_rendered_plan(
  input : String,
  profile : ComparisonProfile,
  css_document : CssStaticDocument,
  document : StructuralDocument,
  plan : RenderedSubjectPlan,
  source_index : Int,
) -> SourceSubject {
  let computed_hierarchy = rendered_plan_fill_hierarchy(
    input, css_document, document, plan,
  )
  let computed_visual_facts = computed_visual_facts_for_subject(
    computed_hierarchy,
    plan.definition_subject_id,
  )
  let resolved_visual_facts = resolved_visual_facts_for_subject(
    computed_hierarchy,
    plan.definition_subject_id,
  )
  let transforms : Array[SourceTransformSite] = []
  let hierarchy : Array[String] = []
  let mut inherited_markers : Array[DeclaredVisualFact] = []
  let mut viewport : ViewportContext = {
    width: profile.viewport_width.to_double(),
    height: profile.viewport_height.to_double(),
  }
  let mut first_node = true
  let mut previous_node_index : Int? = None
  for node_index in plan.rendered_ancestry {
    let node = document.nodes[node_index]
    let stylesheet_match = css_stylesheet_match_for_source(
      css_document,
      node.source_offset,
    )
    let site = if node.kind == "use" {
      source_use_transform_site(input, node, node_index, profile, viewport)
    } else if (node.kind == "symbol" || node.kind == "svg") &&
      previous_node_index
      .map(index => document.nodes[index].kind == "use")
      .unwrap_or(false) {
      let use_node = document.nodes[previous_node_index.unwrap()]
      let result = source_instanced_viewport_site(
        input, use_node, node, node_index, profile, viewport,
      )
      viewport = result.1
      result.0
    } else {
      let (site, child_viewport) = source_transform_site_with_viewport(
        input,
        node.element,
        node_index,
        profile,
        if first_node {
          None
        } else {
          Some(viewport)
        },
      )
      match child_viewport {
        Some(value) => viewport = value
        None => ()
      }
      site
    }
    first_node = false
    previous_node_index = Some(node_index)
    transforms.push(site)
    if node.kind == "svg" ||
      node.kind == "g" ||
      node.kind == "symbol" ||
      node.kind == "use" {
      hierarchy.push(
        hierarchy_element_signature(input, node.element, stylesheet_match),
      )
      inherited_markers = marker_inherited_facts_for_element(
        input,
        node.element,
        stylesheet_match,
        inherited_markers,
      )
    }
  }
  let source_node = document.nodes[plan.source_node_index]
  subject_from_element(
    input,
    source_node.element,
    css_stylesheet_match_for_source(css_document, source_node.source_offset),
    source_index,
    joined_hierarchy_signature(hierarchy),
    structural_parent_path_signature(document, plan),
    rendered_plan_instance_resolution_signature(plan),
    transforms,
    computed_visual_facts,
    resolved_visual_facts,
    inherited_markers,
    viewport,
    profile,
    None,
    None,
    source_node.source_offset,
    match plan.instance_id {
      Some(instance_id) =>
        Some({
          instance_id,
          definition_subject_id: plan.definition_subject_id,
          use_path: plan.use_path,
        })
      None => None
    },
  )
}

///|
pub fn extract_source_subjects_without_clip_internal_or_raise(
  input : String,
  profile : ComparisonProfile,
  include_pattern_children : Bool,
) -> Array[SourceSubject] raise {
  if include_pattern_children {
    return extract_source_subjects_streaming_internal_or_raise(
      input, profile, true,
    )
  }
  let css_document = parse_static_css_document_or_raise(input)
  let document = extract_structural_document_or_raise(input)
  let plans = rendered_subject_plans(document)
  let subjects : Array[SourceSubject] = []
  for index, plan in plans {
    subjects.push(
      source_subject_from_rendered_plan(
        input, profile, css_document, document, plan, index,
      ),
    )
  }
  resolve_marker_subjects_or_raise(input, subjects, profile)
}

///|
pub fn extract_source_subjects_without_clip_or_raise(
  input : String,
  profile : ComparisonProfile,
) -> Array[SourceSubject] raise {
  extract_source_subjects_without_clip_internal_or_raise(input, profile, false)
}

///|
pub fn extract_source_subjects_internal_or_raise(
  input : String,
  profile : ComparisonProfile,
  include_pattern_children : Bool,
) -> Array[SourceSubject] raise {
  resolve_mask_subjects_or_raise(
    input,
    resolve_clip_subjects_or_raise(
      input,
      extract_source_subjects_without_clip_internal_or_raise(
        input, profile, include_pattern_children,
      ),
      profile,
    ),
    profile,
  )
}

///|
pub fn extract_source_subjects_with_profile_or_raise(
  input : String,
  profile : ComparisonProfile,
) -> Array[SourceSubject] raise {
  extract_source_subjects_internal_or_raise(input, profile, false)
}

///|
pub fn extract_pattern_child_subjects_with_profile_or_raise(
  input : String,
  profile : ComparisonProfile,
) -> Array[SourceSubject] raise {
  [
    for
      subject in extract_source_subjects_internal_or_raise(input, profile, true) if subject.resource_owner_id
    is Some(_) => subject
  ]
}

///|
pub fn extract_source_subjects_or_raise(
  input : String,
  profile? : ComparisonProfile = ComparisonProfile::v1_default(),
) -> Array[SourceSubject] raise {
  extract_source_subjects_with_profile_or_raise(input, profile)
}
