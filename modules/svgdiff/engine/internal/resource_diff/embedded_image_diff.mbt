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
fn embedded_image_fact_source(fact : DeclaredVisualFact?) -> String {
  fact.map(value => value.authored_value).unwrap_or("(default)")
}

///|
fn embedded_image_facts_differ(
  before : DeclaredVisualFact?,
  after : DeclaredVisualFact?,
) -> Bool {
  match (before, after) {
    (None, None) => false
    (Some(left), Some(right)) =>
      left.authored_value != right.authored_value || left.origin != right.origin
    _ => true
  }
}

///|
fn embedded_image_subject_ids(
  before : EmbeddedImageSubject?,
  after : EmbeddedImageSubject?,
) -> Array[String] {
  let ids : Array[String] = []
  match before {
    Some(subject) => ids.push(subject.subject_id)
    None => ()
  }
  match after {
    Some(subject) if !ids.contains(subject.subject_id) =>
      ids.push(subject.subject_id)
    _ => ()
  }
  ids
}

///|
fn embedded_image_compact_href_fact(
  subject : EmbeddedImageSubject?,
) -> DeclaredVisualFact? {
  match subject {
    Some(subject) => subject.compact_href_fact
    None => None
  }
}

///|
fn embedded_image_diagnostic_ids(
  report : StructuredReport,
  before : EmbeddedImageSubject?,
  after : EmbeddedImageSubject?,
) -> Array[String] {
  let subjects = embedded_image_subject_ids(before, after)
  let ids = [
    for diagnostic in report.diagnostics if subjects.contains(
      diagnostic.subject_id,
    ) => diagnostic.id
  ]
  ids.sort()
  ids
}

///|
fn embedded_rasters_relation(
  before : EmbeddedRasterDecodeResult,
  after : EmbeddedRasterDecodeResult,
  diagnostic_ids : Array[String],
) -> ComputedRelation {
  match (before, after) {
    (EmbeddedRasterDecoded(left), EmbeddedRasterDecoded(right)) => {
      let equivalent = left.width == right.width &&
        left.height == right.height &&
        left.rgba8_sha256 == right.rgba8_sha256
      {
        status: if equivalent {
          "equivalent"
        } else {
          "different"
        },
        reason_code: if equivalent {
          "decoded_intrinsic_rasters_equal"
        } else {
          "decoded_intrinsic_rasters_differ"
        },
        missing_side: None,
        diagnostic_ids: [],
      }
    }
    _ =>
      {
        status: "indeterminate",
        reason_code: "embedded_raster_decode_unavailable",
        missing_side: None,
        diagnostic_ids,
      }
  }
}

///|
fn embedded_rasters_both_decoded(
  before : EmbeddedRasterDecodeResult,
  after : EmbeddedRasterDecodeResult,
) -> Bool {
  match (before, after) {
    (EmbeddedRasterDecoded(_), EmbeddedRasterDecoded(_)) => true
    _ => false
  }
}

///|
fn embedded_raw_rgba8_squared_error(
  before : Bytes,
  after : Bytes,
  index : Int,
) -> Double {
  let mut sum = 0.0
  for channel in 0..<4 {
    let delta = (before[index + channel].to_int() -
      after[index + channel].to_int()).to_double() /
      255.0
    sum += delta * delta
  }
  sum
}

///|
fn embedded_linear_premultiplied_squared_error(
  before : Bytes,
  after : Bytes,
  index : Int,
) -> Double {
  let before_alpha = before[index + 3].to_int().to_double() / 255.0
  let after_alpha = after[index + 3].to_int().to_double() / 255.0
  let mut sum = 0.0
  for channel in 0..<3 {
    let delta = srgb8_to_linear(before[index + channel].to_int()) * before_alpha -
      srgb8_to_linear(after[index + channel].to_int()) * after_alpha
    sum += delta * delta
  }
  let alpha_delta = before_alpha - after_alpha
  sum + alpha_delta * alpha_delta
}

