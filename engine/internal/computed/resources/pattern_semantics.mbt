///|
pub(all) struct PatternAttributeSource {
  name : String
  fact : DeclaredVisualFact
}

///|
pub(all) struct PatternSource {
  subject_id : String
  authored_id : String?
  hierarchy_index : Int
  attributes : Array[PatternAttributeSource]
  href_fact : DeclaredVisualFact?
  mut has_non_descriptive_child : Bool
}

///|
pub(all) struct PatternSemanticIssue {
  code : String
  subject_id : String
  fact : DeclaredVisualFact?
}

///|
pub(all) struct PatternDocument {
  profile : ComparisonProfile
  hierarchy : FillHierarchy
  patterns : Array[PatternSource]
  child_subjects : Array[SourceSubject]
  issues : Array[PatternSemanticIssue]
}

///|
pub(all) struct ComputedPatternField {
  name : String
  value : String
  number : Double?
  fact : DeclaredVisualFact?
  complete : Bool
}

///|
pub(all) struct ComputedPatternChild {
  subject_id : String
  kind : String
  signature : String
  facts : Array[DeclaredVisualFact]
  computed_facts : Array[DeclaredVisualFact]
  transforms : Array[ComputedPatternChildTransform]
  complete : Bool
}

///|
pub(all) struct ComputedPatternChildTransform {
  key : String
  fact : DeclaredVisualFact
  computed : String
}

///|
pub(all) struct ComputedPattern {
  template_chain : Array[String]
  fields : Array[ComputedPatternField]
  children : Array[ComputedPatternChild]
  tile_matrix : AffineTransform
  content_matrix : AffineTransform
  paint_mode : String
  complete : Bool
}

///|
pub(all) enum PatternSemanticResolution {
  PatternResolved(ComputedPattern)
  PatternUnavailable
}

///|
pub fn pattern_attribute_names() -> Array[String] {
  [
    "x", "y", "width", "height", "patternUnits", "patternContentUnits", "patternTransform",
    "viewBox", "preserveAspectRatio", "overflow",
  ]
}

///|
pub fn pattern_descriptive_child(kind : String) -> Bool {
  kind == "desc" || kind == "title" || kind == "metadata"
}

///|
pub fn pattern_dynamic_child(kind : String) -> Bool {
  kind == "animate" ||
  kind == "animateMotion" ||
  kind == "animateTransform" ||
  kind == "discard" ||
  kind == "script" ||
  kind == "set"
}

///|
pub fn pattern_supported_container(kind : String) -> Bool {
  kind == "g" || kind == "defs" || kind == "svg"
}

///|
pub fn push_pattern_issue(
  issues : Array[PatternSemanticIssue],
  code : String,
  subject_id : String,
  fact : DeclaredVisualFact?,
) -> Unit {
  if !issues.any(issue => {
      issue.code == code &&
      issue.subject_id == subject_id &&
      issue.fact.map(fact => {
        (
          fact.property,
          fact.source_span.start_offset,
          fact.source_span.end_offset,
        )
      }) ==
      fact.map(fact => {
        (
          fact.property,
          fact.source_span.start_offset,
          fact.source_span.end_offset,
        )
      })
    }) {
    issues.push({ code, subject_id, fact })
  }
}

///|
pub fn preferred_pattern_href(
  input : String,
  element : @xml.NamespaceElement,
) -> DeclaredVisualFact? {
  let mut legacy : DeclaredVisualFact? = None
  for attribute in element.attributes {
    if attribute.name.local_name != "href" {
      continue
    }
    let fact = presentation_fact(input, "href", attribute)
    if attribute.name.prefix is None {
      return Some(fact)
    }
    if attribute.name.namespace_uri == Some("http://www.w3.org/1999/xlink") {
      legacy = Some(fact)
    }
  }
  legacy
}

