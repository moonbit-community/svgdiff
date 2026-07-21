///|
fn mask_resource_pair_keys(
  before : MaskSemanticDocument,
  after : MaskSemanticDocument,
) -> Array[String] {
  let keys : Array[String] = []
  for resource in before.resources + after.resources {
    push_unique(keys, resource.authored_id.unwrap_or(resource.subject_id))
  }
  keys.sort()
  keys
}

///|
fn mask_resource_for_key(
  document : MaskSemanticDocument,
  key : String,
) -> MaskRectResource? {
  for resource in document.resources {
    if resource.authored_id.unwrap_or(resource.subject_id) == key {
      return Some(resource)
    }
  }
  None
}

///|
fn mask_region_fact(
  resource : MaskRectResource,
  property : String,
) -> DeclaredVisualFact? {
  let source_property = match property {
    "region-x" => "x"
    "region-y" => "y"
    "region-width" => "width"
    "region-height" => "height"
    _ => property
  }
  shape_fact(resource.region_facts, source_property)
}

///|
fn mask_resource_fact(
  resource : MaskRectResource,
  property : String,
) -> DeclaredVisualFact? {
  match property {
    "maskUnits" => resource.mask_units_fact
    "maskContentUnits" => resource.content_units_fact
    "mask-type" => resource.mask_type_fact
    "color-interpolation" => resource.color_interpolation_fact
    "region-x" | "region-y" | "region-width" | "region-height" =>
      mask_region_fact(resource, property)
    "child-transform" => resource.rect_transform_fact
    _ => shape_fact(resource.rect_facts, property)
  }
}

///|
fn mask_length_signature(length : MaskLength, units : String) -> String {
  if length.percentage && units == "userSpaceOnUse" {
    "\{length.value * 100.0}%"
  } else {
    length.value.to_string()
  }
}

///|
fn mask_resource_computed(
  resource : MaskRectResource,
  property : String,
) -> String {
  match property {
    "maskUnits" => resource.mask_units
    "maskContentUnits" => resource.content_units
    "mask-type" => resource.mask_type
    "color-interpolation" => resource.color_interpolation
    "region-x" => mask_length_signature(resource.region_x, resource.mask_units)
    "region-y" => mask_length_signature(resource.region_y, resource.mask_units)
    "region-width" =>
      mask_length_signature(resource.region_width, resource.mask_units)
    "region-height" =>
      mask_length_signature(resource.region_height, resource.mask_units)
    "child-transform" => resource.rect_transform.signature()
    "x" => resource.rect_bounds.map(value => value.x.to_string()).unwrap_or("")
    "y" => resource.rect_bounds.map(value => value.y.to_string()).unwrap_or("")
    "width" =>
      resource.rect_bounds.map(value => value.width.to_string()).unwrap_or("")
    "height" =>
      resource.rect_bounds.map(value => value.height.to_string()).unwrap_or("")
    "rx" | "ry" => "0"
    "fill" => resource.color_signature
    "fill-opacity" | "opacity" =>
      shape_fact(resource.rect_facts, property)
      .map(value => value.declared_value)
      .unwrap_or("1")
    _ => ""
  }
}

///|
fn mask_resource_number(
  resource : MaskRectResource,
  property : String,
) -> Double? {
  match property {
    "region-x" => Some(resource.region_x.value)
    "region-y" => Some(resource.region_y.value)
    "region-width" => Some(resource.region_width.value)
    "region-height" => Some(resource.region_height.value)
    "x" => resource.rect_bounds.map(value => value.x)
    "y" => resource.rect_bounds.map(value => value.y)
    "width" => resource.rect_bounds.map(value => value.width)
    "height" => resource.rect_bounds.map(value => value.height)
    "rx" | "ry" => Some(0.0)
    "fill-opacity" | "opacity" =>
      parse_shape_number(mask_resource_computed(resource, property))
    _ => None
  }
}