///|
fn embedded_intrinsic_raster_magnitude(
  before : DecodedEmbeddedRaster,
  after : DecodedEmbeddedRaster,
) -> IntrinsicRasterMagnitude {
  if before.width != after.width || before.height != after.height {
    return {
      before_width: before.width,
      before_height: before.height,
      after_width: after.width,
      after_height: after.height,
      compared_pixels: None,
      changed_pixels: None,
      changed_pixel_fraction: None,
      rgba8_rmse: None,
      linear_premultiplied_rgba_rmse: None,
    }
  }
  let pixels = before.width * before.height
  let mut changed_pixels = 0
  let mut rgba8_squared_error = 0.0
  let mut linear_squared_error = 0.0
  for pixel in 0..<pixels {
    let index = pixel * 4
    let mut changed = false
    for channel in 0..<4 {
      if before.rgba8[index + channel] != after.rgba8[index + channel] {
        changed = true
      }
    }
    if changed {
      changed_pixels += 1
    }
    rgba8_squared_error += embedded_raw_rgba8_squared_error(
      before.rgba8,
      after.rgba8,
      index,
    )
    linear_squared_error += embedded_linear_premultiplied_squared_error(
      before.rgba8,
      after.rgba8,
      index,
    )
  }
  {
    before_width: before.width,
    before_height: before.height,
    after_width: after.width,
    after_height: after.height,
    compared_pixels: Some(pixels),
    changed_pixels: Some(changed_pixels),
    changed_pixel_fraction: Some(
      changed_pixels.to_double() / pixels.to_double(),
    ),
    rgba8_rmse: Some((rgba8_squared_error / (pixels * 4).to_double()).sqrt()),
    linear_premultiplied_rgba_rmse: Some(
      (linear_squared_error / (pixels * 4).to_double()).sqrt(),
    ),
  }
}

///|
fn embedded_image_transform_signature(transform : AffineTransform) -> String {
  "matrix(\{transform.a},\{transform.b},\{transform.c},\{transform.d},\{transform.e},\{transform.f})"
}

///|
fn embedded_image_resource_alignment_id(alignment : SubjectAlignment) -> String {
  alignment.id.replace_all(
    old="alignment:image:",
    new="alignment:image-resource:",
  )
}

///|
fn embedded_image_resource_domain(domain : String) -> Bool {
  domain.has_prefix("resource.image.")
}

///|
fn append_embedded_image_difference(
  report : StructuredReport,
  alignment : SubjectAlignment,
  before_subject : EmbeddedImageSubject,
  after_subject : EmbeddedImageSubject,
  property : String,
  domain : String,
  before_fact : DeclaredVisualFact?,
  after_fact : DeclaredVisualFact?,
  source_before : String,
  source_after : String,
  relation : ComputedRelation,
  magnitude : DifferenceMagnitude,
  difference_ids : Array[String],
) -> Unit {
  let resource_difference = embedded_image_resource_domain(domain)
  let difference_alignment_id = if resource_difference {
    embedded_image_resource_alignment_id(alignment)
  } else {
    alignment.id
  }
  let fact_id = "fact:\{difference_alignment_id}:\{property}"
  let difference_id = "diff:\{difference_alignment_id}:\{property}"
  report.changed_facts.push({
    id: fact_id,
    subject_id: difference_alignment_id,
    property,
    before: before_fact,
    after: after_fact,
    affected_subject_ids: embedded_image_subject_ids(
      Some(before_subject),
      Some(after_subject),
    ),
  })
  let evidence_layers : Array[String] = ["source_semantics"]
  if relation.status == "different" {
    evidence_layers.push("computed_appearance")
  }
  report.atomic_differences.push({
    id: difference_id,
    subject_role: if resource_difference {
      "resource"
    } else {
      "entity"
    },
    subject_alignment_id: Some(difference_alignment_id),
    domain,
    source_before,
    source_after,
    source_fact_before: before_fact,
    source_fact_after: after_fact,
    changed_fact_ids: [fact_id],
    evidence_layers,
    computed_relation: relation,
    parameter_delta_css_px: None,
    presence_magnitude: None,
    magnitude,
    domain_ordering: empty_domain_ordering(),
  })
  difference_ids.push(difference_id)
}

///|
fn embedded_numeric_relation(
  before : Double,
  after : Double,
) -> ComputedRelation {
  {
    status: if before == after {
      "equivalent"
    } else {
      "different"
    },
    reason_code: if before == after {
      "used_values_equal"
    } else {
      "used_values_differ"
    },
    missing_side: None,
    diagnostic_ids: [],
  }
}