///|
pub fn pattern_from_element(
  input : String,
  element : @xml.NamespaceElement,
  source_offset : Int,
  hierarchy : FillHierarchy,
) -> PatternSource? {
  if element.name.local_name != "pattern" {
    return None
  }
  let authored_id = authored_subject_id(element)
  let subject_id = authored_id.unwrap_or(
    generated_subject_id("pattern", source_offset),
  )
  guard fill_source_element(hierarchy, subject_id) is Some((hierarchy_index, _)) else {
    return None
  }
  let attributes : Array[PatternAttributeSource] = []
  for attribute in element.attributes {
    let name = attribute.name.local_name
    if pattern_attribute_names().contains(name) {
      attributes.push({ name, fact: presentation_fact(input, name, attribute) })
    }
  }
  Some({
    subject_id,
    authored_id,
    hierarchy_index,
    attributes,
    href_fact: preferred_pattern_href(input, element),
    has_non_descriptive_child: false,
  })
}

///|
pub fn extract_pattern_document_or_raise(
  source : String,
  profile : ComparisonProfile,
) -> PatternDocument raise {
  let hierarchy = extract_fill_hierarchy_or_raise(source)
  let patterns : Array[PatternSource] = []
  let issues : Array[PatternSemanticIssue] = []
  let mut current_pattern : Int? = None
  let mut depth = 0
  let reader = @xml.NamespaceReader::from_string(source)
  for event in reader.read_events_until_eof() {
    match event.kind {
      Start(element) => {
        let kind = element.name.local_name
        match current_pattern {
          Some(index) => {
            depth += 1
            if depth == 2 && !pattern_descriptive_child(kind) {
              patterns[index].has_non_descriptive_child = true
            }
            if pattern_dynamic_child(kind) {
              push_pattern_issue(
                issues,
                "pattern_dynamic_content_unsupported",
                patterns[index].subject_id,
                None,
              )
            } else if !pattern_descriptive_child(kind) &&
              !visual_subject_kind(kind) &&
              !pattern_supported_container(kind) {
              push_pattern_issue(
                issues,
                "pattern_child_semantics_unsupported",
                patterns[index].subject_id,
                None,
              )
            }
          }
          None =>
            match
              pattern_from_element(
                source,
                element,
                event.span.start.offset,
                hierarchy,
              ) {
              Some(pattern) => {
                patterns.push(pattern)
                current_pattern = Some(patterns.length() - 1)
                depth = 1
              }
              None => ()
            }
        }
      }
      Empty(element) => {
        let kind = element.name.local_name
        match current_pattern {
          Some(index) => {
            if depth == 1 && !pattern_descriptive_child(kind) {
              patterns[index].has_non_descriptive_child = true
            }
            if pattern_dynamic_child(kind) {
              push_pattern_issue(
                issues,
                "pattern_dynamic_content_unsupported",
                patterns[index].subject_id,
                None,
              )
            } else if !pattern_descriptive_child(kind) &&
              !visual_subject_kind(kind) &&
              !pattern_supported_container(kind) {
              push_pattern_issue(
                issues,
                "pattern_child_semantics_unsupported",
                patterns[index].subject_id,
                None,
              )
            }
          }
          None =>
            match
              pattern_from_element(
                source,
                element,
                event.span.start.offset,
                hierarchy,
              ) {
              Some(pattern) => patterns.push(pattern)
              None => ()
            }
        }
      }
      End(_) =>
        match current_pattern {
          Some(_) => {
            depth -= 1
            if depth == 0 {
              current_pattern = None
            }
          }
          None => ()
        }
      _ => ()
    }
  }
  let child_subjects = extract_pattern_child_subjects_with_profile_or_raise(
    source, profile,
  )
  for pattern in patterns {
    match pattern_attribute_fact(pattern, "overflow") {
      Some(fact) if fact.declared_value.trim().to_owned().to_lower() != "hidden" =>
        push_pattern_issue(
          issues,
          "pattern_visible_overflow_unsupported",
          pattern.subject_id,
          Some(fact),
        )
      _ => ()
    }
  }
  for subject in child_subjects {
    let mut unsupported = subject.kind == "path" ||
      !subject.geometry_complete ||
      !subject.stroke_complete ||
      subject.marker_active
    for property in ["fill", "stroke"] {
      if paint_server_reference(subject_value(subject, property).unwrap_or(""))
        is Some(_) {
        unsupported = true
      }
    }
    for property in ["marker", "marker-start", "marker-mid", "marker-end"] {
      if subject_value(subject, property).unwrap_or("none") != "none" {
        unsupported = true
      }
    }
    if unsupported {
      push_pattern_issue(
        issues,
        "pattern_child_semantics_unsupported",
        subject.resource_owner_id.unwrap_or("pattern"),
        None,
      )
    }
  }
  { profile, hierarchy, patterns, child_subjects, issues }
}

