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
using @model {
  type ComparisonProfile,
  type DeclaredVisualFact,
  type Diagnostic,
  type ReportSourceSpan,
}

///|
using @source_semantics {
  type CssStaticDocument,
  type RenderedSubjectPlan,
  type StructuralDocument,
  type StructuralSourceNode,
  authored_subject_id,
  css_stylesheet_match_for_source,
  local_href_target,
  presentation_fact,
  use_target_index,
  extract_structural_document_or_raise,
  known_source_element,
  rendered_subject_plans,
  supported_use_target,
  upsert_declared_fact,
}

///|
using @computed {
  type SourceTransformSite,
  type SourceViewportResolution,
  type SvgLengthDirection,
  type ViewportContext,
  default_preserve_aspect_ratio,
  equivalent_viewport_transform,
  normalized_view_box_signature,
  normalized_viewport_fact,
  parse_preserve_aspect_ratio_value,
  parse_view_box_value,
  parse_viewport_length,
  preserve_aspect_ratio_signature,
  source_transform_site,
}

///|
using @affine_transform {type AffineTransform}

///|
using @style {
  type FillHierarchy,
  type FillSourceElement,
  type PaintServerTarget,
  add_fill_source_element,
  visual_declarations_from_element,
}

///|
using @report_support {
  diagnostic_location,
  merge_diagnostic_into,
  unlocated_diagnostic,
}
