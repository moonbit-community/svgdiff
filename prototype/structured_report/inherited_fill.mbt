///|
priv struct FillSourceElement {
  subject_id : String
  parent_index : Int?
  fill_declaration : DeclaredVisualFact?
}

///|
priv struct FillHierarchy {
  elements : Array[FillSourceElement]
  rect_subject_ids : Array[String]
  coverage_codes : Array[String]
  mut has_inherited_fill : Bool
}

///|
priv enum FillHierarchyExtraction {
  ParsedFillHierarchy(FillHierarchy)
  FillHierarchyFailed
}

///|
fn authored_subject_id(element : @xml.NamespaceElement) -> String? {
  for attribute in element.attributes {
    if attribute.name.local_name == "id" {
      let id = attribute.value.trim().to_owned()
      if id != "" {
        return Some(id)
      }
    }
  }
  None
}

///|
fn generated_subject_id(kind : String, index : Int) -> String {
  "\{kind}:\{index}"
}

///|
fn fill_declaration_from_element(
  input : String,
  element : @xml.NamespaceElement,
  coverage_codes : Array[String],
) -> DeclaredVisualFact? {
  let mut fill : DeclaredVisualFact? = None
  let mut style_attribute : @xml.NamespaceAttribute? = None
  for attribute in element.attributes {
    match attribute.name.local_name {
      "class" => push_unique(coverage_codes, "css_cascade_unsupported")
      "fill" => fill = Some(presentation_fact(input, "fill", attribute))
      "style" => style_attribute = Some(attribute)
      _ => ()
    }
  }
  match style_attribute {
    Some(attribute) => {
      let parsed = inline_style_facts(input, attribute)
      match declared_fact_in_array(parsed.facts, "fill") {
        Some(style_fill) => fill = Some(style_fill)
        None => ()
      }
      if !parsed.complete {
        push_unique(coverage_codes, "css_cascade_unsupported")
      }
    }
    None => ()
  }
  match fill {
    Some(fact) => {
      let value = fact.declared_value.to_lower()
      if value == "currentcolor" ||
        value == "inherit" ||
        value == "initial" ||
        value == "revert" ||
        value == "revert-layer" ||
        value == "unset" ||
        value.find("url(") is Some(_) {
        push_unique(coverage_codes, "fill_value_semantics_unsupported")
      }
    }
    None => ()
  }
  fill
}

///|
fn add_fill_source_element(
  input : String,
  element : @xml.NamespaceElement,
  parent_index : Int?,
  elements : Array[FillSourceElement],
  rect_subject_ids : Array[String],
  coverage_codes : Array[String],
  svg_count : Int,
  group_count : Int,
  rect_count : Int,
) -> Int {
  let kind = element.name.local_name
  let generated_index = match kind {
    "svg" => svg_count
    "g" => group_count
    _ => rect_count
  }
  let subject_id = authored_subject_id(element).unwrap_or(
    generated_subject_id(kind, generated_index),
  )
  for current in elements {
    if current.subject_id == subject_id {
      push_unique(coverage_codes, "duplicate_source_subject_id")
      break
    }
  }
  let index = elements.length()
  elements.push({
    subject_id,
    parent_index,
    fill_declaration: fill_declaration_from_element(
      input, element, coverage_codes,
    ),
  })
  if kind == "rect" {
    rect_subject_ids.push(subject_id)
  }
  index
}

///|
fn fill_source_element(
  hierarchy : FillHierarchy,
  subject_id : String,
) -> (Int, FillSourceElement)? {
  for index, element in hierarchy.elements {
    if element.subject_id == subject_id {
      return Some((index, element))
    }
  }
  None
}

///|
fn resolved_fill_for_subject(
  hierarchy : FillHierarchy,
  subject_id : String,
) -> ResolvedVisualFact? {
  match fill_source_element(hierarchy, subject_id) {
    Some((index, _)) => {
      let mut current = Some(index)
      let mut depth = 0
      while current is Some(current_index) {
        let element = hierarchy.elements[current_index]
        match element.fill_declaration {
          Some(declaration) =>
            return Some({
              subject_id,
              property: "fill",
              resolved_value: declaration.declared_value,
              resolution: if depth == 0 {
                "local"
              } else {
                "inherited"
              },
              declaration_owner_id: Some(element.subject_id),
              declaration: Some(declaration),
              inheritance_depth: depth,
            })
          None => {
            current = element.parent_index
            depth += 1
          }
        }
      }
      Some({
        subject_id,
        property: "fill",
        resolved_value: "black",
        resolution: "initial",
        declaration_owner_id: None,
        declaration: None,
        inheritance_depth: 0,
      })
    }
    None => None
  }
}

