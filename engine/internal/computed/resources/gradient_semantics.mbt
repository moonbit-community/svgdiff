///|
pub(all) struct GradientAttributeSource {
  name : String
  fact : DeclaredVisualFact
}

///|
pub(all) struct GradientStopSource {
  subject_id : String
  hierarchy_index : Int
  offset_fact : DeclaredVisualFact?
}

///|
pub(all) struct GradientSource {
  subject_id : String
  authored_id : String?
  kind : String
  hierarchy_index : Int
  source_index : Int
  attributes : Array[GradientAttributeSource]
  href_fact : DeclaredVisualFact?
  stops : Array[GradientStopSource]
  mut has_non_descriptive_child : Bool
}

///|
pub(all) struct GradientSemanticIssue {
  code : String
  subject_id : String
  fact : DeclaredVisualFact?
}

///|
pub(all) struct GradientDocument {
  profile : ComparisonProfile
  hierarchy : FillHierarchy
  gradients : Array[GradientSource]
  issues : Array[GradientSemanticIssue]
}

///|
pub(all) struct ComputedGradientStop {
  subject_id : String
  offset : Double
  color : @css_color.SrgbaColor
  stop_opacity : Double
  effective_alpha : Double
  offset_fact : DeclaredVisualFact?
  color_fact : DeclaredVisualFact?
  opacity_fact : DeclaredVisualFact?
  dependencies : Array[StyleDependency]
  complete : Bool
}

///|
pub(all) struct ComputedGradientField {
  name : String
  value : String
  number : Double?
  fact : DeclaredVisualFact?
  complete : Bool
}

///|
pub(all) struct ComputedGradient {
  kind : String
  template_chain : Array[String]
  fields : Array[ComputedGradientField]
  stops : Array[ComputedGradientStop]
  units : String
  spread_method : String
  coordinate_transform : AffineTransform
  paint_mode : String
  complete : Bool
}

///|
pub(all) enum GradientSemanticResolution {
  GradientResolved(ComputedGradient)
  GradientUnavailable
}

///|
pub fn gradient_attribute_names(kind : String) -> Array[String] {
  if kind == "linearGradient" {
    [
      "x1", "y1", "x2", "y2", "gradientUnits", "gradientTransform", "spreadMethod",
    ]
  } else {
    [
      "cx", "cy", "r", "fx", "fy", "fr", "gradientUnits", "gradientTransform", "spreadMethod",
    ]
  }
}

///|
pub fn gradient_descriptive_child(kind : String) -> Bool {
  kind == "desc" || kind == "title" || kind == "metadata"
}

///|
pub fn gradient_dynamic_child(kind : String) -> Bool {
  kind == "animate" ||
  kind == "animateTransform" ||
  kind == "set" ||
  kind == "script"
}

///|
pub fn gradient_hierarchy_index(
  hierarchy : FillHierarchy,
  kind : String,
  source_offset : Int,
) -> Int? {
  for index, element in hierarchy.elements {
    if element.kind == kind && element.source_offset == source_offset {
      return Some(index)
    }
  }
  None
}

///|
pub fn gradient_source_attribute(
  input : String,
  attribute : @xml.NamespaceAttribute,
  property : String,
) -> GradientAttributeSource {
  { name: property, fact: presentation_fact(input, property, attribute) }
}

