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
fn hide_empty_filter_hosts(
  node : @svg.SVGNode,
  owner_ids : Array[String],
  owner_render_indices : Array[Int],
  next_render_index : Int,
) -> (@svg.SVGNode, Int) {
  let render_index = match node.shape {
    Rect(..)
    | Circle(..)
    | Ellipse(..)
    | Line(..)
    | Polyline(..)
    | Polygon(..)
    | Path(..) => Some(next_render_index)
    _ => None
  }
  let mut next_render_index = if render_index is Some(_) {
    next_render_index + 1
  } else {
    next_render_index
  }
  let children : Array[@svg.SVGNode] = []
  for child in node.children {
    let (child, next) = hide_empty_filter_hosts(
      child, owner_ids, owner_render_indices, next_render_index,
    )
    children.push(child)
    next_render_index = next
  }
  let hidden_by_render_index = render_index
    .map(index => owner_render_indices.contains(index))
    .unwrap_or(false)
  let node = if owner_ids.contains(node.id) || hidden_by_render_index {
    { ..node, opacity: 0.0, filters: [], filter_graph_id: None, children }
  } else {
    { ..node, children, }
  }
  (node, next_render_index)
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
  let empty_filter_hosts = try
    resolve_filter_hosts_or_raise(source, profile)
  catch {
    _ => []
  } noraise {
    value =>
      value.1.filter_map(host => {
        match host.resource {
          Some(resource) if host.complete && resource.primitives.is_empty() =>
            Some(host)
          _ => None
        }
      })
  }
  let empty_filter_owner_ids = empty_filter_hosts.filter_map(host => {
    host.owner_authored_id
  })
  let empty_filter_owner_render_indices = empty_filter_hosts.filter_map(host => {
    if host.owner_authored_id is None {
      host.owner_render_index
    } else {
      None
    }
  })
  let document = if empty_filter_owner_ids.is_empty() &&
    empty_filter_owner_render_indices.is_empty() {
    document
  } else {
    {
      ..document,
      root: hide_empty_filter_hosts(
        document.root,
        empty_filter_owner_ids,
        empty_filter_owner_render_indices,
        0,
      ).0,
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
