// Copyright 2026 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
pub fn rendered_plan_fill_hierarchy(
  input : String,
  css_document : CssStaticDocument,
  document : StructuralDocument,
  plan : RenderedSubjectPlan,
) -> FillHierarchy {
  let elements : Array[FillSourceElement] = []
  let paint_server_targets : Array[PaintServerTarget] = []
  let entity_ids : Array[String] = []
  let coverage_codes : Array[String] = []
  let mut parent_index : Int? = None
  for node in document.nodes {
    if node.kind == "linearGradient" ||
      node.kind == "radialGradient" ||
      node.kind == "pattern" {
      match authored_subject_id(node.element) {
        Some(id) => paint_server_targets.push({ id, kind: node.kind })
        None => ()
      }
    }
  }
  for node_index in plan.rendered_ancestry {
    let node = document.nodes[node_index]
    let index = add_fill_source_element(
      input,
      node.element,
      node.source_offset,
      css_stylesheet_match_for_source(css_document, node.source_offset),
      parent_index,
      elements,
      [],
      entity_ids,
      coverage_codes,
      node.source_offset,
      node.source_offset,
      node.source_offset,
    )
    parent_index = Some(index)
  }
  {
    elements,
    paint_server_targets,
    rect_subject_ids: entity_ids.copy(),
    all_entity_subject_ids: entity_ids,
    coverage_codes,
    has_inherited_visual: false,
  }
}

///|
pub fn source_use_transform_site(
  input : String,
  node : StructuralSourceNode,
  node_index : Int,
  profile : ComparisonProfile,
  viewport : ViewportContext,
) -> SourceTransformSite {
  let site = source_transform_site(input, node.element, node_index)
  let facts : Array[DeclaredVisualFact] = []
  let mut x = 0.0
  let mut y = 0.0
  let mut complete = true
  for attribute in node.element.attributes {
    let direction = match attribute.name.local_name {
      "x" => Some(@computed.SvgLengthDirection::Horizontal)
      "y" => Some(Vertical)
      _ => None
    }
    match direction {
      Some(direction) => {
        let fact = presentation_fact(
          input,
          attribute.name.local_name,
          attribute,
        )
        match
          parse_viewport_length(attribute.value, direction, viewport, profile) {
          Some(resolved) => {
            facts.push({ ..fact, declared_value: resolved.value.to_string() })
            if attribute.name.local_name == "x" {
              x = resolved.value
            } else {
              y = resolved.value
            }
          }
          None => {
            facts.push(fact)
            complete = false
          }
        }
      }
      None => ()
    }
  }
  {
    ..site,
    viewport_facts: facts,
    viewport_matrix: if complete {
      AffineTransform::translate(x, y)
    } else {
      AffineTransform::identity()
    },
    viewport_complete: complete,
  }
}

///|
pub fn namespace_attribute(
  element : @xml.NamespaceElement,
  name : String,
) -> @xml.NamespaceAttribute? {
  for attribute in element.attributes {
    if attribute.name.local_name == name {
      return Some(attribute)
    }
  }
  None
}

///|
pub fn source_instanced_viewport_resolution(
  input : String,
  use_node : StructuralSourceNode,
  target_node : StructuralSourceNode,
  profile : ComparisonProfile,
  parent_context : ViewportContext,
) -> SourceViewportResolution {
  let facts : Array[DeclaredVisualFact] = []
  let invalid_facts : Array[DeclaredVisualFact] = []
  let mut complete = true
  fn resolve_length(
    attribute : @xml.NamespaceAttribute?,
    property : String,
    direction : SvgLengthDirection,
    default_value : Double,
    positive : Bool,
  ) -> Double {
    match attribute {
      Some(attribute) => {
        let fact = presentation_fact(input, property, attribute)
        match
          parse_viewport_length(
            attribute.value,
            direction,
            parent_context,
            profile,
          ) {
          Some(resolved) if !positive || resolved.value > 0.0 => {
            facts.push({ ..fact, declared_value: resolved.value.to_string() })
            resolved.value
          }
          _ => {
            facts.push(fact)
            invalid_facts.push(fact)
            complete = false
            default_value
          }
        }
      }
      None => default_value
    }
  }
  let x = resolve_length(
    namespace_attribute(target_node.element, "x"),
    "x",
    Horizontal,
    0.0,
    false,
  )
  let y = resolve_length(
    namespace_attribute(target_node.element, "y"),
    "y",
    Vertical,
    0.0,
    false,
  )
  let use_width = namespace_attribute(use_node.element, "width")
  let use_height = namespace_attribute(use_node.element, "height")
  let width = resolve_length(
    match use_width {
      Some(attribute) => Some(attribute)
      None => namespace_attribute(target_node.element, "width")
    },
    "width",
    Horizontal,
    parent_context.width,
    true,
  )
  let height = resolve_length(
    match use_height {
      Some(attribute) => Some(attribute)
      None => namespace_attribute(target_node.element, "height")
    },
    "height",
    Vertical,
    parent_context.height,
    true,
  )
  let view_box = match namespace_attribute(target_node.element, "viewBox") {
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
          let fact = presentation_fact(input, "viewBox", attribute)
          facts.push(fact)
          invalid_facts.push(fact)
          complete = false
          None
        }
      }
    None => None
  }
  let preserve = match
    namespace_attribute(target_node.element, "preserveAspectRatio") {
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
          let fact = presentation_fact(input, "preserveAspectRatio", attribute)
          facts.push(fact)
          invalid_facts.push(fact)
          complete = false
          default_preserve_aspect_ratio()
        }
      }
    None => default_preserve_aspect_ratio()
  }
  facts.sort_by(fn(left, right) { left.property.compare(right.property) })
  let matrix = if complete {
    match view_box {
      Some(value) =>
        equivalent_viewport_transform(value, x, y, width, height, preserve)
      None => AffineTransform::translate(x, y)
    }
  } else {
    AffineTransform::identity()
  }
  let child_context : ViewportContext = match view_box {
    Some(value) if complete => { width: value.width, height: value.height }
    _ => { width, height }
  }
  { facts, invalid_facts, matrix, child_context, complete }
}