///|
fn extract_fill_hierarchy_or_raise(input : String) -> FillHierarchy raise {
  let reader = @xml.NamespaceReader::from_string(input)
  let elements : Array[FillSourceElement] = []
  let rect_subject_ids : Array[String] = []
  let coverage_codes : Array[String] = []
  let stack : Array[Int] = []
  let mut svg_count = 0
  let mut group_count = 0
  let mut rect_count = 0
  for event in reader.read_events_until_eof() {
    match event.kind {
      Start(element) => {
        let kind = element.name.local_name
        if kind == "style" {
          push_unique(coverage_codes, "css_cascade_unsupported")
        } else if kind == "svg" || kind == "g" || kind == "rect" {
          let parent_index = stack.last()
          let index = add_fill_source_element(
            input, element, parent_index, elements, rect_subject_ids, coverage_codes,
            svg_count, group_count, rect_count,
          )
          stack.push(index)
          match kind {
            "svg" => svg_count += 1
            "g" => group_count += 1
            _ => rect_count += 1
          }
        }
      }
      Empty(element) => {
        let kind = element.name.local_name
        if kind == "style" {
          push_unique(coverage_codes, "css_cascade_unsupported")
        } else if kind == "svg" || kind == "g" || kind == "rect" {
          ignore(
            add_fill_source_element(
              input,
              element,
              stack.last(),
              elements,
              rect_subject_ids,
              coverage_codes,
              svg_count,
              group_count,
              rect_count,
            ),
          )
          match kind {
            "svg" => svg_count += 1
            "g" => group_count += 1
            _ => rect_count += 1
          }
        }
      }
      End(name) =>
        if name.local_name == "svg" ||
          name.local_name == "g" ||
          name.local_name == "rect" {
          ignore(stack.pop())
        }
      _ => ()
    }
  }
  let hierarchy = {
    elements,
    rect_subject_ids,
    coverage_codes,
    has_inherited_fill: false,
  }
  for subject_id in rect_subject_ids {
    match resolved_fill_for_subject(hierarchy, subject_id) {
      Some({ resolution: "inherited", .. }) => {
        hierarchy.has_inherited_fill = true
        break
      }
      _ => ()
    }
  }
  hierarchy
}

///|
fn extract_fill_hierarchy(input : String) -> FillHierarchyExtraction {
  try extract_fill_hierarchy_or_raise(input) catch {
    _ => FillHierarchyFailed
  } noraise {
    hierarchy => ParsedFillHierarchy(hierarchy)
  }
}

///|
fn local_fill_declaration(
  hierarchy : FillHierarchy,
  subject_id : String,
) -> DeclaredVisualFact? {
  match fill_source_element(hierarchy, subject_id) {
    Some((_, element)) => element.fill_declaration
    None => None
  }
}

///|
fn resolution_source_changed(
  before : ResolvedVisualFact?,
  after : ResolvedVisualFact?,
) -> Bool {
  match (before, after) {
    (Some(before), Some(after)) => {
      let origin_changed = match (before.declaration, after.declaration) {
        (Some(before), Some(after)) => before.origin != after.origin
        (None, None) => false
        _ => true
      }
      before.resolved_value != after.resolved_value ||
      before.resolution != after.resolution ||
      before.declaration_owner_id != after.declaration_owner_id ||
      origin_changed
    }
    (None, None) => false
    _ => true
  }
}

///|
fn resolved_fill_owner(
  hierarchy : FillHierarchy,
  subject_id : String,
) -> String? {
  match resolved_fill_for_subject(hierarchy, subject_id) {
    Some(resolution) => resolution.declaration_owner_id
    None => None
  }
}

///|
fn append_unique_subjects(
  target : Array[String],
  source : Array[String],
) -> Unit {
  for subject_id in source {
    if !target.contains(subject_id) {
      target.push(subject_id)
    }
  }
}

///|
fn source_element_ids(hierarchy : FillHierarchy) -> Array[String] {
  [
    for element in hierarchy.elements => element.subject_id
  ]
}

///|
fn affected_rects_for_owner(
  owner_id : String,
  before : FillHierarchy,
  after : FillHierarchy,
) -> Array[String] {
  let rect_ids : Array[String] = []
  append_unique_subjects(rect_ids, before.rect_subject_ids)
  append_unique_subjects(rect_ids, after.rect_subject_ids)
  [
    for rect_id in rect_ids if resolved_fill_owner(before, rect_id) ==
    Some(owner_id) ||
    resolved_fill_owner(after, rect_id) == Some(owner_id) => rect_id
  ]
}

