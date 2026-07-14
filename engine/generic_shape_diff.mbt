///|
fn source_subject_fact(
  subject : SourceSubject,
  property : String,
) -> DeclaredVisualFact? {
  declared_fact_in_array(subject.facts, property)
}

///|
fn source_subject_id(subject : SourceSubject) -> String {
  subject.reference.authored_id.unwrap_or(
    "\{subject.kind}:\{subject.reference.source_index}",
  )
}

///|
fn generic_property_domain(property : String) -> String {
  match property {
    "x" | "y" | "cx" | "cy" | "x1" | "y1" | "x2" | "y2" | "points" =>
      "geometry.position"
    "width" | "height" | "rx" | "ry" | "r" => "geometry.size"
    "fill" => "paint.fill"
    "stroke" => "paint.stroke"
    "stroke-width" => "paint.stroke_width"
    "opacity" => "paint.opacity"
    _ => "document.unsupported"
  }
}

///|
fn generic_default_value(property : String) -> String? {
  match property {
    "x"
    | "y"
    | "cx"
    | "cy"
    | "x1"
    | "y1"
    | "x2"
    | "y2"
    | "width"
    | "height"
    | "rx"
    | "ry"
    | "r" => Some("0")
    "fill" => Some("black")
    "stroke" => Some("none")
    "stroke-width" | "opacity" => Some("1")
    _ => None
  }
}

///|
fn generic_computed_value(
  property : String,
  fact : DeclaredVisualFact?,
) -> String? {
  match fact {
    Some(fact) => {
      let value = fact.declared_value.trim().to_owned().to_lower()
      match (property, value) {
        ("fill" | "stroke", "red" | "#f00" | "#ff0000") => Some("#ff0000")
        ("fill" | "stroke", "blue" | "#00f" | "#0000ff") => Some("#0000ff")
        ("fill" | "stroke", "black" | "#000" | "#000000") => Some("#000000")
        _ => Some(value)
      }
    }
    None => generic_default_value(property)
  }
}

///|
fn generic_relation(
  property : String,
  before : DeclaredVisualFact?,
  after : DeclaredVisualFact?,
) -> ComputedRelation {
  let before_value = generic_computed_value(property, before)
  let after_value = generic_computed_value(property, after)
  match (before_value, after_value) {
    (Some(before_value), Some(after_value)) => {
      let equivalent = match
        (
          parse_alignment_number(Some(before_value)),
          parse_alignment_number(Some(after_value)),
        ) {
        (Some(before_number), Some(after_number)) =>
          before_number == after_number
        _ => before_value == after_value
      }
      {
        status: if equivalent {
          "equivalent"
        } else {
          "different"
        },
        reason_code: if equivalent {
          "same_resolved_fact"
        } else {
          "resolved_facts_differ"
        },
        missing_side: None,
        diagnostic_ids: [],
      }
    }
    (None, Some(_)) =>
      {
        status: "not_applicable",
        reason_code: "before_fact_absent",
        missing_side: Some("before"),
        diagnostic_ids: [],
      }
    (Some(_), None) =>
      {
        status: "not_applicable",
        reason_code: "after_fact_absent",
        missing_side: Some("after"),
        diagnostic_ids: [],
      }
    _ =>
      {
        status: "equivalent",
        reason_code: "both_facts_absent",
        missing_side: None,
        diagnostic_ids: [],
      }
  }
}

///|
fn generic_parameter_delta(
  before : DeclaredVisualFact?,
  after : DeclaredVisualFact?,
) -> Double? {
  match
    (generic_computed_value("", before), generic_computed_value("", after)) {
    (Some(before_value), Some(after_value)) =>
      match
        (
          parse_alignment_number(Some(before_value)),
          parse_alignment_number(Some(after_value)),
        ) {
        (Some(before_number), Some(after_number)) =>
          Some(after_number - before_number)
        _ => None
      }
    _ => None
  }
}

///|
fn alignment_subject_ids(
  before : Array[SourceSubject],
  after : Array[SourceSubject],
) -> Array[String] {
  let ids : Array[String] = []
  for subject in before {
    let id = source_subject_id(subject)
    if !ids.contains(id) {
      ids.push(id)
    }
  }
  for subject in after {
    let id = source_subject_id(subject)
    if !ids.contains(id) {
      ids.push(id)
    }
  }
  ids
}

///|
fn subjects_for_references(
  subjects : Array[SourceSubject],
  references : Array[SubjectReference],
) -> Array[SourceSubject] {
  let selected : Array[SourceSubject] = []
  for reference in references {
    match subjects.get(reference.source_index) {
      Some(subject) if subject.kind == reference.kind => selected.push(subject)
      None => ()
      _ => ()
    }
  }
  selected
}

