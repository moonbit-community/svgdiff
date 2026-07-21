///|
pub(all) struct StructuralSourceNode {
  source_id : String
  kind : String
  source_offset : Int
  parent_index : Int?
  children : Array[Int]
  element : @xml.NamespaceElement
  direct_text : String
  definition_content : Bool
  href_fact : DeclaredVisualFact?
}

///|
pub(all) struct StructuralDocument {
  nodes : Array[StructuralSourceNode]
  id_indices : Map[String, Int]
}

///|
pub(all) struct RenderedSubjectPlan {
  source_node_index : Int
  rendered_ancestry : Array[Int]
  use_path : Array[String]
  instance_id : String?
  definition_subject_id : String
}

///|
pub fn structural_source_kind(kind : String) -> Bool {
  fill_hierarchy_kind(kind) || kind == "marker" || kind == "text"
}

///|
pub fn structural_definition_container(kind : String) -> Bool {
  match kind {
    "defs"
    | "symbol"
    | "linearGradient"
    | "radialGradient"
    | "pattern"
    | "marker"
    | "clipPath" => true
    _ => false
  }
}

///|
pub fn structural_href_fact(
  input : String,
  element : @xml.NamespaceElement,
) -> DeclaredVisualFact? {
  let mut legacy : DeclaredVisualFact? = None
  for attribute in element.attributes {
    if attribute.name.local_name != "href" {
      continue
    }
    let fact = presentation_fact(input, "href", attribute)
    if attribute.name.prefix is None {
      return Some(fact)
    }
    if attribute.name.namespace_uri == Some("http://www.w3.org/1999/xlink") {
      legacy = Some(fact)
    }
  }
  legacy
}

///|
pub fn add_structural_source_node(
  input : String,
  element : @xml.NamespaceElement,
  source_offset : Int,
  parent_index : Int?,
  nodes : Array[StructuralSourceNode],
  id_indices : Map[String, Int],
) -> Int {
  let kind = element.name.local_name
  let source_id = authored_subject_id(element).unwrap_or(
    generated_subject_id(kind, source_offset),
  )
  let definition_content = structural_definition_container(kind) ||
    (match parent_index {
      Some(parent) => nodes[parent].definition_content
      None => false
    })
  let index = nodes.length()
  nodes.push({
    source_id,
    kind,
    source_offset,
    parent_index,
    children: [],
    element,
    direct_text: "",
    definition_content,
    href_fact: structural_href_fact(input, element),
  })
  match parent_index {
    Some(parent) => nodes[parent].children.push(index)
    None => ()
  }
  match authored_subject_id(element) {
    Some(id) if id_indices.get(id) is None => id_indices[id] = index
    _ => ()
  }
  index
}

///|
pub fn extract_structural_document_or_raise(
  input : String,
) -> StructuralDocument raise {
  let nodes : Array[StructuralSourceNode] = []
  let id_indices : Map[String, Int] = Map([])
  let stack : Array[Int?] = []
  let reader = @xml.NamespaceReader::from_string(input)
  for event in reader.read_events_until_eof() {
    match event.kind {
      Start(element) => {
        let parent_index = match stack.last() {
          Some(value) => value
          None => None
        }
        if structural_source_kind(element.name.local_name) {
          let index = add_structural_source_node(
            input,
            element,
            event.span.start.offset,
            parent_index,
            nodes,
            id_indices,
          )
          stack.push(Some(index))
        } else {
          stack.push(parent_index)
        }
      }
      Empty(element) =>
        if structural_source_kind(element.name.local_name) {
          ignore(
            add_structural_source_node(
              input,
              element,
              event.span.start.offset,
              match stack.last() {
                Some(value) => value
                None => None
              },
              nodes,
              id_indices,
            ),
          )
        }
      End(_) => ignore(stack.pop())
      Text(_) | CData(_) =>
        match stack.last() {
          Some(Some(index)) if nodes[index].kind == "text" => {
            let node = nodes[index]
            nodes[index] = {
              ..node,
              direct_text: node.direct_text + source_slice(input, event.span),
            }
          }
          _ => ()
        }
      _ => ()
    }
  }
  { nodes, id_indices }
}