///|
pub fn extract_pattern_document(
  source : String,
  profile : ComparisonProfile,
) -> PatternDocument? {
  try extract_pattern_document_or_raise(source, profile) catch {
    _ => None
  } noraise {
    document => Some(document)
  }
}

///|
pub fn pattern_by_id(document : PatternDocument, id : String) -> PatternSource? {
  for pattern in document.patterns {
    if pattern.authored_id == Some(id) {
      return Some(pattern)
    }
  }
  None
}

///|
pub fn pattern_attribute_fact(
  pattern : PatternSource,
  name : String,
) -> DeclaredVisualFact? {
  for attribute in pattern.attributes {
    if attribute.name == name {
      return Some(attribute.fact)
    }
  }
  None
}

///|
pub fn same_document_pattern_target(
  document : PatternDocument,
  pattern : PatternSource,
) -> PatternSource? {
  match pattern.href_fact {
    None => None
    Some(fact) => {
      let value = fact.declared_value.trim().to_owned()
      if !value.has_prefix("#") || value.length() <= 1 {
        push_pattern_issue(
          document.issues,
          "pattern_external_reference_unsupported",
          pattern.subject_id,
          Some(fact),
        )
        return None
      }
      match pattern_by_id(document, value.view(start_offset=1).to_owned()) {
        Some(target) if target.subject_id != pattern.subject_id => Some(target)
        _ => {
          push_pattern_issue(
            document.issues,
            "pattern_reference_invalid",
            pattern.subject_id,
            Some(fact),
          )
          None
        }
      }
    }
  }
}

///|
pub fn pattern_attribute_from_chain(
  document : PatternDocument,
  pattern : PatternSource,
  name : String,
  stack : Array[String],
) -> DeclaredVisualFact? {
  match pattern_attribute_fact(pattern, name) {
    Some(fact) => return Some(fact)
    None => ()
  }
  if stack.contains(pattern.subject_id) {
    push_pattern_issue(
      document.issues,
      "pattern_reference_cycle",
      pattern.subject_id,
      pattern.href_fact,
    )
    return None
  }
  stack.push(pattern.subject_id)
  let result = match same_document_pattern_target(document, pattern) {
    Some(target) => pattern_attribute_from_chain(document, target, name, stack)
    None => None
  }
  ignore(stack.pop())
  result
}

///|
pub fn pattern_content_provider(
  document : PatternDocument,
  pattern : PatternSource,
  stack : Array[String],
) -> PatternSource? {
  if pattern.has_non_descriptive_child {
    return Some(pattern)
  }
  if stack.contains(pattern.subject_id) {
    push_pattern_issue(
      document.issues,
      "pattern_reference_cycle",
      pattern.subject_id,
      pattern.href_fact,
    )
    return None
  }
  stack.push(pattern.subject_id)
  let result = match same_document_pattern_target(document, pattern) {
    Some(target) => pattern_content_provider(document, target, stack)
    None => None
  }
  ignore(stack.pop())
  result
}

