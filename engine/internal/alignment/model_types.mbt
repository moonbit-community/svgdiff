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
  type AlignmentEvidence,
  type ComparisonProfile,
  type DeclaredVisualFact,
  type SubjectAlignment,
  type SubjectReference,
}

///|
using @ir {
  type SourceSubject,
  type StructuralAlignmentSubject,
  source_subject_fact,
  subject_value,
}

///|
using @control {type ComparisonGuard, type ComparisonInterrupted}

///|
using @source_semantics {
  type StructuralDocument,
  authored_subject_id,
  structural_path_segment,
}

///|
using @path_data {type NormalizedPathSegment, normalized_path_segment_signature}

///|
using @affine_transform {type AffineTransform}

///|
using @computed {type CssBounds}

///|
using @geometry {basic_shape_geometry_property, parse_alignment_number}

///|
using @resources {alignment_property_order, source_subject_bounds}
