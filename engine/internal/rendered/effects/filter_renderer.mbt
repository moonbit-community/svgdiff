///|
fn filter_host_for_node(
  hosts : Array[ResolvedFilterHost],
  node : @svg.SVGNode,
) -> ResolvedFilterHost? {
  if node.id == "" {
    return None
  }
  for host in hosts {
    if host.owner_id == node.id && host.complete && host.resource is Some(_) {
      return Some(host)
    }
  }
  None
}

///|
fn filter_subtree_active(
  hosts : Array[ResolvedFilterHost],
  node : @svg.SVGNode,
) -> Bool {
  filter_host_for_node(hosts, node) is Some(_) ||
  node.children.any(child => filter_subtree_active(hosts, child))
}

///|
fn filter_clip_image(image : @svg.Image, region : CssBounds?) -> Unit {
  match region {
    Some(region) => {
      let filter_bounds : @svg.BoundingBox = {
        min_x: region.x,
        min_y: region.y,
        max_x: region.x + region.width,
        max_y: region.y + region.height,
      }
      group_compositor_clear_outside_bounds(image, filter_bounds)
    }
    None =>
      for index in 0..<image.pixels.length() {
        image.pixels[index] = @svg.Color::transparent()
      }
  }
}

///|
fn filter_source_alpha(image : @svg.Image) -> @svg.Image {
  let output = image.clone()
  for index, pixel in image.pixels {
    output.pixels[index] = @svg.Color::rgba(0, 0, 0, pixel.a)
  }
  output
}

///|
fn filter_offset_image(image : @svg.Image, dx : Int, dy : Int) -> @svg.Image {
  let output = @svg.Image::new(image.width, image.height)
  for y in 0..<image.height {
    for x in 0..<image.width {
      let target_x = x + dx
      let target_y = y + dy
      if target_x >= 0 &&
        target_x < image.width &&
        target_y >= 0 &&
        target_y < image.height {
        output.pixels[target_y * image.width + target_x] = image.pixels[y *
          image.width +
          x]
      }
    }
  }
  output
}

///|
fn filter_input_image(
  name : String,
  source_graphic : @svg.Image,
  source_alpha : @svg.Image,
  previous : @svg.Image?,
  named : Map[String, @svg.Image],
) -> @svg.Image? {
  match name {
    "SourceGraphic" => Some(source_graphic)
    "SourceAlpha" => Some(source_alpha)
    "__previous__" => previous
    name => named.get(name)
  }
}

///|
fn filter_evaluate_host(
  source_graphic : @svg.Image,
  host : ResolvedFilterHost,
) -> @svg.Image {
  guard host.resource is Some(resource) else { return source_graphic.clone() }
  let source_graphic = source_graphic.clone()
  filter_clip_image(source_graphic, host.filter_region)
  let source_alpha = filter_source_alpha(source_graphic)
  let named : Map[String, @svg.Image] = Map([])
  let mut previous : @svg.Image? = None
  for primitive in resource.primitives {
    guard filter_input_image(
        primitive.input,
        source_graphic,
        source_alpha,
        previous,
        named,
      )
      is Some(input) else {
      return @svg.Image::new(source_graphic.width, source_graphic.height)
    }
    let offset = host.primitive_offsets[primitive.index]
    let output = filter_offset_image(input, offset.0, offset.1)
    filter_clip_image(output, host.filter_region)
    previous = Some(output)
    match primitive.result {
      Some(name) => named[name] = output
      None => ()
    }
  }
  previous.unwrap_or(
    @svg.Image::new(source_graphic.width, source_graphic.height),
  )
}

///|
fn filter_render_leaf(
  document : @svg.SVGDocument,
  hosts : Array[ResolvedFilterHost],
  ancestors : Array[@svg.SVGNode],
  leaf : @svg.SVGNode,
  width : Int,
  height : Int,
) -> @svg.Image {
  let unfiltered_leaf = { ..leaf, filters: [], filter_graph_id: None }
  let source = group_compositor_render_leaf(
    document, ancestors, unfiltered_leaf, width, height,
  )
  match filter_host_for_node(hosts, leaf) {
    Some(host) => filter_evaluate_host(source, host)
    None => source
  }
}

///|
fn filter_render_container(
  document : @svg.SVGDocument,
  hosts : Array[ResolvedFilterHost],
  ancestors : Array[@svg.SVGNode],
  container : @svg.SVGNode,
  width : Int,
  height : Int,
) -> @svg.Image {
  let output = @svg.Image::new(width, height)
  let child_ancestors = ancestors.copy()
  child_ancestors.push(container)
  for child in group_compositor_children(container) {
    let child_image = if !filter_subtree_active(hosts, child) {
      if group_compositor_atomic_container(child) {
        group_compositor_render_masked_container(
          document, child_ancestors, child, width, height,
        )
      } else if group_compositor_container(child) {
        group_compositor_render_container(
          document, child_ancestors, child, width, height,
        )
      } else {
        group_compositor_render_leaf(
          document, child_ancestors, child, width, height,
        )
      }
    } else if group_compositor_container(child) {
      filter_render_container(
        document, hosts, child_ancestors, child, width, height,
      )
    } else {
      filter_render_leaf(document, hosts, child_ancestors, child, width, height)
    }
    group_compositor_over_image(output, child_image)
  }
  group_compositor_apply_opacity(output, container.opacity)
  output
}

///|
fn render_filter_product_source_to_image(
  source : String,
  profile : ComparisonProfile,
) -> @svg.Image? {
  let hosts = try resolve_filter_hosts_or_raise(source, profile) catch {
    _ => return None
  } noraise {
    value => value.1
  }
  guard @svg.parse_svg_document(
      normalize_renderer_input_with_profile(source, profile),
    )
    is Some(document) else {
    return None
  }
  let complete_hosts = hosts.filter(host => host.complete)
  if complete_hosts.is_empty() {
    return Some(
      render_product_document_to_image(
        document,
        profile.viewport_width,
        profile.viewport_height,
      ),
    )
  }
  if group_compositor_container(document.root) {
    Some(
      filter_render_container(
        document,
        complete_hosts,
        [],
        document.root,
        profile.viewport_width,
        profile.viewport_height,
      ),
    )
  } else {
    Some(
      filter_render_leaf(
        document,
        complete_hosts,
        [],
        document.root,
        profile.viewport_width,
        profile.viewport_height,
      ),
    )
  }
}

///|
