///|
priv struct ReferenceEdge {
  target_id : String
  span : @xml.SourceSpan
  expands : Bool
  resource_dependency : Bool
}

///|
priv struct ReferenceDefinition {
  mut resource_kind : Bool
  mut descendant_elements : Int
  edges : Array[ReferenceEdge]
}

///|
priv struct ReferenceGraph {
  definitions : Array[ReferenceDefinition]
  indices : Map[String, Int]
  global_use_edges : Array[ReferenceEdge]
  mut total_elements : Int
  mut edge_instances : Int
  mut edge_limit_span : @xml.SourceSpan?
}

///|
fn ReferenceGraph::new() -> ReferenceGraph {
  {
    definitions: [],
    indices: Map([]),
    global_use_edges: [],
    total_elements: 0,
    edge_instances: 0,
    edge_limit_span: None,
  }
}

///|
fn ReferenceGraph::definition_index(
  self : ReferenceGraph,
  id : String,
  kind : String,
) -> Int {
  match self.indices.get(id) {
    Some(index) => {
      if reference_resource_kind(kind) {
        self.definitions[index].resource_kind = true
      }
      index
    }
    None => {
      let index = self.definitions.length()
      self.indices[id] = index
      self.definitions.push({
        resource_kind: reference_resource_kind(kind),
        descendant_elements: 0,
        edges: [],
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
    | "symbol" => true
    _ => false
  }
}

///|
fn percent_hex_value(character : Char) -> Int? {
  if character >= '0' && character <= '9' {
    Some(character.to_int() - '0'.to_int())
  } else if character >= 'a' && character <= 'f' {
    Some(10 + character.to_int() - 'a'.to_int())
  } else if character >= 'A' && character <= 'F' {
    Some(10 + character.to_int() - 'A'.to_int())
  } else {
    None
  }
}

///|
fn decode_local_fragment(value : String) -> String {
  let output = StringBuilder::new()
  let mut index = 0
  while index < value.length() {
    let character = value[index].unsafe_to_char()
    if character == '%' && index + 2 < value.length() {
      match
        (
          percent_hex_value(value[index + 1].unsafe_to_char()),
          percent_hex_value(value[index + 2].unsafe_to_char()),
        ) {
        (Some(high), Some(low)) => {
          output.write_char((high * 16 + low).unsafe_to_char())
          index += 3
          continue
        }
        _ => ()
      }
    }
    output.write_char(character)
    index += 1
  }
  output.to_string()
}

///|
fn local_href_target(value : String) -> String? {
  let normalized = value.trim().to_owned()
  if normalized.length() <= 1 || normalized[0].unsafe_to_char() != '#' {
    return None
  }
  Some(
    decode_local_fragment(
      normalized.view(start_offset=1, end_offset=normalized.length()).to_owned(),
    ),
  )
}

///|
fn ascii_url_start(value : String, index : Int) -> Bool {
  if index + 3 >= value.length() {
    return false
  }
  let u = value[index].unsafe_to_char()
  let r = value[index + 1].unsafe_to_char()
  let l = value[index + 2].unsafe_to_char()
  (u == 'u' || u == 'U') &&
  (r == 'r' || r == 'R') &&
  (l == 'l' || l == 'L') &&
  value[index + 3].unsafe_to_char() == '('
}

///|
fn ascii_reference_whitespace(character : Char) -> Bool {
  character == ' ' ||
  character == '\t' ||
  character == '\n' ||
  character == '\r' ||
  character == '\u000c'
}

///|
fn local_url_targets(value : String) -> Array[String] {
  let targets : Array[String] = []
  let mut index = 0
  while index < value.length() {
    if !ascii_url_start(value, index) {
      index += 1
      continue
    }
    let mut cursor = index + 4
    while cursor < value.length() &&
          ascii_reference_whitespace(value[cursor].unsafe_to_char()) {
      cursor += 1
    }
    let quote = if cursor < value.length() &&
      (
        value[cursor].unsafe_to_char() == '\'' ||
        value[cursor].unsafe_to_char() == '"'
      ) {
      let quote = Some(value[cursor].unsafe_to_char())
      cursor += 1
      quote
    } else {
      None
    }
    while cursor < value.length() &&
          ascii_reference_whitespace(value[cursor].unsafe_to_char()) {
      cursor += 1
    }
    if cursor < value.length() && value[cursor].unsafe_to_char() == '#' {
      cursor += 1
      let start = cursor
      while cursor < value.length() {
        let character = value[cursor].unsafe_to_char()
        let closes_quote = match quote {
          Some(quote_character) => character == quote_character
          None => false
        }
        if character == ')' ||
          ascii_reference_whitespace(character) ||
          closes_quote {
          break
        }
        cursor += 1
      }
      if cursor > start {
        targets.push(
          decode_local_fragment(
            value.view(start_offset=start, end_offset=cursor).to_owned(),
          ),
        )
      }
    }
    index += 4
  }
  targets
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
fn record_reference_edges(
  graph : ReferenceGraph,
  owners : Array[Int],
  element_kind : String,
  attribute : @xml.NamespaceAttribute,
  edge_limit : Int,
) -> Unit {
  if graph.edge_limit_span is Some(_) {
    return
  }
  if attribute.name.local_name == "href" {
    match local_href_target(attribute.value) {
      Some(target_id) => {
        let edge = {
          target_id,
          span: attribute.span,
          expands: element_kind == "use",
          resource_dependency: reference_resource_kind(element_kind),
        }
        if edge.expands {
          graph.global_use_edges.push(edge)
        }
        if edge.expands || edge.resource_dependency {
          for owner in owners {
            if graph.edge_instances >= edge_limit {
              graph.edge_limit_span = Some(attribute.span)
              return
            }
            graph.definitions[owner].edges.push(edge)
            graph.edge_instances += 1
          }
        }
      }
      None => ()
    }
  }
  for target_id in local_url_targets(attribute.value) {
    let edge = {
      target_id,
      span: attribute.span,
      expands: false,
      resource_dependency: true,
    }
    for owner in owners {
      if graph.edge_instances >= edge_limit {
        graph.edge_limit_span = Some(attribute.span)
        return
      }
      graph.definitions[owner].edges.push(edge)
      graph.edge_instances += 1
    }
  }
}

///|
fn build_reference_graph(
  input : String,
  edge_limit : Int,
) -> ReferenceGraph raise {
  let graph = ReferenceGraph::new()
  let active_definitions : Array[Int] = []
  let frames : Array[Int?] = []
  let reader = @xml.NamespaceReader::from_string(input)
  while !reader.is_eof() {
    let event = reader.read_event()
    match event.kind {
      Start(element) | Empty(element) => {
        graph.total_elements += 1
        let own = match element_authored_id(element) {
          Some(id) => Some(graph.definition_index(id, element.name.local_name))
          None => None
        }
        let owners = unique_active_definitions(active_definitions, own)
        for owner in owners {
          graph.definitions[owner].descendant_elements += 1
        }
        for attribute in element.attributes {
          record_reference_edges(
            graph,
            owners,
            element.name.local_name,
            attribute,
            edge_limit,
          )
          if graph.edge_limit_span is Some(_) {
            return graph
          }
        }
        match event.kind {
          Start(_) => {
            frames.push(own)
            match own {
              Some(index) => active_definitions.push(index)
              None => ()
            }
          }
          _ => ()
        }
      }
      End(_) =>
        match frames.pop() {
          Some(Some(_)) => ignore(active_definitions.pop())
          _ => ()
        }
      Eof => break
      _ => ()
    }
  }
  graph
}

///|
fn graph_edge_target(graph : ReferenceGraph, edge : ReferenceEdge) -> Int? {
  match graph.indices.get(edge.target_id) {
    Some(target) if edge.expands => Some(target)
    Some(target) if edge.resource_dependency &&
      graph.definitions[target].resource_kind => Some(target)
    _ => None
  }
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
fn reference_cycle_diagnostic(
  graph : ReferenceGraph,
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
      let edges = graph.definitions[node].edges
      let edge_index = stack_edges[top]
      if edge_index >= edges.length() {
        states[node] = 2
        ignore(stack_nodes.pop())
        ignore(stack_edges.pop())
        continue
      }
      stack_edges[top] = edge_index + 1
      let edge = edges[edge_index]
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
fn expansion_target_index(graph : ReferenceGraph, edge : ReferenceEdge) -> Int? {
  if edge.expands {
    graph.indices.get(edge.target_id)
  } else {
    None
  }
}

///|
fn reference_expansion_diagnostic(
  graph : ReferenceGraph,
  source_role : String,
  limit : Int,
) -> Diagnostic? {
  let count = graph.definitions.length()
  let indegrees = Array::make(count, 0)
  for definition in graph.definitions {
    for edge in definition.edges {
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
    for edge in graph.definitions[node].edges {
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
      for edge in definition.edges {
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
    for edge in graph.definitions[node].edges {
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
  for edge in graph.global_use_edges {
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
fn reference_safety_diagnostic(
  input : String,
  source_role : String,
  limits : ResourceLimits,
) -> Diagnostic? raise {
  let graph = build_reference_graph(input, limits.max_reference_graph_edges)
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