///|
pub fn source_instanced_viewport_site(
  input : String,
  use_node : StructuralSourceNode,
  target_node : StructuralSourceNode,
  node_index : Int,
  profile : ComparisonProfile,
  parent_context : ViewportContext,
) -> (SourceTransformSite, ViewportContext) {
  let site = source_transform_site(input, target_node.element, node_index)
  let viewport = source_instanced_viewport_resolution(
    input, use_node, target_node, profile, parent_context,
  )
  (
    {
      ..site,
      viewport_facts: viewport.facts,
      viewport_matrix: viewport.matrix,
      viewport_complete: viewport.complete,
    },
    viewport.child_context,
  )
}

///|
pub fn use_diagnostic(
  code : String,
  subject_id : String,
  source_role : String,
  span : ReportSourceSpan,
) -> Diagnostic {
  let id_code = code.replace_all(old="_", new="-")
  {
    ..unlocated_diagnostic(
      "diagnostic:\{id_code}:\{subject_id}",
      code,
      subject_id,
      ["source_semantics", "computed_appearance", "rendered_evidence"],
    ),
    source_locations: [diagnostic_location(source_role, span)],
  }
}

///|
pub fn use_rendered_diagnostic(
  code : String,
  subject_id : String,
  source_role : String,
  span : ReportSourceSpan,
) -> Diagnostic {
  let id_code = code.replace_all(old="_", new="-")
  {
    ..unlocated_diagnostic(
      "diagnostic:\{id_code}:\{subject_id}",
      code,
      subject_id,
      ["rendered_evidence"],
    ),
    source_locations: [diagnostic_location(source_role, span)],
  }
}

///|
pub fn structural_subtree_uses_current_color(
  document : StructuralDocument,
  node_index : Int,
) -> Bool {
  let node = document.nodes[node_index]
  for attribute in node.element.attributes {
    if attribute.value.to_lower().find("currentcolor") is Some(_) {
      return true
    }
  }
  for child in node.children {
    if structural_subtree_uses_current_color(document, child) {
      return true
    }
  }
  false
}

