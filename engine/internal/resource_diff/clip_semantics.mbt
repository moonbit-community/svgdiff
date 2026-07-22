///|
fn clip_resource_pair_keys(
  before : ClipSemanticDocument,
  after : ClipSemanticDocument,
) -> Array[String] {
  let keys : Array[String] = []
  for resource in before.resources + after.resources {
    push_unique(keys, resource.authored_id.unwrap_or(resource.subject_id))
  }
  keys.sort()
  keys
}

///|
fn clip_resource_for_key(
  document : ClipSemanticDocument,
  key : String,
) -> ClipRectResource? {
  for resource in document.resources {
    if resource.authored_id.unwrap_or(resource.subject_id) == key {
      return Some(resource)
    }
  }
  None
}

///|
fn clip_resource_fact(
  resource : ClipRectResource,
  property : String,
) -> DeclaredVisualFact? {
  match property {
    "clipPathUnits" => resource.units_fact
    "transform" => resource.transform_fact
    "child-transform" => resource.rect_transform_fact
    _ => shape_fact(resource.rect_facts, property)
  }
}

///|
fn clip_resource_computed(
  resource : ClipRectResource,
  property : String,
) -> String {
  match property {
    "clipPathUnits" => resource.units
    "transform" => resource.transform.signature()
    "child-transform" => resource.rect_transform.signature()
    "clip-rule" => "simple-rect"
    "x" =>
      resource.rect_bounds.map(bounds => bounds.x.to_string()).unwrap_or("")
    "y" =>
      resource.rect_bounds.map(bounds => bounds.y.to_string()).unwrap_or("")
    "width" =>
      resource.rect_bounds.map(bounds => bounds.width.to_string()).unwrap_or("")
    "height" =>
      resource.rect_bounds
      .map(bounds => bounds.height.to_string())
      .unwrap_or("")
    "rx" | "ry" => "0"
    _ => ""
  }
}

///|
fn clip_resource_number(
  resource : ClipRectResource,
  property : String,
) -> Double? {
  guard resource.rect_bounds is Some(bounds) else { return None }
  match property {
    "x" => Some(bounds.x)
    "y" => Some(bounds.y)
    "width" => Some(bounds.width)
    "height" => Some(bounds.height)
    "rx" | "ry" => Some(0.0)
    _ => None
  }
}