///|
fn mask_resource_magnitude(
  before : MaskRectResource,
  after : MaskRectResource,
  property : String,
) -> DifferenceMagnitude {
  match
    (
      mask_resource_number(before, property),
      mask_resource_number(after, property),
    ) {
    (Some(before), Some(after)) => {
      let delta = after - before
      {
        ..empty_difference_magnitude(),
        parameter_abs_user_units: Some(delta.abs()),
        parameter_signed_user_units: Some(delta),
        symmetric_relative: Some(symmetric_relative_delta(before, after)),
      }
    }
    _ => empty_difference_magnitude()
  }
}

///|
fn mask_resource_affected_subjects(
  before : Array[SourceSubject],
  after : Array[SourceSubject],
  key : String,
) -> Array[String] {
  let ids : Array[String] = []
  for subject in before + after {
    if subject.mask_resource_id == Some(key) {
      push_unique(ids, source_subject_id(subject))
    }
  }
  ids.sort()
  ids
}

///|
fn mask_rendered_evidence(
  before_svg : String,
  after_svg : String,
  profile : ComparisonProfile,
) -> RenderedEvidence {
  match
    (
      @svg.parse_svg_document(
        normalize_renderer_input_with_profile(before_svg, profile),
      ),
      @svg.parse_svg_document(
        normalize_renderer_input_with_profile(after_svg, profile),
      ),
    ) {
    (Some(before), Some(after)) =>
      computed_rendered_evidence(rendered_difference(before, after, profile))
    _ => not_computed_rendered_evidence("mask_renderer_unavailable")
  }
}

///|
fn mask_resource_diagnostic_ids(
  report : StructuredReport,
  subject_ids : Array[String],
) -> Array[String] {
  let ids : Array[String] = []
  for diagnostic in report.diagnostics {
    if subject_ids.contains(diagnostic.subject_id) &&
      diagnostic.code.has_prefix("mask_") {
      push_unique(ids, diagnostic.id)
    }
  }
  ids.sort()
  ids
}

///|
fn mask_resource_domain(property : String) -> String {
  match property {
    "maskUnits" | "maskContentUnits" => "resource.mask.units"
    "mask-type" => "resource.mask.type"
    "color-interpolation" => "resource.mask.color_space"
    "child-transform" => "resource.mask.transform"
    "fill" => "resource.mask.color"
    "fill-opacity" | "opacity" => "resource.mask.alpha"
    _ => "resource.mask.geometry"
  }
}

///|
fn mask_resource_effective_computed(
  resource : MaskRectResource,
  property : String,
  subjects : Array[SourceSubject],
  key : String,
) -> String {
  if property != "fill" && property != "mask-type" {
    return mask_resource_computed(resource, property)
  }
  let modes : Array[String] = []
  for subject in subjects {
    if subject.mask_resource_id == Some(key) && subject.mask_mode is Some(mode) {
      push_unique(modes, mode)
    }
  }
  modes.sort()
  if modes.is_empty() {
    return "inactive"
  }
  if property == "mask-type" {
    return modes.join("|")
  }
  let values : Array[String] = []
  for mode in modes {
    let value = if mode == "alpha" {
      resource.content_alpha
    } else {
      resource.content_luminance
    }
    values.push("\{mode}:\{value}")
  }
  values.join("|")
}

///|
fn mask_host_attachments(
  document : MaskSemanticDocument,
) -> Array[MaskHostAttachment] {
  let attachments : Array[MaskHostAttachment] = []
  for element in document.hierarchy.elements {
    if !group_opacity_container(element.kind) {
      continue
    }
    guard computed_visual_for_subject(
        document.hierarchy,
        element.subject_id,
        "mask",
      )
      is Some(mask) &&
      mask.reported.declaration is Some(mask_fact) &&
      mask.reported.resolved_value != "none" else {
      continue
    }
    let mode = computed_visual_for_subject(
      document.hierarchy,
      element.subject_id,
      "mask-mode",
    )
    attachments.push({
      subject_id: element.subject_id,
      mask_fact,
      mask_value: mask.reported.resolved_value,
      mode_fact: mode.bind(value => value.reported.declaration),
      mode_value: mode
      .map(value => value.reported.resolved_value)
      .unwrap_or("match-source"),
    })
  }
  attachments
}

