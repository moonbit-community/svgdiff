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
fn blend_site_for_node(
  sites : Array[BlendSite],
  node : @svg.SVGNode,
) -> BlendSite? {
  if node.id == "" {
    return None
  }
  for site in sites {
    if site.owner_id == node.id {
      return Some(site)
    }
  }
  None
}

///|
fn blend_subtree_active(sites : Array[BlendSite], node : @svg.SVGNode) -> Bool {
  blend_site_for_node(sites, node)
  .map(site => site.blend_mode != "normal")
  .unwrap_or(false) ||
  node.children.any(child => blend_subtree_active(sites, child))
}

///|
priv struct BlendRgb {
  r : Double
  g : Double
  b : Double
}

///|
fn blend_rgb(r : Double, g : Double, b : Double) -> BlendRgb {
  { r, g, b }
}

///|
fn blend_lum(color : BlendRgb) -> Double {
  0.3 * color.r + 0.59 * color.g + 0.11 * color.b
}

///|
fn blend_sat(color : BlendRgb) -> Double {
  let minimum = color.r.min(color.g).min(color.b)
  let maximum = color.r.max(color.g).max(color.b)
  maximum - minimum
}

///|
fn blend_clip_color(color : BlendRgb) -> BlendRgb {
  let lum = blend_lum(color)
  let minimum = color.r.min(color.g).min(color.b)
  let maximum = color.r.max(color.g).max(color.b)
  let first = if minimum < 0.0 {
    let scale = lum / (lum - minimum)
    blend_rgb(
      lum + (color.r - lum) * scale,
      lum + (color.g - lum) * scale,
      lum + (color.b - lum) * scale,
    )
  } else {
    color
  }
  if maximum > 1.0 {
    let scale = (1.0 - lum) / (maximum - lum)
    blend_rgb(
      lum + (first.r - lum) * scale,
      lum + (first.g - lum) * scale,
      lum + (first.b - lum) * scale,
    )
  } else {
    first
  }
}

///|
fn blend_set_lum(color : BlendRgb, lum : Double) -> BlendRgb {
  let delta = lum - blend_lum(color)
  blend_clip_color(blend_rgb(color.r + delta, color.g + delta, color.b + delta))
}

///|
fn blend_set_sat(color : BlendRgb, saturation : Double) -> BlendRgb {
  let minimum = color.r.min(color.g).min(color.b)
  let maximum = color.r.max(color.g).max(color.b)
  if maximum == minimum {
    return blend_rgb(0.0, 0.0, 0.0)
  }
  let channel = fn(value) {
    if value == minimum {
      0.0
    } else if value == maximum {
      saturation
    } else {
      (value - minimum) * saturation / (maximum - minimum)
    }
  }
  blend_rgb(channel(color.r), channel(color.g), channel(color.b))
}

///|
fn blend_soft_light(backdrop : Double, source : Double) -> Double {
  if source <= 0.5 {
    backdrop - (1.0 - 2.0 * source) * backdrop * (1.0 - backdrop)
  } else {
    let d = if backdrop <= 0.25 {
      ((16.0 * backdrop - 12.0) * backdrop + 4.0) * backdrop
    } else {
      backdrop.sqrt()
    }
    backdrop + (2.0 * source - 1.0) * (d - backdrop)
  }
}

///|
fn blend_separable_channel(
  backdrop : Double,
  source : Double,
  mode : String,
) -> Double {
  match mode {
    "normal" => source
    "multiply" => backdrop * source
    "screen" => backdrop + source - backdrop * source
    "overlay" =>
      if backdrop <= 0.5 {
        2.0 * backdrop * source
      } else {
        1.0 - 2.0 * (1.0 - backdrop) * (1.0 - source)
      }
    "darken" => backdrop.min(source)
    "lighten" => backdrop.max(source)
    "color-dodge" =>
      if backdrop == 0.0 {
        0.0
      } else if source == 1.0 {
        1.0
      } else {
        (backdrop / (1.0 - source)).min(1.0)
      }
    "color-burn" =>
      if backdrop == 1.0 {
        1.0
      } else if source == 0.0 {
        0.0
      } else {
        (1.0 - (1.0 - backdrop) / source).max(0.0)
      }
    "hard-light" =>
      if source <= 0.5 {
        2.0 * backdrop * source
      } else {
        1.0 - 2.0 * (1.0 - backdrop) * (1.0 - source)
      }
    "soft-light" => blend_soft_light(backdrop, source)
    "difference" => (backdrop - source).abs()
    "exclusion" => backdrop + source - 2.0 * backdrop * source
    _ => source
  }
}

