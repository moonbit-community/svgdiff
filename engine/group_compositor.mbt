///|
fn group_compositor_container(node : @svg.SVGNode) -> Bool {
  node.shape is Group
}

///|
fn group_compositor_active(node : @svg.SVGNode) -> Bool {
  if group_compositor_container(node) && node.opacity != 1.0 {
    return true
  }
  node.children.any(group_compositor_active)
}

///|
fn group_compositor_children(node : @svg.SVGNode) -> Array[@svg.SVGNode] {
  let children = node.children.copy()
  for index in 1..<children.length() {
    let current = children[index]
    let mut previous = index - 1
    while previous >= 0 && children[previous].z_index > current.z_index {
      children[previous + 1] = children[previous]
      previous -= 1
    }
    children[previous + 1] = current
  }
  children
}

///|
fn group_compositor_clamped_opacity(value : Double) -> Double {
  value.max(0.0).min(1.0)
}

///|
fn group_compositor_scaled_alpha(alpha : Int, opacity : Double) -> Int {
  (alpha.to_double() * group_compositor_clamped_opacity(opacity) + 0.5).to_int()
}

///|
fn group_compositor_source_over(
  destination : @svg.Color,
  source : @svg.Color,
) -> @svg.Color {
  if source.a == 0 {
    return destination
  }
  if source.a == 255 || destination.a == 0 {
    return source
  }
  let inverse_source_alpha = 255 - source.a
  let output_alpha_numerator = source.a * 255 +
    destination.a * inverse_source_alpha
  let output_alpha = (output_alpha_numerator + 127) / 255
  if output_alpha == 0 {
    return @svg.Color::transparent()
  }
  fn channel(
    destination_channel : Int,
    source_channel : Int,
    destination_alpha : Int,
    source_alpha : Int,
    inverse_source_alpha : Int,
    output_alpha_numerator : Int,
  ) -> Int {
    let numerator = source_channel * source_alpha * 255 +
      destination_channel * destination_alpha * inverse_source_alpha
    (numerator + output_alpha_numerator / 2) / output_alpha_numerator
  }
  @svg.Color::rgba(
    channel(
      destination.r,
      source.r,
      destination.a,
      source.a,
      inverse_source_alpha,
      output_alpha_numerator,
    ),
    channel(
      destination.g,
      source.g,
      destination.a,
      source.a,
      inverse_source_alpha,
      output_alpha_numerator,
    ),
    channel(
      destination.b,
      source.b,
      destination.a,
      source.a,
      inverse_source_alpha,
      output_alpha_numerator,
    ),
    output_alpha,
  )
}

///|
fn group_compositor_over_image(
  destination : @svg.Image,
  source : @svg.Image,
) -> Unit {
  for index in 0..<destination.pixels.length() {
    destination.pixels[index] = group_compositor_source_over(
      destination.pixels[index],
      source.pixels[index],
    )
  }
}

///|
fn group_compositor_apply_opacity(image : @svg.Image, opacity : Double) -> Unit {
  for index, pixel in image.pixels {
    image.pixels[index] = {
      ..pixel,
      a: group_compositor_scaled_alpha(pixel.a, opacity),
    }
  }
}

///|
fn group_compositor_branch_root(
  ancestors : Array[@svg.SVGNode],
  leaf : @svg.SVGNode,
) -> @svg.SVGNode {
  let mut branch = leaf
  let mut index = ancestors.length() - 1
  while index >= 0 {
    branch = { ..ancestors[index], opacity: 1.0, children: [branch] }
    index -= 1
  }
  branch
}

///|
fn group_compositor_render_leaf(
  document : @svg.SVGDocument,
  ancestors : Array[@svg.SVGNode],
  leaf : @svg.SVGNode,
  width : Int,
  height : Int,
) -> @svg.Image {
  @svg.render_svg_document_to_image(
    { ..document, root: group_compositor_branch_root(ancestors, leaf) },
    width,
    height,
  )
}

///|
fn group_compositor_render_container(
  document : @svg.SVGDocument,
  ancestors : Array[@svg.SVGNode],
  container : @svg.SVGNode,
  width : Int,
  height : Int,
) -> @svg.Image {
  let output = @svg.Image::new(width, height)
  let child_ancestors = ancestors.copy()
  child_ancestors.push(container)
  for child in group_compositor_children(container) {
    let child_image = if group_compositor_container(child) {
      group_compositor_render_container(
        document, child_ancestors, child, width, height,
      )
    } else {
      group_compositor_render_leaf(
        document, child_ancestors, child, width, height,
      )
    }
    group_compositor_over_image(output, child_image)
  }
  group_compositor_apply_opacity(output, container.opacity)
  output
}

///|
fn render_product_document_to_image(
  document : @svg.SVGDocument,
  width : Int,
  height : Int,
) -> @svg.Image {
  if !group_compositor_active(document.root) {
    return @svg.render_svg_document_to_image(document, width, height)
  }
  if group_compositor_container(document.root) {
    group_compositor_render_container(
      document,
      [],
      document.root,
      width,
      height,
    )
  } else {
    group_compositor_render_leaf(document, [], document.root, width, height)
  }
}