///|
fn mask_host_attachment_for_id(
  attachments : Array[MaskHostAttachment],
  id : String,
) -> MaskHostAttachment? {
  for attachment in attachments {
    if attachment.subject_id == id {
      return Some(attachment)
    }
  }
  None
}

///|
fn mask_host_affected_subjects(
  before : Array[SourceSubject],
  after : Array[SourceSubject],
  owner_id : String,
) -> Array[String] {
  let ids : Array[String] = []
  for subject in before + after {
    if subject.mask_owner_id == Some(owner_id) {
      push_unique(ids, source_subject_id(subject))
    }
  }
  ids.sort()
  ids
}

///|
fn mask_host_complete(
  before : Array[SourceSubject],
  after : Array[SourceSubject],
  owner_id : String,
) -> Bool {
  (before + after).all(subject => {
    subject.mask_owner_id != Some(owner_id) || subject.mask_complete
  })
}

///|
fn mask_host_diagnostic_ids(
  report : StructuredReport,
  affected_subject_ids : Array[String],
) -> Array[String] {
  let ids : Array[String] = []
  for diagnostic in report.diagnostics {
    if affected_subject_ids.contains(diagnostic.subject_id) &&
      diagnostic.code.has_prefix("mask_") {
      push_unique(ids, diagnostic.id)
    }
  }
  ids.sort()
  ids
}

