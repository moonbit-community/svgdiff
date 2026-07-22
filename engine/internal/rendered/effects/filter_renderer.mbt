///|
fn hide_empty_filter_hosts(
  node : @svg.SVGNode,
  owner_ids : Array[String],
) -> @svg.SVGNode {
  let children = node.children.map(child => {
    hide_empty_filter_hosts(child, owner_ids)
  })
  if owner_ids.contains(node.id) {
    { ..node, opacity: 0.0, filters: [], filter_graph_id: None, children }
  } else {
    { ..node, children, }
  }
}

///|
fn render_filter_product_source_to_image(
  source : String,
  profile : ComparisonProfile,
) -> @svg.Image? {
  guard @svg.parse_svg_document(
      normalize_renderer_input_with_profile(source, profile),
    )
    is Some(document) else {
    return None
  }
  let empty_filter_owner_ids = try
    resolve_filter_hosts_or_raise(source, profile)
  catch {
    _ => []
  } noraise {
    value =>
      value.1.filter_map(host => {
        match host.resource {
          Some(resource) if host.complete && resource.primitives.is_empty() =>
            Some(host.owner_id)
          _ => None
        }
      })
  }
  let document = if empty_filter_owner_ids.is_empty() {
    document
  } else {
    {
      ..document,
      root: hide_empty_filter_hosts(document.root, empty_filter_owner_ids),
    }
  }
  Some(
    @svg.render_svg_document_to_image(
      document,
      profile.viewport_width,
      profile.viewport_height,
    ),
  )
}
