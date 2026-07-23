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
using @model {type ComparisonProfile, type DeclaredVisualFact, type Diagnostic}

///|
using @ir {type SourceSubject, source_subject_id, subject_value}

///|
using @computed {
  type CssBounds,
  type SvgLengthDirection,
  type ViewportContext,
  parse_svg_length,
  parse_svg_length_at,
}

///|
using @report_support {
  diagnostic_location,
  merge_diagnostic_into,
  unlocated_diagnostic,
}

///|
using @source_semantics {declared_fact_in_array}

///|
using @number_parser {type NumberParser}

///|
using @path_data {type PathSegmentEvidence}