///|
pub fn append_use_structure_diagnostics(
  input : String,
  profile : ComparisonProfile,
  source_role : String,
  diagnostics : Array[Diagnostic],
) -> Unit raise {
  let document = extract_structural_document_or_raise(input)
  let viewport : ViewportContext = {
    width: profile.viewport_width.to_double(),
    height: profile.viewport_height.to_double(),
  }
  for node in document.nodes {
    if node.kind != "use" {
      continue
    }
    match node.href_fact {
      None =>
        merge_diagnostic_into(
          diagnostics,
          use_diagnostic("use_href_missing", node.source_id, source_role, {
            start_offset: node.source_offset,
            end_offset: node.source_offset + 1,
          }),
        )
      Some(fact) =>
        match local_href_target(fact.declared_value) {
          None =>
            merge_diagnostic_into(
              diagnostics,
              use_diagnostic(
                "use_external_reference_unsupported",
                node.source_id,
                source_role,
                fact.source_span,
              ),
            )
          Some(target_id) =>
            match document.id_indices.get(target_id) {
              None =>
                merge_diagnostic_into(
                  diagnostics,
                  use_diagnostic(
                    "use_target_missing",
                    node.source_id,
                    source_role,
                    fact.source_span,
                  ),
                )
              Some(target) if !supported_use_target(document.nodes[target].kind) =>
                merge_diagnostic_into(
                  diagnostics,
                  use_diagnostic(
                    "use_target_kind_unsupported",
                    node.source_id,
                    source_role,
                    fact.source_span,
                  ),
                )
              _ => ()
            }
        }
    }
    let viewport_target = match use_target_index(document, node) {
      Some(target) => {
        let kind = document.nodes[target].kind
        kind == "symbol" || kind == "svg"
      }
      None => false
    }
    for attribute in node.element.attributes {
      let direction = match attribute.name.local_name {
        "x" => Some(@computed.SvgLengthDirection::Horizontal)
        "y" => Some(Vertical)
        "width" if viewport_target => Some(Horizontal)
        "height" if viewport_target => Some(Vertical)
        _ => None
      }
      match direction {
        Some(direction) if parse_viewport_length(
            attribute.value,
            direction,
            viewport,
            profile,
          )
          is None =>
          merge_diagnostic_into(
            diagnostics,
            use_diagnostic(
              "use_length_semantics_unsupported",
              node.source_id,
              source_role,
              {
                start_offset: attribute.span.start.offset,
                end_offset: attribute.span.end.offset,
              },
            ),
          )
        _ => ()
      }
    }
    let use_transform = source_use_transform_site(
      input,
      node,
      node.source_offset,
      profile,
      viewport,
    )
    if use_transform.fact is Some(transform_fact) &&
      !use_transform.matrix.is_identity() &&
      !use_transform.viewport_matrix.is_identity() {
      merge_diagnostic_into(
        diagnostics,
        use_rendered_diagnostic(
          "renderer_use_transform_raster_unproven",
          node.source_id,
          source_role,
          transform_fact.source_span,
        ),
      )
      for fact in use_transform.viewport_facts {
        merge_diagnostic_into(
          diagnostics,
          use_rendered_diagnostic(
            "renderer_use_transform_raster_unproven",
            node.source_id,
            source_role,
            fact.source_span,
          ),
        )
      }
    }
    match use_target_index(document, node) {
      Some(target) if structural_subtree_uses_current_color(document, target) =>
        merge_diagnostic_into(
          diagnostics,
          use_rendered_diagnostic(
            "renderer_use_inherited_paint_raster_unproven",
            node.source_id,
            source_role,
            node.href_fact.unwrap().source_span,
          ),
        )
      _ => ()
    }
    match use_target_index(document, node) {
      Some(target) if document.nodes[target].kind == "symbol" ||
        document.nodes[target].kind == "svg" => {
        let resolution = source_instanced_viewport_resolution(
          input,
          node,
          document.nodes[target],
          profile,
          viewport,
        )
        if !resolution.complete {
          for fact in resolution.invalid_facts {
            merge_diagnostic_into(
              diagnostics,
              use_diagnostic(
                "viewport_semantics_unsupported",
                node.source_id,
                source_role,
                fact.source_span,
              ),
            )
          }
        } else if !resolution.matrix.is_identity() &&
          !resolution.matrix.has_proven_renderer_conformance() {
          for fact in resolution.facts {
            merge_diagnostic_into(
              diagnostics,
              use_diagnostic(
                "renderer_viewport_raster_unproven",
                node.source_id,
                source_role,
                fact.source_span,
              ),
            )
          }
        }
      }
      _ => ()
    }
  }
}

///|
pub fn empty_rendered_scene_supported(input : String) -> Bool raise {
  let reader = @xml.NamespaceReader::from_string(input)
  for event in reader.read_events_until_eof() {
    match event.kind {
      Start(element) | Empty(element) => {
        let kind = element.name.local_name
        if !known_source_element(kind) || kind == "text" {
          return false
        }
      }
      _ => ()
    }
  }
  true
}

///|
pub fn structural_resource_content(
  document : StructuralDocument,
  node_index : Int,
) -> Bool {
  let mut current : Int? = Some(node_index)
  while current is Some(index) {
    let kind = document.nodes[index].kind
    if kind == "linearGradient" ||
      kind == "radialGradient" ||
      kind == "pattern" ||
      kind == "marker" ||
      kind == "clipPath" ||
      kind == "mask" ||
      kind == "filter" {
      return true
    }
    current = document.nodes[index].parent_index
  }
  false
}

///|
pub fn rendered_plan_contains_node(
  plans : Array[RenderedSubjectPlan],
  node_index : Int,
) -> Bool {
  plans.any(plan => plan.rendered_ancestry.contains(node_index))
}

///|
pub fn unused_definition_indices(document : StructuralDocument) -> Array[Int] {
  let plans = rendered_subject_plans(document)
  [
    for index, node in document.nodes if node.definition_content &&
    !structural_resource_content(document, index) &&
    !rendered_plan_contains_node(plans, index) => index
  ]
}

///|
pub fn structural_definition_facts(
  input : String,
  css_document : CssStaticDocument,
  node : StructuralSourceNode,
) -> Array[DeclaredVisualFact] {
  let facts = visual_declarations_from_element(
    input,
    node.element,
    css_stylesheet_match_for_source(css_document, node.source_offset),
    [],
  )
  for attribute in node.element.attributes {
    let property = attribute.name.local_name
    if property == "transform" ||
      property == "href" ||
      property == "viewBox" ||
      property == "preserveAspectRatio" ||
      property == "d" {
      upsert_declared_fact(facts, presentation_fact(input, property, attribute))
    }
  }
  facts.sort_by(fn(left, right) { left.property.compare(right.property) })
  facts
}
