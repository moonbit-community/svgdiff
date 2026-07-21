///|
fn filter_host_attachments(
  document : FilterSemanticDocument,
) -> Array[FilterHostAttachment] {
  let attachments : Array[FilterHostAttachment] = []
  for element in document.hierarchy.elements {
    match
      computed_visual_for_subject(
        document.hierarchy,
        element.subject_id,
        "filter",
      ) {
      Some(resolution) if resolution.reported.declaration is Some(fact) =>
        attachments.push({
          owner_id: element.subject_id,
          fact,
          value: resolution.reported.resolved_value,
        })
      _ => ()
    }
  }
  attachments
}

///|
fn filter_attachment_for_owner(
  attachments : Array[FilterHostAttachment],
  owner_id : String,
) -> FilterHostAttachment? {
  for attachment in attachments {
    if attachment.owner_id == owner_id {
      return Some(attachment)
    }
  }
  None
}

///|
fn filter_attachment_effect_value(
  attachment : FilterHostAttachment?,
  hosts : Array[ResolvedFilterHost],
) -> String {
  guard attachment is Some(attachment) else { return "none" }
  if parse_filter_reference(attachment.value) is FilterNone {
    return "none"
  }
  for host in hosts {
    if host.owner_id == attachment.owner_id && host.complete {
      return match host.resource {
        Some(_) => {
          let id = host.resource_id.unwrap_or("")
          "resource:\{id}"
        }
        None => "none"
      }
    }
  }
  attachment.value
}

///|
fn filter_resource_keys(
  before : FilterSemanticDocument,
  after : FilterSemanticDocument,
) -> Array[String] {
  let keys : Array[String] = []
  for resource in before.resources + after.resources {
    push_unique(keys, resource.authored_id.unwrap_or(resource.subject_id))
  }
  keys.sort()
  keys
}

///|
fn filter_resource_for_key(
  document : FilterSemanticDocument,
  key : String,
) -> FilterResource? {
  for resource in document.resources {
    if resource.authored_id.unwrap_or(resource.subject_id) == key {
      return Some(resource)
    }
  }
  None
}

///|
fn filter_affected_hosts(
  before : Array[ResolvedFilterHost],
  after : Array[ResolvedFilterHost],
  resource_id : String,
) -> Array[String] {
  let ids : Array[String] = []
  for host in before + after {
    if host.resource_id == Some(resource_id) {
      push_unique(ids, host.owner_id)
    }
  }
  ids.sort()
  ids
}

