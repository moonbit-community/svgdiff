///|
priv struct OpacityGroup {
  subject_id : String
  source_index : Int
  kind : String
  fact : DeclaredVisualFact?
}

///|
fn opacity_groups_or_raise(input : String) -> Array[OpacityGroup] raise {
  let groups : Array[OpacityGroup] = []
  let reader = @xml.NamespaceReader::from_string(input)
  for event in reader.read_events_until_eof() {
    match event.kind {
      Start(element) | Empty(element) if element.name.local_name == "g" ||
        element.name.local_name == "svg" => {
        let kind = element.name.local_name
        let mut subject_id = if kind == "svg" {
          "svg"
        } else {
          "g:\{groups.length()}"
        }
        let mut fact : DeclaredVisualFact? = None
        let mut style_attribute : @xml.NamespaceAttribute? = None
        for attribute in element.attributes {
          match attribute.name.local_name {
            "id" if attribute.value.trim() != "" =>
              subject_id = attribute.value.trim().to_owned()
            "opacity" =>
              fact = Some(presentation_fact(input, "opacity", attribute))
            "style" => style_attribute = Some(attribute)
            _ => ()
          }
        }
        match style_attribute {
          Some(attribute) => {
            let style = inline_style_facts(input, attribute)
            match declared_fact_in_array(style.facts, "opacity") {
              Some(style_fact) => fact = Some(style_fact)
              None => ()
            }
          }
          None => ()
        }
        groups.push({ subject_id, source_index: groups.length(), kind, fact })
      }
      _ => ()
    }
  }
  groups
}

///|
fn attach_group_opacity_differences(
  report : StructuredReport,
  before_svg : String,
  after_svg : String,
) -> (StructuredReport, Array[SubjectAlignment]) {
  let before = opacity_groups_or_raise(before_svg) catch {
    _ => return (report, [])
  }
  let after = opacity_groups_or_raise(after_svg) catch {
    _ => return (report, [])
  }
  let after_used = Array::make(after.length(), false)
  let changed_facts = report.changed_facts.copy()
  let differences = report.atomic_differences.copy()
  let events = report.events.copy()
  let extra_alignments : Array[SubjectAlignment] = []
  for before_group in before {
    let mut after_index = -1
    for index, after_group in after {
      if !after_used[index] && before_group.subject_id == after_group.subject_id {
        after_index = index
        break
      }
    }
    if after_index < 0 && before.length() == 1 && after.length() == 1 {
      after_index = 0
    }
    if after_index < 0 {
      continue
    }
    after_used[after_index] = true
    let after_group = after[after_index]
    if !declared_fact_changed(before_group.fact, after_group.fact) {
      continue
    }
    let alignment_id = "alignment:group-opacity:\{extra_alignments.length()}"
    let fact_id = "fact:\{alignment_id}:opacity"
    let difference_id = "diff:\{alignment_id}:opacity"
    let diagnostic_id = "diagnostic:group-opacity-compositing-unsupported:\{before_group.subject_id}"
    extra_alignments.push({
      id: alignment_id,
      relation: "correspondence",
      before: [
        {
          source_index: before_group.source_index,
          kind: before_group.kind,
          authored_id: Some(before_group.subject_id),
        },
      ],
      after: [
        {
          source_index: after_group.source_index,
          kind: after_group.kind,
          authored_id: Some(after_group.subject_id),
        },
      ],
      basis: "group_identity_or_singleton",
    })
    changed_facts.push({
      id: fact_id,
      subject_id: before_group.subject_id,
      property: "opacity",
      before: before_group.fact,
      after: after_group.fact,
      affected_subject_ids: [before_group.subject_id],
    })
    differences.push({
      id: difference_id,
      subject_role: "entity",
      subject_alignment_id: Some(alignment_id),
      domain: "compositing.opacity",
      source_before: declared_value_or_empty(before_group.fact),
      source_after: declared_value_or_empty(after_group.fact),
      source_fact_before: before_group.fact,
      source_fact_after: after_group.fact,
      changed_fact_ids: [fact_id],
      evidence_layers: ["source_semantics"],
      computed_relation: {
        status: "indeterminate",
        reason_code: "group_opacity_compositing_unsupported",
        missing_side: None,
        diagnostic_ids: [diagnostic_id],
      },
      parameter_delta_css_px: None,
      presence_magnitude: None,
      magnitude: empty_difference_magnitude(),
      domain_ordering: empty_domain_ordering(),
    })
    events.push({
      id: "event:\{alignment_id}",
      primary_subject_id: alignment_id,
      atomic_difference_ids: [difference_id],
      rendered_outcome: not_computed_rendered_evidence(
        "group_opacity_compositing_unsupported",
      ),
      difference_regions: [],
    })
  }
  (
    { ..report, changed_facts, atomic_differences: differences, events },
    extra_alignments,
  )
}
