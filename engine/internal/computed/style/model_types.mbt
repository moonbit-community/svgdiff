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
  type ResolvedVisualFact,
}

///|
using @ir {type SourceSubject, subject_value}

///|
using @source_semantics {
  type CssCascadeCandidate,
  type CssStylesheetMatch,
  type PaintFallbackValue,
  ascii_url_start,
  authored_subject_id,
  cascade_visual_declarations,
  css_custom_property_name,
  css_stylesheet_match_for_source,
  fill_hierarchy_kind,
  generated_subject_id,
  inline_style_facts,
  canonical_paint_order,
  canonical_winding_rule,
  paint_rule_issue_code,
  paint_rule_value_valid,
  canonical_marker_reference,
  canonical_clip_path_reference,
  canonical_mask_reference,
  parse_paint_value,
  parse_clip_path_reference,
  parse_filter_reference,
  parse_mask_reference,
  parse_static_css_document_or_raise,
  presentation_cascade_candidate,
  presentation_fact,
  push_unique,
  declared_fact_in_array,
  source_range_slice,
  structural_definition_container,
  supported_css_declaration_property,
  trim_range,
  upsert_declared_fact,
  visual_subject_kind,
}

///|
using @computed {type ViewportContext, parse_svg_length}

///|
using @geometry {
  basic_shape_length_direction,
  parse_shape_number,
  parse_shape_points,
  parse_stroke_dasharray_with_context,
}