///|
pub fn use_target_index(
  document : StructuralDocument,
  node : StructuralSourceNode,
) -> Int? {
  guard node.kind == "use" else { return None }
  guard node.href_fact is Some(fact) else { return None }
  guard local_href_target(fact.declared_value) is Some(target_id) else {
    return None
  }
  document.id_indices.get(target_id)
}

///|
pub fn supported_use_target(kind : String) -> Bool {
  visual_subject_kind(kind) ||
  kind == "g" ||
  kind == "svg" ||
  kind == "symbol" ||
  kind == "use"
}

///|
pub fn rendered_instance_id(
  definition_subject_id : String,
  use_path : Array[String],
) -> String {
  let mut result = "instance"
  for use_id in use_path {
    result = "\{result}/\{use_id}"
  }
  "\{result}/\{definition_subject_id}"
}

///|
pub fn append_rendered_subject_plans(
  document : StructuralDocument,
  node_index : Int,
  rendered_ancestry : Array[Int],
  use_path : Array[String],
  plans : Array[RenderedSubjectPlan],
  active_use_targets : Array[Int],
) -> Unit {
  let node = document.nodes[node_index]
  if use_path.is_empty() && node.definition_content {
    return
  }
  let ancestry = rendered_ancestry.copy()
  ancestry.push(node_index)
  if visual_subject_kind(node.kind) {
    plans.push({
      source_node_index: node_index,
      rendered_ancestry: ancestry,
      use_path,
      instance_id: if use_path.is_empty() {
        None
      } else {
        Some(rendered_instance_id(node.source_id, use_path))
      },
      definition_subject_id: node.source_id,
    })
    return
  }
  if node.kind == "use" {
    guard use_target_index(document, node) is Some(target_index) else { return }
    guard supported_use_target(document.nodes[target_index].kind) else {
      return
    }
    guard !active_use_targets.contains(target_index) else { return }
    let nested_path = use_path.copy()
    nested_path.push(node.source_id)
    let active = active_use_targets.copy()
    active.push(target_index)
    append_rendered_subject_plans(
      document, target_index, ancestry, nested_path, plans, active,
    )
    return
  }
  for child in node.children {
    append_rendered_subject_plans(
      document, child, ancestry, use_path, plans, active_use_targets,
    )
  }
}

///|
pub fn rendered_subject_plans(
  document : StructuralDocument,
) -> Array[RenderedSubjectPlan] {
  let plans : Array[RenderedSubjectPlan] = []
  for index, node in document.nodes {
    if node.parent_index is None && !node.definition_content {
      append_rendered_subject_plans(document, index, [], [], plans, [])
    }
  }
  plans
}

///|
pub fn structural_same_kind_ordinal(
  document : StructuralDocument,
  node_index : Int,
) -> Int {
  let node = document.nodes[node_index]
  let mut ordinal = 0
  match node.parent_index {
    Some(parent_index) =>
      for sibling_index in document.nodes[parent_index].children {
        if sibling_index == node_index {
          break
        }
        if document.nodes[sibling_index].kind == node.kind {
          ordinal += 1
        }
      }
    None =>
      for sibling_index, sibling in document.nodes {
        if sibling_index == node_index {
          break
        }
        if sibling.parent_index is None && sibling.kind == node.kind {
          ordinal += 1
        }
      }
  }
  ordinal
}

///|
pub fn structural_path_segment(
  document : StructuralDocument,
  node_index : Int,
) -> String {
  let node = document.nodes[node_index]
  "\{node.kind}[\{structural_same_kind_ordinal(document, node_index)}]"
}

///|
pub fn structural_parent_path_signature(
  document : StructuralDocument,
  plan : RenderedSubjectPlan,
) -> String {
  let segments : Array[String] = []
  let parent_count = plan.rendered_ancestry.length() - 1
  for index in 0..<parent_count {
    segments.push(
      structural_path_segment(document, plan.rendered_ancestry[index]),
    )
  }
  segments.join("/")
}

///|
pub fn rendered_plan_instance_resolution_signature(
  plan : RenderedSubjectPlan,
) -> String {
  if plan.use_path.is_empty() {
    "direct"
  } else {
    "definition=\{plan.definition_subject_id};depth=\{plan.use_path.length()}"
  }
}
