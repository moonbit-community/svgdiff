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
  type AtomicDifference,
  type ChangedFact,
  type Diagnostic,
  type DiagnosticSourceLocation,
  type DifferenceRegion,
  type ImpactAssessment,
  type ImpactDominationWitness,
  type ImpactFrontierGroup,
  type ImpactMeasurement,
  type StructuredReport,
  type SubjectAlignment,
  type SubjectReference,
  type VisualEvent,
}

///|
using @source_semantics {
  type ParsedResourceLocator,
  generated_subject_id,
  parse_resource_locator,
  resource_url_locators,
  source_slice,
}

///|
using @report_support {diagnostic_location_from_xml, same_diagnostic_location}

///|
using @resource_model {type ResourceLimits, resource_limit_diagnostic}
