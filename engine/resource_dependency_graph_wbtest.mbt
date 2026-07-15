///|
fn dependency_node(
  graph : ResourceDependencyGraph,
  subject_id : String,
) -> ResourceDependencyNode? {
  for node in graph.nodes {
    if node.subject_id == subject_id {
      return Some(node)
    }
  }
  None
}

///|
test "typed resource graph retains every family relation and locator" {
  let source = "<svg><defs><linearGradient id='base'/><linearGradient id='gradient' href='#base'/><pattern id='pattern' href='#gradient'/><marker id='marker' href='#pattern'/><clipPath id='clip' href='#marker'/><mask id='mask' href='#clip'/><filter id='filter' href='#mask'><feImage href='#embedded'/></filter><symbol id='symbol' href='#filter'><image id='embedded' href='data:image/png;base64,AA=='/></symbol></defs><style>#box{fill:url(#gradient)}</style><rect id='box' fill='url(#gradient)' marker-end='url(#marker)' clip-path='url(#clip)' mask='url(#mask)' filter='url(#filter)'/><rect id='missing-consumer' fill='url(#missing)'/><use id='placed' href='#symbol'/><image id='remote' href='asset.png'/><image id='invalid' href=''/></svg>"
  let graph = build_resource_dependency_graph(source, 1_000_000)
  assert_eq(graph.nodes.length(), 18)
  for
    kind in [
      "linearGradient", "pattern", "marker", "clipPath", "mask", "filter", "symbol",
      "image",
    ] {
    assert_true(graph.nodes.any(node => node.kind == kind))
  }
  guard dependency_node(graph, "embedded") is Some(image) else {
    fail("expected authored image resource node")
  }
  assert_eq(image.authored_id, Some("embedded"))
  assert_true(image.source_offset >= 0)
  assert_true(image.span.end.offset > image.span.start.offset)
  assert_true(image.definition_index is Some(_))
  let relations = graph.edges.map(edge => edge.relation)
  for
    relation in [
      "template", "marker_template", "clip_template", "mask_template", "filter_template",
      "symbol_template", "image", "paint", "marker", "clip", "mask", "filter", "use_instance",
      "style_resource",
    ] {
    assert_true(relations.contains(relation))
  }
  let locator_kinds = graph.edges.map(edge => edge.locator_kind)
  assert_true(locator_kinds.contains("local"))
  assert_true(locator_kinds.contains("data"))
  assert_true(locator_kinds.contains("external"))
  assert_true(locator_kinds.contains("invalid"))
  assert_true(
    graph.edges.any(edge => {
      edge.relation == "image" &&
      edge.locator_kind == "data" &&
      edge.locator == "data:image/png;base64,AA==" &&
      edge.target_id is None &&
      edge.span.end.offset > edge.span.start.offset
    }),
  )
  assert_eq(resource_dependency_target_kinds(graph, "embedded"), ["image"])
  assert_eq(resource_dependency_target_kinds(graph, "missing"), [])
  assert_true(
    resource_dependency_forward_targets(graph, "missing-consumer").contains(
      "missing",
    ),
  )
  let mut style_subject : String? = None
  for node in graph.nodes {
    if node.kind == "style" {
      style_subject = Some(node.subject_id)
    }
  }
  guard style_subject is Some(style_subject) else {
    fail("expected stylesheet dependency source")
  }
  assert_eq(resource_dependency_forward_targets(graph, style_subject), [
    "gradient", "base",
  ])
}

///|
test "resource graph traversal is deterministic and crosses nested definitions" {
  let source = "<svg><defs><linearGradient id='base'/><linearGradient id='paint' href='#base'/><image id='image' href='data:image/png;base64,AA=='/><filter id='effect'><feImage href='#image'/></filter><symbol id='symbol'><rect id='inside' fill='url(#paint)' filter='url(#effect)'/></symbol></defs><use id='placed' href='#symbol'/></svg>"
  let first = build_resource_dependency_graph(source, 1_000_000)
  let second = build_resource_dependency_graph(source, 1_000_000)
  assert_eq(
    resource_dependency_forward_targets(first, "inside"),
    resource_dependency_forward_targets(second, "inside"),
  )
  let forward = resource_dependency_forward_targets(first, "inside")
  assert_true(forward.contains("paint"))
  assert_true(forward.contains("base"))
  assert_true(forward.contains("effect"))
  assert_true(forward.contains("image"))
  let reverse = resource_dependency_reverse_subjects(first, "image")
  assert_true(reverse.any(subject => subject.has_prefix("feImage:")))
  assert_true(reverse.contains("inside"))
  assert_true(reverse.contains("placed"))
  assert_eq(reverse, resource_dependency_reverse_subjects(second, "image"))
  let inside_edges = [
    for edge in first.edges if first.nodes[edge.source_node_index].subject_id ==
    "inside" => edge
  ]
  assert_eq(inside_edges.length(), 2)
  assert_true(
    inside_edges.all(edge => edge.owner_definition_indices.length() >= 2),
  )
}