///|
fn embedded_image_parameter_magnitude(
  before : EmbeddedImageSubject,
  after : EmbeddedImageSubject,
  property : String,
  before_value : Double,
  after_value : Double,
) -> DifferenceMagnitude {
  let delta = after_value - before_value
  let magnitude = {
    ..empty_difference_magnitude(),
    parameter_abs_user_units: Some(delta.abs()),
    parameter_signed_user_units: Some(delta),
    symmetric_relative: Some(
      symmetric_relative_delta(before_value, after_value),
    ),
  }
  if property == "opacity" ||
    !before.placement_complete ||
    !after.placement_complete {
    return magnitude
  }
  let direction = basic_shape_length_direction(property)
  guard common_parameter_directional_css_scale(
      before.cumulative_transform,
      after.cumulative_transform,
      direction,
    )
    is Some(scale) else {
    return magnitude
  }
  let css = delta.abs() * scale
  {
    ..magnitude,
    parameter_abs_css_px: Some(css),
    parameter_entity_fraction: parameter_entity_fraction_from_bounds(css, [
      embedded_image_subject_bounds(before),
      embedded_image_subject_bounds(after),
    ]),
  }
}

///|
fn append_embedded_image_fact_difference(
  report : StructuredReport,
  alignment : SubjectAlignment,
  before : EmbeddedImageSubject,
  after : EmbeddedImageSubject,
  property : String,
  domain : String,
  before_fact : DeclaredVisualFact?,
  after_fact : DeclaredVisualFact?,
  before_value : Double,
  after_value : Double,
  difference_ids : Array[String],
) -> Unit {
  if embedded_image_facts_differ(before_fact, after_fact) ||
    before_value != after_value {
    append_embedded_image_difference(
      report,
      alignment,
      before,
      after,
      property,
      domain,
      before_fact,
      after_fact,
      embedded_image_fact_source(before_fact),
      embedded_image_fact_source(after_fact),
      embedded_numeric_relation(before_value, after_value),
      embedded_image_parameter_magnitude(
        before, after, property, before_value, after_value,
      ),
      difference_ids,
    )
  }
}

