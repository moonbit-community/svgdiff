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
fn node_descends_from(
  document : @source_semantics.StructuralDocument,
  node_index : Int,
  ancestor_index : Int,
) -> Bool {
  let mut current = document.nodes[node_index].parent_index
  while current is Some(index) {
    if index == ancestor_index {
      return true
    }
    current = document.nodes[index].parent_index
  }
  false
}

///|
fn plan_descends_from(
  plan : @source_semantics.RenderedSubjectPlan,
  node_index : Int,
) -> Bool {
  plan.rendered_ancestry.contains(node_index)
}

///|
fn group_text(
  document : @source_semantics.StructuralDocument,
  group_index : Int,
) -> (Array[String], Array[String]) {
  let texts : Array[String] = []
  for index, node in document.nodes {
    if node.kind != "text" ||
      !(index == group_index || node_descends_from(document, index, group_index)) {
      continue
    }
    let text = normalized_scene_text(node.direct_text)
    if text == "" {
      continue
    }
    texts.push(text)
  }
  let semantic : Array[String] = []
  let symbolic : Array[String] = []
  let mut has_group_circle = false
  for index, node in document.nodes {
    if node.kind == "circle" &&
      (index == group_index || node_descends_from(document, index, group_index)) {
      has_group_circle = true
      break
    }
  }
  for text in texts {
    if texts.length() > 1 && has_group_circle && symbolic_scene_text(text) {
      symbolic.push(text)
    } else {
      semantic.push(text)
    }
  }
  (semantic, symbolic)
}

///|
fn group_primitive_indices(
  plans : Array[@source_semantics.RenderedSubjectPlan],
  group_index : Int,
) -> Array[Int] {
  [
    for index, plan in plans if plan_descends_from(plan, group_index) => index
  ]
}

///|
fn primitive_kinds(
  subjects : Array[@ir.SourceSubject],
  indices : Array[Int],
) -> Array[String] {
  let kinds = [ for index in indices => subjects[index].kind ]
  kinds.sort()
  kinds
}

///|
fn primitive_style_signature(subject : @ir.SourceSubject) -> String {
  let parts : Array[String] = []
  for
    property in [
      "fill", "fill-rule", "stroke", "stroke-width", "stroke-linecap", "stroke-linejoin",
      "stroke-dasharray",
    ] {
    let value = if property == "fill" || property == "stroke" {
      @style.generic_effective_paint(subject, property, None)
    } else {
      @ir.subject_value(subject, property)
    }
    match value {
      Some(value) => parts.push("\{property}=\{value}")
      None => ()
    }
  }
  parts.join("|")
}

///|
fn scene_object_bounds(
  subjects : Array[@ir.SourceSubject],
  indices : Array[Int],
) -> @model.VisualObjectBounds? {
  let mut bounds : @computed.CssBounds? = None
  for index in indices {
    bounds = @computed.union_bounds(
      bounds,
      @resources.source_subject_bounds(subjects[index]),
    )
  }
  match bounds {
    Some(value) =>
      Some({ x: value.x, y: value.y, width: value.width, height: value.height })
    None => None
  }
}

///|
fn qualifying_entity_groups(
  document : @source_semantics.StructuralDocument,
  plans : Array[@source_semantics.RenderedSubjectPlan],
) -> Array[Int] {
  let raw : Array[Int] = []
  for index, node in document.nodes {
    if node.kind != "g" || node.definition_content {
      continue
    }
    let (semantic, _) = group_text(document, index)
    let indices = group_primitive_indices(plans, index)
    if !semantic.is_empty() &&
      indices.any(primitive_index => {
        document.nodes[plans[primitive_index].source_node_index].kind == "rect"
      }) {
      raw.push(index)
    }
  }
  [
    for index in raw if !raw.any(other => {
      other != index && node_descends_from(document, other, index)
    }) => index
  ]
}

///|
fn node_in_any_group(
  document : @source_semantics.StructuralDocument,
  node_index : Int,
  groups : Array[Int],
) -> Bool {
  groups.any(group => {
    node_index == group || node_descends_from(document, node_index, group)
  })
}

