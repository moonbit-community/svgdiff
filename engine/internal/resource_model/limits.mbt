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
/// Fixed safety budgets for one comparison.
///
/// This type stays package-private so production callers share one versioned
/// contract while whitebox tests can exercise exact boundaries cheaply.
pub(all) struct ResourceLimits {
  max_input_bytes : Int
  max_elements : Int
  max_path_data_units : Int
  max_nesting_depth : Int
  max_references : Int
  max_reference_graph_edges : Int
  max_expanded_elements : Int
  max_embedded_data_uri_bytes : Int
  max_embedded_data_bytes : Int
  max_embedded_raster_dimension : Int
  max_embedded_raster_pixels : Int
  max_resource_bundle_entries : Int
  max_resource_bundle_entry_bytes : Int
  max_resource_bundle_bytes : Int
  max_raster_dimension : Int
  max_raster_pixels : Int
  max_regions : Int
  max_perceptual_map_pixels : Int
  max_perceptual_flip_samples : Int
  max_report_bytes : Int
}

///|
pub fn default_resource_limits() -> ResourceLimits {
  {
    max_input_bytes: 8_388_608,
    max_elements: 100_000,
    max_path_data_units: 1_000_000,
    max_nesting_depth: 256,
    max_references: 100_000,
    max_reference_graph_edges: 1_000_000,
    max_expanded_elements: 1_000_000,
    max_embedded_data_uri_bytes: 6_291_456,
    max_embedded_data_bytes: 4_194_304,
    max_embedded_raster_dimension: 8_192,
    max_embedded_raster_pixels: 16_777_216,
    max_resource_bundle_entries: 1_024,
    max_resource_bundle_entry_bytes: 4_194_304,
    max_resource_bundle_bytes: 16_777_216,
    max_raster_dimension: 8_192,
    max_raster_pixels: 16_777_216,
    max_regions: 65_536,
    max_perceptual_map_pixels: 1_048_576,
    max_perceptual_flip_samples: 268_435_456,
    max_report_bytes: 33_554_432,
  }
}

///|
pub fn utf8_character_bytes(character : Char) -> Int {
  let codepoint = character.to_int()
  if codepoint <= 0x7f {
    1
  } else if codepoint <= 0x7ff {
    2
  } else if codepoint <= 0xffff {
    3
  } else {
    4
  }
}

///|
pub fn utf8_byte_length(value : String) -> Int {
  value.fold(init=0, fn(length, character) {
    length + utf8_character_bytes(character)
  })
}

///|
pub fn utf8_byte_length_exceeds(value : String, limit : Int) -> Bool {
  let mut length = 0
  for character in value {
    length += utf8_character_bytes(character)
    if length > limit {
      return true
    }
  }
  false
}

///|
pub fn limit_subject(dimension : String, source_role : String?) -> String {
  match source_role {
    Some(role) => "\{dimension}.\{role}"
    None => dimension
  }
}

///|
pub fn resource_limit_diagnostic(
  dimension : String,
  source_role : String?,
  span : @xml.SourceSpan?,
) -> Diagnostic {
  let subject_id = limit_subject(dimension, source_role)
  let source_locations = match (source_role, span) {
    (Some(role), Some(span)) => [diagnostic_location_from_xml(role, span)]
    _ => []
  }
  {
    id: "diagnostic:resource-limit-exceeded:\{subject_id}",
    code: "resource_limit_exceeded",
    subject_id,
    affected_evidence_layers: [
      "source_semantics", "computed_appearance", "rendered_evidence",
    ],
    source_locations,
  }
}
