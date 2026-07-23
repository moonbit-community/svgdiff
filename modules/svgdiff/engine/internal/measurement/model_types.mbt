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
  type CanvasOutcome,
  type ChangedFact,
  type ComparisonProfile,
  type DeclaredVisualFact,
  type DifferenceMagnitude,
  type DifferenceRegion,
  type DomainOrdering,
  type PaintedBoundaryDisplacementMagnitude,
  type PaintedCoverageDifferenceMagnitude,
  type PresenceMagnitude,
  type RenderedMagnitude,
  type StructuredReport,
  type SubjectAlignment,
  type TransformEffectMagnitude,
  type VisualEvent,
}

///|
using @ir {
  type SourceSubject,
  source_subject_fact,
  source_subject_id,
  source_subject_ids,
  subjects_for_references,
  subject_value,
}

///|
using @control {type ComparisonGuard, type ComparisonInterrupted}

///|
using @attribution {event_changed_fact_ids, event_influence_subject_ids}

///|
using @source_semantics {push_unique}

///|
using @path_data {
  type NormalizedPathParameter,
  type PathSegmentEvidence,
  normalized_path_segment_kind,
  normalized_path_segment_parameters,
  normalized_path_segment_signature,
}

///|
using @computed {
  type CssBounds,
  type SvgLengthDirection,
  intersect_bounds,
  union_bounds,
}

///|
using @affine_transform {type AffineTransform}

///|
using @geometry {basic_shape_length_direction, parse_alignment_number}

///|
using @resource_model {type ComparisonResourceBundles, type ResourceLimits}

///|
using @resources {
  type EmbeddedImageSubject,
  embedded_image_subject_bounds,
  embedded_image_subject_for_reference,
  extract_embedded_image_subjects_or_raise,
  extract_source_subjects_with_profile_or_raise,
  source_subject_bounds,
  source_subject_unclipped_bounds,
}

///|
using @effects {type ResolvedFilterHost, resolve_filter_hosts_or_raise}

///|
using @rendered {
  computed_canvas_perceptual_flip_evidence,
  computed_rendered_evidence,
  event_local_perceptual_color_evidence,
  event_local_perceptual_flip_evidence,
  image_pixel_at,
  image_pixel_count,
  linear_premultiplied_rgba_squared_error,
  not_computed_canvas_outcome,
  not_computed_canvas_perceptual_flip_evidence,
  not_computed_perceptual_color_evidence,
  not_computed_perceptual_flip_evidence,
  not_computed_rendered_evidence,
  pixel_in_regions,
  pixels_differ,
  raw_rgba8_squared_error,
  rendered_image_difference,
  render_product_document_to_image,
}

///|
using @normalization {normalize_renderer_input_with_profile}

///|
using @rendered_effects {render_product_source_to_image}

///|
using @report_support {empty_difference_magnitude, empty_domain_ordering}