///|
fn clip_resource_magnitude(
  before : ClipRectResource,
  after : ClipRectResource,
  property : String,
) -> DifferenceMagnitude {
  match
    (
      clip_resource_number(before, property),
      clip_resource_number(after, property),
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
fn clip_resource_affected_subjects(
  before : Array[SourceSubject],
  after : Array[SourceSubject],
  key : String,
) -> Array[String] {
  let ids : Array[String] = []
  for subject in before + after {
    if subject.clip_resource_id == Some(key) {
      push_unique(ids, source_subject_id(subject))
    }
  }
  ids.sort()
  ids
}

///|
fn clip_rendered_evidence(
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
    _ => not_computed_rendered_evidence("clip_path_renderer_unavailable")
  }
}

///|
fn clip_resource_diagnostic_ids(
  report : StructuredReport,
  subject_ids : Array[String],
) -> Array[String] {
  let ids : Array[String] = []
  for diagnostic in report.diagnostics {
    if subject_ids.contains(diagnostic.subject_id) &&
      diagnostic.code.has_prefix("clip_path_") {
      push_unique(ids, diagnostic.id)
    }
  }
  ids.sort()
  ids
}

///|
pub fn attach_clip_path_differences(
  report : StructuredReport,
  before_svg : String,
  after_svg : String,
) -> StructuredReport {
  let before_document = extract_clip_semantic_document_or_raise(
    before_svg,
    report.profile,
  ) catch {
    _ => return report
  }
  let after_document = extract_clip_semantic_document_or_raise(
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
  let rendered = clip_rendered_evidence(before_svg, after_svg, report.profile)
  for key in clip_resource_pair_keys(before_document, after_document) {
    match
      (
        clip_resource_for_key(before_document, key),
        clip_resource_for_key(after_document, key),
      ) {
      (Some(before), Some(after)) => {
        let difference_ids : Array[String] = []
        let affected_subject_ids = clip_resource_affected_subjects(
          before_subjects, after_subjects, key,
        )
        for
          property in [
            "clipPathUnits", "transform", "x", "y", "width", "height", "rx", "ry",
            "child-transform", "clip-rule",
          ] {
          let before_fact = clip_resource_fact(before, property)
          let after_fact = clip_resource_fact(after, property)
          if !declared_fact_changed(before_fact, after_fact) {
            continue
          }
          let fact_id = "fact:clip:\{key}:\{property}"
          let difference_id = "diff:clip:\{key}:\{property}"
          let computed_before = clip_resource_computed(before, property)
          let computed_after = clip_resource_computed(after, property)
          let diagnostic_ids = clip_resource_diagnostic_ids(report, [
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
            domain: match property {
              "clipPathUnits" => "resource.clip.units"
              "transform" | "child-transform" => "resource.clip.transform"
              "clip-rule" => "resource.clip.rule"
              _ => "resource.clip.geometry"
            },
            source_before: declared_value_or_empty(before_fact),
            source_after: declared_value_or_empty(after_fact),
            source_fact_before: before_fact,
            source_fact_after: after_fact,
            changed_fact_ids: [fact_id],
            evidence_layers: if complete && computed_before != computed_after {
              ["source_semantics", "computed_appearance"]
            } else {
              ["source_semantics"]
            },
            computed_relation: if complete {
              {
                status: if computed_before == computed_after {
                  "equivalent"
                } else {
                  "different"
                },
                reason_code: if computed_before == computed_after {
                  "same_resolved_clip_resource"
                } else {
                  "different_resolved_clip_resource"
                },
                missing_side: None,
                diagnostic_ids: [],
              }
            } else {
              {
                status: "indeterminate",
                reason_code: "clip_resource_coverage_partial",
                missing_side: None,
                diagnostic_ids,
              }
            },
            parameter_delta_css_px: None,
            presence_magnitude: None,
            magnitude: clip_resource_magnitude(before, after, property),
            domain_ordering: empty_domain_ordering(),
          })
          difference_ids.push(difference_id)
        }
        if !difference_ids.is_empty() {
          events.push({
            id: "event:clip:\{key}",
            primary_subject_id: key,
            atomic_difference_ids: difference_ids,
            rendered_outcome: if before.complete && after.complete {
              rendered
            } else {
              not_computed_rendered_evidence(
                "clip_resource_rendered_evidence_unavailable",
              )
            },
            difference_regions: [],
          })
        }
      }
      (before, after) => {
        let insertion = before is None
        let resource = match after {
          Some(resource) => resource
          None => before.unwrap()
        }
        let affected_subject_ids = clip_resource_affected_subjects(
          before_subjects, after_subjects, key,
        )
        let fact_id = "fact:clip:\{key}:presence"
        let difference_id = "diff:clip:\{key}:presence"
        let before_fact = before.map(resource => resource.presence_fact)
        let after_fact = after.map(resource => resource.presence_fact)
        let diagnostic_ids = clip_resource_diagnostic_ids(
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
          domain: "resource.clip.presence",
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
              "unreferenced_clip_resource"
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
          id: "event:clip:\{key}",
          primary_subject_id: key,
          atomic_difference_ids: [difference_id],
          rendered_outcome: if resource.complete {
            rendered
          } else {
            not_computed_rendered_evidence(
              "clip_resource_rendered_evidence_unavailable",
            )
          },
          difference_regions: [],
        })
      }
    }
  }
  { ..report, changed_facts, atomic_differences: differences, events }
}