///|
fn blend_opaque_color(
  backdrop : @svg.Color,
  source : @svg.Color,
  mode : String,
) -> @svg.Color {
  let backdrop_rgb = blend_rgb(
    backdrop.r.to_double() / 255.0,
    backdrop.g.to_double() / 255.0,
    backdrop.b.to_double() / 255.0,
  )
  let source_rgb = blend_rgb(
    source.r.to_double() / 255.0,
    source.g.to_double() / 255.0,
    source.b.to_double() / 255.0,
  )
  let result = match mode {
    "hue" =>
      blend_set_lum(
        blend_set_sat(source_rgb, blend_sat(backdrop_rgb)),
        blend_lum(backdrop_rgb),
      )
    "saturation" =>
      blend_set_lum(
        blend_set_sat(backdrop_rgb, blend_sat(source_rgb)),
        blend_lum(backdrop_rgb),
      )
    "color" => blend_set_lum(source_rgb, blend_lum(backdrop_rgb))
    "luminosity" => blend_set_lum(backdrop_rgb, blend_lum(source_rgb))
    _ =>
      blend_rgb(
        blend_separable_channel(backdrop_rgb.r, source_rgb.r, mode),
        blend_separable_channel(backdrop_rgb.g, source_rgb.g, mode),
        blend_separable_channel(backdrop_rgb.b, source_rgb.b, mode),
      )
  }
  @svg.Color::rgba(
    (result.r * 255.0).round().to_int().clamp(min=0, max=255),
    (result.g * 255.0).round().to_int().clamp(min=0, max=255),
    (result.b * 255.0).round().to_int().clamp(min=0, max=255),
    255,
  )
}

///|
fn blend_binary_source_over(
  destination : @svg.Image,
  source : @svg.Image,
  mode : String,
) -> Bool {
  for index in 0..<destination.pixels.length() {
    let backdrop = destination.pixels[index]
    let foreground = source.pixels[index]
    if (backdrop.a != 0 && backdrop.a != 255) ||
      (foreground.a != 0 && foreground.a != 255) {
      return false
    }
    destination.pixels[index] = if foreground.a == 0 {
      backdrop
    } else if backdrop.a == 0 {
      foreground
    } else {
      blend_opaque_color(backdrop, foreground, mode)
    }
  }
  true
}

///|
fn blend_render_inactive_subtree(
  document : @svg.SVGDocument,
  ancestors : Array[@svg.SVGNode],
  node : @svg.SVGNode,
  width : Int,
  height : Int,
) -> @svg.Image {
  if group_compositor_atomic_container(node) {
    group_compositor_render_masked_container(
      document, ancestors, node, width, height,
    )
  } else if group_compositor_container(node) {
    group_compositor_render_container(document, ancestors, node, width, height)
  } else {
    group_compositor_render_leaf(document, ancestors, node, width, height)
  }
}

///|
fn blend_render_node_into(
  destination : @svg.Image,
  document : @svg.SVGDocument,
  sites : Array[BlendSite],
  ancestors : Array[@svg.SVGNode],
  node : @svg.SVGNode,
  width : Int,
  height : Int,
) -> Bool {
  if !blend_subtree_active(sites, node) {
    group_compositor_over_image(
      destination,
      blend_render_inactive_subtree(document, ancestors, node, width, height),
    )
    return true
  }
  if group_compositor_container(node) {
    let child_ancestors = ancestors.copy()
    child_ancestors.push(node)
    let isolated = blend_site_for_node(sites, node)
      .map(site => site.isolation == "isolate")
      .unwrap_or(false)
    let target = if isolated {
      @svg.Image::new(width, height)
    } else {
      destination
    }
    for child in group_compositor_children(node) {
      if !blend_render_node_into(
          target, document, sites, child_ancestors, child, width, height,
        ) {
        return false
      }
    }
    if isolated {
      group_compositor_over_image(destination, target)
    }
    return true
  }
  let source = group_compositor_render_leaf(
    document, ancestors, node, width, height,
  )
  match blend_site_for_node(sites, node) {
    Some(site) if site.blend_mode != "normal" =>
      match blend_mode_from_keyword(site.blend_mode) {
        Some(_) =>
          blend_binary_source_over(destination, source, site.blend_mode)
        None => false
      }
    _ => {
      group_compositor_over_image(destination, source)
      true
    }
  }
}

///|
fn render_blend_product_source_to_image(
  source : String,
  profile : ComparisonProfile,
  semantic : BlendSemanticDocument,
) -> @svg.Image? {
  guard semantic.complete &&
    @svg.parse_svg_document(
      normalize_renderer_input_with_profile(source, profile),
    )
    is Some(document) else {
    return None
  }
  let output = @svg.Image::new(profile.viewport_width, profile.viewport_height)
  if blend_render_node_into(
      output,
      document,
      semantic.sites,
      [],
      document.root,
      profile.viewport_width,
      profile.viewport_height,
    ) {
    Some(output)
  } else {
    None
  }
}

///|
pub fn render_product_source_to_image(
  source : String,
  profile : ComparisonProfile,
) -> @svg.Image? {
  let semantic = try
    resolve_blend_semantic_document_or_raise(source, profile)
  catch {
    _ => return None
  } noraise {
    value => value
  }
  if semantic.active {
    render_blend_product_source_to_image(source, profile, semantic)
  } else {
    render_filter_product_source_to_image(source, profile)
  }
}

///|