///|
fn relation_group_candidates(
  document : @source_semantics.StructuralDocument,
  entity_groups : Array[Int],
) -> Array[Int] {
  let raw : Array[Int] = []
  for index, node in document.nodes {
    if node.kind != "g" ||
      node.definition_content ||
      node_in_any_group(document, index, entity_groups) {
      continue
    }
    let relation_group = match
      @source_semantics.structural_node_attribute_value(node, "class") {
      Some(value) =>
        value
        .split(" ")
        .any(part => {
          part == "link" || part == "relation" || part.has_prefix("relation-")
        })
      None => false
    }
    if !relation_group {
      continue
    }
    let mut has_path = false
    let mut has_rect = false
    for child_index, child in document.nodes {
      if node_descends_from(document, child_index, index) {
        if child.kind == "path" ||
          child.kind == "line" ||
          child.kind == "polyline" {
          has_path = true
        }
        if child.kind == "rect" {
          has_rect = true
        }
      }
    }
    if has_path && !has_rect {
      raw.push(index)
    }
  }
  [
    for index in raw if !raw.any(other => {
      other != index && node_descends_from(document, other, index)
    }) => index
  ]
}

///|
fn relation_class(value : String) -> Bool {
  value
  .split(" ")
  .any(part => {
    part == "link" || part == "relation" || part.has_prefix("relation-")
  })
}

///|
fn relation_edge_class(value : String) -> Bool {
  value.split(" ").any(part => part == "link" || part == "relation")
}

///|
fn relation_primitive_indices(
  document : @source_semantics.StructuralDocument,
  plans : Array[@source_semantics.RenderedSubjectPlan],
  entity_groups : Array[Int],
  relation_groups : Array[Int],
) -> Array[Int] {
  let indices : Array[Int] = []
  for primitive_index, plan in plans {
    let node_index = plan.source_node_index
    if node_in_any_group(document, node_index, relation_groups) {
      indices.push(primitive_index)
      continue
    }
    if node_in_any_group(document, node_index, entity_groups) {
      continue
    }
    match
      @source_semantics.structural_node_attribute_value(
        document.nodes[node_index],
        "class",
      ) {
      Some(value) if relation_class(value) => indices.push(primitive_index)
      _ => ()
    }
  }
  indices
}

///|
fn relation_subject_indices(
  document : @source_semantics.StructuralDocument,
  plans : Array[@source_semantics.RenderedSubjectPlan],
  entity_groups : Array[Int],
  relation_groups : Array[Int],
) -> Array[Int] {
  let indices : Array[Int] = []
  for primitive_index, plan in plans {
    let node = document.nodes[plan.source_node_index]
    if node.kind != "path" ||
      node_in_any_group(document, plan.source_node_index, entity_groups) {
      continue
    }
    if node_in_any_group(document, plan.source_node_index, relation_groups) {
      indices.push(primitive_index)
      continue
    }
    match @source_semantics.structural_node_attribute_value(node, "class") {
      Some(value) if relation_edge_class(value) => indices.push(primitive_index)
      _ => ()
    }
  }
  indices
}

///|
fn path_endpoints(
  subject : @ir.SourceSubject,
) -> ((Double, Double), (Double, Double))? {
  let mut first : (Double, Double)? = None
  let mut last : (Double, Double)? = None
  for segment in subject.path_segments {
    match segment.normalized {
      MoveTo(x, y) => {
        if first is None {
          first = Some((x, y))
        }
        last = Some((x, y))
      }
      LineTo(x, y)
      | CubicTo(_, _, _, _, x, y)
      | QuadraticTo(_, _, x, y)
      | ArcTo(_, _, _, _, _, x, y) => last = Some((x, y))
      ClosePath => ()
    }
  }
  match (first, last) {
    (Some((first_x, first_y)), Some((last_x, last_y))) =>
      Some(
        (
          subject.cumulative_transform.apply_point(first_x, first_y),
          subject.cumulative_transform.apply_point(last_x, last_y),
        ),
      )
    _ => None
  }
}

///|
fn point_distance_to_bounds(
  x : Double,
  y : Double,
  bounds : @model.VisualObjectBounds,
) -> Double {
  let dx = if x < bounds.x {
    bounds.x - x
  } else if x > bounds.x + bounds.width {
    x - bounds.x - bounds.width
  } else {
    0.0
  }
  let dy = if y < bounds.y {
    bounds.y - y
  } else if y > bounds.y + bounds.height {
    y - bounds.y - bounds.height
  } else {
    0.0
  }
  dx + dy
}