///|
pub fn pattern_template_chain(
  document : PatternDocument,
  pattern : PatternSource,
) -> Array[String] {
  let chain : Array[String] = []
  let mut current : PatternSource? = Some(pattern)
  while current is Some(_) && chain.length() <= document.patterns.length() {
    guard current is Some(value) else { break }
    if chain.contains(value.subject_id) {
      push_pattern_issue(
        document.issues,
        "pattern_reference_cycle",
        value.subject_id,
        value.href_fact,
      )
      break
    }
    chain.push(value.subject_id)
    current = same_document_pattern_target(document, value)
  }
  chain
}

///|
pub fn computed_pattern_field(
  name : String,
  value : String,
  number : Double?,
  fact : DeclaredVisualFact?,
  complete : Bool,
) -> ComputedPatternField {
  { name, value, number, fact, complete }
}

///|
pub fn pattern_keyword_field(
  document : PatternDocument,
  pattern : PatternSource,
  name : String,
  initial : String,
) -> ComputedPatternField {
  let fact = pattern_attribute_from_chain(document, pattern, name, [])
  let value = fact
    .map(fact => fact.declared_value.trim().to_owned())
    .unwrap_or(initial)
  if value == "objectBoundingBox" || value == "userSpaceOnUse" {
    computed_pattern_field(name, value, None, fact, true)
  } else {
    push_pattern_issue(
      document.issues,
      "pattern_units_syntax_unsupported",
      pattern.subject_id,
      fact,
    )
    computed_pattern_field(name, initial, None, fact, false)
  }
}

///|
pub fn pattern_length_field(
  document : PatternDocument,
  pattern : PatternSource,
  name : String,
  initial : String,
  direction : SvgLengthDirection,
  viewport : ViewportContext,
  nonnegative : Bool,
) -> ComputedPatternField {
  let fact = pattern_attribute_from_chain(document, pattern, name, [])
  let source = fact.map(fact => fact.declared_value).unwrap_or(initial)
  match parse_svg_length(source, direction, viewport, document.profile) {
    Some(value) if !nonnegative || value >= 0.0 =>
      computed_pattern_field(
        name,
        canonical_shape_number(value),
        Some(value),
        fact,
        true,
      )
    _ => {
      push_pattern_issue(
        document.issues,
        "pattern_length_syntax_unsupported",
        pattern.subject_id,
        fact,
      )
      computed_pattern_field(name, "0", Some(0.0), fact, false)
    }
  }
}

///|
pub fn pattern_transform_field(
  document : PatternDocument,
  pattern : PatternSource,
) -> (ComputedPatternField, AffineTransform) {
  let fact = pattern_attribute_from_chain(
    document,
    pattern,
    "patternTransform",
    [],
  )
  match fact {
    None =>
      (
        computed_pattern_field(
          "patternTransform",
          AffineTransform::identity().signature(),
          None,
          None,
          true,
        ),
        AffineTransform::identity(),
      )
    Some(fact) =>
      match parse_transform_list(fact.declared_value) {
        ValidTransformList(transform) =>
          (
            computed_pattern_field(
              "patternTransform",
              transform.matrix.signature(),
              None,
              Some(fact),
              true,
            ),
            transform.matrix,
          )
        InvalidTransformList => {
          push_pattern_issue(
            document.issues,
            "pattern_transform_syntax_unsupported",
            pattern.subject_id,
            Some(fact),
          )
          (
            computed_pattern_field(
              "patternTransform",
              AffineTransform::identity().signature(),
              None,
              Some(fact),
              false,
            ),
            AffineTransform::identity(),
          )
        }
      }
  }
}

///|
pub fn pattern_field_number(
  fields : Array[ComputedPatternField],
  name : String,
) -> Double {
  for field in fields {
    if field.name == name {
      return field.number.unwrap_or(0.0)
    }
  }
  0.0
}