///|
fn generic_basic_shape_report(
  before_svg : String,
  after_svg : String,
  before_document : @svg.SVGDocument,
  after_document : @svg.SVGDocument,
  profile : ComparisonProfile,
  alignments : Array[SubjectAlignment],
) -> StructuredReport? {
  let before = extract_source_subjects_or_raise(before_svg) catch {
    _ => return None
  }
  let after = extract_source_subjects_or_raise(after_svg) catch {
    _ => return None
  }
  let needs_generic = before.length() > 1 ||
    after.length() > 1 ||
    before.any(subject => subject.kind != "rect") ||
    after.any(subject => subject.kind != "rect")
  if !needs_generic {
    return None
  }
  let changed_facts : Array[ChangedFact] = []
  let differences : Array[AtomicDifference] = []
  let events : Array[VisualEvent] = []
  let rendered = rendered_difference(before_document, after_document, profile)
  for alignment in alignments {
    let before_subjects = subjects_for_references(before, alignment.before)
    let after_subjects = subjects_for_references(after, alignment.after)
    let alignment_difference_ids : Array[String] = []
    match (before_subjects, after_subjects) {
      ([before_subject], [after_subject]) =>
        for property in alignment_property_order() {
          let before_fact = source_subject_fact(before_subject, property)
          let after_fact = source_subject_fact(after_subject, property)
          if !declared_fact_changed(before_fact, after_fact) {
            continue
          }
          let fact_id = "fact:\{alignment.id}:\{property}"
          let difference_id = "diff:\{alignment.id}:\{property}"
          let relation = generic_relation(property, before_fact, after_fact)
          changed_facts.push({
            id: fact_id,
            subject_id: alignment.id,
            property,
            before: before_fact,
            after: after_fact,
            affected_subject_ids: alignment_subject_ids([before_subject], [
              after_subject,
            ]),
          })
          let evidence_layers : Array[String] = ["source_semantics"]
          if relation.status == "different" {
            evidence_layers.push("computed_appearance")
          }
          if rendered.changed_pixels > 0 {
            evidence_layers.push("rendered_evidence")
          }
          differences.push({
            id: difference_id,
            subject_role: "entity",
            subject_alignment_id: Some(alignment.id),
            domain: generic_property_domain(property),
            source_before: declared_value_or_empty(before_fact),
            source_after: declared_value_or_empty(after_fact),
            source_fact_before: before_fact,
            source_fact_after: after_fact,
            changed_fact_ids: [fact_id],
            evidence_layers,
            computed_relation: relation,
            parameter_delta_css_px: generic_parameter_delta(
              before_fact, after_fact,
            ),
            presence_magnitude: None,
            magnitude: empty_difference_magnitude(),
            domain_ordering: empty_domain_ordering(),
          })
          alignment_difference_ids.push(difference_id)
        }
      ([], [_]) | ([_], []) => {
        let property = "presence"
        let fact_id = "fact:\{alignment.id}:presence"
        let difference_id = "diff:\{alignment.id}:presence"
        changed_facts.push({
          id: fact_id,
          subject_id: alignment.id,
          property,
          before: None,
          after: None,
          affected_subject_ids: alignment_subject_ids(
            before_subjects, after_subjects,
          ),
        })
        let insertion = before_subjects.is_empty()
        differences.push({
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
          source_fact_before: None,
          source_fact_after: None,
          changed_fact_ids: [fact_id],
          evidence_layers: [
            "source_semantics", "computed_appearance", "rendered_evidence",
          ],
          computed_relation: {
            status: "not_applicable",
            reason_code: if insertion {
              "before_fact_absent"
            } else {
              "after_fact_absent"
            },
            missing_side: Some(if insertion { "before" } else { "after" }),
            diagnostic_ids: [],
          },
          parameter_delta_css_px: None,
          presence_magnitude: None,
          magnitude: empty_difference_magnitude(),
          domain_ordering: empty_domain_ordering(),
        })
        alignment_difference_ids.push(difference_id)
      }
      _ => {
        let fact_id = "fact:\{alignment.id}:structure"
        let difference_id = "diff:\{alignment.id}:structure"
        changed_facts.push({
          id: fact_id,
          subject_id: alignment.id,
          property: "structure",
          before: None,
          after: None,
          affected_subject_ids: alignment_subject_ids(
            before_subjects, after_subjects,
          ),
        })
        differences.push({
          id: difference_id,
          subject_role: "entity",
          subject_alignment_id: Some(alignment.id),
          domain: "document.structure",
          source_before: "\{before_subjects.length()} subjects",
          source_after: "\{after_subjects.length()} subjects",
          source_fact_before: None,
          source_fact_after: None,
          changed_fact_ids: [fact_id],
          evidence_layers: ["source_semantics", "computed_appearance"],
          computed_relation: {
            status: "equivalent",
            reason_code: alignment.basis,
            missing_side: None,
            diagnostic_ids: [],
          },
          parameter_delta_css_px: None,
          presence_magnitude: None,
          magnitude: empty_difference_magnitude(),
          domain_ordering: empty_domain_ordering(),
        })
        alignment_difference_ids.push(difference_id)
      }
    }
    if !alignment_difference_ids.is_empty() {
      events.push({
        id: "event:\{alignment.id}",
        primary_subject_id: alignment.id,
        atomic_difference_ids: alignment_difference_ids,
        rendered_outcome: computed_rendered_evidence(rendered),
        difference_regions: [],
      })
    }
  }
  Some({
    schema_version: "1.1",
    analysis_status: "complete",
    coverage_matrix: [],
    renderer_capability_gaps: [],
    profile,
    subject_alignments: alignments,
    changed_facts,
    source_resolutions: [],
    atomic_differences: differences,
    events,
    diagnostics: [],
  })
}
