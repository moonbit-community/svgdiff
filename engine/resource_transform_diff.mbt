///|
fn resource_transform_pairs(
  before : Array[ResourceTransformSubject],
  after : Array[ResourceTransformSubject],
) -> Array[(ResourceTransformSubject, ResourceTransformSubject)] {
  let pairs : Array[(ResourceTransformSubject, ResourceTransformSubject)] = []
  let used = Array::make(after.length(), false)
  for before_resource in before {
    let mut selected = -1
    if before_resource.authored_id is Some(_) {
      for index, after_resource in after {
        if !used[index] &&
          before_resource.kind == after_resource.kind &&
          before_resource.authored_id == after_resource.authored_id {
          selected = index
          break
        }
      }
    }
    if selected < 0 {
      for index, after_resource in after {
        if !used[index] && before_resource.kind == after_resource.kind {
          selected = index
          break
        }
      }
    }
    if selected >= 0 {
      used[selected] = true
      pairs.push((before_resource, after[selected]))
    }
  }
  pairs
}

///|
fn resource_transform_declaration_changed(
  before : ResourceTransformSubject,
  after : ResourceTransformSubject,
) -> Bool {
  match (before.fact, after.fact) {
    (None, None) => false
    (Some(_), None) | (None, Some(_)) => true
    (Some(before_fact), Some(after_fact)) =>
      if before.complete && after.complete {
        before.normalized_signature != after.normalized_signature
      } else {
        before_fact.declared_value != after_fact.declared_value
      }
  }
}

///|
fn resource_transform_diagnostic_ids(
  report : StructuredReport,
  subject_id : String,
  kind : String,
) -> Array[String] {
  [
    for diagnostic in report.diagnostics if (
      diagnostic.subject_id == subject_id || diagnostic.subject_id == kind
    ) &&
    (
      diagnostic.code == "resource_transform_semantics_unsupported" ||
      diagnostic.code == "transform_syntax_unsupported"
    ) => diagnostic.id
  ]
}

///|
fn resource_transform_event_evidence() -> RenderedEvidence {
  {
    status: "not_computed",
    reason_code: Some("resource_transform_semantics_unsupported"),
    magnitude: None,
  }
}

///|
fn attach_resource_transform_differences(
  report : StructuredReport,
  before_svg : String,
  after_svg : String,
) -> StructuredReport {
  let before = extract_resource_transforms_or_raise(before_svg) catch {
    _ => return report
  }
  let after = extract_resource_transforms_or_raise(after_svg) catch {
    _ => return report
  }
  let changed_facts = report.changed_facts.copy()
  let differences = report.atomic_differences.copy()
  let events = report.events.copy()
  for pair in resource_transform_pairs(before, after) {
    let (before_resource, after_resource) = pair
    if before_resource.kind == "linearGradient" ||
      before_resource.kind == "radialGradient" {
      continue
    }
    if !resource_transform_declaration_changed(before_resource, after_resource) {
      continue
    }
    let fact_id = "fact:resource-transform:\{before_resource.node_index}:\{after_resource.node_index}:\{before_resource.property}"
    changed_facts.push({
      id: fact_id,
      subject_id: before_resource.subject_id,
      property: before_resource.property,
      before: before_resource.fact,
      after: after_resource.fact,
      affected_subject_ids: [before_resource.subject_id],
    })
    let diagnostic_ids = resource_transform_diagnostic_ids(
      report,
      before_resource.subject_id,
      before_resource.kind,
    )
    let list_id = "diff:resource-transform:\{before_resource.node_index}:\{after_resource.node_index}:list"
    let relation = if !before_resource.complete || !after_resource.complete {
      {
        status: "indeterminate",
        reason_code: "transform_syntax_unsupported",
        missing_side: None,
        diagnostic_ids,
      }
    } else if before_resource.matrix == after_resource.matrix {
      {
        status: "equivalent",
        reason_code: "same_resource_transform_matrix",
        missing_side: None,
        diagnostic_ids,
      }
    } else {
      {
        status: "different",
        reason_code: "resource_transform_matrices_differ",
        missing_side: None,
        diagnostic_ids,
      }
    }
    differences.push({
      id: list_id,
      subject_role: "resource",
      subject_alignment_id: None,
      domain: "resource.transform.list",
      source_before: declared_value_or_empty(before_resource.fact),
      source_after: declared_value_or_empty(after_resource.fact),
      source_fact_before: before_resource.fact,
      source_fact_after: after_resource.fact,
      changed_fact_ids: [fact_id],
      evidence_layers: if relation.status == "indeterminate" {
        ["source_semantics"]
      } else {
        ["source_semantics", "computed_appearance"]
      },
      computed_relation: relation,
      parameter_delta_css_px: None,
      presence_magnitude: None,
      magnitude: empty_difference_magnitude(),
      domain_ordering: empty_domain_ordering(),
    })
    let difference_ids = [list_id]
    if before_resource.complete &&
      after_resource.complete &&
      before_resource.matrix != after_resource.matrix {
      let matrix_id = "diff:resource-transform:\{before_resource.node_index}:\{after_resource.node_index}:matrix"
      differences.push({
        id: matrix_id,
        subject_role: "resource",
        subject_alignment_id: None,
        domain: "resource.transform.matrix",
        source_before: before_resource.matrix.signature(),
        source_after: after_resource.matrix.signature(),
        source_fact_before: None,
        source_fact_after: None,
        changed_fact_ids: [fact_id],
        evidence_layers: ["computed_appearance"],
        computed_relation: {
          status: "different",
          reason_code: "resource_transform_matrices_differ",
          missing_side: None,
          diagnostic_ids,
        },
        parameter_delta_css_px: None,
        presence_magnitude: None,
        magnitude: empty_difference_magnitude(),
        domain_ordering: empty_domain_ordering(),
      })
      difference_ids.push(matrix_id)
    }
    events.push({
      id: "event:resource-transform:\{before_resource.node_index}:\{after_resource.node_index}",
      primary_subject_id: before_resource.subject_id,
      atomic_difference_ids: difference_ids,
      rendered_outcome: resource_transform_event_evidence(),
      difference_regions: [],
    })
  }
  { ..report, changed_facts, atomic_differences: differences, events }
}