///|
fn append_embedded_image_correspondence(
  report : StructuredReport,
  alignment : SubjectAlignment,
  before : EmbeddedImageSubject,
  after : EmbeddedImageSubject,
) -> Array[String] {
  let difference_ids : Array[String] = []
  let diagnostic_ids = embedded_image_diagnostic_ids(
    report,
    Some(before),
    Some(after),
  )
  let compact_source_changed = before.compact_href_fact.map(fact => {
      fact.authored_value
    }) !=
    after.compact_href_fact.map(fact => fact.authored_value)
  if before.href_authored != after.href_authored ||
    (
      !embedded_rasters_both_decoded(before.raster, after.raster) &&
      compact_source_changed
    ) {
    append_embedded_image_difference(
      report,
      alignment,
      before,
      after,
      "href",
      "resource.image.source",
      before.compact_href_fact,
      after.compact_href_fact,
      before.compact_href_fact
      .map(fact => fact.authored_value)
      .unwrap_or("(missing)"),
      after.compact_href_fact
      .map(fact => fact.authored_value)
      .unwrap_or("(missing)"),
      embedded_rasters_relation(before.raster, after.raster, diagnostic_ids),
      empty_difference_magnitude(),
      difference_ids,
    )
  }
  match (before.raster, after.raster) {
    (EmbeddedRasterDecoded(left), EmbeddedRasterDecoded(right)) => {
      let intrinsic = embedded_intrinsic_raster_magnitude(left, right)
      if left.width != right.width {
        append_embedded_image_difference(
          report,
          alignment,
          before,
          after,
          "intrinsic_width",
          "resource.image.intrinsic_width",
          before.compact_href_fact,
          after.compact_href_fact,
          left.width.to_string(),
          right.width.to_string(),
          embedded_numeric_relation(
            left.width.to_double(),
            right.width.to_double(),
          ),
          empty_difference_magnitude(),
          difference_ids,
        )
      }
      if left.height != right.height {
        append_embedded_image_difference(
          report,
          alignment,
          before,
          after,
          "intrinsic_height",
          "resource.image.intrinsic_height",
          before.compact_href_fact,
          after.compact_href_fact,
          left.height.to_string(),
          right.height.to_string(),
          embedded_numeric_relation(
            left.height.to_double(),
            right.height.to_double(),
          ),
          empty_difference_magnitude(),
          difference_ids,
        )
      }
      if left.width != right.width ||
        left.height != right.height ||
        left.rgba8_sha256 != right.rgba8_sha256 {
        append_embedded_image_difference(
          report,
          alignment,
          before,
          after,
          "decoded_content",
          "resource.image.content",
          before.compact_href_fact,
          after.compact_href_fact,
          left.rgba8_sha256,
          right.rgba8_sha256,
          {
            status: "different",
            reason_code: "decoded_intrinsic_rasters_differ",
            missing_side: None,
            diagnostic_ids: [],
          },
          { ..empty_difference_magnitude(), intrinsic_raster: Some(intrinsic) },
          difference_ids,
        )
      }
    }
    _ => ()
  }
  append_embedded_image_fact_difference(
    report,
    alignment,
    before,
    after,
    "x",
    "geometry.position",
    before.x_fact,
    after.x_fact,
    before.x,
    after.x,
    difference_ids,
  )
  append_embedded_image_fact_difference(
    report,
    alignment,
    before,
    after,
    "y",
    "geometry.position",
    before.y_fact,
    after.y_fact,
    before.y,
    after.y,
    difference_ids,
  )
  append_embedded_image_fact_difference(
    report,
    alignment,
    before,
    after,
    "width",
    "geometry.size",
    before.width_fact,
    after.width_fact,
    before.width,
    after.width,
    difference_ids,
  )
  append_embedded_image_fact_difference(
    report,
    alignment,
    before,
    after,
    "height",
    "geometry.size",
    before.height_fact,
    after.height_fact,
    before.height,
    after.height,
    difference_ids,
  )
  append_embedded_image_fact_difference(
    report,
    alignment,
    before,
    after,
    "opacity",
    "compositing.opacity",
    before.opacity_fact,
    after.opacity_fact,
    before.opacity,
    after.opacity,
    difference_ids,
  )
  if embedded_image_facts_differ(
      before.preserve_aspect_ratio_fact,
      after.preserve_aspect_ratio_fact,
    ) ||
    before.preserve_aspect_ratio != after.preserve_aspect_ratio {
    append_embedded_image_difference(
      report,
      alignment,
      before,
      after,
      "preserveAspectRatio",
      "geometry.image.preserve_aspect_ratio",
      before.preserve_aspect_ratio_fact,
      after.preserve_aspect_ratio_fact,
      embedded_image_fact_source(before.preserve_aspect_ratio_fact),
      embedded_image_fact_source(after.preserve_aspect_ratio_fact),
      {
        status: if before.preserve_aspect_ratio == after.preserve_aspect_ratio {
          "equivalent"
        } else {
          "different"
        },
        reason_code: if before.preserve_aspect_ratio ==
          after.preserve_aspect_ratio {
          "preserve_aspect_ratio_values_equal"
        } else {
          "preserve_aspect_ratio_values_differ"
        },
        missing_side: None,
        diagnostic_ids: [],
      },
      empty_difference_magnitude(),
      difference_ids,
    )
  }
  let before_transform = embedded_image_transform_signature(
    before.cumulative_transform,
  )
  let after_transform = embedded_image_transform_signature(
    after.cumulative_transform,
  )
  if before_transform != after_transform {
    append_embedded_image_difference(
      report,
      alignment,
      before,
      after,
      "transform",
      "geometry.transform",
      None,
      None,
      before_transform,
      after_transform,
      {
        status: "different",
        reason_code: "cumulative_transform_matrices_differ",
        missing_side: None,
        diagnostic_ids: [],
      },
      empty_difference_magnitude(),
      difference_ids,
    )
  }
  difference_ids
}