///|
pub fn pattern_coordinate_base(
  units : String,
  transform : AffineTransform,
  subject : SourceSubject?,
) -> (AffineTransform, Bool, String) {
  let cumulative = subject
    .map(subject => subject.cumulative_transform)
    .unwrap_or(AffineTransform::identity())
  if units == "userSpaceOnUse" {
    return (
      cumulative.multiply(transform),
      subject.map(subject => subject.transform_complete).unwrap_or(true),
      "",
    )
  }
  match
    subject
    .map(source_subject_geometry_bounds)
    .unwrap_or(Some({ x: 0.0, y: 0.0, width: 1.0, height: 1.0 })) {
    Some(bounds) => {
      let implicit = AffineTransform::translate(bounds.x, bounds.y).multiply(
        AffineTransform::scale(bounds.width, bounds.height),
      )
      (
        cumulative.multiply(implicit.multiply(transform)),
        subject.map(subject => subject.transform_complete).unwrap_or(true),
        if bounds.width == 0.0 || bounds.height == 0.0 {
          "none_empty_object_bounding_box"
        } else {
          ""
        },
      )
    }
    None => (cumulative.multiply(transform), false, "")
  }
}

///|
pub fn pattern_cloned_child_hierarchy(
  document : PatternDocument,
  host : PatternSource,
  provider : PatternSource,
  child : SourceSubject,
) -> (FillHierarchy, Int)? {
  let mut child_index = -1
  for index, element in document.hierarchy.elements {
    if element.kind == child.kind &&
      element.source_offset == child.source_offset {
      child_index = index
      break
    }
  }
  if child_index < 0 {
    return None
  }
  let chain : Array[Int] = []
  let mut current : Int? = Some(child_index)
  while current is Some(_) {
    guard current is Some(index) else { break }
    if index == provider.hierarchy_index {
      break
    }
    chain.push(index)
    current = document.hierarchy.elements[index].parent_index
  }
  if current != Some(provider.hierarchy_index) {
    return None
  }
  let elements = document.hierarchy.elements.copy()
  let mut parent = host.hierarchy_index
  let mut index = chain.length() - 1
  while index >= 0 {
    let original = elements[chain[index]]
    elements.push({ ..original, parent_index: Some(parent) })
    parent = elements.length() - 1
    index -= 1
  }
  Some(({ ..document.hierarchy, elements, }, parent))
}

///|
pub fn pattern_child_fact_value(
  facts : Array[DeclaredVisualFact],
  property : String,
  fallback : String,
) -> String {
  declared_fact_in_array(facts, property)
  .map(fact => fact.declared_value)
  .unwrap_or(fallback)
}

///|
pub fn pattern_child_paint_active(
  child : SourceSubject,
  facts : Array[DeclaredVisualFact],
  property : String,
) -> Bool {
  if property == "fill" && !child.fillable_interior {
    return false
  }
  if property == "stroke" {
    if !child.stroke_path_present ||
      parse_shape_number(pattern_child_fact_value(facts, "stroke-width", "1")).unwrap_or(
        0.0,
      ) <=
      0.0 {
      return false
    }
  }
  let paint = pattern_child_fact_value(
    facts,
    property,
    if property == "fill" {
      "black"
    } else {
      "none"
    },
  )
  if paint == "none" {
    return false
  }
  match @css_color.parse_solid_color(paint) {
    Resolved(color) if color.alpha == 0.0 => return false
    _ => ()
  }
  let paint_opacity = if property == "fill" {
    "fill-opacity"
  } else {
    "stroke-opacity"
  }
  @css_color.parse_alpha_value(
    pattern_child_fact_value(facts, paint_opacity, "1"),
  ).unwrap_or(1.0) >
  0.0 &&
  @css_color.parse_alpha_value(pattern_child_fact_value(facts, "opacity", "1")).unwrap_or(
    1.0,
  ) >
  0.0
}