///|
test "duplicate IDs widen target kinds and reverse consumers" {
  let source = "<svg><defs><linearGradient id='shared'/><pattern id='shared'/><symbol id='outer'><g id='inner'><rect id='nested' fill='url(#shared)'/></g></symbol></defs><rect id='direct' fill='url(#shared)'/><use id='placed' href='#outer'/></svg>"
  let graph = build_resource_dependency_graph(source, 1_000_000)
  assert_eq(resource_dependency_target_kinds(graph, "shared"), [
    "linearGradient", "pattern",
  ])
  let reverse = resource_dependency_reverse_subjects(graph, "shared")
  assert_true(reverse.contains("nested"))
  assert_true(reverse.contains("direct"))
  assert_true(reverse.contains("placed"))
}

///|
test "terminal image dependencies share the materialized edge budget" {
  let source = "<svg id='root'><image href='data:image/png;base64,AA=='/></svg>"
  let exact = build_resource_dependency_graph(source, 1)
  assert_eq(exact.edge_instances, 1)
  assert_true(exact.edge_limit_span is None)
  let exceeded = build_resource_dependency_graph(source, 0)
  assert_true(exceeded.edge_limit_span is Some(_))
}

///|
test "unsupported resource effects remain partial and source located" {
  let source = "<svg><defs><clipPath id='clip'><rect width='4' height='4'/></clipPath><mask id='mask'><rect width='4' height='4'/></mask><filter id='filter'><feImage href='data:image/png;base64,AA=='/></filter></defs><image id='image' href='data:image/png;base64,AA=='/><rect width='8' height='8' clip-path='url(#clip)' mask='url(#mask)' filter='url(#filter)'/></svg>"
  let report = compare(source, source, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "partial")
  assert_true(!report.diagnostics.is_empty())
  assert_true(
    report.diagnostics.any(diagnostic => {
      !diagnostic.source_locations.is_empty() &&
      diagnostic.source_locations.all(location => {
        location.source_span.end_offset > location.source_span.start_offset
      })
    }),
  )
}

///|
test "supported resource reports agree with graph consumer reachability" {
  let before = "<svg><defs><linearGradient id='gradient' x1='0'><stop offset='0' stop-color='red'/><stop offset='1' stop-color='blue'/></linearGradient><pattern id='pattern' width='4' height='4' patternUnits='userSpaceOnUse'><rect width='4' height='4' fill='red'/></pattern><marker id='marker' markerWidth='3' markerHeight='3'><path d='M0 0 L3 1.5 L0 3 Z'/></marker><symbol id='red-symbol'><rect width='4' height='4' fill='red'/></symbol><symbol id='blue-symbol'><rect width='4' height='4' fill='blue'/></symbol></defs><rect id='gradient-box' width='8' height='8' fill='url(#gradient)'/><rect id='pattern-box' x='8' width='8' height='8' fill='url(#pattern)'/><line id='edge' x1='1' y1='12' x2='12' y2='12' marker-end='url(#marker)'/><use id='placed' href='#red-symbol'/></svg>"
  let after = before
    .replace_all(old="x1='0'", new="x1='1'")
    .replace_all(
      old="width='4' height='4' patternUnits",
      new="width='5' height='4' patternUnits",
    )
    .replace_all(old="markerWidth='3'", new="markerWidth='4'")
    .replace_all(old="href='#red-symbol'", new="href='#blue-symbol'")
  let before_graph = build_resource_dependency_graph(before, 1_000_000)
  assert_true(
    resource_dependency_reverse_subjects(before_graph, "gradient").contains(
      "gradient-box",
    ),
  )
  assert_true(
    resource_dependency_reverse_subjects(before_graph, "pattern").contains(
      "pattern-box",
    ),
  )
  assert_true(
    resource_dependency_reverse_subjects(before_graph, "marker").contains(
      "edge",
    ),
  )
  assert_eq(resource_dependency_forward_targets(before_graph, "placed"), [
    "red-symbol",
  ])
  let report = compare(before, after, ComparisonProfile::v1_default())
  for
    resource_and_consumer in [
      ("gradient", "gradient-box"),
      ("pattern", "pattern-box"),
      ("marker", "edge"),
    ] {
    let (resource_id, consumer_id) = resource_and_consumer
    assert_true(
      report.changed_facts.any(fact => {
        fact.subject_id == resource_id &&
        fact.affected_subject_ids.contains(consumer_id)
      }),
    )
  }
  assert_true(
    report.atomic_differences.any(difference => {
      difference.domain == "document.structure.resource_resolution"
    }),
  )
}
