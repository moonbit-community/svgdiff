///|
fn source_element_ids(hierarchy : FillHierarchy) -> Array[String] {
  [
    for element in hierarchy.elements => element.subject_id
  ]
}

///|
fn affected_entities_for_owner(
  owner_id : String,
  property : String,
  before : FillHierarchy,
  after : FillHierarchy,
) -> Array[String] {
  let rect_ids : Array[String] = []
  append_unique_subjects(rect_ids, before.rect_subject_ids)
  append_unique_subjects(rect_ids, after.rect_subject_ids)
  for element in before.elements {
    if element.kind == "stop" && !rect_ids.contains(element.subject_id) {
      rect_ids.push(element.subject_id)
    }
  }
  for element in after.elements {
    if element.kind == "stop" && !rect_ids.contains(element.subject_id) {
      rect_ids.push(element.subject_id)
    }
  }
  let affected : Array[String] = []
  for rect_id in rect_ids {
    if resolved_visual_dependency_present(before, rect_id, owner_id, property) ||
      resolved_visual_dependency_present(after, rect_id, owner_id, property) {
      affected.push(rect_id)
    }
  }
  affected
}

///|
fn resolved_visual_dependency_present(
  hierarchy : FillHierarchy,
  subject_id : String,
  owner_id : String,
  dependency_property : String,
) -> Bool {
  for property in resolved_visual_properties() {
    if property == "color" {
      continue
    }
    match computed_visual_for_subject(hierarchy, subject_id, property) {
      Some(resolution) =>
        if resolution.dependencies.any(dependency => {
            dependency.owner_id == owner_id &&
            dependency.property == dependency_property
          }) {
          return true
        }
      None => ()
    }
  }
  false
}

///|
fn hierarchy_declared_properties(hierarchy : FillHierarchy) -> Array[String] {
  let properties = resolved_visual_properties()
  for element in hierarchy.elements {
    for declaration in element.visual_declarations {
      if !properties.contains(declaration.property) {
        properties.push(declaration.property)
      }
    }
  }
  properties
}

///|
fn compare_changed_visual_facts(
  before : FillHierarchy,
  after : FillHierarchy,
) -> Array[ChangedFact] {
  let subject_ids = source_element_ids(before)
  append_unique_subjects(subject_ids, source_element_ids(after))
  let changed : Array[ChangedFact] = []
  let properties = hierarchy_declared_properties(before)
  for property in hierarchy_declared_properties(after) {
    if !properties.contains(property) {
      properties.push(property)
    }
  }
  for subject_id in subject_ids {
    for property in properties {
      let before_fact = local_property_declaration(before, subject_id, property)
      let after_fact = local_property_declaration(after, subject_id, property)
      if declared_fact_changed(before_fact, after_fact) {
        let affected = affected_entities_for_owner(
          subject_id, property, before, after,
        )
        if affected.is_empty() &&
          (property == "color" || css_custom_property_name(property)) {
          continue
        }
        changed.push({
          id: "changed:source:\{subject_id}:\{property}",
          subject_id,
          property,
          before: before_fact,
          after: after_fact,
          affected_subject_ids: affected,
        })
      }
    }
  }
  changed
}

///|
fn source_subject_for_id(
  subjects : Array[SourceSubject],
  subject_id : String,
) -> SourceSubject? {
  for subject in subjects {
    if source_subject_id(subject) == subject_id {
      return Some(subject)
    }
  }
  None
}

