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
pub(all) struct ResourceDependencyNode {
  subject_id : String
  kind : String
  authored_id : String?
  source_offset : Int
  span : @xml.SourceSpan
  definition_index : Int?
}

///|
pub(all) struct ResourceDependencyEdge {
  source_node_index : Int
  owner_definition_indices : Array[Int]
  relation : String
  locator_kind : String
  locator : String
  target_id : String?
  span : @xml.SourceSpan
  expands : Bool
  resource_dependency : Bool
}

///|
pub(all) struct ReferenceDefinition {
  id : String
  node_indices : Array[Int]
  resource_kinds : Array[String]
  mut descendant_elements : Int
  edge_indices : Array[Int]
}

///|
pub(all) struct ResourceDependencyGraph {
  nodes : Array[ResourceDependencyNode]
  edges : Array[ResourceDependencyEdge]
  definitions : Array[ReferenceDefinition]
  indices : Map[String, Int]
  global_use_edge_indices : Array[Int]
  mut total_elements : Int
  mut edge_instances : Int
  mut edge_limit_span : @xml.SourceSpan?
}

///|
pub fn ResourceDependencyGraph::new() -> ResourceDependencyGraph {
  {
    nodes: [],
    edges: [],
    definitions: [],
    indices: Map([]),
    global_use_edge_indices: [],
    total_elements: 0,
    edge_instances: 0,
    edge_limit_span: None,
  }
}

///|
pub fn ResourceDependencyGraph::definition_index(
  self : ResourceDependencyGraph,
  id : String,
  kind : String,
  node_index : Int,
) -> Int {
  match self.indices.get(id) {
    Some(index) => {
      if reference_resource_kind(kind) {
        if !self.definitions[index].resource_kinds.contains(kind) {
          self.definitions[index].resource_kinds.push(kind)
        }
      }
      self.definitions[index].node_indices.push(node_index)
      index
    }
    None => {
      let index = self.definitions.length()
      self.indices[id] = index
      self.definitions.push({
        id,
        node_indices: [node_index],
        resource_kinds: if reference_resource_kind(kind) {
          [kind]
        } else {
          []
        },
        descendant_elements: 0,
        edge_indices: [],
      })
      index
    }
  }
}

///|
fn reference_resource_kind(kind : String) -> Bool {
  match kind {
    "linearGradient"
    | "radialGradient"
    | "pattern"
    | "marker"
    | "clipPath"
    | "mask"
    | "filter"
    | "symbol"
    | "image" => true
    _ => false
  }
}

///|
fn element_authored_id(element : @xml.NamespaceElement) -> String? {
  for attribute in element.attributes {
    if attribute.name.local_name == "id" {
      let id = attribute.value.trim().to_owned()
      if id != "" {
        return Some(id)
      }
    }
  }
  None
}

///|
fn unique_active_definitions(active : Array[Int], own : Int?) -> Array[Int] {
  let unique : Array[Int] = []
  for index in active {
    if !unique.contains(index) {
      unique.push(index)
    }
  }
  match own {
    Some(index) if !unique.contains(index) => unique.push(index)
    _ => ()
  }
  unique
}

///|
fn resource_href_source_kind(kind : String) -> Bool {
  kind == "use" || kind == "feImage" || reference_resource_kind(kind)
}

///|
fn resource_dependency_relation(
  element_kind : String,
  attribute_name : String,
) -> String {
  if attribute_name == "href" {
    match element_kind {
      "use" => "use_instance"
      "linearGradient" | "radialGradient" | "pattern" => "template"
      "marker" => "marker_template"
      "clipPath" => "clip_template"
      "mask" => "mask_template"
      "filter" => "filter_template"
      "symbol" => "symbol_template"
      "image" | "feImage" => "image"
      _ => "resource"
    }
  } else {
    match attribute_name {
      "fill" | "stroke" => "paint"
      "marker" | "marker-start" | "marker-mid" | "marker-end" => "marker"
      "clip-path" => "clip"
      "mask" => "mask"
      "filter" => "filter"
      "style" => "style_resource"
      _ => "resource"
    }
  }
}

///|
fn append_resource_dependency_edge(
  graph : ResourceDependencyGraph,
  source_node_index : Int,
  owners : Array[Int],
  relation : String,
  locator : ParsedResourceLocator,
  span : @xml.SourceSpan,
  expands : Bool,
  resource_dependency : Bool,
  edge_limit : Int,
) -> Unit {
  if graph.edge_limit_span is Some(_) {
    return
  }
  let edge_index = graph.edges.length()
  graph.edges.push({
    source_node_index,
    owner_definition_indices: owners.copy(),
    relation,
    locator_kind: locator.kind,
    locator: locator.locator,
    target_id: locator.target_id,
    span,
    expands,
    resource_dependency,
  })
  if expands {
    graph.global_use_edge_indices.push(edge_index)
  }
  for owner in owners {
    if graph.edge_instances >= edge_limit {
      graph.edge_limit_span = Some(span)
      return
    }
    graph.definitions[owner].edge_indices.push(edge_index)
    graph.edge_instances += 1
  }
}