///|
fn filter_region_fact(
  resource : FilterResource,
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
fn filter_length_signature(length : FilterLength, units : String) -> String {
  if length.percentage || units == "objectBoundingBox" {
    "\{length.value * 100.0}%"
  } else {
    length.value.to_string()
  }
}

///|
fn filter_resource_property_fact(
  resource : FilterResource,
  property : String,
) -> DeclaredVisualFact? {
  match property {
    "filterUnits" => resource.filter_units_fact
    "primitiveUnits" => resource.primitive_units_fact
    "region-x" | "region-y" | "region-width" | "region-height" =>
      filter_region_fact(resource, property)
    _ => None
  }
}

///|
fn filter_resource_property_value(
  resource : FilterResource,
  property : String,
) -> String {
  match property {
    "filterUnits" => resource.filter_units
    "primitiveUnits" => resource.primitive_units
    "region-x" =>
      filter_length_signature(resource.region_x, resource.filter_units)
    "region-y" =>
      filter_length_signature(resource.region_y, resource.filter_units)
    "region-width" =>
      filter_length_signature(resource.region_width, resource.filter_units)
    "region-height" =>
      filter_length_signature(resource.region_height, resource.filter_units)
    _ => ""
  }
}

///|
fn filter_resource_property_number(
  resource : FilterResource,
  property : String,
) -> Double? {
  match property {
    "region-x" => Some(resource.region_x.value)
    "region-y" => Some(resource.region_y.value)
    "region-width" => Some(resource.region_width.value)
    "region-height" => Some(resource.region_height.value)
    _ => None
  }
}

///|
fn filter_primitive_fact(
  primitive : FilterOffsetPrimitive,
  property : String,
) -> DeclaredVisualFact? {
  match property {
    "in" => primitive.input_fact
    "result" => primitive.result_fact
    "dx" => primitive.dx_fact
    "dy" => primitive.dy_fact
    _ => None
  }
}

///|
fn filter_primitive_value(
  primitive : FilterOffsetPrimitive,
  property : String,
) -> String {
  match property {
    "in" => primitive.input
    "result" => primitive.result.unwrap_or("")
    "dx" => primitive.dx.to_string()
    "dy" => primitive.dy.to_string()
    _ => ""
  }
}

///|
fn filter_offset_for_source(
  resource : FilterResource,
  source : FilterPrimitiveSource?,
) -> FilterOffsetPrimitive? {
  source
  .bind(value => value.offset_index)
  .bind(index => resource.primitives.get(index))
}

///|
pub fn filter_primitive_source_fact(
  input : String,
  source : FilterPrimitiveSource?,
) -> DeclaredVisualFact? {
  source.map(value => {
    clip_source_fact(
      input,
      "primitive-source",
      value.start_offset,
      value.end_offset,
    )
  })
}

///|
fn filter_primitive_source_value(
  input : String,
  source : FilterPrimitiveSource?,
) -> String {
  source
  .map(value => source_range_slice(input, value.start_offset, value.end_offset))
  .unwrap_or("")
}

///|
fn filter_primitive_source_is_opaque(source : FilterPrimitiveSource?) -> Bool {
  source
  .map(value => value.kind != "feOffset" || value.offset_index is None)
  .unwrap_or(false)
}

///|
fn filter_report_diagnostic_ids(
  report : StructuredReport,
  subjects : Array[String],
) -> Array[String] {
  let ids : Array[String] = []
  for diagnostic in report.diagnostics {
    if diagnostic.code.has_prefix("filter_") &&
      subjects.any(subject => {
        diagnostic.subject_id == subject ||
        diagnostic.subject_id.has_prefix("\{subject}:")
      }) {
      push_unique(ids, diagnostic.id)
    }
  }
  ids.sort()
  ids
}

///|
fn filter_rendered_evidence(
  before_svg : String,
  after_svg : String,
  profile : ComparisonProfile,
) -> RenderedEvidence {
  match
    (
      render_product_source_to_image(before_svg, profile),
      render_product_source_to_image(after_svg, profile),
    ) {
    (Some(before), Some(after)) =>
      computed_rendered_evidence(rendered_image_difference(before, after))
    _ => not_computed_rendered_evidence("filter_renderer_unavailable")
  }
}

///|
fn filter_resource_event_complete(
  before_resource : FilterResource?,
  after_resource : FilterResource?,
  before_hosts : Array[ResolvedFilterHost],
  after_hosts : Array[ResolvedFilterHost],
  resource_id : String,
  diagnostic_ids : Array[String],
) -> Bool {
  if !diagnostic_ids.is_empty() ||
    before_resource.map(value => !value.complete).unwrap_or(false) ||
    after_resource.map(value => !value.complete).unwrap_or(false) {
    return false
  }
  for host in before_hosts + after_hosts {
    if host.resource_id == Some(resource_id) && !host.complete {
      return false
    }
  }
  true
}

///|
fn filter_owner_event_complete(
  before_hosts : Array[ResolvedFilterHost],
  after_hosts : Array[ResolvedFilterHost],
  owner_id : String,
  diagnostic_ids : Array[String],
) -> Bool {
  if !diagnostic_ids.is_empty() {
    return false
  }
  for host in before_hosts + after_hosts {
    if host.owner_id == owner_id && !host.complete {
      return false
    }
  }
  true
}

///|
fn append_filter_report_difference(
  changed_facts : Array[ChangedFact],
  differences : Array[AtomicDifference],
  difference_ids : Array[String],
  fact_id : String,
  difference_id : String,
  subject_id : String,
  subject_role : String,
  property : String,
  domain : String,
  before_fact : DeclaredVisualFact?,
  after_fact : DeclaredVisualFact?,
  before_value : String,
  after_value : String,
  affected_subject_ids : Array[String],
  diagnostic_ids : Array[String],
  number_before : Double?,
  number_after : Double?,
) -> Unit {
  let complete = diagnostic_ids.is_empty()
  changed_facts.push({
    id: fact_id,
    subject_id,
    property,
    before: before_fact,
    after: after_fact,
    affected_subject_ids,
  })
  let magnitude = match (number_before, number_after) {
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
  differences.push({
    id: difference_id,
    subject_role,
    subject_alignment_id: None,
    domain,
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
          "same_resolved_filter_fact"
        } else {
          "resolved_filter_facts_differ"
        },
        missing_side: match (before_fact, after_fact) {
          (None, Some(_)) => Some("before")
          (Some(_), None) => Some("after")
          _ => None
        },
        diagnostic_ids: [],
      }
    } else {
      {
        status: "indeterminate",
        reason_code: "filter_coverage_partial",
        missing_side: None,
        diagnostic_ids,
      }
    },
    parameter_delta_css_px: None,
    presence_magnitude: None,
    magnitude,
    domain_ordering: empty_domain_ordering(),
  })
  difference_ids.push(difference_id)
}