///|
pub fn attach_mask_differences(
  report : StructuredReport,
  before_svg : String,
  after_svg : String,
) -> StructuredReport {
  let before_document = extract_mask_semantic_document_or_raise(
    before_svg,
    report.profile,
  ) catch {
    _ => return report
  }
  let after_document = extract_mask_semantic_document_or_raise(
    after_svg,
    report.profile,
  ) catch {
    _ => return report
  }
  if before_document.resources.is_empty() && after_document.resources.is_empty() {
    return report
  }
  let before_subjects = extract_source_subjects_with_profile_or_raise(
    before_svg,
    report.profile,
  ) catch {
    _ => []
  }
  let after_subjects = extract_source_subjects_with_profile_or_raise(
    after_svg,
    report.profile,
  ) catch {
    _ => []
  }
  let changed_facts = report.changed_facts.copy()
  let differences = report.atomic_differences.copy()
  let events = report.events.copy()
  let rendered = mask_rendered_evidence(before_svg, after_svg, report.profile)
  for key in mask_resource_pair_keys(before_document, after_document) {
    match
      (
        mask_resource_for_key(before_document, key),
        mask_resource_for_key(after_document, key),
      ) {
      (Some(before), Some(after)) => {
        let difference_ids : Array[String] = []
        let affected_subject_ids = mask_resource_affected_subjects(
          before_subjects, after_subjects, key,
        )
        for
          property in [
            "maskUnits", "maskContentUnits", "region-x", "region-y", "region-width",
            "region-height", "mask-type", "color-interpolation", "child-transform",
            "x", "y", "width", "height", "rx", "ry", "fill", "fill-opacity", "opacity",
          ] {
          let before_fact = mask_resource_fact(before, property)
          let after_fact = mask_resource_fact(after, property)
          if !declared_fact_changed(before_fact, after_fact) {
            continue
          }
          let fact_id = "fact:mask:\{key}:\{property}"
          let difference_id = "diff:mask:\{key}:\{property}"
          let before_computed = mask_resource_effective_computed(
            before, property, before_subjects, key,
          )
          let after_computed = mask_resource_effective_computed(
            after, property, after_subjects, key,
          )
          let diagnostic_ids = mask_resource_diagnostic_ids(report, [
            before.subject_id,
            after.subject_id,
          ])
          let complete = before.complete &&
            after.complete &&
            diagnostic_ids.is_empty()
          changed_facts.push({
            id: fact_id,
            subject_id: before.subject_id,
            property,
            before: before_fact,
            after: after_fact,
            affected_subject_ids,
          })
          differences.push({
            id: difference_id,
            subject_role: "resource",
            subject_alignment_id: None,
            domain: mask_resource_domain(property),
            source_before: declared_value_or_empty(before_fact),
            source_after: declared_value_or_empty(after_fact),
            source_fact_before: before_fact,
            source_fact_after: after_fact,
            changed_fact_ids: [fact_id],
            evidence_layers: if complete && before_computed != after_computed {
              ["source_semantics", "computed_appearance"]
            } else {
              ["source_semantics"]
            },
            computed_relation: if complete {
              {
                status: if before_computed == after_computed {
                  "equivalent"
                } else {
                  "different"
                },
                reason_code: if before_computed == after_computed {
                  "same_resolved_mask_resource"
                } else {
                  "different_resolved_mask_resource"
                },
                missing_side: None,
                diagnostic_ids: [],
              }
            } else {
              {
                status: "indeterminate",
                reason_code: "mask_resource_coverage_partial",
                missing_side: None,
                diagnostic_ids,
              }
            },
            parameter_delta_css_px: None,
            presence_magnitude: None,
            magnitude: mask_resource_magnitude(before, after, property),
            domain_ordering: empty_domain_ordering(),
          })
          difference_ids.push(difference_id)
        }
        if !difference_ids.is_empty() {
          events.push({
            id: "event:mask:\{key}",
            primary_subject_id: key,
            atomic_difference_ids: difference_ids,
            rendered_outcome: if before.complete && after.complete {
              rendered
            } else {
              not_computed_rendered_evidence(
                "mask_resource_rendered_evidence_unavailable",
              )
            },
            difference_regions: [],
          })
        }
      }
      (before, after) => {
        let insertion = before is None
        let resource = match (before, after) {
          (Some(resource), _) | (_, Some(resource)) => resource
          _ => abort("unreachable empty mask resource pair")
        }
        let affected_subject_ids = mask_resource_affected_subjects(
          before_subjects, after_subjects, key,
        )
        let fact_id = "fact:mask:\{key}:presence"
        let difference_id = "diff:mask:\{key}:presence"
        let before_fact = before.map(value => value.presence_fact)
        let after_fact = after.map(value => value.presence_fact)
        let diagnostic_ids = mask_resource_diagnostic_ids(
          report,
          [resource.subject_id, ..affected_subject_ids],
        )
        changed_facts.push({
          id: fact_id,
          subject_id: resource.subject_id,
          property: "presence",
          before: before_fact,
          after: after_fact,
          affected_subject_ids,
        })
        differences.push({
          id: difference_id,
          subject_role: "resource",
          subject_alignment_id: None,
          domain: "resource.mask.presence",
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
          source_fact_before: before_fact,
          source_fact_after: after_fact,
          changed_fact_ids: [fact_id],
          evidence_layers: if affected_subject_ids.is_empty() {
            ["source_semantics"]
          } else {
            ["source_semantics", "computed_appearance"]
          },
          computed_relation: {
            status: if affected_subject_ids.is_empty() {
              "equivalent"
            } else {
              "not_applicable"
            },
            reason_code: if affected_subject_ids.is_empty() {
              "unreferenced_mask_resource"
            } else if insertion {
              "before_resource_absent"
            } else {
              "after_resource_absent"
            },
            missing_side: Some(if insertion { "before" } else { "after" }),
            diagnostic_ids,
          },
          parameter_delta_css_px: None,
          presence_magnitude: None,
          magnitude: empty_difference_magnitude(),
          domain_ordering: empty_domain_ordering(),
        })
        events.push({
          id: "event:mask:\{key}",
          primary_subject_id: key,
          atomic_difference_ids: [difference_id],
          rendered_outcome: if resource.complete {
            rendered
          } else {
            not_computed_rendered_evidence(
              "mask_resource_rendered_evidence_unavailable",
            )
          },
          difference_regions: [],
        })
      }
    }
  }
  let before_attachments = mask_host_attachments(before_document)
  let after_attachments = mask_host_attachments(after_document)
  let owner_ids : Array[String] = []
  for attachment in before_attachments + after_attachments {
    push_unique(owner_ids, attachment.subject_id)
  }
  owner_ids.sort()
  for owner_id in owner_ids {
    let before = mask_host_attachment_for_id(before_attachments, owner_id)
    let after = mask_host_attachment_for_id(after_attachments, owner_id)
    let affected_subject_ids = mask_host_affected_subjects(
      before_subjects, after_subjects, owner_id,
    )
    let event_difference_ids : Array[String] = []
    for property in ["mask", "mask-mode"] {
      let before_fact = before.bind(value => {
        if property == "mask" {
          Some(value.mask_fact)
        } else {
          value.mode_fact
        }
      })
      let after_fact = after.bind(value => {
        if property == "mask" {
          Some(value.mask_fact)
        } else {
          value.mode_fact
        }
      })
      if !declared_fact_changed(before_fact, after_fact) {
        continue
      }
      let before_value = before
        .map(value => {
          if property == "mask" {
            value.mask_value
          } else {
            value.mode_value
          }
        })
        .unwrap_or(if property == "mask" { "none" } else { "match-source" })
      let after_value = after
        .map(value => {
          if property == "mask" {
            value.mask_value
          } else {
            value.mode_value
          }
        })
        .unwrap_or(if property == "mask" { "none" } else { "match-source" })
      let fact_id = "fact:mask-host:\{owner_id}:\{property}"
      let difference_id = "diff:mask-host:\{owner_id}:\{property}"
      let diagnostic_ids = mask_host_diagnostic_ids(
        report, affected_subject_ids,
      )
      let complete = mask_host_complete(
          before_subjects, after_subjects, owner_id,
        ) &&
        diagnostic_ids.is_empty()
      changed_facts.push({
        id: fact_id,
        subject_id: owner_id,
        property,
        before: before_fact,
        after: after_fact,
        affected_subject_ids,
      })
      differences.push({
        id: difference_id,
        subject_role: "entity",
        subject_alignment_id: None,
        domain: if property == "mask" {
          "masking.attachment"
        } else {
          "masking.mode"
        },
        source_before: declared_value_or_empty(before_fact),
        source_after: declared_value_or_empty(after_fact),
        source_fact_before: before_fact,
        source_fact_after: after_fact,
        changed_fact_ids: [fact_id],
        evidence_layers: if complete && before_value != after_value {
          ["source_semantics", "computed_appearance"]
        } else {
          ["source_semantics"]
        },
        computed_relation: if complete {
          {
            status: if before_value == after_value {
              "equivalent"
            } else {
              "different"
            },
            reason_code: if before_value == after_value {
              "same_resolved_mask_host_fact"
            } else {
              "resolved_mask_host_facts_differ"
            },
            missing_side: match (before, after) {
              (None, Some(_)) => Some("before")
              (Some(_), None) => Some("after")
              _ => None
            },
            diagnostic_ids: [],
          }
        } else {
          {
            status: "indeterminate",
            reason_code: "mask_host_coverage_partial",
            missing_side: None,
            diagnostic_ids,
          }
        },
        parameter_delta_css_px: None,
        presence_magnitude: None,
        magnitude: empty_difference_magnitude(),
        domain_ordering: empty_domain_ordering(),
      })
      event_difference_ids.push(difference_id)
    }
    if !event_difference_ids.is_empty() {
      events.push({
        id: "event:mask-host:\{owner_id}",
        primary_subject_id: owner_id,
        atomic_difference_ids: event_difference_ids,
        rendered_outcome: if mask_host_complete(
            before_subjects, after_subjects, owner_id,
          ) {
          rendered
        } else {
          not_computed_rendered_evidence(
            "mask_host_rendered_evidence_unavailable",
          )
        },
        difference_regions: [],
      })
    }
  }
  { ..report, changed_facts, atomic_differences: differences, events }
}