///|
fn inherited_fill_report_from_hierarchies(
  before : FillHierarchy,
  after : FillHierarchy,
  before_svg : String,
  after_svg : String,
  profile : ComparisonProfile,
) -> StructuredReport {
  let before_subjects = extract_source_subjects_internal_or_raise(
    before_svg, profile, true,
  ) catch {
    _ => []
  }
  let after_subjects = extract_source_subjects_internal_or_raise(
    after_svg, profile, true,
  ) catch {
    _ => []
  }
  let rendered = match
    (
      @svg.parse_svg_document(
        normalize_renderer_input_with_profile(before_svg, profile),
      ),
      @svg.parse_svg_document(
        normalize_renderer_input_with_profile(after_svg, profile),
      ),
    ) {
    (Some(before_document), Some(after_document)) =>
      Some(rendered_difference(before_document, after_document, profile))
    _ => None
  }
  let changed_facts = compare_changed_visual_facts(before, after)
  let rect_ids : Array[String] = []
  append_unique_subjects(rect_ids, before.rect_subject_ids)
  append_unique_subjects(rect_ids, after.rect_subject_ids)
  let resolutions : Array[SourceResolutionPair] = []
  let differences : Array[AtomicDifference] = []
  let events : Array[VisualEvent] = []
  let diagnostics : Array[Diagnostic] = []
  for code in before.coverage_codes {
    ignore(
      add_diagnostic(diagnostics, code, "document", [
        "source_semantics", "computed_appearance",
      ]),
    )
  }
  for code in after.coverage_codes {
    ignore(
      add_diagnostic(diagnostics, code, "document", [
        "source_semantics", "computed_appearance",
      ]),
    )
  }
  if rendered is None {
    ignore(
      add_diagnostic(
        diagnostics,
        "ordinary_inheritance_renderer_unavailable",
        "document",
        ["rendered_evidence"],
      ),
    )
  }
  for subject_id in rect_ids {
    for property in resolved_visual_properties() {
      if property == "color" ||
        property == "mix-blend-mode" ||
        property == "isolation" {
        continue
      }
      let before_resolution = resolved_visual_for_subject(
        before, subject_id, property,
      )
      let after_resolution = resolved_visual_for_subject(
        after, subject_id, property,
      )
      match (before_resolution, after_resolution) {
        (Some(before_value), Some(after_value)) => {
          if !resolution_source_changed(Some(before_value), Some(after_value)) {
            continue
          }
          resolutions.push({
            subject_id,
            property,
            before: before_resolution,
            after: after_resolution,
          })
          let dependencies : Array[StyleDependency] = []
          match computed_visual_for_subject(before, subject_id, property) {
            Some(resolution) =>
              append_style_dependencies(dependencies, resolution.dependencies)
            None => ()
          }
          match computed_visual_for_subject(after, subject_id, property) {
            Some(resolution) =>
              append_style_dependencies(dependencies, resolution.dependencies)
            None => ()
          }
          let changed_fact_ids = [
            for fact in changed_facts if fact.affected_subject_ids.contains(
              subject_id,
            ) &&
            dependencies.any(dependency => {
              dependency.owner_id == fact.subject_id &&
              dependency.property == fact.property
            }) => fact.id
          ]
          let before_subject = source_subject_for_id(
            before_subjects, subject_id,
          )
          let after_subject = source_subject_for_id(after_subjects, subject_id)
          let before_computed_fact = match
            computed_visual_for_subject(before, subject_id, property) {
            Some(resolution) => resolution.computed_fact
            None => None
          }
          let after_computed_fact = match
            computed_visual_for_subject(after, subject_id, property) {
            Some(resolution) => resolution.computed_fact
            None => None
          }
          let relation : ComputedRelation = if !before.coverage_codes.is_empty() ||
            !after.coverage_codes.is_empty() {
            {
              status: "indeterminate",
              reason_code: "inherited_visual_analysis_coverage_incomplete",
              missing_side: None,
              diagnostic_ids: diagnostic_ids(diagnostics),
            }
          } else {
            match (before_subject, after_subject) {
              (Some(before_subject), Some(after_subject)) =>
                generic_relation(
                  property, before_subject, after_subject, before_computed_fact,
                  after_computed_fact,
                )
              _ => {
                let diagnostic_id = add_diagnostic(
                  diagnostics,
                  "source_subject_alignment_unsupported",
                  subject_id,
                  ["computed_appearance", "rendered_evidence"],
                )
                {
                  status: "indeterminate",
                  reason_code: "source_subject_alignment_unsupported",
                  missing_side: None,
                  diagnostic_ids: [diagnostic_id],
                }
              }
            }
          }
          let parameter_delta = match (before_subject, after_subject) {
            (Some(before_subject), Some(after_subject)) =>
              generic_parameter_delta(
                property, before_subject, after_subject, before_computed_fact, after_computed_fact,
              )
            _ => None
          }
          let magnitude = match (before_subject, after_subject) {
            (Some(before_subject), Some(after_subject)) =>
              generic_initial_magnitude(
                property, relation, before_subject, after_subject, parameter_delta,
              )
            _ => empty_difference_magnitude()
          }
          let evidence_layers : Array[String] = ["source_semantics"]
          if relation.status == "different" {
            evidence_layers.push("computed_appearance")
          }
          match rendered {
            Some(rendered) if rendered.changed_pixels > 0 =>
              evidence_layers.push("rendered_evidence")
            _ => ()
          }
          let difference_id = "diff:entity:\{subject_id}:\{property}"
          differences.push({
            id: difference_id,
            subject_role: "entity",
            subject_alignment_id: None,
            domain: generic_property_domain(property),
            source_before: match before_value.declaration {
              Some(declaration) => declaration.declared_value
              None => before_value.resolved_value
            },
            source_after: match after_value.declaration {
              Some(declaration) => declaration.declared_value
              None => after_value.resolved_value
            },
            source_fact_before: before_value.declaration,
            source_fact_after: after_value.declaration,
            changed_fact_ids,
            evidence_layers,
            computed_relation: relation,
            parameter_delta_css_px: if before_subject
              .map(subject => {
                basic_shape_geometry_property(subject.kind, property)
              })
              .unwrap_or(false) ||
              property == "stroke-width" {
              parameter_delta
            } else {
              None
            },
            presence_magnitude: None,
            magnitude,
            domain_ordering: empty_domain_ordering(),
          })
          events.push({
            id: "event:\{subject_id}:\{property}",
            primary_subject_id: subject_id,
            atomic_difference_ids: [difference_id],
            rendered_outcome: match rendered {
              Some(rendered) => computed_rendered_evidence(rendered)
              None =>
                not_computed_rendered_evidence(
                  "ordinary_inheritance_renderer_unavailable",
                )
            },
            difference_regions: [],
          })
        }
        _ =>
          ignore(
            add_diagnostic(
              diagnostics,
              "source_subject_alignment_unsupported",
              subject_id,
              ["source_semantics", "computed_appearance", "rendered_evidence"],
            ),
          )
      }
    }
  }
  {
    schema_version: "1.46",
    analysis_status: if diagnostics.is_empty() {
      "complete"
    } else {
      "partial"
    },
    canvas_outcome: not_computed_canvas_outcome("rendered_evidence_unavailable"),
    impact_assessment: empty_impact_assessment(),
    coverage_matrix: [],
    renderer_capability_gaps: [],
    profile,
    subject_alignments: [],
    changed_facts,
    source_resolutions: resolutions,
    atomic_differences: differences,
    events,
    diagnostics,
  }
}

