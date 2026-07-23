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
  type ResolvedVisualFact,
}

///|
using @ir {type SourceSubject, source_subject_id}

///|
using @source_semantics {
  authored_subject_id,
  parse_filter_reference,
  presentation_fact,
  push_unique,
  visual_subject_kind,
}

///|
using @computed {type CssBounds, intersect_bounds, parse_svg_length}

///|
using @geometry {basic_shape_length_direction, parse_shape_number}

///|
using @affine_transform {type AffineTransform}

///|
using @style {
  type FillHierarchy,
  type StyleDependency,
  blend_mode_from_keyword,
  computed_visual_for_subject,
  extract_fill_hierarchy_or_raise,
  fill_entity_kind,
  fill_source_element,
}

///|
using @resources {
  clip_attribute,
  clip_hierarchy_subject_id_at,
  clip_source_fact,
  extract_source_subjects_with_profile_or_raise,
  source_subject_bounds,
}

///|
using @report_support {
  diagnostic_location,
  merge_diagnostic_into,
  unlocated_diagnostic,
}