///|
fn nearest_object_id(
  objects : Array[SceneObject],
  x : Double,
  y : Double,
) -> String? {
  let mut selected : String? = None
  let mut selected_distance = 1.7976931348623157e308
  let mut second_distance = 1.7976931348623157e308
  for object in objects {
    guard object.summary.bounds is Some(bounds) else { continue }
    let distance = point_distance_to_bounds(x, y, bounds)
    if distance < selected_distance {
      second_distance = selected_distance
      selected_distance = distance
      selected = Some(object.summary.id)
    } else if distance < second_distance {
      second_distance = distance
    }
  }
  if selected_distance == second_distance {
    None
  } else {
    selected
  }
}

///|
fn build_relations(
  subjects : Array[@ir.SourceSubject],
  relation_indices : Array[Int],
  objects : Array[SceneObject],
  side : String,
) -> Array[@model.VisualRelationSummary] {
  let relations : Array[@model.VisualRelationSummary] = []
  for relation_index, subject_index in relation_indices {
    let endpoints : Array[String] = []
    match path_endpoints(subjects[subject_index]) {
      Some(((start_x, start_y), (end_x, end_y))) => {
        match nearest_object_id(objects, start_x, start_y) {
          Some(id) => endpoints.push(id)
          None => ()
        }
        match nearest_object_id(objects, end_x, end_y) {
          Some(id) if !endpoints.contains(id) => endpoints.push(id)
          _ => ()
        }
      }
      None => ()
    }
    relations.push({
      id: "relation:\{side}:\{relation_index}",
      side,
      label: None,
      endpoint_object_ids: endpoints,
      endpoint_basis: if endpoints.length() == 2 {
        "nearest_endpoint"
      } else {
        "unresolved"
      },
    })
  }
  relations
}

///|
fn build_visual_scene(
  input : String,
  side : String,
  profile : @model.ComparisonProfile,
) -> VisualScene raise {
  let document = @source_semantics.extract_structural_document_or_raise(input)
  let plans = @source_semantics.rendered_subject_plans(document)
  let subjects = @resources.extract_source_subjects_with_profile_or_raise(
    input, profile,
  )
  let entity_groups = qualifying_entity_groups(document, plans)
  let objects : Array[SceneObject] = []
  let semantic_text : Array[String] = []
  for object_index, group_index in entity_groups {
    let (semantic, symbolic) = group_text(document, group_index)
    let indices = group_primitive_indices(plans, group_index)
    semantic_text.push_iter(semantic.iter())
    objects.push({
      summary: {
        id: "object:\{side}:\{object_index}",
        side,
        role: "entity",
        label: if semantic is [first, ..] {
          Some(first)
        } else {
          None
        },
        semantic_text: semantic,
        symbolic_text: symbolic,
        primitive_kinds: primitive_kinds(subjects, indices),
        bounds: scene_object_bounds(subjects, indices),
      },
      identity: @source_semantics.structural_node_attribute_value(
        document.nodes[group_index],
        "id",
      ),
      style_signatures: [
        for index in indices => primitive_style_signature(subjects[index])
      ],
    })
  }
  let relation_groups = relation_group_candidates(document, entity_groups)
  let relation_edge_groups = relation_groups.filter(index => {
    match
      @source_semantics.structural_node_attribute_value(
        document.nodes[index],
        "class",
      ) {
      Some(value) => relation_edge_class(value)
      None => false
    }
  })
  let relation_indices = relation_primitive_indices(
    document, plans, entity_groups, relation_groups,
  )
  let relation_subjects = relation_subject_indices(
    document, plans, entity_groups, relation_edge_groups,
  )
  for primitive_index, subject in subjects {
    let plan = plans[primitive_index]
    if node_in_any_group(document, plan.source_node_index, entity_groups) ||
      relation_indices.contains(primitive_index) {
      continue
    }
    let object_index = objects.length()
    objects.push({
      summary: {
        id: "object:\{side}:\{object_index}",
        side,
        role: "graphic",
        label: None,
        semantic_text: [],
        symbolic_text: [],
        primitive_kinds: [subject.kind],
        bounds: scene_object_bounds(subjects, [primitive_index]),
      },
      identity: subject.reference.authored_id,
      style_signatures: [primitive_style_signature(subject)],
    })
  }
  for index, node in document.nodes {
    if node.kind == "text" && !node_in_any_group(document, index, entity_groups) {
      let text = normalized_scene_text(node.direct_text)
      if text != "" {
        semantic_text.push(text)
      }
    }
  }
  semantic_text.sort()
  {
    objects,
    relations: build_relations(subjects, relation_subjects, objects, side),
    semantic_text,
  }
}
