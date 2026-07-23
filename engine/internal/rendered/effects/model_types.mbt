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
using @model {type ComparisonProfile}

///|
using @computed_effects {
  type BlendSemanticDocument,
  type BlendSite,
  resolve_blend_semantic_document_or_raise,
  resolve_filter_hosts_or_raise,
}

///|
using @style {blend_mode_from_keyword}

///|
using @rendered {
  group_compositor_atomic_container,
  group_compositor_children,
  group_compositor_container,
  group_compositor_over_image,
  group_compositor_render_container,
  group_compositor_render_leaf,
  group_compositor_render_masked_container,
}

///|
using @normalization {normalize_renderer_input_with_profile}
