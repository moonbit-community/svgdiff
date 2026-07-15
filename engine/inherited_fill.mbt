///|
priv struct FillSourceElement {
  subject_id : String
  kind : String
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
    | "defs"
    | "linearGradient"
    | "stop"
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
  visual_subject_kind(kind)
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
    "color", "fill", "stroke", "stroke-width", "stroke-linecap", "stroke-linejoin",
    "stroke-miterlimit", "stroke-dasharray", "stroke-dashoffset", "marker-start",
    "marker-mid", "marker-end",
  ]
}

///|
fn resolved_visual_properties() -> Array[String] {
  [
    "x", "y", "width", "height", "rx", "ry", "cx", "cy", "r", "x1", "y1", "x2", "y2",
    "points", "stop-color", "stop-opacity", "color", "fill", "stroke", "stroke-width",
    "stroke-linecap", "stroke-linejoin", "stroke-miterlimit", "stroke-dasharray",
    "stroke-dashoffset", "vector-effect", "opacity", "marker", "marker-start", "marker-mid",
    "marker-end",
  ]
}

///|
fn resolved_style_property(property : String) -> Bool {
  supported_css_declaration_property(property)
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
    } else if resolved_style_property(property) {
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
        if resolved_style_property(candidate.declaration.property) {
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
    if resolved_style_property(candidate.declaration.property) {
      candidates.push(candidate)
    }
  }
  if !stylesheet_match.complete {
    push_unique(coverage_codes, "css_cascade_unsupported")
  }
  let declarations = cascade_visual_declarations(candidates)
  for fact in declarations {
    let value = fact.declared_value.to_lower()
    if value == "revert-layer" {
      push_unique(coverage_codes, "css_revert_layer_unsupported")
    } else if fact.property == "fill" || fact.property == "stroke" {
      if value.find("url(") is Some(_) {
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
    kind,
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
    "color" => "black"
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
    "stop-color" => "black"
    "stop-opacity" => "1"
    "x" | "y" | "cx" | "cy" | "x1" | "y1" | "x2" | "y2" | "r" => "0"
    "width" | "height" | "rx" | "ry" => "auto"
    "points" => ""
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
priv struct StyleDependency {
  owner_id : String
  property : String
}

///|
priv struct ComputedVisualResolution {
  reported : ResolvedVisualFact
  computed_fact : DeclaredVisualFact?
  dependencies : Array[StyleDependency]
  complete : Bool
}

///|
priv struct CustomValueResolution {
  value : String?
  dependencies : Array[StyleDependency]
  complete : Bool
}

///|
priv enum CssSubstitutionResult {
  Substituted(String, Array[StyleDependency])
  InvalidSubstitution(Array[StyleDependency])
  UnsupportedSubstitution(Array[StyleDependency])
}

///|
fn append_style_dependency(
  dependencies : Array[StyleDependency],
  dependency : StyleDependency,
) -> Unit {
  if !dependencies.any(current => {
      current.owner_id == dependency.owner_id &&
      current.property == dependency.property
    }) {
    dependencies.push(dependency)
  }
}

///|
fn append_style_dependencies(
  target : Array[StyleDependency],
  source : Array[StyleDependency],
) -> Unit {
  for dependency in source {
    append_style_dependency(target, dependency)
  }
}

///|
fn custom_property_declaration(
  element : FillSourceElement,
  property : String,
) -> DeclaredVisualFact? {
  declared_fact_in_array(element.visual_declarations, property)
}

///|
fn var_function_at(value : String, index : Int) -> Bool {
  index + 4 <= value.length() &&
  source_range_slice(value, index, index + 4).to_lower() == "var("
}

///|
fn resolve_custom_property(
  hierarchy : FillHierarchy,
  element_index : Int,
  property : String,
  stack : Array[String],
) -> CustomValueResolution {
  let key = "\{element_index}:\{property}"
  if stack.contains(key) {
    return { value: None, dependencies: [], complete: true }
  }
  if stack.length() >= 64 {
    push_unique(hierarchy.coverage_codes, "css_variable_expansion_limit")
    return { value: None, dependencies: [], complete: false }
  }
  stack.push(key)
  let element = hierarchy.elements[element_index]
  let result = match custom_property_declaration(element, property) {
    None =>
      match element.parent_index {
        Some(parent) =>
          resolve_custom_property(hierarchy, parent, property, stack)
        None => { value: None, dependencies: [], complete: true }
      }
    Some(declaration) => {
      let dependencies = [{ owner_id: element.subject_id, property }]
      let keyword = declaration.declared_value.trim().to_owned().to_lower()
      if keyword == "initial" {
        { value: None, dependencies, complete: true }
      } else if keyword == "inherit" ||
        keyword == "unset" ||
        keyword == "revert" {
        match element.parent_index {
          Some(parent) => {
            let inherited = resolve_custom_property(
              hierarchy, parent, property, stack,
            )
            append_style_dependencies(dependencies, inherited.dependencies)
            {
              value: inherited.value,
              dependencies,
              complete: inherited.complete,
            }
          }
          None => { value: None, dependencies, complete: true }
        }
      } else if keyword == "revert-layer" {
        push_unique(hierarchy.coverage_codes, "css_revert_layer_unsupported")
        { value: None, dependencies, complete: false }
      } else {
        match
          substitute_css_variables(
            hierarchy,
            element_index,
            declaration.declared_value,
            stack,
          ) {
          Substituted(value, referenced) => {
            append_style_dependencies(dependencies, referenced)
            if value.length() > 65536 {
              push_unique(
                hierarchy.coverage_codes,
                "css_variable_expansion_limit",
              )
              { value: None, dependencies, complete: false }
            } else {
              { value: Some(value), dependencies, complete: true }
            }
          }
          InvalidSubstitution(referenced) => {
            append_style_dependencies(dependencies, referenced)
            { value: None, dependencies, complete: true }
          }
          UnsupportedSubstitution(referenced) => {
            append_style_dependencies(dependencies, referenced)
            { value: None, dependencies, complete: false }
          }
        }
      }
    }
  }
  ignore(stack.pop())
  result
}

///|
fn substitute_css_variables(
  hierarchy : FillHierarchy,
  element_index : Int,
  value : String,
  stack : Array[String],
) -> CssSubstitutionResult {
  let dependencies : Array[StyleDependency] = []
  let mut result = ""
  let mut position = 0
  while position < value.length() {
    if value[position] == '"' ||
      value[position] == '\'' ||
      value[position] == '\\' {
      push_unique(hierarchy.coverage_codes, "css_variable_syntax_unsupported")
      return UnsupportedSubstitution(dependencies)
    }
    if !var_function_at(value, position) {
      result += source_range_slice(value, position, position + 1)
      position += 1
      continue
    }
    let argument_start = position + 4
    let mut cursor = argument_start
    let mut depth = 1
    let mut comma = -1
    while cursor < value.length() && depth > 0 {
      if value[cursor] == '(' {
        depth += 1
      } else if value[cursor] == ')' {
        depth -= 1
      } else if value[cursor] == ',' && depth == 1 && comma < 0 {
        comma = cursor
      }
      cursor += 1
    }
    if depth != 0 {
      push_unique(hierarchy.coverage_codes, "css_variable_syntax_unsupported")
      return UnsupportedSubstitution(dependencies)
    }
    let argument_end = if comma < 0 { cursor - 1 } else { comma }
    let name_range = trim_range(value, argument_start, argument_end)
    let name = source_range_slice(value, name_range.0, name_range.1)
    if !css_custom_property_name(name) {
      push_unique(hierarchy.coverage_codes, "css_variable_syntax_unsupported")
      return UnsupportedSubstitution(dependencies)
    }
    let custom = resolve_custom_property(hierarchy, element_index, name, stack)
    append_style_dependencies(dependencies, custom.dependencies)
    if !custom.complete {
      return UnsupportedSubstitution(dependencies)
    }
    match custom.value {
      Some(replacement) => result += replacement
      None if comma >= 0 => {
        let fallback = source_range_slice(value, comma + 1, cursor - 1)
        match
          substitute_css_variables(hierarchy, element_index, fallback, stack) {
          Substituted(replacement, fallback_dependencies) => {
            append_style_dependencies(dependencies, fallback_dependencies)
            result += replacement
          }
          InvalidSubstitution(fallback_dependencies) => {
            append_style_dependencies(dependencies, fallback_dependencies)
            return InvalidSubstitution(dependencies)
          }
          UnsupportedSubstitution(fallback_dependencies) => {
            append_style_dependencies(dependencies, fallback_dependencies)
            return UnsupportedSubstitution(dependencies)
          }
        }
      }
      None => return InvalidSubstitution(dependencies)
    }
    position = cursor
    if result.length() > 65536 {
      push_unique(hierarchy.coverage_codes, "css_variable_expansion_limit")
      return UnsupportedSubstitution(dependencies)
    }
  }
  Substituted(result.trim().to_owned(), dependencies)
}

///|
fn computed_fact_from_resolution(
  property : String,
  value : String,
  declaration : DeclaredVisualFact?,
) -> DeclaredVisualFact? {
  match declaration {
    Some(declaration) =>
      Some({ ..declaration, property, declared_value: value })
    None => None
  }
}

///|
fn substituted_paint_value_valid(property : String, value : String) -> Bool {
  let normalized = value.trim().to_owned().to_lower()
  if property != "color" && normalized == "none" {
    return true
  }
  if normalized.has_prefix("#") {
    let digits = normalized.length() - 1
    return digits == 3 || digits == 4 || digits == 6 || digits == 8
  }
  if normalized.has_prefix("rgb(") ||
    normalized.has_prefix("rgba(") ||
    normalized.has_prefix("hsl(") ||
    normalized.has_prefix("hsla(") {
    return normalized.has_suffix(")")
  }
  if parse_svg_length(
      normalized,
      Unspecified,
      { width: 16.0, height: 16.0 },
      ComparisonProfile::v1_default(),
    )
    is Some(_) {
    return false
  }
  normalized != "" &&
  normalized.all(code => (code >= 'a' && code <= 'z') || code == '-')
}

///|
fn substituted_visual_value_valid(property : String, value : String) -> Bool {
  let normalized = value.trim().to_owned().to_lower()
  let profile = ComparisonProfile::v1_default()
  let viewport : ViewportContext = { width: 16.0, height: 16.0 }
  match property {
    "fill" | "stroke" | "color" | "stop-color" =>
      substituted_paint_value_valid(property, normalized)
    "x" | "y" | "cx" | "cy" | "x1" | "y1" | "x2" | "y2" =>
      parse_svg_length(
        normalized,
        basic_shape_length_direction(property),
        viewport,
        profile,
      )
      is Some(_)
    "width" | "height" | "rx" | "ry" =>
      normalized == "auto" ||
      (match
        parse_svg_length(
          normalized,
          basic_shape_length_direction(property),
          viewport,
          profile,
        ) {
        Some(number) => number >= 0.0
        None => false
      })
    "r" =>
      match parse_svg_length(normalized, Horizontal, viewport, profile) {
        Some(number) => number >= 0.0
        None => false
      }
    "points" => {
      let (_, complete, _) = parse_shape_points(normalized)
      complete
    }
    "stroke-width" =>
      match parse_svg_length(normalized, Unspecified, viewport, profile) {
        Some(number) => number >= 0.0
        None => false
      }
    "stroke-linecap" => ["butt", "round", "square"].contains(normalized)
    "stroke-linejoin" =>
      ["miter", "miter-clip", "round", "bevel", "arcs"].contains(normalized)
    "stroke-miterlimit" =>
      match parse_shape_number(normalized) {
        Some(number) => number >= 1.0
        None => false
      }
    "stroke-dasharray" =>
      if normalized == "none" {
        true
      } else {
        let (values, complete) = parse_stroke_dasharray_with_context(
          normalized, viewport, profile,
        )
        complete && values.all(value => value >= 0.0)
      }
    "stroke-dashoffset" =>
      parse_svg_length(normalized, Unspecified, viewport, profile) is Some(_)
    "vector-effect" =>
      normalized == "none" || normalized == "non-scaling-stroke"
    "opacity" => parse_shape_number(normalized) is Some(_)
    "stop-opacity" => parse_shape_number(normalized) is Some(_)
    "marker" | "marker-start" | "marker-mid" | "marker-end" =>
      normalized == "none" || canonical_marker_reference(normalized) is Some(_)
    _ => false
  }
}

///|
fn initial_computed_visual(
  subject_id : String,
  property : String,
  declaration : DeclaredVisualFact?,
  resolution : String,
  dependencies : Array[StyleDependency],
) -> ComputedVisualResolution {
  let value = initial_visual_value(property)
  {
    reported: {
      subject_id,
      property,
      resolved_value: value,
      resolution,
      declaration_owner_id: match declaration {
        Some(_) => Some(subject_id)
        None => None
      },
      declaration,
      inheritance_depth: 0,
    },
    computed_fact: computed_fact_from_resolution(property, value, declaration),
    dependencies,
    complete: true,
  }
}

///|
fn inherited_computed_visual(
  hierarchy : FillHierarchy,
  element_index : Int,
  property : String,
) -> ComputedVisualResolution {
  let element = hierarchy.elements[element_index]
  match element.parent_index {
    Some(parent_index) => {
      let parent = computed_visual_for_index(hierarchy, parent_index, property)
      let parent_report = parent.reported
      if parent_report.declaration is None {
        initial_computed_visual(element.subject_id, property, None, "initial", [])
      } else {
        let computed_fact = computed_fact_from_resolution(
          property,
          parent_report.resolved_value,
          parent_report.declaration,
        )
        {
          reported: {
            ..parent_report,
            subject_id: element.subject_id,
            property,
            resolution: "inherited",
            inheritance_depth: parent_report.inheritance_depth + 1,
          },
          computed_fact,
          dependencies: parent.dependencies,
          complete: parent.complete,
        }
      }
    }
    None =>
      initial_computed_visual(element.subject_id, property, None, "initial", [])
  }
}

///|
fn explicit_defaulted_visual(
  hierarchy : FillHierarchy,
  element_index : Int,
  property : String,
  declaration : DeclaredVisualFact,
  keyword : String,
  dependencies : Array[StyleDependency],
) -> ComputedVisualResolution {
  let element = hierarchy.elements[element_index]
  let inherit_value = keyword == "inherit" ||
    (
      (keyword == "unset" || keyword == "revert") &&
      inherited_visual_properties().contains(property)
    )
  if !inherit_value {
    return initial_computed_visual(
      element.subject_id,
      property,
      Some(declaration),
      "explicit_\{keyword}_initial",
      dependencies,
    )
  }
  if element.parent_index is None {
    return initial_computed_visual(
      element.subject_id,
      property,
      Some(declaration),
      "explicit_\{keyword}_initial",
      dependencies,
    )
  }
  let inherited = inherited_computed_visual(hierarchy, element_index, property)
  append_style_dependencies(dependencies, inherited.dependencies)
  let value = inherited.reported.resolved_value
  {
    reported: {
      subject_id: element.subject_id,
      property,
      resolved_value: value,
      resolution: "explicit_\{keyword}_inherit",
      declaration_owner_id: Some(element.subject_id),
      declaration: Some(declaration),
      inheritance_depth: 0,
    },
    computed_fact: computed_fact_from_resolution(
      property,
      value,
      Some(declaration),
    ),
    dependencies,
    complete: inherited.complete,
  }
}

///|
fn computed_visual_for_index(
  hierarchy : FillHierarchy,
  index : Int,
  property : String,
) -> ComputedVisualResolution {
  let element = hierarchy.elements[index]
  match local_visual_declaration(element, property) {
    None if inherited_visual_properties().contains(property) =>
      inherited_computed_visual(hierarchy, index, property)
    None =>
      initial_computed_visual(element.subject_id, property, None, "initial", [])
    Some(declaration) => {
      let dependencies = [{ owner_id: element.subject_id, property }]
      let had_variable = declaration.declared_value.to_lower().find("var(")
        is Some(_)
      let substitution = substitute_css_variables(
        hierarchy,
        index,
        declaration.declared_value,
        [],
      )
      let (value, complete) = match substitution {
        Substituted(value, referenced) => {
          append_style_dependencies(dependencies, referenced)
          (value, true)
        }
        InvalidSubstitution(referenced) => {
          append_style_dependencies(dependencies, referenced)
          let defaulted = explicit_defaulted_visual(
            hierarchy, index, property, declaration, "unset", dependencies,
          )
          return defaulted
        }
        UnsupportedSubstitution(referenced) => {
          append_style_dependencies(dependencies, referenced)
          (declaration.declared_value, false)
        }
      }
      let keyword = value.trim().to_owned().to_lower()
      if keyword == "revert-layer" {
        push_unique(hierarchy.coverage_codes, "css_revert_layer_unsupported")
        return {
          ..initial_computed_visual(
            element.subject_id,
            property,
            Some(declaration),
            "unsupported_revert_layer",
            dependencies,
          ),
          complete: false,
        }
      }
      if keyword == "inherit" ||
        keyword == "initial" ||
        keyword == "unset" ||
        keyword == "revert" {
        return explicit_defaulted_visual(
          hierarchy, index, property, declaration, keyword, dependencies,
        )
      }
      if property == "color" && keyword == "currentcolor" {
        return explicit_defaulted_visual(
          hierarchy, index, property, declaration, "inherit", dependencies,
        )
      }
      if (
          property == "fill" || property == "stroke" || property == "stop-color"
        ) &&
        keyword == "currentcolor" {
        let color = computed_visual_for_index(hierarchy, index, "color")
        append_style_dependencies(dependencies, color.dependencies)
        let resolved = color.reported.resolved_value
        return {
          reported: {
            subject_id: element.subject_id,
            property,
            resolved_value: resolved,
            resolution: "current_color",
            declaration_owner_id: Some(element.subject_id),
            declaration: Some(declaration),
            inheritance_depth: 0,
          },
          computed_fact: computed_fact_from_resolution(
            property,
            resolved,
            Some(declaration),
          ),
          dependencies,
          complete: complete && color.complete,
        }
      }
      if had_variable && !substituted_visual_value_valid(property, value) {
        return explicit_defaulted_visual(
          hierarchy, index, property, declaration, "unset", dependencies,
        )
      }
      {
        reported: {
          subject_id: element.subject_id,
          property,
          resolved_value: value,
          resolution: "local",
          declaration_owner_id: Some(element.subject_id),
          declaration: Some(declaration),
          inheritance_depth: 0,
        },
        computed_fact: computed_fact_from_resolution(
          property,
          value,
          Some(declaration),
        ),
        dependencies,
        complete,
      }
    }
  }
}

///|
fn computed_visual_for_subject(
  hierarchy : FillHierarchy,
  subject_id : String,
  property : String,
) -> ComputedVisualResolution? {
  match fill_source_element(hierarchy, subject_id) {
    Some((index, _)) =>
      Some(computed_visual_for_index(hierarchy, index, property))
    None => None
  }
}

///|
fn resolved_visual_for_subject(
  hierarchy : FillHierarchy,
  subject_id : String,
  property : String,
) -> ResolvedVisualFact? {
  match computed_visual_for_subject(hierarchy, subject_id, property) {
    Some(resolution) => Some(resolution.reported)
    None => None
  }
}

///|
fn computed_visual_facts_for_subject(
  hierarchy : FillHierarchy,
  subject_id : String,
) -> Array[DeclaredVisualFact] {
  let facts : Array[DeclaredVisualFact] = []
  for property in resolved_visual_properties() {
    match computed_visual_for_subject(hierarchy, subject_id, property) {
      Some(resolution) =>
        match resolution.computed_fact {
          Some(fact) => upsert_declared_fact(facts, fact)
          None => ()
        }
      _ => ()
    }
  }
  facts
}

///|
fn renderer_computed_override_facts_for_subject(
  hierarchy : FillHierarchy,
  subject_id : String,
) -> Array[DeclaredVisualFact] {
  let facts : Array[DeclaredVisualFact] = []
  for property in resolved_visual_properties() {
    match computed_visual_for_subject(hierarchy, subject_id, property) {
      Some({ reported, computed_fact: Some(fact), complete: true, .. }) => {
        let declared_value_differs = match reported.declaration {
          Some(declaration) =>
            declaration.declared_value != reported.resolved_value
          None => false
        }
        let needs_override = reported.resolution == "inherited" ||
          declared_value_differs
        if needs_override {
          upsert_declared_fact(facts, fact)
        }
      }
      _ => ()
    }
  }
  facts
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
      if property == "color" {
        continue
      }
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
      if property == "color" {
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
    schema_version: "1.15",
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

///|
fn first_hierarchy_subject_id(
  hierarchy : FillHierarchy,
  kind : String,
) -> String? {
  for element in hierarchy.elements {
    if element.kind == kind {
      return Some(element.subject_id)
    }
  }
  None
}

///|
fn gradient_style_changed_facts(
  before_svg : String,
  after_svg : String,
) -> Array[ChangedFact] {
  guard extract_fill_hierarchy(before_svg) is ParsedFillHierarchy(before) else {
    return []
  }
  guard extract_fill_hierarchy(after_svg) is ParsedFillHierarchy(after) else {
    return []
  }
  let before_stop = first_hierarchy_subject_id(before, "stop")
  let after_stop = first_hierarchy_subject_id(after, "stop")
  [
    for fact in compare_changed_visual_facts(before, after) if before_stop
    .map(id => fact.affected_subject_ids.contains(id))
    .unwrap_or(false) ||
    after_stop
    .map(id => fact.affected_subject_ids.contains(id))
    .unwrap_or(false) => fact
  ]
}