///|
fn record_resource_dependency_edges(
  graph : ResourceDependencyGraph,
  source_node_index : Int,
  owners : Array[Int],
  element_kind : String,
  attribute : @xml.NamespaceAttribute,
  edge_limit : Int,
) -> Unit {
  if graph.edge_limit_span is Some(_) {
    return
  }
  if attribute.name.local_name == "href" {
    if resource_href_source_kind(element_kind) {
      let locator = parse_resource_locator(attribute.value)
      append_resource_dependency_edge(
        graph,
        source_node_index,
        owners,
        resource_dependency_relation(element_kind, "href"),
        locator,
        attribute.span,
        element_kind == "use" && locator.kind == "local",
        element_kind != "use",
        edge_limit,
      )
    }
  }
  for locator in resource_url_locators(attribute.value) {
    append_resource_dependency_edge(
      graph,
      source_node_index,
      owners,
      resource_dependency_relation(element_kind, attribute.name.local_name),
      locator,
      attribute.span,
      false,
      true,
      edge_limit,
    )
    if graph.edge_limit_span is Some(_) {
      return
    }
  }
}

///|
fn record_stylesheet_resource_dependencies(
  graph : ResourceDependencyGraph,
  source_node_index : Int,
  owners : Array[Int],
  value : String,
  span : @xml.SourceSpan,
  edge_limit : Int,
) -> Unit {
  for locator in resource_url_locators(value) {
    append_resource_dependency_edge(
      graph, source_node_index, owners, "style_resource", locator, span, false, true,
      edge_limit,
    )
    if graph.edge_limit_span is Some(_) {
      return
    }
  }
}

///|
pub fn build_resource_dependency_graph(
  input : String,
  edge_limit : Int,
) -> ResourceDependencyGraph raise {
  let graph = ResourceDependencyGraph::new()
  let active_definitions : Array[Int] = []
  let frames : Array[Int?] = []
  let node_frames : Array[Int] = []
  let reader = @xml.NamespaceReader::from_string(input)
  while !reader.is_eof() {
    let event = reader.read_event()
    match event.kind {
      Start(element) | Empty(element) => {
        graph.total_elements += 1
        let node_index = graph.nodes.length()
        let authored_id = element_authored_id(element)
        graph.nodes.push({
          subject_id: "",
          kind: element.name.local_name,
          authored_id,
          source_offset: 0,
          span: event.span,
          definition_index: None,
        })
        let node = graph.nodes[node_index]
        graph.nodes[node_index] = {
          ..node,
          source_offset: node.span.start.offset,
        }
        let located_node = graph.nodes[node_index]
        let own = match located_node.authored_id {
          Some(id) =>
            Some(graph.definition_index(id, located_node.kind, node_index))
          None => None
        }
        graph.nodes[node_index] = {
          ..located_node,
          subject_id: located_node.authored_id.unwrap_or(
            generated_subject_id(located_node.kind, located_node.source_offset),
          ),
          definition_index: own,
        }
        let source_node = graph.nodes[node_index]
        let owners = unique_active_definitions(
          active_definitions,
          source_node.definition_index,
        )
        for owner in owners {
          graph.definitions[owner].descendant_elements += 1
        }
        for attribute in element.attributes {
          record_resource_dependency_edges(
            graph,
            node_index,
            owners,
            source_node.kind,
            attribute,
            edge_limit,
          )
          if graph.edge_limit_span is Some(_) {
            return graph
          }
        }
        match event.kind {
          Start(_) => {
            node_frames.push(node_index)
            frames.push(source_node.definition_index)
            match source_node.definition_index {
              Some(index) => active_definitions.push(index)
              None => ()
            }
          }
          _ => ()
        }
      }
      Text(_) | CData(_) =>
        match node_frames.last() {
          Some(node_index) if graph.nodes[node_index].kind == "style" =>
            record_stylesheet_resource_dependencies(
              graph,
              node_index,
              active_definitions.copy(),
              source_slice(input, event.span),
              event.span,
              edge_limit,
            )
          _ => ()
        }
      End(_) => {
        ignore(node_frames.pop())
        match frames.pop() {
          Some(Some(_)) => ignore(active_definitions.pop())
          _ => ()
        }
      }
      Eof => break
      _ => ()
    }
  }
  graph
}