///|
pub fn attach_filter_differences(
  report : StructuredReport,
  before_svg : String,
  after_svg : String,
) -> StructuredReport {
  let before = try
    resolve_filter_hosts_or_raise(before_svg, report.profile)
  catch {
    _ => return report
  } noraise {
    value => value
  }
  let after = try
    resolve_filter_hosts_or_raise(after_svg, report.profile)
  catch {
    _ => return report
  } noraise {
    value => value
  }
  if before.0.resources.is_empty() &&
    after.0.resources.is_empty() &&
    filter_host_attachments(before.0).is_empty() &&
    filter_host_attachments(after.0).is_empty() {
    return report
  }
  let changed_facts = report.changed_facts.copy()
  let differences = report.atomic_differences.copy()
  let events = report.events.copy()
  let rendered = filter_rendered_evidence(before_svg, after_svg, report.profile)
  for key in filter_resource_keys(before.0, after.0) {
    let before_resource = filter_resource_for_key(before.0, key)
    let after_resource = filter_resource_for_key(after.0, key)
    let affected = filter_affected_hosts(before.1, after.1, key)
    let event_diagnostics = filter_report_diagnostic_ids(
      report,
      [
        before_resource.map(value => value.subject_id).unwrap_or(key),
        after_resource.map(value => value.subject_id).unwrap_or(key),
        ..affected,
      ],
    )
    let difference_ids : Array[String] = []
    match (before_resource, after_resource) {
      (Some(left), Some(right)) => {
        let diagnostics = filter_report_diagnostic_ids(
          report,
          [left.subject_id, right.subject_id, ..affected],
        )
        for
          property in [
            "filterUnits", "primitiveUnits", "region-x", "region-y", "region-width",
            "region-height",
          ] {
          let left_fact = filter_resource_property_fact(left, property)
          let right_fact = filter_resource_property_fact(right, property)
          if declared_fact_changed(left_fact, right_fact) {
            append_filter_report_difference(
              changed_facts,
              differences,
              difference_ids,
              "fact:filter:\{key}:\{property}",
              "diff:filter:\{key}:\{property}",
              left.subject_id,
              "resource",
              property,
              if property == "filterUnits" || property == "primitiveUnits" {
                "resource.filter.units"
              } else {
                "resource.filter.region"
              },
              left_fact,
              right_fact,
              filter_resource_property_value(left, property),
              filter_resource_property_value(right, property),
              affected,
              diagnostics,
              filter_resource_property_number(left, property),
              filter_resource_property_number(right, property),
            )
          }
        }
        let primitive_count = left.primitive_sources
          .length()
          .max(right.primitive_sources.length())
        for position in 0..<primitive_count {
          let left_source = left.primitive_sources.get(position)
          let right_source = right.primitive_sources.get(position)
          if filter_primitive_source_is_opaque(left_source) ||
            filter_primitive_source_is_opaque(right_source) {
            let left_fact = filter_primitive_source_fact(
              before_svg, left_source,
            )
            let right_fact = filter_primitive_source_fact(
              after_svg, right_source,
            )
            if declared_fact_changed(left_fact, right_fact) {
              let source = match (left_source, right_source) {
                (Some(value), _) | (_, Some(value)) => value
                _ => abort("unreachable empty filter primitive source pair")
              }
              append_filter_report_difference(
                changed_facts,
                differences,
                difference_ids,
                "fact:filter:\{key}:primitive:\{source.position}:source",
                "diff:filter:\{key}:primitive:\{source.position}:source",
                source.subject_id,
                "resource",
                "primitive-source",
                "resource.filter.primitive.source",
                left_fact,
                right_fact,
                filter_primitive_source_value(before_svg, left_source),
                filter_primitive_source_value(after_svg, right_source),
                affected,
                diagnostics,
                None,
                None,
              )
            }
            continue
          }
          let left_primitive = filter_offset_for_source(left, left_source)
          let right_primitive = filter_offset_for_source(right, right_source)
          match (left_primitive, right_primitive) {
            (Some(left_primitive), Some(right_primitive)) =>
              for property in ["in", "result", "dx", "dy"] {
                let left_fact = filter_primitive_fact(left_primitive, property)
                let right_fact = filter_primitive_fact(
                  right_primitive, property,
                )
                if declared_fact_changed(left_fact, right_fact) {
                  append_filter_report_difference(
                    changed_facts,
                    differences,
                    difference_ids,
                    "fact:filter:\{key}:primitive:\{position}:\{property}",
                    "diff:filter:\{key}:primitive:\{position}:\{property}",
                    left_primitive.subject_id,
                    "resource",
                    property,
                    if property == "dx" || property == "dy" {
                      "resource.filter.primitive.offset"
                    } else {
                      "resource.filter.primitive.graph"
                    },
                    left_fact,
                    right_fact,
                    filter_primitive_value(left_primitive, property),
                    filter_primitive_value(right_primitive, property),
                    affected,
                    diagnostics,
                    if property == "dx" {
                      Some(left_primitive.dx)
                    } else if property == "dy" {
                      Some(left_primitive.dy)
                    } else {
                      None
                    },
                    if property == "dx" {
                      Some(right_primitive.dx)
                    } else if property == "dy" {
                      Some(right_primitive.dy)
                    } else {
                      None
                    },
                  )
                }
              }
            (left_primitive, right_primitive) => {
              let primitive = match (left_primitive, right_primitive) {
                (Some(value), _) | (_, Some(value)) => value
                _ => abort("unreachable empty filter primitive pair")
              }
              append_filter_report_difference(
                changed_facts,
                differences,
                difference_ids,
                "fact:filter:\{key}:primitive:\{position}:presence",
                "diff:filter:\{key}:primitive:\{position}:presence",
                primitive.subject_id,
                "resource",
                "presence",
                "resource.filter.primitive.presence",
                left_primitive.map(value => value.presence_fact),
                right_primitive.map(value => value.presence_fact),
                if left_primitive is Some(_) {
                  "feOffset"
                } else {
                  ""
                },
                if right_primitive is Some(_) {
                  "feOffset"
                } else {
                  ""
                },
                affected,
                diagnostics,
                None,
                None,
              )
            }
          }
        }
      }
      (left, right) => {
        let resource = match (left, right) {
          (Some(value), _) | (_, Some(value)) => value
          _ => abort("unreachable empty filter resource pair")
        }
        append_filter_report_difference(
          changed_facts,
          differences,
          difference_ids,
          "fact:filter:\{key}:presence",
          "diff:filter:\{key}:presence",
          resource.subject_id,
          "resource",
          "presence",
          "resource.filter.presence",
          left.map(value => value.presence_fact),
          right.map(value => value.presence_fact),
          if left is Some(_) {
            "filter"
          } else {
            ""
          },
          if right is Some(_) {
            "filter"
          } else {
            ""
          },
          affected,
          filter_report_diagnostic_ids(
            report,
            [resource.subject_id, ..affected],
          ),
          None,
          None,
        )
        let diagnostics = filter_report_diagnostic_ids(
          report,
          [resource.subject_id, ..affected],
        )
        for source in resource.primitive_sources {
          guard filter_primitive_source_is_opaque(Some(source)) else {
            continue
          }
          let left_source = if left is Some(_) { Some(source) } else { None }
          let right_source = if right is Some(_) { Some(source) } else { None }
          append_filter_report_difference(
            changed_facts,
            differences,
            difference_ids,
            "fact:filter:\{key}:primitive:\{source.position}:source",
            "diff:filter:\{key}:primitive:\{source.position}:source",
            source.subject_id,
            "resource",
            "primitive-source",
            "resource.filter.primitive.source",
            filter_primitive_source_fact(before_svg, left_source),
            filter_primitive_source_fact(after_svg, right_source),
            filter_primitive_source_value(before_svg, left_source),
            filter_primitive_source_value(after_svg, right_source),
            affected,
            diagnostics,
            None,
            None,
          )
        }
      }
    }
    if !difference_ids.is_empty() {
      events.push({
        id: "event:filter:\{key}",
        primary_subject_id: key,
        atomic_difference_ids: difference_ids,
        rendered_outcome: if filter_resource_event_complete(
            before_resource,
            after_resource,
            before.1,
            after.1,
            key,
            event_diagnostics,
          ) {
          rendered
        } else {
          not_computed_rendered_evidence(
            "filter_resource_rendered_evidence_unavailable",
          )
        },
        difference_regions: [],
      })
    }
  }
  let before_attachments = filter_host_attachments(before.0)
  let after_attachments = filter_host_attachments(after.0)
  let owner_ids : Array[String] = []
  for attachment in before_attachments + after_attachments {
    push_unique(owner_ids, attachment.owner_id)
  }
  owner_ids.sort()
  for owner_id in owner_ids {
    let left = filter_attachment_for_owner(before_attachments, owner_id)
    let right = filter_attachment_for_owner(after_attachments, owner_id)
    let left_fact = left.map(value => value.fact)
    let right_fact = right.map(value => value.fact)
    if !declared_fact_changed(left_fact, right_fact) {
      continue
    }
    let difference_ids : Array[String] = []
    let owner_diagnostics = filter_report_diagnostic_ids(report, [owner_id])
    append_filter_report_difference(
      changed_facts,
      differences,
      difference_ids,
      "fact:filter-host:\{owner_id}:filter",
      "diff:filter-host:\{owner_id}:filter",
      owner_id,
      "entity",
      "filter",
      "filtering.attachment",
      left_fact,
      right_fact,
      filter_attachment_effect_value(left, before.1),
      filter_attachment_effect_value(right, after.1),
      [owner_id],
      owner_diagnostics,
      None,
      None,
    )
    events.push({
      id: "event:filter-host:\{owner_id}",
      primary_subject_id: owner_id,
      atomic_difference_ids: difference_ids,
      rendered_outcome: if filter_owner_event_complete(
          before.1,
          after.1,
          owner_id,
          owner_diagnostics,
        ) {
        rendered
      } else {
        not_computed_rendered_evidence(
          "filter_host_rendered_evidence_unavailable",
        )
      },
      difference_regions: [],
    })
  }
  { ..report, changed_facts, atomic_differences: differences, events }
}