///|
pub fn preferred_gradient_href(
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
pub fn gradient_source_from_element(
  input : String,
  element : @xml.NamespaceElement,
  source_index : Int,
  hierarchy : FillHierarchy,
) -> GradientSource? {
  let kind = element.name.local_name
  if kind != "linearGradient" && kind != "radialGradient" {
    return None
  }
  guard gradient_hierarchy_index(hierarchy, kind, source_index)
    is Some(hierarchy_index) else {
    return None
  }
  let hierarchy_element = hierarchy.elements[hierarchy_index]
  let names = gradient_attribute_names(kind)
  let attributes : Array[GradientAttributeSource] = []
  for attribute in element.attributes {
    let name = attribute.name.local_name
    if names.contains(name) {
      attributes.push(gradient_source_attribute(input, attribute, name))
    }
  }
  Some({
    subject_id: hierarchy_element.subject_id,
    authored_id: authored_subject_id(element),
    kind,
    hierarchy_index,
    source_index,
    attributes,
    href_fact: preferred_gradient_href(input, element),
    stops: [],
    has_non_descriptive_child: false,
  })
}

///|
pub fn gradient_stop_from_element(
  input : String,
  element : @xml.NamespaceElement,
  source_index : Int,
  hierarchy : FillHierarchy,
) -> GradientStopSource? {
  guard gradient_hierarchy_index(hierarchy, "stop", source_index)
    is Some(hierarchy_index) else {
    return None
  }
  let mut offset_fact : DeclaredVisualFact? = None
  for attribute in element.attributes {
    if attribute.name.local_name == "offset" {
      offset_fact = Some(presentation_fact(input, "offset", attribute))
    }
  }
  Some({
    subject_id: hierarchy.elements[hierarchy_index].subject_id,
    hierarchy_index,
    offset_fact,
  })
}

///|
pub fn push_gradient_issue(
  issues : Array[GradientSemanticIssue],
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
pub fn append_gradient_color_interpolation_facts(
  source : String,
  element : @xml.NamespaceElement,
  facts : Array[DeclaredVisualFact],
) -> Unit {
  for attribute in element.attributes {
    if attribute.name.local_name == "color-interpolation" {
      facts.push(presentation_fact(source, "color-interpolation", attribute))
    } else if attribute.name.local_name == "style" {
      for fact in inline_style_facts(source, attribute).facts {
        if fact.property == "color-interpolation" {
          facts.push(fact)
        }
      }
    }
  }
}

///|
pub fn extract_gradient_document_or_raise(
  source : String,
  profile : ComparisonProfile,
) -> GradientDocument raise {
  let hierarchy = extract_fill_hierarchy_or_raise(source)
  let gradients : Array[GradientSource] = []
  let issues : Array[GradientSemanticIssue] = []
  let color_interpolation_facts : Array[DeclaredVisualFact] = []
  let mut current_gradient : Int? = None
  let mut gradient_depth = 0
  let reader = @xml.NamespaceReader::from_string(source)
  for event in reader.read_events_until_eof() {
    match event.kind {
      Start(element) => {
        append_gradient_color_interpolation_facts(
          source, element, color_interpolation_facts,
        )
        let kind = element.name.local_name
        match current_gradient {
          Some(index) => {
            gradient_depth += 1
            if gradient_depth == 2 {
              if kind == "stop" {
                match
                  gradient_stop_from_element(
                    source,
                    element,
                    event.span.start.offset,
                    hierarchy,
                  ) {
                  Some(stop) => {
                    gradients[index].stops.push(stop)
                    gradients[index].has_non_descriptive_child = true
                  }
                  None => ()
                }
              } else if !gradient_descriptive_child(kind) {
                gradients[index].has_non_descriptive_child = true
                if gradient_dynamic_child(kind) {
                  push_gradient_issue(
                    issues,
                    "gradient_dynamic_content_unsupported",
                    gradients[index].subject_id,
                    None,
                  )
                }
              }
            }
          }
          None =>
            match
              gradient_source_from_element(
                source,
                element,
                event.span.start.offset,
                hierarchy,
              ) {
              Some(gradient) => {
                gradients.push(gradient)
                current_gradient = Some(gradients.length() - 1)
                gradient_depth = 1
              }
              None => ()
            }
        }
      }
      Empty(element) => {
        append_gradient_color_interpolation_facts(
          source, element, color_interpolation_facts,
        )
        let kind = element.name.local_name
        match current_gradient {
          Some(index) if gradient_depth == 1 =>
            if kind == "stop" {
              match
                gradient_stop_from_element(
                  source,
                  element,
                  event.span.start.offset,
                  hierarchy,
                ) {
                Some(stop) => {
                  gradients[index].stops.push(stop)
                  gradients[index].has_non_descriptive_child = true
                }
                None => ()
              }
            } else if !gradient_descriptive_child(kind) {
              gradients[index].has_non_descriptive_child = true
              if gradient_dynamic_child(kind) {
                push_gradient_issue(
                  issues,
                  "gradient_dynamic_content_unsupported",
                  gradients[index].subject_id,
                  None,
                )
              }
            }
          None =>
            match
              gradient_source_from_element(
                source,
                element,
                event.span.start.offset,
                hierarchy,
              ) {
              Some(gradient) => gradients.push(gradient)
              None => ()
            }
          _ => ()
        }
      }
      End(_) =>
        match current_gradient {
          Some(_) => {
            gradient_depth -= 1
            if gradient_depth == 0 {
              current_gradient = None
            }
          }
          None => ()
        }
      _ => ()
    }
  }
  let stylesheets = parse_document_stylesheets_or_raise(source)
  for rule in stylesheets.rules {
    for candidate in rule.declarations {
      if candidate.declaration.property == "color-interpolation" {
        color_interpolation_facts.push(candidate.declaration)
      }
    }
  }
  for fact in color_interpolation_facts {
    if fact.declared_value.trim().to_owned().to_lower() != "srgb" {
      for gradient in gradients {
        push_gradient_issue(
          issues,
          "gradient_color_interpolation_unsupported",
          gradient.subject_id,
          Some(fact),
        )
      }
    }
  }
  { profile, hierarchy, gradients, issues }
}

///|
pub fn extract_gradient_document(
  source : String,
  profile : ComparisonProfile,
) -> GradientDocument? {
  try extract_gradient_document_or_raise(source, profile) catch {
    _ => None
  } noraise {
    document => Some(document)
  }
}

///|
pub fn gradient_by_id(
  document : GradientDocument,
  id : String,
) -> GradientSource? {
  for gradient in document.gradients {
    if gradient.authored_id == Some(id) {
      return Some(gradient)
    }
  }
  None
}

///|
pub fn gradient_source_attribute_fact(
  gradient : GradientSource,
  name : String,
) -> DeclaredVisualFact? {
  for attribute in gradient.attributes {
    if attribute.name == name {
      return Some(attribute.fact)
    }
  }
  None
}

///|
pub fn same_document_gradient_target(
  document : GradientDocument,
  gradient : GradientSource,
) -> GradientSource? {
  match gradient.href_fact {
    None => None
    Some(fact) => {
      let value = fact.declared_value.trim().to_owned()
      if !value.has_prefix("#") || value.length() <= 1 {
        push_gradient_issue(
          document.issues,
          "gradient_external_reference_unsupported",
          gradient.subject_id,
          Some(fact),
        )
        return None
      }
      let id = value.view(start_offset=1).to_owned()
      match gradient_by_id(document, id) {
        Some(target) => Some(target)
        None => {
          push_gradient_issue(
            document.issues,
            "gradient_reference_invalid",
            gradient.subject_id,
            Some(fact),
          )
          None
        }
      }
    }
  }
}

///|
pub fn gradient_attribute_from_chain(
  document : GradientDocument,
  gradient : GradientSource,
  name : String,
  stack : Array[String],
) -> DeclaredVisualFact? {
  match gradient_source_attribute_fact(gradient, name) {
    Some(fact) => return Some(fact)
    None => ()
  }
  if stack.contains(gradient.subject_id) {
    push_gradient_issue(
      document.issues,
      "gradient_reference_cycle",
      gradient.subject_id,
      gradient.href_fact,
    )
    return None
  }
  stack.push(gradient.subject_id)
  let result = match same_document_gradient_target(document, gradient) {
    Some(target) => gradient_attribute_from_chain(document, target, name, stack)
    None => None
  }
  ignore(stack.pop())
  result
}

///|
pub fn gradient_stop_provider(
  document : GradientDocument,
  gradient : GradientSource,
  stack : Array[String],
) -> GradientSource? {
  if gradient.has_non_descriptive_child {
    return Some(gradient)
  }
  if stack.contains(gradient.subject_id) {
    push_gradient_issue(
      document.issues,
      "gradient_reference_cycle",
      gradient.subject_id,
      gradient.href_fact,
    )
    return None
  }
  stack.push(gradient.subject_id)
  let provider = match same_document_gradient_target(document, gradient) {
    Some(target) => gradient_stop_provider(document, target, stack)
    None => None
  }
  ignore(stack.pop())
  provider
}

///|
pub fn gradient_template_chain(
  document : GradientDocument,
  gradient : GradientSource,
) -> Array[String] {
  let chain : Array[String] = []
  let mut current : GradientSource? = Some(gradient)
  while current is Some(_) && chain.length() <= document.gradients.length() {
    guard current is Some(value) else { break }
    if chain.contains(value.subject_id) {
      push_gradient_issue(
        document.issues,
        "gradient_reference_cycle",
        value.subject_id,
        value.href_fact,
      )
      break
    }
    chain.push(value.subject_id)
    current = same_document_gradient_target(document, value)
  }
  chain
}

///|
pub fn parse_gradient_offset(source : String) -> Double? {
  @css_color.parse_alpha_value(source)
}

///|
pub fn computed_gradient_stop(
  document : GradientDocument,
  host : GradientSource,
  source : GradientStopSource,
  stop_index : Int,
  minimum_offset : Double,
) -> ComputedGradientStop {
  let elements = document.hierarchy.elements.copy()
  let original = elements[source.hierarchy_index]
  elements.push({
    ..original,
    subject_id: "\{host.subject_id}:stop:\{stop_index}",
    parent_index: Some(host.hierarchy_index),
  })
  let hierarchy : FillHierarchy = { ..document.hierarchy, elements, }
  let index = elements.length() - 1
  let color_resolution = computed_visual_for_index(
    hierarchy, index, "stop-color",
  )
  let opacity_resolution = computed_visual_for_index(
    hierarchy, index, "stop-opacity",
  )
  let mut complete = color_resolution.complete && opacity_resolution.complete
  let dependencies = color_resolution.dependencies.copy()
  append_style_dependencies(dependencies, opacity_resolution.dependencies)
  let authored_offset = source.offset_fact
    .map(fact => parse_gradient_offset(fact.declared_value))
    .unwrap_or(Some(0.0))
  let offset = match authored_offset {
    Some(offset) => offset.max(minimum_offset)
    None => {
      complete = false
      push_gradient_issue(
        document.issues,
        "gradient_offset_syntax_unsupported",
        host.subject_id,
        source.offset_fact,
      )
      minimum_offset
    }
  }
  let color = match
    @css_color.parse_solid_color(color_resolution.reported.resolved_value) {
    Resolved(color) => color
    _ => {
      complete = false
      push_gradient_issue(
        document.issues,
        "solid_color_syntax_unsupported",
        host.subject_id,
        color_resolution.reported.declaration,
      )
      { red: 0, green: 0, blue: 0, alpha: 1.0 }
    }
  }
  let stop_opacity = match
    @css_color.parse_alpha_value(opacity_resolution.reported.resolved_value) {
    Some(value) => value
    None => {
      complete = false
      push_gradient_issue(
        document.issues,
        "opacity_syntax_unsupported",
        host.subject_id,
        opacity_resolution.reported.declaration,
      )
      1.0
    }
  }
  {
    subject_id: source.subject_id,
    offset,
    color,
    stop_opacity,
    effective_alpha: color.alpha * stop_opacity,
    offset_fact: source.offset_fact,
    color_fact: color_resolution.reported.declaration,
    opacity_fact: opacity_resolution.reported.declaration,
    dependencies,
    complete,
  }
}

///|
pub fn computed_gradient_stops(
  document : GradientDocument,
  gradient : GradientSource,
) -> Array[ComputedGradientStop] {
  guard gradient_stop_provider(document, gradient, []) is Some(provider) else {
    return []
  }
  let stops : Array[ComputedGradientStop] = []
  let mut minimum_offset = 0.0
  for index, source in provider.stops {
    let stop = computed_gradient_stop(
      document, gradient, source, index, minimum_offset,
    )
    minimum_offset = stop.offset
    stops.push(stop)
  }
  stops
}

///|
pub fn gradient_field(
  name : String,
  value : String,
  number : Double?,
  fact : DeclaredVisualFact?,
  complete : Bool,
) -> ComputedGradientField {
  { name, value, number, fact, complete }
}

///|
pub fn gradient_keyword_field(
  document : GradientDocument,
  gradient : GradientSource,
  name : String,
  initial : String,
  allowed : Array[String],
  diagnostic : String,
) -> ComputedGradientField {
  let fact = gradient_attribute_from_chain(document, gradient, name, [])
  let value = fact
    .map(fact => fact.declared_value.trim().to_owned())
    .unwrap_or(initial)
  if allowed.contains(value) {
    gradient_field(name, value, None, fact, true)
  } else {
    push_gradient_issue(document.issues, diagnostic, gradient.subject_id, fact)
    gradient_field(name, initial, None, fact, false)
  }
}

///|
pub fn gradient_length_field(
  document : GradientDocument,
  gradient : GradientSource,
  name : String,
  initial : String,
  direction : SvgLengthDirection,
  viewport : ViewportContext,
  nonnegative : Bool,
) -> ComputedGradientField {
  let fact = gradient_attribute_from_chain(document, gradient, name, [])
  let source = fact.map(fact => fact.declared_value).unwrap_or(initial)
  match parse_svg_length(source, direction, viewport, document.profile) {
    Some(value) if !nonnegative || value >= 0.0 =>
      gradient_field(
        name,
        canonical_shape_number(value),
        Some(value),
        fact,
        true,
      )
    _ => {
      push_gradient_issue(
        document.issues,
        "gradient_length_syntax_unsupported",
        gradient.subject_id,
        fact,
      )
      let fallback = parse_svg_length(
        initial,
        direction,
        viewport,
        document.profile,
      ).unwrap_or(0.0)
      gradient_field(
        name,
        canonical_shape_number(fallback),
        Some(fallback),
        fact,
        false,
      )
    }
  }
}

///|
pub fn gradient_transform_field(
  document : GradientDocument,
  gradient : GradientSource,
) -> (ComputedGradientField, AffineTransform) {
  let fact = gradient_attribute_from_chain(
    document,
    gradient,
    "gradientTransform",
    [],
  )
  match fact {
    None =>
      (
        gradient_field(
          "gradientTransform",
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
            gradient_field(
              "gradientTransform",
              transform.matrix.signature(),
              None,
              Some(fact),
              true,
            ),
            transform.matrix,
          )
        InvalidTransformList => {
          push_gradient_issue(
            document.issues,
            "gradient_transform_syntax_unsupported",
            gradient.subject_id,
            Some(fact),
          )
          (
            gradient_field(
              "gradientTransform",
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
pub fn computed_gradient_paint_mode(
  kind : String,
  fields : Array[ComputedGradientField],
  stops : Array[ComputedGradientStop],
) -> String {
  if stops.is_empty() {
    return "none_no_stops"
  }
  if stops.length() == 1 {
    return "solid_single_stop"
  }
  if kind == "linearGradient" {
    let x1 = computed_gradient_number(fields, "x1")
    let y1 = computed_gradient_number(fields, "y1")
    let x2 = computed_gradient_number(fields, "x2")
    let y2 = computed_gradient_number(fields, "y2")
    if x1 == x2 && y1 == y2 {
      "solid_degenerate_linear_last_stop"
    } else {
      "linear"
    }
  } else {
    let cx = computed_gradient_number(fields, "cx")
    let cy = computed_gradient_number(fields, "cy")
    let r = computed_gradient_number(fields, "r")
    let fx = computed_gradient_number(fields, "fx")
    let fy = computed_gradient_number(fields, "fy")
    let fr = computed_gradient_number(fields, "fr")
    let distance = @math.hypot(fx - cx, fy - cy)
    if r == 0.0 || distance + r <= fr {
      "none_overlapping_radial_circles"
    } else if distance + fr == r {
      "radial_tangent_focal_circle"
    } else {
      "radial"
    }
  }
}

///|
pub fn computed_gradient_number(
  fields : Array[ComputedGradientField],
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
pub fn gradient_coordinate_transform(
  units : String,
  gradient_transform : AffineTransform,
  subject : SourceSubject?,
) -> (AffineTransform, Bool, String) {
  let cumulative = subject
    .map(subject => subject.cumulative_transform)
    .unwrap_or(AffineTransform::identity())
  if units == "userSpaceOnUse" {
    return (
      cumulative.multiply(gradient_transform),
      subject.map(subject => subject.transform_complete).unwrap_or(true),
      "",
    )
  }
  let bounds = subject
    .map(source_subject_geometry_bounds)
    .unwrap_or(Some({ x: 0.0, y: 0.0, width: 1.0, height: 1.0 }))
  match bounds {
    Some(bounds) => {
      let implicit = AffineTransform::translate(bounds.x, bounds.y).multiply(
        AffineTransform::scale(bounds.width, bounds.height),
      )
      (
        cumulative.multiply(implicit.multiply(gradient_transform)),
        subject.map(subject => subject.transform_complete).unwrap_or(true),
        if bounds.width == 0.0 || bounds.height == 0.0 {
          "none_empty_object_bounding_box"
        } else {
          ""
        },
      )
    }
    None => (cumulative.multiply(gradient_transform), false, "")
  }
}

///|
pub fn resolve_computed_gradient(
  document : GradientDocument,
  gradient : GradientSource,
  subject : SourceSubject?,
) -> ComputedGradient {
  let units = gradient_keyword_field(
    document,
    gradient,
    "gradientUnits",
    "objectBoundingBox",
    ["objectBoundingBox", "userSpaceOnUse"],
    "gradient_units_syntax_unsupported",
  )
  let spread = gradient_keyword_field(
    document,
    gradient,
    "spreadMethod",
    "pad",
    ["pad", "reflect", "repeat"],
    "gradient_spread_method_syntax_unsupported",
  )
  let length_viewport : ViewportContext = if units.value == "objectBoundingBox" {
    { width: 1.0, height: 1.0 }
  } else {
    subject
    .map(subject => subject.viewport)
    .unwrap_or({
      width: document.profile.viewport_width.to_double(),
      height: document.profile.viewport_height.to_double(),
    })
  }
  let fields : Array[ComputedGradientField] = [units, spread]
  if gradient.kind == "linearGradient" {
    fields.push(
      gradient_length_field(
        document,
        gradient,
        "x1",
        "0%",
        Horizontal,
        length_viewport,
        false,
      ),
    )
    fields.push(
      gradient_length_field(
        document,
        gradient,
        "y1",
        "0%",
        Vertical,
        length_viewport,
        false,
      ),
    )
    fields.push(
      gradient_length_field(
        document,
        gradient,
        "x2",
        "100%",
        Horizontal,
        length_viewport,
        false,
      ),
    )
    fields.push(
      gradient_length_field(
        document,
        gradient,
        "y2",
        "0%",
        Vertical,
        length_viewport,
        false,
      ),
    )
  } else {
    let cx = gradient_length_field(
      document,
      gradient,
      "cx",
      "50%",
      Horizontal,
      length_viewport,
      false,
    )
    let cy = gradient_length_field(
      document,
      gradient,
      "cy",
      "50%",
      Vertical,
      length_viewport,
      false,
    )
    fields.push(cx)
    fields.push(cy)
    fields.push(
      gradient_length_field(
        document,
        gradient,
        "r",
        "50%",
        Unspecified,
        length_viewport,
        true,
      ),
    )
    let fx_fact = gradient_attribute_from_chain(document, gradient, "fx", [])
    if fx_fact is Some(_) {
      fields.push(
        gradient_length_field(
          document,
          gradient,
          "fx",
          "50%",
          Horizontal,
          length_viewport,
          false,
        ),
      )
    } else {
      fields.push(
        gradient_field("fx", cx.value, cx.number, cx.fact, cx.complete),
      )
    }
    let fy_fact = gradient_attribute_from_chain(document, gradient, "fy", [])
    if fy_fact is Some(_) {
      fields.push(
        gradient_length_field(
          document,
          gradient,
          "fy",
          "50%",
          Vertical,
          length_viewport,
          false,
        ),
      )
    } else {
      fields.push(
        gradient_field("fy", cy.value, cy.number, cy.fact, cy.complete),
      )
    }
    fields.push(
      gradient_length_field(
        document,
        gradient,
        "fr",
        "0%",
        Unspecified,
        length_viewport,
        true,
      ),
    )
  }
  let (transform_field, gradient_transform) = gradient_transform_field(
    document, gradient,
  )
  fields.push(transform_field)
  let stops = computed_gradient_stops(document, gradient)
  let (coordinate_transform, coordinate_complete, empty_bbox_mode) = gradient_coordinate_transform(
    units.value,
    gradient_transform,
    subject,
  )
  let mut complete = coordinate_complete &&
    fields.all(field => field.complete) &&
    stops.all(stop => stop.complete)
  if !coordinate_complete {
    complete = false
    push_gradient_issue(
      document.issues,
      "gradient_target_bounds_unavailable",
      gradient.subject_id,
      None,
    )
  }
  let paint_mode = if empty_bbox_mode != "" {
    empty_bbox_mode
  } else {
    computed_gradient_paint_mode(gradient.kind, fields, stops)
  }
  let template_chain = gradient_template_chain(document, gradient)
  if document.issues.any(issue => template_chain.contains(issue.subject_id)) {
    complete = false
  }
  {
    kind: gradient.kind,
    template_chain,
    fields,
    stops,
    units: units.value,
    spread_method: spread.value,
    coordinate_transform,
    paint_mode,
    complete,
  }
}

///|
pub fn resolve_gradient_by_id(
  document : GradientDocument,
  id : String,
  subject : SourceSubject?,
) -> GradientSemanticResolution {
  match gradient_by_id(document, id) {
    Some(gradient) =>
      GradientResolved(resolve_computed_gradient(document, gradient, subject))
    None => GradientUnavailable
  }
}

///|
pub fn ComputedGradientStop::signature(self : ComputedGradientStop) -> String {
  "stop(\{self.offset},\{self.color.red},\{self.color.green},\{self.color.blue},\{self.effective_alpha})"
}

///|
pub fn ComputedGradient::signature(self : ComputedGradient) -> String {
  let mut signature = "\{self.kind}|units=\{self.units}|spread=\{self.spread_method}|mode=\{self.paint_mode}|matrix=\{self.coordinate_transform.signature()}"
  for field in self.fields {
    if field.name != "gradientUnits" &&
      field.name != "spreadMethod" &&
      field.name != "gradientTransform" {
      signature += "|\{field.name}=\{field.value}"
    }
  }
  for stop in self.stops {
    signature += "|\{stop.signature()}"
  }
  signature
}
