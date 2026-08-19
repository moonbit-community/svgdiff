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
using @model {type ComparisonProfile, type DeclaredVisualFact}

///|
using @ir {type SourceSubject}

///|
using @source_semantics {
  type StructuralDocument,
  type StructuralSourceNode,
  authored_subject_id,
  empty_css_stylesheet_match,
  extract_structural_document_or_raise,
  fill_hierarchy_kind,
  group_opacity_container,
  inline_style_facts,
  parse_mask_reference,
  rect_declared_facts_from_element,
  source_range_slice,
  upsert_declared_fact,
  use_target_index,
  visual_subject_kind,
}

///|
using @computed {
  type ViewportContext,
  source_transform_site_with_viewport,
  source_viewport_resolution,
}

///|
using @effects {resolve_blend_semantic_document_or_raise}

///|
using @geometry {
  type BasicShapeGeometryResolution,
  resolve_basic_shape_geometry_with_context,
  resolve_stroke_geometry_with_context,
  shape_fact,
}

///|
using @style {
  type FillHierarchy,
  type FillSourceElement,
  computed_visual_for_subject,
  extract_fill_hierarchy,
  renderer_computed_override_facts_for_subject,
}

///|
using @resources {
  extract_mask_semantic_document_or_raise,
  extract_source_subjects_with_profile_or_raise,
  marker_resource_from_element,
  mask_resource_for_id,
}