///|
fn graph_edge_target(
  graph : ResourceDependencyGraph,
  edge : ResourceDependencyEdge,
) -> Int? {
  guard edge.locator_kind == "local" && edge.locator.has_prefix("#") else {
    return None
  }
  guard edge.target_id is Some(target_id) else { return None }
  match graph.indices.get(target_id) {
    Some(target) if edge.expands => Some(target)
    Some(target) if edge.resource_dependency &&
      !resource_dependency_target_kinds(graph, target_id).is_empty() =>
      Some(target)
    _ => None
  }
}

///|
pub fn resource_dependency_target_kinds(
  graph : ResourceDependencyGraph,
  target_id : String,
) -> Array[String] {
  match graph.indices.get(target_id) {
    Some(index) => graph.definitions[index].resource_kinds.copy()
    None => []
  }
}

///|
#warnings("-unused_value")
pub fn resource_dependency_forward_targets(
  graph : ResourceDependencyGraph,
  subject_id : String,
) -> Array[String] {
  let pending : Array[Int] = []
  for edge_index, edge in graph.edges {
    if graph.nodes[edge.source_node_index].subject_id == subject_id {
      pending.push(edge_index)
    }
  }
  let visited_edges : Array[Int] = []
  let visited_definitions : Array[Int] = []
  let targets : Array[String] = []
  let mut cursor = 0
  while cursor < pending.length() {
    let edge_index = pending[cursor]
    cursor += 1
    if visited_edges.contains(edge_index) {
      continue
    }
    visited_edges.push(edge_index)
    let edge = graph.edges[edge_index]
    match edge.target_id {
      Some(target_id) => {
        if !targets.contains(target_id) {
          targets.push(target_id)
        }
        match graph.indices.get(target_id) {
          Some(definition_index) if !visited_definitions.contains(
              definition_index,
            ) => {
            visited_definitions.push(definition_index)
            for nested_edge in graph.definitions[definition_index].edge_indices {
              pending.push(nested_edge)
            }
          }
          _ => ()
        }
      }
      None => ()
    }
  }
  targets
}

///|
#warnings("-unused_value")
pub fn resource_dependency_reverse_subjects(
  graph : ResourceDependencyGraph,
  target_id : String,
) -> Array[String] {
  let pending : Array[String] = [target_id]
  let visited_targets : Array[String] = []
  let subjects : Array[String] = []
  let mut cursor = 0
  while cursor < pending.length() {
    let current = pending[cursor]
    cursor += 1
    if visited_targets.contains(current) {
      continue
    }
    visited_targets.push(current)
    for edge in graph.edges {
      if edge.target_id != Some(current) {
        continue
      }
      let source_subject = graph.nodes[edge.source_node_index].subject_id
      if !subjects.contains(source_subject) {
        subjects.push(source_subject)
      }
      for owner in edge.owner_definition_indices {
        let owner_id = graph.definitions[owner].id
        if !visited_targets.contains(owner_id) && !pending.contains(owner_id) {
          pending.push(owner_id)
        }
      }
    }
  }
  subjects
}

///|
fn diagnostic_locations_for_spans(
  source_role : String,
  spans : Array[@xml.SourceSpan],
) -> Array[DiagnosticSourceLocation] {
  let locations : Array[DiagnosticSourceLocation] = []
  for span in spans {
    let location = diagnostic_location_from_xml(source_role, span)
    if !locations.any(current => same_diagnostic_location(current, location)) {
      locations.push(location)
    }
  }
  locations
}

///|
fn reference_failure_diagnostic(
  code : String,
  dimension : String,
  source_role : String,
  spans : Array[@xml.SourceSpan],
) -> Diagnostic {
  let subject_id = "\{dimension}.\{source_role}"
  {
    id: "diagnostic:\{code.replace_all(old="_", new="-")}:\{subject_id}",
    code,
    subject_id,
    affected_evidence_layers: [
      "source_semantics", "computed_appearance", "rendered_evidence",
    ],
    source_locations: diagnostic_locations_for_spans(source_role, spans),
  }
}

///|
pub fn reference_cycle_diagnostic(
  graph : ResourceDependencyGraph,
  source_role : String,
) -> Diagnostic? {
  let count = graph.definitions.length()
  let states = Array::make(count, 0)
  let parent_nodes = Array::make(count, -1)
  let parent_spans : Array[@xml.SourceSpan?] = Array::make(count, None)
  for root in 0..<count {
    if states[root] != 0 {
      continue
    }
    let stack_nodes : Array[Int] = [root]
    let stack_edges : Array[Int] = [0]
    states[root] = 1
    while !stack_nodes.is_empty() {
      let top = stack_nodes.length() - 1
      let node = stack_nodes[top]
      let edges = graph.definitions[node].edge_indices
      let edge_index = stack_edges[top]
      if edge_index >= edges.length() {
        states[node] = 2
        ignore(stack_nodes.pop())
        ignore(stack_edges.pop())
        continue
      }
      stack_edges[top] = edge_index + 1
      let edge = graph.edges[edges[edge_index]]
      let target = match graph_edge_target(graph, edge) {
        Some(target) => target
        None => continue
      }
      if states[target] == 0 {
        states[target] = 1
        parent_nodes[target] = node
        parent_spans[target] = Some(edge.span)
        stack_nodes.push(target)
        stack_edges.push(0)
      } else if states[target] == 1 {
        let spans : Array[@xml.SourceSpan] = [edge.span]
        let mut cursor = node
        while cursor != target && cursor >= 0 {
          match parent_spans[cursor] {
            Some(span) => spans.push(span)
            None => ()
          }
          cursor = parent_nodes[cursor]
        }
        return Some(
          reference_failure_diagnostic(
            "reference_cycle_detected", "reference_cycle", source_role, spans,
          ),
        )
      }
    }
  }
  None
}