///|
fn compare_changed_fill_facts(
  before : FillHierarchy,
  after : FillHierarchy,
) -> Array[ChangedFact] {
  let subject_ids = source_element_ids(before)
  append_unique_subjects(subject_ids, source_element_ids(after))
  let changed : Array[ChangedFact] = []
  for subject_id in subject_ids {
    let before_fact = local_fill_declaration(before, subject_id)
    let after_fact = local_fill_declaration(after, subject_id)
    if declared_fact_changed(before_fact, after_fact) {
      changed.push({
        id: "changed:source:\{subject_id}:fill",
        subject_id,
        property: "fill",
        before: before_fact,
        after: after_fact,
        affected_subject_ids: affected_rects_for_owner(
          subject_id, before, after,
        ),
      })
    }
  }
  changed
}

///|
fn changed_fact_ids_for_subject(
  changed_facts : Array[ChangedFact],
  subject_id : String,
) -> Array[String] {
  [
    for fact in changed_facts if fact.affected_subject_ids.contains(subject_id) => {
      fact.id
    }
  ]
}

///|
fn source_resolution_diagnostic_ids(
  diagnostics : Array[Diagnostic],
) -> Array[String] {
  [
    for diagnostic in diagnostics if diagnostic.code !=
    "inherited_fill_rendered_evidence_deferred" => diagnostic.id
  ]
}

///|
fn inherited_fill_report_from_hierarchies(
  before : FillHierarchy,
  after : FillHierarchy,
  profile : ComparisonProfile,
) -> StructuredReport {
  let changed_facts = compare_changed_fill_facts(before, after)
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
  ignore(
    add_diagnostic(
      diagnostics,
      "inherited_fill_rendered_evidence_deferred",
      "document",
      ["rendered_evidence"],
    ),
  )
  for subject_id in rect_ids {
    let before_resolution = resolved_fill_for_subject(before, subject_id)
    let after_resolution = resolved_fill_for_subject(after, subject_id)
    resolutions.push({
      subject_id,
      property: "fill",
      before: before_resolution,
      after: after_resolution,
    })
    match (before_resolution, after_resolution) {
      (Some(before_value), Some(after_value)) => {
        if !resolution_source_changed(Some(before_value), Some(after_value)) {
          continue
        }
        let changed_fact_ids = changed_fact_ids_for_subject(
          changed_facts, subject_id,
        )
        let relation = if !before.coverage_codes.is_empty() ||
          !after.coverage_codes.is_empty() {
          {
            status: "indeterminate",
            reason_code: "inherited_fill_analysis_coverage_incomplete",
            missing_side: None,
            diagnostic_ids: source_resolution_diagnostic_ids(diagnostics),
          }
        } else if before_value.resolved_value == after_value.resolved_value {
          {
            status: "equivalent",
            reason_code: "same_resolved_fill",
            missing_side: None,
            diagnostic_ids: [],
          }
        } else {
          let diagnostic_id = add_diagnostic(
            diagnostics,
            "computed_fill_value_semantics_deferred",
            subject_id,
            ["computed_appearance"],
          )
          {
            status: "indeterminate",
            reason_code: "computed_fill_value_semantics_deferred",
            missing_side: None,
            diagnostic_ids: [diagnostic_id],
          }
        }
        let difference_id = "diff:entity:\{subject_id}:fill"
        differences.push({
          id: difference_id,
          subject_role: "entity",
          domain: "paint.fill",
          source_before: before_value.resolved_value,
          source_after: after_value.resolved_value,
          source_fact_before: before_value.declaration,
          source_fact_after: after_value.declaration,
          changed_fact_ids,
          evidence_layers: ["source_semantics"],
          computed_relation: relation,
          parameter_delta_css_px: None,
          presence_magnitude: None,
        })
        events.push({
          id: "event:\{subject_id}",
          primary_subject_id: subject_id,
          atomic_difference_ids: [difference_id],
          rendered_outcome: {
            status: "not_computed",
            reason_code: Some("inherited_fill_rendered_evidence_deferred"),
            magnitude: None,
          },
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
  {
    schema_version: "0.3-prototype",
    analysis_status: "partial",
    profile,
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
      let handles_source_slice = before.has_inherited_fill ||
        after.has_inherited_fill ||
        before.coverage_codes.contains("css_cascade_unsupported") ||
        after.coverage_codes.contains("css_cascade_unsupported")
      if handles_source_slice {
        Some(inherited_fill_report_from_hierarchies(before, after, profile))
      } else {
        None
      }
    }
    _ => None
  }
}