///|
pub fn normalize_pattern_child_paint_rules(
  child : SourceSubject,
  facts : Array[DeclaredVisualFact],
) -> Unit {
  match declared_fact_in_array(facts, "paint-order") {
    Some(fact) =>
      match parse_paint_order_value(fact.declared_value) {
        ValidPaintOrder(order) => {
          let active : Array[String] = []
          for operation in order {
            let enabled = match operation {
              "fill" => pattern_child_paint_active(child, facts, "fill")
              "stroke" => pattern_child_paint_active(child, facts, "stroke")
              "markers" => child.marker_active
              _ => false
            }
            if enabled {
              active.push(operation)
            }
          }
          upsert_declared_fact(facts, {
            ..fact,
            declared_value: if active.is_empty() {
              "inactive"
            } else {
              paint_order_signature(active)
            },
          })
        }
        InvalidPaintOrder => ()
      }
    None => ()
  }
  match declared_fact_in_array(facts, "fill-rule") {
    Some(fact) => {
      let computed = if !pattern_child_paint_active(child, facts, "fill") {
        "inactive"
      } else {
        match child.kind {
          "rect" | "circle" | "ellipse" => "single_simple_contour"
          _ => fact.declared_value
        }
      }
      upsert_declared_fact(facts, { ..fact, declared_value: computed })
    }
    None => ()
  }
  match declared_fact_in_array(facts, "clip-rule") {
    Some(fact) =>
      upsert_declared_fact(facts, { ..fact, declared_value: "inactive" })
    None => ()
  }
}

///|
pub fn computed_pattern_child(
  document : PatternDocument,
  host : PatternSource,
  provider : PatternSource,
  child : SourceSubject,
  viewport : ViewportContext,
  content_matrix : AffineTransform,
) -> ComputedPatternChild {
  let facts = child.facts.copy()
  let resolved_facts = child.facts.copy()
  let mut complete = child.kind != "path" &&
    child.geometry_complete &&
    child.stroke_complete &&
    !child.marker_active
  let mut relative_matrix = AffineTransform::identity()
  let mut inside_provider = false
  let transforms : Array[ComputedPatternChildTransform] = []
  for site in child.transform_chain {
    if inside_provider {
      relative_matrix = relative_matrix
        .multiply(site.matrix)
        .multiply(site.viewport_matrix)
      complete = complete && site.complete && site.viewport_complete
      match site.fact {
        Some(fact) =>
          transforms.push({
            key: site.subject_id,
            fact,
            computed: site.matrix.signature(),
          })
        None => ()
      }
    } else if site.kind == "pattern" && site.subject_id == provider.subject_id {
      inside_provider = true
    }
  }
  complete = complete && inside_provider
  match declared_fact_in_array(facts, "transform") {
    Some(fact) =>
      upsert_declared_fact(resolved_facts, {
        ..fact,
        declared_value: relative_matrix.signature(),
      })
    None => ()
  }
  match pattern_cloned_child_hierarchy(document, host, provider, child) {
    Some((hierarchy, index)) =>
      for property in resolved_visual_properties() {
        let resolution = computed_visual_for_index(hierarchy, index, property)
        complete = complete && resolution.complete
        match resolution.computed_fact {
          Some(fact) => upsert_declared_fact(resolved_facts, fact)
          None => ()
        }
        for dependency in resolution.dependencies {
          match
            computed_visual_for_subject(
              hierarchy,
              dependency.owner_id,
              dependency.property,
            ) {
            Some(dependency_resolution) =>
              match dependency_resolution.reported.declaration {
                Some(fact) => upsert_declared_fact(facts, fact)
                None => ()
              }
            None => ()
          }
        }
      }
    None => complete = false
  }
  let geometry = resolve_basic_shape_geometry_with_context(
    child.kind,
    resolved_facts,
    viewport,
    document.profile,
  )
  complete = complete && geometry.complete
  normalize_pattern_child_paint_rules(child, resolved_facts)
  let mut signature = "\{child.kind}|matrix=\{content_matrix.multiply(relative_matrix).signature()}"
  for value in geometry.values {
    signature += "|\{value.0}=\{value.1}"
  }
  for
    property in [
      "fill", "fill-opacity", "stroke", "stroke-opacity", "stroke-width", "stroke-linecap",
      "stroke-linejoin", "stroke-miterlimit", "stroke-dasharray", "stroke-dashoffset",
      "vector-effect", "paint-order", "fill-rule", "clip-rule", "opacity",
    ] {
    match declared_fact_in_array(resolved_facts, property) {
      Some(fact) => signature += "|\{property}=\{fact.declared_value}"
      None => ()
    }
  }
  {
    subject_id: child.reference.authored_id.unwrap_or(
      generated_subject_id(child.kind, child.reference.source_index),
    ),
    kind: child.kind,
    signature,
    facts,
    computed_facts: resolved_facts,
    transforms,
    complete,
  }
}