///|
fn expansion_target_index(
  graph : ResourceDependencyGraph,
  edge : ResourceDependencyEdge,
) -> Int? {
  guard edge.expands &&
    edge.relation == "use_instance" &&
    edge.target_id is Some(target_id) else {
    return None
  }
  graph.indices.get(target_id)
}

///|
pub fn reference_expansion_diagnostic(
  graph : ResourceDependencyGraph,
  source_role : String,
  limit : Int,
) -> Diagnostic? {
  let count = graph.definitions.length()
  let indegrees = Array::make(count, 0)
  for definition in graph.definitions {
    for edge_index in definition.edge_indices {
      let edge = graph.edges[edge_index]
      match expansion_target_index(graph, edge) {
        Some(target) => indegrees[target] += 1
        None => ()
      }
    }
  }
  let queue : Array[Int] = []
  for index in 0..<count {
    if indegrees[index] == 0 {
      queue.push(index)
    }
  }
  let order : Array[Int] = []
  let mut cursor = 0
  while cursor < queue.length() {
    let node = queue[cursor]
    cursor += 1
    order.push(node)
    for edge_index in graph.definitions[node].edge_indices {
      let edge = graph.edges[edge_index]
      match expansion_target_index(graph, edge) {
        Some(target) => {
          indegrees[target] -= 1
          if indegrees[target] == 0 {
            queue.push(target)
          }
        }
        None => ()
      }
    }
  }
  // The all-reference cycle check runs first. Keep this fail-closed fallback
  // so an internal graph invariant cannot admit an unsafe renderer input.
  if order.length() != count {
    for definition in graph.definitions {
      for edge_index in definition.edge_indices {
        let edge = graph.edges[edge_index]
        if edge.expands {
          return Some(
            reference_failure_diagnostic(
              "reference_cycle_detected",
              "reference_cycle",
              source_role,
              [edge.span],
            ),
          )
        }
      }
    }
    return Some(
      reference_failure_diagnostic(
        "reference_cycle_detected",
        "reference_cycle",
        source_role,
        [],
      ),
    )
  }
  let costs = Array::make(count, 0)
  let mut order_index = order.length()
  while order_index > 0 {
    order_index -= 1
    let node = order[order_index]
    let mut cost = graph.definitions[node].descendant_elements
    for edge_index in graph.definitions[node].edge_indices {
      let edge = graph.edges[edge_index]
      match expansion_target_index(graph, edge) {
        Some(target) => {
          if costs[target] > limit - cost {
            return Some(
              reference_failure_diagnostic(
                "reference_expansion_limit_exceeded",
                "reference_expansion",
                source_role,
                [edge.span],
              ),
            )
          }
          cost += costs[target]
        }
        None => ()
      }
    }
    costs[node] = cost
  }
  let mut total = graph.total_elements
  for edge_index in graph.global_use_edge_indices {
    let edge = graph.edges[edge_index]
    match expansion_target_index(graph, edge) {
      Some(target) => {
        if costs[target] > limit - total {
          return Some(
            reference_failure_diagnostic(
              "reference_expansion_limit_exceeded",
              "reference_expansion",
              source_role,
              [edge.span],
            ),
          )
        }
        total += costs[target]
      }
      None => ()
    }
  }
  None
}

///|
pub fn reference_safety_diagnostic(
  input : String,
  source_role : String,
  limits : ResourceLimits,
) -> Diagnostic? raise {
  let graph = build_resource_dependency_graph(
    input,
    limits.max_reference_graph_edges,
  )
  match graph.edge_limit_span {
    Some(span) =>
      return Some(
        resource_limit_diagnostic(
          "reference_graph_edges",
          Some(source_role),
          Some(span),
        ),
      )
    None => ()
  }
  match reference_cycle_diagnostic(graph, source_role) {
    Some(diagnostic) => return Some(diagnostic)
    None => ()
  }
  reference_expansion_diagnostic(
    graph,
    source_role,
    limits.max_expanded_elements,
  )
}