///|
fn inherited_fill_report(
  before_svg : String,
  after_svg : String,
  profile : ComparisonProfile,
) -> StructuredReport? {
  match
    (extract_fill_hierarchy(before_svg), extract_fill_hierarchy(after_svg)) {
    (ParsedFillHierarchy(before), ParsedFillHierarchy(after)) => {
      let handles_source_slice = before.has_inherited_visual ||
        after.has_inherited_visual ||
        hierarchy_has_scene_computed_value_semantics(before) ||
        hierarchy_has_scene_computed_value_semantics(after) ||
        before.coverage_codes.contains("css_cascade_unsupported") ||
        after.coverage_codes.contains("css_cascade_unsupported")
      if handles_source_slice {
        Some(
          inherited_fill_report_from_hierarchies(
            before, after, before_svg, after_svg, profile,
          ),
        )
      } else {
        None
      }
    }
    _ => None
  }
}

///|
fn hierarchy_has_scene_computed_value_semantics(
  hierarchy : FillHierarchy,
) -> Bool {
  for subject_id in hierarchy.rect_subject_ids {
    for property in resolved_visual_properties() {
      if property == "stop-color" || property == "stop-opacity" {
        continue
      }
      match computed_visual_for_subject(hierarchy, subject_id, property) {
        Some(resolution) => {
          if resolution.dependencies.any(dependency => {
              dependency.property == "color" ||
              css_custom_property_name(dependency.property)
            }) {
            return true
          }
          match resolution.reported.declaration {
            Some(declaration) => {
              let value = declaration.declared_value.to_lower()
              if css_wide_keyword(value) ||
                value == "currentcolor" ||
                value.find("var(") is Some(_) {
                return true
              }
            }
            None => ()
          }
        }
        None => ()
      }
    }
  }
  false
}