///|
pub fn computed_pattern_children(
  document : PatternDocument,
  host : PatternSource,
  viewport : ViewportContext,
  content_matrix : AffineTransform,
) -> Array[ComputedPatternChild] {
  guard pattern_content_provider(document, host, []) is Some(provider) else {
    return []
  }
  let children : Array[ComputedPatternChild] = []
  for child in document.child_subjects {
    if child.resource_owner_id == Some(provider.subject_id) {
      children.push(
        computed_pattern_child(
          document, host, provider, child, viewport, content_matrix,
        ),
      )
    }
  }
  children
}

///|
pub fn resolve_computed_pattern(
  document : PatternDocument,
  pattern : PatternSource,
  subject : SourceSubject?,
) -> ComputedPattern {
  let units = pattern_keyword_field(
    document, pattern, "patternUnits", "objectBoundingBox",
  )
  let content_units = pattern_keyword_field(
    document, pattern, "patternContentUnits", "userSpaceOnUse",
  )
  let viewport : ViewportContext = if units.value == "objectBoundingBox" {
    { width: 1.0, height: 1.0 }
  } else {
    subject
    .map(subject => subject.viewport)
    .unwrap_or({
      width: document.profile.viewport_width.to_double(),
      height: document.profile.viewport_height.to_double(),
    })
  }
  let fields : Array[ComputedPatternField] = [units, content_units]
  let overflow_fact = pattern_attribute_fact(pattern, "overflow")
  let overflow = overflow_fact
    .map(fact => fact.declared_value.trim().to_owned().to_lower())
    .unwrap_or("hidden")
  fields.push(
    computed_pattern_field(
      "overflow",
      overflow,
      None,
      overflow_fact,
      overflow == "hidden",
    ),
  )
  fields.push(
    pattern_length_field(
      document,
      pattern,
      "x",
      "0",
      Horizontal,
      viewport,
      false,
    ),
  )
  fields.push(
    pattern_length_field(document, pattern, "y", "0", Vertical, viewport, false),
  )
  fields.push(
    pattern_length_field(
      document,
      pattern,
      "width",
      "0",
      Horizontal,
      viewport,
      true,
    ),
  )
  fields.push(
    pattern_length_field(
      document,
      pattern,
      "height",
      "0",
      Vertical,
      viewport,
      true,
    ),
  )
  let (transform_field, transform) = pattern_transform_field(document, pattern)
  fields.push(transform_field)
  let (tile_matrix, coordinate_complete, empty_bbox_mode) = pattern_coordinate_base(
    units.value,
    transform,
    subject,
  )
  let x = pattern_field_number(fields, "x")
  let y = pattern_field_number(fields, "y")
  let width = pattern_field_number(fields, "width")
  let height = pattern_field_number(fields, "height")
  let view_box_fact = pattern_attribute_from_chain(
    document,
    pattern,
    "viewBox",
    [],
  )
  let preserve_fact = pattern_attribute_from_chain(
    document,
    pattern,
    "preserveAspectRatio",
    [],
  )
  let mut viewport_complete = true
  let mut view_box_signature = "none"
  let mut child_viewport : ViewportContext = if content_units.value ==
    "objectBoundingBox" {
    { width: 1.0, height: 1.0 }
  } else {
    subject.map(subject => subject.viewport).unwrap_or(viewport)
  }
  let content_matrix = match view_box_fact {
    Some(fact) =>
      match parse_view_box_value(fact.declared_value) {
        Some(view_box) => {
          view_box_signature = normalized_view_box_signature(view_box)
          for index, field in fields {
            if field.name == "patternContentUnits" {
              fields[index] = { ..field, value: "ignored_by_viewBox" }
              break
            }
          }
          let preserve = match preserve_fact {
            Some(preserve_fact) =>
              match
                parse_preserve_aspect_ratio_value(preserve_fact.declared_value) {
                Some(value) => value
                None => {
                  viewport_complete = false
                  push_pattern_issue(
                    document.issues,
                    "pattern_viewport_syntax_unsupported",
                    pattern.subject_id,
                    Some(preserve_fact),
                  )
                  default_preserve_aspect_ratio()
                }
              }
            None => default_preserve_aspect_ratio()
          }
          fields.push(
            computed_pattern_field(
              "preserveAspectRatio",
              preserve_aspect_ratio_signature(preserve),
              None,
              preserve_fact,
              viewport_complete,
            ),
          )
          child_viewport = { width: view_box.width, height: view_box.height }
          tile_matrix.multiply(
            equivalent_viewport_transform(
              view_box, x, y, width, height, preserve,
            ),
          )
        }
        None => {
          viewport_complete = false
          push_pattern_issue(
            document.issues,
            "pattern_viewport_syntax_unsupported",
            pattern.subject_id,
            Some(fact),
          )
          tile_matrix
        }
      }
    None => {
      if preserve_fact is Some(_) {
        fields.push(
          computed_pattern_field(
            "preserveAspectRatio",
            "ignored_without_viewBox",
            None,
            preserve_fact,
            true,
          ),
        )
      }
      pattern_coordinate_base(content_units.value, transform, subject).0
    }
  }
  fields.push(
    computed_pattern_field(
      "viewBox",
      view_box_signature,
      None,
      view_box_fact,
      viewport_complete,
    ),
  )
  let children = computed_pattern_children(
    document, pattern, child_viewport, content_matrix,
  )
  let chain = pattern_template_chain(document, pattern)
  let mut complete = coordinate_complete &&
    viewport_complete &&
    fields.all(field => field.complete) &&
    children.all(child => child.complete)
  if !coordinate_complete {
    push_pattern_issue(
      document.issues,
      "pattern_target_bounds_unavailable",
      pattern.subject_id,
      None,
    )
  }
  if document.issues.any(issue => chain.contains(issue.subject_id)) {
    complete = false
  }
  let paint_mode = if empty_bbox_mode != "" {
    empty_bbox_mode
  } else if width == 0.0 || height == 0.0 {
    "none_zero_tile"
  } else if children.is_empty() {
    "none_empty_content"
  } else {
    "pattern"
  }
  {
    template_chain: chain,
    fields,
    children,
    tile_matrix,
    content_matrix,
    paint_mode,
    complete,
  }
}

///|
pub fn resolve_pattern_by_id(
  document : PatternDocument,
  id : String,
  subject : SourceSubject?,
) -> PatternSemanticResolution {
  match pattern_by_id(document, id) {
    Some(pattern) =>
      PatternResolved(resolve_computed_pattern(document, pattern, subject))
    None => PatternUnavailable
  }
}

///|
pub fn ComputedPattern::signature(self : ComputedPattern) -> String {
  let mut result = "mode=\{self.paint_mode}|tile=\{self.tile_matrix.signature()}|content=\{self.content_matrix.signature()}"
  for field in self.fields {
    if field.name != "patternTransform" {
      result += "|\{field.name}=\{field.value}"
    }
  }
  for child in self.children {
    result += "|child=\{child.signature}"
  }
  result
}