///|
fn append_embedded_image_presence(
  report : StructuredReport,
  alignment : SubjectAlignment,
  before : EmbeddedImageSubject?,
  after : EmbeddedImageSubject?,
) -> Array[String] {
  let insertion = before is None
  let fact_id = "fact:\{alignment.id}:presence"
  let difference_id = "diff:\{alignment.id}:presence"
  report.changed_facts.push({
    id: fact_id,
    subject_id: alignment.id,
    property: "presence",
    before: embedded_image_compact_href_fact(before),
    after: embedded_image_compact_href_fact(after),
    affected_subject_ids: embedded_image_subject_ids(before, after),
  })
  report.atomic_differences.push({
    id: difference_id,
    subject_role: "entity",
    subject_alignment_id: Some(alignment.id),
    domain: if insertion {
      "presence.insertion"
    } else {
      "presence.deletion"
    },
    source_before: if insertion {
      ""
    } else {
      "present"
    },
    source_after: if insertion {
      "present"
    } else {
      ""
    },
    source_fact_before: embedded_image_compact_href_fact(before),
    source_fact_after: embedded_image_compact_href_fact(after),
    changed_fact_ids: [fact_id],
    evidence_layers: ["source_semantics", "computed_appearance"],
    computed_relation: {
      status: "not_applicable",
      reason_code: if insertion {
        "before_image_absent"
      } else {
        "after_image_absent"
      },
      missing_side: Some(if insertion { "before" } else { "after" }),
      diagnostic_ids: embedded_image_diagnostic_ids(report, before, after),
    },
    parameter_delta_css_px: None,
    presence_magnitude: None,
    magnitude: empty_difference_magnitude(),
    domain_ordering: empty_domain_ordering(),
  })
  let resource_alignment_id = embedded_image_resource_alignment_id(alignment)
  let resource_fact_id = "fact:\{resource_alignment_id}:presence"
  let resource_difference_id = "diff:\{resource_alignment_id}:presence"
  report.changed_facts.push({
    id: resource_fact_id,
    subject_id: resource_alignment_id,
    property: "presence",
    before: embedded_image_compact_href_fact(before),
    after: embedded_image_compact_href_fact(after),
    affected_subject_ids: embedded_image_subject_ids(before, after),
  })
  report.atomic_differences.push({
    id: resource_difference_id,
    subject_role: "resource",
    subject_alignment_id: Some(resource_alignment_id),
    domain: "resource.image.presence",
    source_before: if insertion {
      ""
    } else {
      "present"
    },
    source_after: if insertion {
      "present"
    } else {
      ""
    },
    source_fact_before: embedded_image_compact_href_fact(before),
    source_fact_after: embedded_image_compact_href_fact(after),
    changed_fact_ids: [resource_fact_id],
    evidence_layers: ["source_semantics", "computed_appearance"],
    computed_relation: {
      status: "not_applicable",
      reason_code: if insertion {
        "before_resource_absent"
      } else {
        "after_resource_absent"
      },
      missing_side: Some(if insertion { "before" } else { "after" }),
      diagnostic_ids: embedded_image_diagnostic_ids(report, before, after),
    },
    parameter_delta_css_px: None,
    presence_magnitude: None,
    magnitude: empty_difference_magnitude(),
    domain_ordering: empty_domain_ordering(),
  })
  [difference_id, resource_difference_id]
}

///|
pub fn attach_embedded_image_differences(
  report : StructuredReport,
  before_svg : String,
  after_svg : String,
  alignments : Array[SubjectAlignment],
  resources : ComparisonResourceBundles,
  limits : ResourceLimits,
) -> StructuredReport {
  let before = extract_embedded_image_subjects_or_raise(
    before_svg,
    report.profile,
    resources.before,
    limits,
  ) catch {
    _ => return report
  }
  let after = extract_embedded_image_subjects_or_raise(
    after_svg,
    report.profile,
    resources.after,
    limits,
  ) catch {
    _ => return report
  }
  for alignment in alignments {
    guard alignment.id.has_prefix("alignment:image:") else { continue }
    let before_subject = embedded_image_subject_for_reference(
      before,
      alignment.before,
    )
    let after_subject = embedded_image_subject_for_reference(
      after,
      alignment.after,
    )
    let difference_ids = match (before_subject, after_subject) {
      (Some(left), Some(right)) =>
        append_embedded_image_correspondence(report, alignment, left, right)
      (None, Some(_)) | (Some(_), None) =>
        append_embedded_image_presence(
          report, alignment, before_subject, after_subject,
        )
      _ => []
    }
    if !difference_ids.is_empty() {
      report.events.push({
        id: "event:\{alignment.id}",
        primary_subject_id: alignment.id,
        atomic_difference_ids: difference_ids,
        rendered_outcome: not_computed_rendered_evidence(
          "renderer_embedded_raster_unavailable",
        ),
        difference_regions: [],
      })
    }
  }
  let embedded_renderer_unavailable = report.diagnostics.any(diagnostic => {
    diagnostic.code == "renderer_embedded_raster_unavailable"
  })
  if !embedded_renderer_unavailable {
    return report
  }
  let events = [
    for event in report.events => {
      if event.rendered_outcome.status == "computed" {
        {
          ..event,
          rendered_outcome: not_computed_rendered_evidence(
            "renderer_embedded_raster_unavailable",
          ),
        }
      } else {
        event
      }
    }
  ]
  { ..report, events, }
}
