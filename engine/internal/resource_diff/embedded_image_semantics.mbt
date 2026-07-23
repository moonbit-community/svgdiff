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
pub fn embedded_image_alignment(
  index : Int,
  relation : String,
  before : EmbeddedImageSubject?,
  after : EmbeddedImageSubject?,
  basis : String,
) -> SubjectAlignment {
  {
    id: "alignment:image:\{index}",
    subject_role: "entity",
    relation,
    before: before.map(subject => [subject.reference]).unwrap_or([]),
    after: after.map(subject => [subject.reference]).unwrap_or([]),
    basis,
    evidence: alignment_evidence(
      "embedded_image_source_order_v1",
      if relation == "correspondence" {
        Some(0.0)
      } else {
        None
      },
      if relation == "correspondence" {
        1
      } else {
        0
      },
      if relation == "correspondence" {
        1
      } else {
        0
      },
      if relation == "correspondence" {
        "unique"
      } else {
        "not_assessed"
      },
    ),
  }
}

///|
pub fn embedded_image_alignments(
  before : Array[EmbeddedImageSubject],
  after : Array[EmbeddedImageSubject],
) -> Array[SubjectAlignment] {
  let alignments : Array[SubjectAlignment] = []
  let before_used = Array::make(before.length(), false)
  let after_used = Array::make(after.length(), false)
  for before_index, subject in before {
    guard subject.reference.authored_id is Some(id) else { continue }
    if embedded_image_unique_id_count(before, id) != 1 ||
      embedded_image_unique_id_count(after, id) != 1 {
      continue
    }
    for after_index, candidate in after {
      if candidate.reference.authored_id == Some(id) {
        alignments.push(
          embedded_image_alignment(
            alignments.length(),
            "correspondence",
            Some(subject),
            Some(candidate),
            "unique_authored_id",
          ),
        )
        before_used[before_index] = true
        after_used[after_index] = true
        break
      }
    }
  }
  let remaining_before = [
    for index in 0..<before.length() if !before_used[index] => index
  ]
  let remaining_after = [
    for index in 0..<after.length() if !after_used[index] => index
  ]
  let paired = remaining_before.length().min(remaining_after.length())
  for index in 0..<paired {
    let before_index = remaining_before[index]
    let after_index = remaining_after[index]
    alignments.push(
      embedded_image_alignment(
        alignments.length(),
        "correspondence",
        Some(before[before_index]),
        Some(after[after_index]),
        "stable_image_source_order",
      ),
    )
    before_used[before_index] = true
    after_used[after_index] = true
  }
  for index, subject in before {
    if !before_used[index] {
      alignments.push(
        embedded_image_alignment(
          alignments.length(),
          "deletion",
          Some(subject),
          None,
          "unmatched_image_subject",
        ),
      )
    }
  }
  for index, subject in after {
    if !after_used[index] {
      alignments.push(
        embedded_image_alignment(
          alignments.length(),
          "insertion",
          None,
          Some(subject),
          "unmatched_image_subject",
        ),
      )
    }
  }
  let entity_alignments = alignments.copy()
  for alignment in entity_alignments {
    alignments.push({
      ..alignment,
      id: alignment.id.replace_all(
        old="alignment:image:",
        new="alignment:image-resource:",
      ),
      subject_role: "resource",
      basis: match alignment.basis {
        "unique_authored_id" => "resource_unique_authored_id"
        "stable_image_source_order" => "resource_stable_image_source_order"
        "unmatched_image_subject" => "unmatched_image_resource"
        basis => basis
      },
    })
  }
  alignments
}

///|
pub fn embedded_image_alignments_for_sources(
  before_svg : String,
  after_svg : String,
  profile : ComparisonProfile,
  before_bundle : ResourceBundle,
  after_bundle : ResourceBundle,
  limits : ResourceLimits,
) -> Array[SubjectAlignment] {
  let before = extract_embedded_image_subjects_or_raise(
    before_svg, profile, before_bundle, limits,
  ) catch {
    _ => return []
  }
  let after = extract_embedded_image_subjects_or_raise(
    after_svg, profile, after_bundle, limits,
  ) catch {
    _ => return []
  }
  embedded_image_alignments(before, after)
}

///|
pub fn embedded_image_diagnostic_location(
  source_role : String,
  subject : EmbeddedImageSubject,
) -> Array[DiagnosticSourceLocation] {
  match subject.href_fact {
    Some(fact) => [diagnostic_location(source_role, fact.source_span)]
    None => []
  }
}

///|
pub fn embedded_image_diagnostic(
  source_role : String,
  subject : EmbeddedImageSubject,
  code : String,
  layers : Array[String],
) -> Diagnostic {
  {
    id: "diagnostic:\{code}:\{source_role}:\{subject.reference.source_index}",
    code,
    subject_id: subject.subject_id,
    affected_evidence_layers: layers,
    source_locations: embedded_image_diagnostic_location(source_role, subject),
  }
}

///|
pub fn embedded_image_preflight_diagnostics(
  input : String,
  profile : ComparisonProfile,
  source_role : String,
  bundle : ResourceBundle,
  limits : ResourceLimits,
) -> Array[Diagnostic] raise {
  let diagnostics : Array[Diagnostic] = []
  for
    subject in extract_embedded_image_subjects_or_raise(
      input, profile, bundle, limits,
    ) {
    match subject.raster {
      EmbeddedRasterDecoded(_) =>
        diagnostics.push(
          embedded_image_diagnostic(
            source_role,
            subject,
            "renderer_embedded_raster_unavailable",
            ["rendered_evidence"],
          ),
        )
      EmbeddedRasterColorUnsupported(image) =>
        diagnostics.push(
          embedded_image_diagnostic(
            source_role,
            subject,
            image.diagnostic_code,
            ["computed_appearance", "rendered_evidence"],
          ),
        )
      EmbeddedRasterUnsupported(reason) =>
        diagnostics.push(
          embedded_image_diagnostic(
            source_role,
            subject,
            if reason == "embedded_raster_variant_unsupported" {
              "embedded_raster_variant_unsupported"
            } else {
              "embedded_raster_media_type_unsupported"
            },
            ["computed_appearance", "rendered_evidence"],
          ),
        )
      EmbeddedRasterInvalid(_) =>
        diagnostics.push(
          embedded_image_diagnostic(
            source_role,
            subject,
            "embedded_raster_data_invalid",
            ["computed_appearance", "rendered_evidence"],
          ),
        )
      EmbeddedRasterLimitExceeded(dimension) =>
        diagnostics.push(
          unlocated_diagnostic(
            "diagnostic:resource-limit-exceeded:\{source_role}:\{dimension}",
            "resource_limit_exceeded",
            "\{source_role}:\{dimension}",
            ["source_semantics", "computed_appearance", "rendered_evidence"],
          ),
        )
      EmbeddedRasterBundleMissing =>
        diagnostics.push(
          embedded_image_diagnostic(
            source_role,
            subject,
            "resource_bundle_entry_missing",
            ["computed_appearance", "rendered_evidence"],
          ),
        )
    }
    if !subject.placement_complete {
      diagnostics.push(
        embedded_image_diagnostic(
          source_role,
          subject,
          "embedded_image_placement_unsupported",
          ["computed_appearance", "rendered_evidence"],
        ),
      )
    }
    if !subject.direct_visual {
      diagnostics.push(
        embedded_image_diagnostic(
          source_role,
          subject,
          "embedded_image_instance_resolution_unsupported",
          ["computed_appearance", "rendered_evidence"],
        ),
      )
    }
  }
  diagnostics
}
