///|
priv struct FillSourceElement {
  subject_id : String
  parent_index : Int?
  visual_declarations : Array[DeclaredVisualFact]
}

///|
priv struct FillHierarchy {
  elements : Array[FillSourceElement]
  rect_subject_ids : Array[String]
  coverage_codes : Array[String]
  mut has_inherited_visual : Bool
}

///|
fn fill_hierarchy_kind(kind : String) -> Bool {
  match kind {
    "svg"
    | "g"
    | "rect"
    | "circle"
    | "ellipse"
    | "line"
    | "polyline"
    | "polygon"
    | "path" => true
    _ => false
  }
}

///|
fn fill_entity_kind(kind : String) -> Bool {
  kind != "svg" && kind != "g"
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
fn inherited_visual_properties() -> Array[String] {
  [
    "fill", "stroke", "stroke-width", "stroke-linecap", "stroke-linejoin", "stroke-miterlimit",
    "stroke-dasharray", "stroke-dashoffset", "marker-start", "marker-mid", "marker-end",
  ]
}

///|
fn ordinary_subject_inherited_properties() -> Array[String] {
  [
    "fill", "stroke", "stroke-width", "stroke-linecap", "stroke-linejoin", "stroke-miterlimit",
    "stroke-dasharray", "stroke-dashoffset",
  ]
}

///|
fn resolved_visual_properties() -> Array[String] {
  [
    "fill", "stroke", "stroke-width", "stroke-linecap", "stroke-linejoin", "stroke-miterlimit",
    "stroke-dasharray", "stroke-dashoffset", "vector-effect", "opacity", "marker",
    "marker-start", "marker-mid", "marker-end",
  ]
}

///|
fn css_wide_keyword(value : String) -> Bool {
  match value.trim().to_owned().to_lower() {
    "inherit" | "initial" | "unset" | "revert" | "revert-layer" => true
    _ => false
  }
}

///|
fn visual_declarations_from_element(
  input : String,
  element : @xml.NamespaceElement,
  stylesheet_match : CssStylesheetMatch,
  coverage_codes : Array[String],
) -> Array[DeclaredVisualFact] {
  let candidates : Array[CssCascadeCandidate] = []
  let mut style_attribute : @xml.NamespaceAttribute? = None
  for attribute in element.attributes {
    let property = attribute.name.local_name
    if property == "style" {
      style_attribute = Some(attribute)
    } else if resolved_visual_properties().contains(property) {
      let fact = presentation_fact(input, property, attribute)
      candidates.push(
        presentation_cascade_candidate(fact, attribute.span.start.offset),
      )
    }
  }
  match style_attribute {
    Some(attribute) => {
      let parsed = inline_style_facts(input, attribute)
      for candidate in parsed.candidates {
        if resolved_visual_properties().contains(candidate.declaration.property) {
          candidates.push(candidate)
        }
      }
      if !parsed.complete {
        push_unique(coverage_codes, "css_cascade_unsupported")
      }
    }
    None => ()
  }
  for candidate in stylesheet_match.candidates {
    if resolved_visual_properties().contains(candidate.declaration.property) {
      candidates.push(candidate)
    }
  }
  if !stylesheet_match.complete {
    push_unique(coverage_codes, "css_cascade_unsupported")
  }
  let declarations = cascade_visual_declarations(candidates)
  for fact in declarations {
    let value = fact.declared_value.to_lower()
    if css_wide_keyword(value) {
      push_unique(coverage_codes, "css_wide_keyword_unsupported")
    } else if fact.property == "fill" || fact.property == "stroke" {
      if value == "currentcolor" || value.find("url(") is Some(_) {
        push_unique(
          coverage_codes,
          "\{fact.property}_value_semantics_unsupported",
        )
      }
    }
  }
  declarations
}

///|
fn add_fill_source_element(
  input : String,
  element : @xml.NamespaceElement,
  stylesheet_match : CssStylesheetMatch,
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
    visual_declarations: visual_declarations_from_element(
      input, element, stylesheet_match, coverage_codes,
    ),
  })
  if fill_entity_kind(kind) {
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
fn initial_visual_value(property : String) -> String {
  match property {
    "fill" => "black"
    "stroke" => "none"
    "stroke-width" | "opacity" => "1"
    "stroke-linecap" => "butt"
    "stroke-linejoin" => "miter"
    "stroke-miterlimit" => "4"
    "stroke-dasharray" => "none"
    "stroke-dashoffset" => "0"
    "vector-effect" => "none"
    "marker-start" | "marker-mid" | "marker-end" => "none"
    _ => ""
  }
}

///|
fn local_visual_declaration(
  element : FillSourceElement,
  property : String,
) -> DeclaredVisualFact? {
  match declared_fact_in_array(element.visual_declarations, property) {
    Some(fact) => Some(fact)
    None if property == "marker-start" ||
      property == "marker-mid" ||
      property == "marker-end" =>
      match declared_fact_in_array(element.visual_declarations, "marker") {
        Some(fact) => Some({ ..fact, property, })
        None => None
      }
    None => None
  }
}

///|
fn resolved_visual_for_subject(
  hierarchy : FillHierarchy,
  subject_id : String,
  property : String,
) -> ResolvedVisualFact? {
  match fill_source_element(hierarchy, subject_id) {
    Some((index, _)) => {
      let mut current = Some(index)
      let mut depth = 0
      while current is Some(current_index) {
        let element = hierarchy.elements[current_index]
        match local_visual_declaration(element, property) {
          Some(declaration) =>
            return Some({
              subject_id,
              property,
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
          None =>
            if property == "opacity" || property == "vector-effect" {
              current = None
            } else {
              current = element.parent_index
              depth += 1
            }
        }
      }
      Some({
        subject_id,
        property,
        resolved_value: initial_visual_value(property),
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
  let css_document = parse_static_css_document_or_raise(input)
  let reader = @xml.NamespaceReader::from_string(input)
  let elements : Array[FillSourceElement] = []
  let rect_subject_ids : Array[String] = []
  let coverage_codes : Array[String] = []
  let stack : Array[Int] = []
  let mut svg_count = 0
  let mut group_count = 0
  let mut rect_count = 0
  let mut marker_depth = 0
  for event in reader.read_events_until_eof() {
    match event.kind {
      Start(element) => {
        let kind = element.name.local_name
        if kind == "marker" {
          marker_depth += 1
        }
        if marker_depth == 0 && fill_hierarchy_kind(kind) {
          let parent_index = stack.last()
          let index = add_fill_source_element(
            input,
            element,
            css_stylesheet_match_for_source(
              css_document,
              event.span.start.offset,
            ),
            parent_index,
            elements,
            rect_subject_ids,
            coverage_codes,
            svg_count,
            group_count,
            rect_count,
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
        if marker_depth == 0 && fill_hierarchy_kind(kind) {
          ignore(
            add_fill_source_element(
              input,
              element,
              css_stylesheet_match_for_source(
                css_document,
                event.span.start.offset,
              ),
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
      End(name) => {
        if marker_depth == 0 && fill_hierarchy_kind(name.local_name) {
          ignore(stack.pop())
        }
        if name.local_name == "marker" {
          marker_depth -= 1
        }
      }
      _ => ()
    }
  }
  let hierarchy = {
    elements,
    rect_subject_ids,
    coverage_codes,
    has_inherited_visual: false,
  }
  for subject_id in rect_subject_ids {
    for property in inherited_visual_properties() {
      match resolved_visual_for_subject(hierarchy, subject_id, property) {
        Some({ resolution: "inherited", .. }) =>
          hierarchy.has_inherited_visual = true
        _ => ()
      }
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
fn local_property_declaration(
  hierarchy : FillHierarchy,
  subject_id : String,
  property : String,
) -> DeclaredVisualFact? {
  match fill_source_element(hierarchy, subject_id) {
    Some((_, element)) => local_visual_declaration(element, property)
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
fn resolved_visual_owner(
  hierarchy : FillHierarchy,
  subject_id : String,
  property : String,
) -> String? {
  match resolved_visual_for_subject(hierarchy, subject_id, property) {
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
fn affected_entities_for_owner(
  owner_id : String,
  property : String,
  before : FillHierarchy,
  after : FillHierarchy,
) -> Array[String] {
  let rect_ids : Array[String] = []
  append_unique_subjects(rect_ids, before.rect_subject_ids)
  append_unique_subjects(rect_ids, after.rect_subject_ids)
  [
    for rect_id in rect_ids if resolved_visual_owner(before, rect_id, property) ==
    Some(owner_id) ||
    resolved_visual_owner(after, rect_id, property) == Some(owner_id) => rect_id
  ]
}

///|
fn compare_changed_visual_facts(
  before : FillHierarchy,
  after : FillHierarchy,
) -> Array[ChangedFact] {
  let subject_ids = source_element_ids(before)
  append_unique_subjects(subject_ids, source_element_ids(after))
  let changed : Array[ChangedFact] = []
  for subject_id in subject_ids {
    for property in resolved_visual_properties() {
      let before_fact = local_property_declaration(before, subject_id, property)
      let after_fact = local_property_declaration(after, subject_id, property)
      if declared_fact_changed(before_fact, after_fact) {
        changed.push({
          id: "changed:source:\{subject_id}:\{property}",
          subject_id,
          property,
          before: before_fact,
          after: after_fact,
          affected_subject_ids: affected_entities_for_owner(
            subject_id, property, before, after,
          ),
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
  let before_subjects = extract_source_subjects_with_profile_or_raise(
    before_svg, profile,
  ) catch {
    _ => []
  }
  let after_subjects = extract_source_subjects_with_profile_or_raise(
    after_svg, profile,
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
          let changed_fact_ids = [
            for fact in changed_facts if fact.property == property &&
            fact.affected_subject_ids.contains(subject_id) => fact.id
          ]
          let before_subject = source_subject_for_id(
            before_subjects, subject_id,
          )
          let after_subject = source_subject_for_id(after_subjects, subject_id)
          let relation = if !before.coverage_codes.is_empty() ||
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
                  property,
                  before_subject,
                  after_subject,
                  before_value.declaration,
                  after_value.declaration,
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
                property,
                before_subject,
                after_subject,
                before_value.declaration,
                after_value.declaration,
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
            source_before: before_value.resolved_value,
            source_after: after_value.resolved_value,
            source_fact_before: before_value.declaration,
            source_fact_after: after_value.declaration,
            changed_fact_ids,
            evidence_layers,
            computed_relation: relation,
            parameter_delta_css_px: parameter_delta,
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
    schema_version: "1.14",
    analysis_status: if diagnostics.is_empty() {
      "complete"
    } else {
      "partial"
    },
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
