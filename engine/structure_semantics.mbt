///|
priv struct StructuralSourceNode {
  source_id : String
  kind : String
  source_offset : Int
  parent_index : Int?
  children : Array[Int]
  element : @xml.NamespaceElement
  definition_content : Bool
  href_fact : DeclaredVisualFact?
}

///|
priv struct StructuralDocument {
  nodes : Array[StructuralSourceNode]
  id_indices : Map[String, Int]
}

///|
priv struct RenderedSubjectPlan {
  source_node_index : Int
  rendered_ancestry : Array[Int]
  use_path : Array[String]
  instance_id : String?
  definition_subject_id : String
}

///|
fn structural_source_kind(kind : String) -> Bool {
  fill_hierarchy_kind(kind) || kind == "marker"
}

///|
fn structural_definition_container(kind : String) -> Bool {
  match kind {
    "defs"
    | "symbol"
    | "linearGradient"
    | "radialGradient"
    | "pattern"
    | "marker"
    | "clipPath" => true
    _ => false
  }
}

///|
fn structural_href_fact(
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
fn add_structural_source_node(
  input : String,
  element : @xml.NamespaceElement,
  source_offset : Int,
  parent_index : Int?,
  nodes : Array[StructuralSourceNode],
  id_indices : Map[String, Int],
) -> Int {
  let kind = element.name.local_name
  let source_id = authored_subject_id(element).unwrap_or(
    generated_subject_id(kind, source_offset),
  )
  let definition_content = structural_definition_container(kind) ||
    (match parent_index {
      Some(parent) => nodes[parent].definition_content
      None => false
    })
  let index = nodes.length()
  nodes.push({
    source_id,
    kind,
    source_offset,
    parent_index,
    children: [],
    element,
    definition_content,
    href_fact: structural_href_fact(input, element),
  })
  match parent_index {
    Some(parent) => nodes[parent].children.push(index)
    None => ()
  }
  match authored_subject_id(element) {
    Some(id) if id_indices.get(id) is None => id_indices[id] = index
    _ => ()
  }
  index
}

///|
fn extract_structural_document_or_raise(
  input : String,
) -> StructuralDocument raise {
  let nodes : Array[StructuralSourceNode] = []
  let id_indices : Map[String, Int] = Map([])
  let stack : Array[Int?] = []
  let reader = @xml.NamespaceReader::from_string(input)
  for event in reader.read_events_until_eof() {
    match event.kind {
      Start(element) => {
        let parent_index = match stack.last() {
          Some(value) => value
          None => None
        }
        if structural_source_kind(element.name.local_name) {
          let index = add_structural_source_node(
            input,
            element,
            event.span.start.offset,
            parent_index,
            nodes,
            id_indices,
          )
          stack.push(Some(index))
        } else {
          stack.push(parent_index)
        }
      }
      Empty(element) =>
        if structural_source_kind(element.name.local_name) {
          ignore(
            add_structural_source_node(
              input,
              element,
              event.span.start.offset,
              match stack.last() {
                Some(value) => value
                None => None
              },
              nodes,
              id_indices,
            ),
          )
        }
      End(_) => ignore(stack.pop())
      _ => ()
    }
  }
  { nodes, id_indices }
}

///|
fn use_target_index(
  document : StructuralDocument,
  node : StructuralSourceNode,
) -> Int? {
  guard node.kind == "use" else { return None }
  guard node.href_fact is Some(fact) else { return None }
  guard local_href_target(fact.declared_value) is Some(target_id) else {
    return None
  }
  document.id_indices.get(target_id)
}

///|
fn supported_use_target(kind : String) -> Bool {
  visual_subject_kind(kind) ||
  kind == "g" ||
  kind == "svg" ||
  kind == "symbol" ||
  kind == "use"
}

///|
fn rendered_instance_id(
  definition_subject_id : String,
  use_path : Array[String],
) -> String {
  let mut result = "instance"
  for use_id in use_path {
    result = "\{result}/\{use_id}"
  }
  "\{result}/\{definition_subject_id}"
}

///|
fn append_rendered_subject_plans(
  document : StructuralDocument,
  node_index : Int,
  rendered_ancestry : Array[Int],
  use_path : Array[String],
  plans : Array[RenderedSubjectPlan],
  active_use_targets : Array[Int],
) -> Unit {
  let node = document.nodes[node_index]
  if use_path.is_empty() && node.definition_content {
    return
  }
  let ancestry = rendered_ancestry.copy()
  ancestry.push(node_index)
  if visual_subject_kind(node.kind) {
    plans.push({
      source_node_index: node_index,
      rendered_ancestry: ancestry,
      use_path,
      instance_id: if use_path.is_empty() {
        None
      } else {
        Some(rendered_instance_id(node.source_id, use_path))
      },
      definition_subject_id: node.source_id,
    })
    return
  }
  if node.kind == "use" {
    guard use_target_index(document, node) is Some(target_index) else { return }
    guard supported_use_target(document.nodes[target_index].kind) else {
      return
    }
    guard !active_use_targets.contains(target_index) else { return }
    let nested_path = use_path.copy()
    nested_path.push(node.source_id)
    let active = active_use_targets.copy()
    active.push(target_index)
    append_rendered_subject_plans(
      document, target_index, ancestry, nested_path, plans, active,
    )
    return
  }
  for child in node.children {
    append_rendered_subject_plans(
      document, child, ancestry, use_path, plans, active_use_targets,
    )
  }
}

///|
fn rendered_subject_plans(
  document : StructuralDocument,
) -> Array[RenderedSubjectPlan] {
  let plans : Array[RenderedSubjectPlan] = []
  for index, node in document.nodes {
    if node.parent_index is None && !node.definition_content {
      append_rendered_subject_plans(document, index, [], [], plans, [])
    }
  }
  plans
}

///|
fn structural_same_kind_ordinal(
  document : StructuralDocument,
  node_index : Int,
) -> Int {
  let node = document.nodes[node_index]
  let mut ordinal = 0
  match node.parent_index {
    Some(parent_index) =>
      for sibling_index in document.nodes[parent_index].children {
        if sibling_index == node_index {
          break
        }
        if document.nodes[sibling_index].kind == node.kind {
          ordinal += 1
        }
      }
    None =>
      for sibling_index, sibling in document.nodes {
        if sibling_index == node_index {
          break
        }
        if sibling.parent_index is None && sibling.kind == node.kind {
          ordinal += 1
        }
      }
  }
  ordinal
}

///|
fn structural_path_segment(
  document : StructuralDocument,
  node_index : Int,
) -> String {
  let node = document.nodes[node_index]
  "\{node.kind}[\{structural_same_kind_ordinal(document, node_index)}]"
}

///|
fn structural_parent_path_signature(
  document : StructuralDocument,
  plan : RenderedSubjectPlan,
) -> String {
  let segments : Array[String] = []
  let parent_count = plan.rendered_ancestry.length() - 1
  for index in 0..<parent_count {
    segments.push(
      structural_path_segment(document, plan.rendered_ancestry[index]),
    )
  }
  segments.join("/")
}

///|
fn rendered_plan_instance_resolution_signature(
  plan : RenderedSubjectPlan,
) -> String {
  if plan.use_path.is_empty() {
    "direct"
  } else {
    "definition=\{plan.definition_subject_id};depth=\{plan.use_path.length()}"
  }
}

///|
fn rendered_plan_fill_hierarchy(
  input : String,
  css_document : CssStaticDocument,
  document : StructuralDocument,
  plan : RenderedSubjectPlan,
) -> FillHierarchy {
  let elements : Array[FillSourceElement] = []
  let paint_server_targets : Array[PaintServerTarget] = []
  let entity_ids : Array[String] = []
  let coverage_codes : Array[String] = []
  let mut parent_index : Int? = None
  for node in document.nodes {
    if node.kind == "linearGradient" ||
      node.kind == "radialGradient" ||
      node.kind == "pattern" {
      match authored_subject_id(node.element) {
        Some(id) => paint_server_targets.push({ id, kind: node.kind })
        None => ()
      }
    }
  }
  for node_index in plan.rendered_ancestry {
    let node = document.nodes[node_index]
    let index = add_fill_source_element(
      input,
      node.element,
      node.source_offset,
      css_stylesheet_match_for_source(css_document, node.source_offset),
      parent_index,
      elements,
      [],
      entity_ids,
      coverage_codes,
      node.source_offset,
      node.source_offset,
      node.source_offset,
    )
    parent_index = Some(index)
  }
  {
    elements,
    paint_server_targets,
    rect_subject_ids: entity_ids.copy(),
    all_entity_subject_ids: entity_ids,
    coverage_codes,
    has_inherited_visual: false,
  }
}

///|
fn source_use_transform_site(
  input : String,
  node : StructuralSourceNode,
  node_index : Int,
  profile : ComparisonProfile,
  viewport : ViewportContext,
) -> SourceTransformSite {
  let site = source_transform_site(input, node.element, node_index)
  let facts : Array[DeclaredVisualFact] = []
  let mut x = 0.0
  let mut y = 0.0
  let mut complete = true
  for attribute in node.element.attributes {
    let direction = match attribute.name.local_name {
      "x" => Some(Horizontal)
      "y" => Some(Vertical)
      _ => None
    }
    match direction {
      Some(direction) => {
        let fact = presentation_fact(
          input,
          attribute.name.local_name,
          attribute,
        )
        match
          parse_viewport_length(attribute.value, direction, viewport, profile) {
          Some(resolved) => {
            facts.push({ ..fact, declared_value: resolved.value.to_string() })
            if attribute.name.local_name == "x" {
              x = resolved.value
            } else {
              y = resolved.value
            }
          }
          None => {
            facts.push(fact)
            complete = false
          }
        }
      }
      None => ()
    }
  }
  {
    ..site,
    viewport_facts: facts,
    viewport_matrix: if complete {
      AffineTransform::translate(x, y)
    } else {
      AffineTransform::identity()
    },
    viewport_complete: complete,
  }
}

///|
fn namespace_attribute(
  element : @xml.NamespaceElement,
  name : String,
) -> @xml.NamespaceAttribute? {
  for attribute in element.attributes {
    if attribute.name.local_name == name {
      return Some(attribute)
    }
  }
  None
}

///|
fn source_instanced_viewport_resolution(
  input : String,
  use_node : StructuralSourceNode,
  target_node : StructuralSourceNode,
  profile : ComparisonProfile,
  parent_context : ViewportContext,
) -> SourceViewportResolution {
  let facts : Array[DeclaredVisualFact] = []
  let invalid_facts : Array[DeclaredVisualFact] = []
  let mut complete = true
  fn resolve_length(
    attribute : @xml.NamespaceAttribute?,
    property : String,
    direction : SvgLengthDirection,
    default_value : Double,
    positive : Bool,
  ) -> Double {
    match attribute {
      Some(attribute) => {
        let fact = presentation_fact(input, property, attribute)
        match
          parse_viewport_length(
            attribute.value,
            direction,
            parent_context,
            profile,
          ) {
          Some(resolved) if !positive || resolved.value > 0.0 => {
            facts.push({ ..fact, declared_value: resolved.value.to_string() })
            resolved.value
          }
          _ => {
            facts.push(fact)
            invalid_facts.push(fact)
            complete = false
            default_value
          }
        }
      }
      None => default_value
    }
  }
  let x = resolve_length(
    namespace_attribute(target_node.element, "x"),
    "x",
    Horizontal,
    0.0,
    false,
  )
  let y = resolve_length(
    namespace_attribute(target_node.element, "y"),
    "y",
    Vertical,
    0.0,
    false,
  )
  let use_width = namespace_attribute(use_node.element, "width")
  let use_height = namespace_attribute(use_node.element, "height")
  let width = resolve_length(
    match use_width {
      Some(attribute) => Some(attribute)
      None => namespace_attribute(target_node.element, "width")
    },
    "width",
    Horizontal,
    parent_context.width,
    true,
  )
  let height = resolve_length(
    match use_height {
      Some(attribute) => Some(attribute)
      None => namespace_attribute(target_node.element, "height")
    },
    "height",
    Vertical,
    parent_context.height,
    true,
  )
  let view_box = match namespace_attribute(target_node.element, "viewBox") {
    Some(attribute) =>
      match parse_view_box_value(attribute.value) {
        Some(value) => {
          facts.push(
            normalized_viewport_fact(
              input,
              "viewBox",
              attribute,
              normalized_view_box_signature(value),
            ),
          )
          Some(value)
        }
        None => {
          let fact = presentation_fact(input, "viewBox", attribute)
          facts.push(fact)
          invalid_facts.push(fact)
          complete = false
          None
        }
      }
    None => None
  }
  let preserve = match
    namespace_attribute(target_node.element, "preserveAspectRatio") {
    Some(attribute) =>
      match parse_preserve_aspect_ratio_value(attribute.value) {
        Some(value) => {
          facts.push(
            normalized_viewport_fact(
              input,
              "preserveAspectRatio",
              attribute,
              preserve_aspect_ratio_signature(value),
            ),
          )
          value
        }
        None => {
          let fact = presentation_fact(input, "preserveAspectRatio", attribute)
          facts.push(fact)
          invalid_facts.push(fact)
          complete = false
          default_preserve_aspect_ratio()
        }
      }
    None => default_preserve_aspect_ratio()
  }
  facts.sort_by(fn(left, right) { left.property.compare(right.property) })
  let matrix = if complete {
    match view_box {
      Some(value) =>
        equivalent_viewport_transform(value, x, y, width, height, preserve)
      None => AffineTransform::translate(x, y)
    }
  } else {
    AffineTransform::identity()
  }
  let child_context = match view_box {
    Some(value) if complete => { width: value.width, height: value.height }
    _ => { width, height }
  }
  { facts, invalid_facts, matrix, child_context, complete }
}

///|
fn source_instanced_viewport_site(
  input : String,
  use_node : StructuralSourceNode,
  target_node : StructuralSourceNode,
  node_index : Int,
  profile : ComparisonProfile,
  parent_context : ViewportContext,
) -> (SourceTransformSite, ViewportContext) {
  let site = source_transform_site(input, target_node.element, node_index)
  let viewport = source_instanced_viewport_resolution(
    input, use_node, target_node, profile, parent_context,
  )
  (
    {
      ..site,
      viewport_facts: viewport.facts,
      viewport_matrix: viewport.matrix,
      viewport_complete: viewport.complete,
    },
    viewport.child_context,
  )
}

///|
fn use_diagnostic(
  code : String,
  subject_id : String,
  source_role : String,
  span : ReportSourceSpan,
) -> Diagnostic {
  let id_code = code.replace_all(old="_", new="-")
  {
    ..unlocated_diagnostic(
      "diagnostic:\{id_code}:\{subject_id}",
      code,
      subject_id,
      ["source_semantics", "computed_appearance", "rendered_evidence"],
    ),
    source_locations: [diagnostic_location(source_role, span)],
  }
}

///|
fn use_rendered_diagnostic(
  code : String,
  subject_id : String,
  source_role : String,
  span : ReportSourceSpan,
) -> Diagnostic {
  let id_code = code.replace_all(old="_", new="-")
  {
    ..unlocated_diagnostic(
      "diagnostic:\{id_code}:\{subject_id}",
      code,
      subject_id,
      ["rendered_evidence"],
    ),
    source_locations: [diagnostic_location(source_role, span)],
  }
}

///|
fn append_use_structure_diagnostics(
  input : String,
  profile : ComparisonProfile,
  source_role : String,
  diagnostics : Array[Diagnostic],
) -> Unit raise {
  let document = extract_structural_document_or_raise(input)
  let viewport : ViewportContext = {
    width: profile.viewport_width.to_double(),
    height: profile.viewport_height.to_double(),
  }
  for node in document.nodes {
    if node.kind != "use" {
      continue
    }
    match node.href_fact {
      None =>
        merge_diagnostic_into(
          diagnostics,
          use_diagnostic("use_href_missing", node.source_id, source_role, {
            start_offset: node.source_offset,
            end_offset: node.source_offset + 1,
          }),
        )
      Some(fact) =>
        match local_href_target(fact.declared_value) {
          None =>
            merge_diagnostic_into(
              diagnostics,
              use_diagnostic(
                "use_external_reference_unsupported",
                node.source_id,
                source_role,
                fact.source_span,
              ),
            )
          Some(target_id) =>
            match document.id_indices.get(target_id) {
              None =>
                merge_diagnostic_into(
                  diagnostics,
                  use_diagnostic(
                    "use_target_missing",
                    node.source_id,
                    source_role,
                    fact.source_span,
                  ),
                )
              Some(target) if !supported_use_target(document.nodes[target].kind) =>
                merge_diagnostic_into(
                  diagnostics,
                  use_diagnostic(
                    "use_target_kind_unsupported",
                    node.source_id,
                    source_role,
                    fact.source_span,
                  ),
                )
              _ => ()
            }
        }
    }
    let viewport_target = match use_target_index(document, node) {
      Some(target) => {
        let kind = document.nodes[target].kind
        kind == "symbol" || kind == "svg"
      }
      None => false
    }
    for attribute in node.element.attributes {
      let direction = match attribute.name.local_name {
        "x" => Some(Horizontal)
        "y" => Some(Vertical)
        "width" if viewport_target => Some(Horizontal)
        "height" if viewport_target => Some(Vertical)
        _ => None
      }
      match direction {
        Some(direction) if parse_viewport_length(
            attribute.value,
            direction,
            viewport,
            profile,
          )
          is None =>
          merge_diagnostic_into(
            diagnostics,
            use_diagnostic(
              "use_length_semantics_unsupported",
              node.source_id,
              source_role,
              {
                start_offset: attribute.span.start.offset,
                end_offset: attribute.span.end.offset,
              },
            ),
          )
        _ => ()
      }
    }
    let use_transform = source_use_transform_site(
      input,
      node,
      node.source_offset,
      profile,
      viewport,
    )
    if use_transform.fact is Some(transform_fact) &&
      !use_transform.matrix.is_identity() &&
      !use_transform.viewport_matrix.is_identity() {
      merge_diagnostic_into(
        diagnostics,
        use_rendered_diagnostic(
          "renderer_use_transform_raster_unproven",
          node.source_id,
          source_role,
          transform_fact.source_span,
        ),
      )
      for fact in use_transform.viewport_facts {
        merge_diagnostic_into(
          diagnostics,
          use_rendered_diagnostic(
            "renderer_use_transform_raster_unproven",
            node.source_id,
            source_role,
            fact.source_span,
          ),
        )
      }
    }
    match use_target_index(document, node) {
      Some(target) if document.nodes[target].kind == "symbol" ||
        document.nodes[target].kind == "svg" => {
        let resolution = source_instanced_viewport_resolution(
          input,
          node,
          document.nodes[target],
          profile,
          viewport,
        )
        if !resolution.complete {
          for fact in resolution.invalid_facts {
            merge_diagnostic_into(
              diagnostics,
              use_diagnostic(
                "viewport_semantics_unsupported",
                node.source_id,
                source_role,
                fact.source_span,
              ),
            )
          }
        } else if !resolution.matrix.is_identity() &&
          !resolution.matrix.has_proven_renderer_conformance() {
          for fact in resolution.facts {
            merge_diagnostic_into(
              diagnostics,
              use_diagnostic(
                "renderer_viewport_raster_unproven",
                node.source_id,
                source_role,
                fact.source_span,
              ),
            )
          }
        }
      }
      _ => ()
    }
  }
}

///|
fn empty_rendered_scene_supported(input : String) -> Bool raise {
  let reader = @xml.NamespaceReader::from_string(input)
  for event in reader.read_events_until_eof() {
    match event.kind {
      Start(element) | Empty(element) => {
        let kind = element.name.local_name
        if !known_source_element(kind) || kind == "text" {
          return false
        }
      }
      _ => ()
    }
  }
  true
}

///|
fn structural_resource_content(
  document : StructuralDocument,
  node_index : Int,
) -> Bool {
  let mut current : Int? = Some(node_index)
  while current is Some(index) {
    let kind = document.nodes[index].kind
    if kind == "linearGradient" ||
      kind == "radialGradient" ||
      kind == "pattern" ||
      kind == "marker" ||
      kind == "clipPath" {
      return true
    }
    current = document.nodes[index].parent_index
  }
  false
}

///|
fn rendered_plan_contains_node(
  plans : Array[RenderedSubjectPlan],
  node_index : Int,
) -> Bool {
  plans.any(plan => plan.rendered_ancestry.contains(node_index))
}

///|
fn unused_definition_indices(document : StructuralDocument) -> Array[Int] {
  let plans = rendered_subject_plans(document)
  [
    for index, node in document.nodes if node.definition_content &&
    !structural_resource_content(document, index) &&
    !rendered_plan_contains_node(plans, index) => index
  ]
}

///|
fn structural_definition_facts(
  input : String,
  css_document : CssStaticDocument,
  node : StructuralSourceNode,
) -> Array[DeclaredVisualFact] {
  let facts = visual_declarations_from_element(
    input,
    node.element,
    css_stylesheet_match_for_source(css_document, node.source_offset),
    [],
  )
  for attribute in node.element.attributes {
    let property = attribute.name.local_name
    if property == "transform" ||
      property == "href" ||
      property == "viewBox" ||
      property == "preserveAspectRatio" ||
      property == "d" {
      upsert_declared_fact(facts, presentation_fact(input, property, attribute))
    }
  }
  facts.sort_by(fn(left, right) { left.property.compare(right.property) })
  facts
}

///|
fn structural_definition_domain(property : String) -> String {
  match property {
    "href" => "document.reference"
    "viewBox" | "preserveAspectRatio" => "geometry.viewport"
    "transform" => "geometry.transform"
    _ => generic_property_domain(property)
  }
}

///|
fn append_unused_definition_fact_difference(
  report : StructuredReport,
  subject_id : String,
  property : String,
  before : DeclaredVisualFact?,
  after : DeclaredVisualFact?,
  missing_side : String?,
) -> Unit {
  let safe_subject_id = subject_id.replace_all(old=":", new="-")
  let fact_id = "fact:unused-definition:\{safe_subject_id}:\{property}"
  let difference_id = "diff:unused-definition:\{safe_subject_id}:\{property}"
  report.changed_facts.push({
    id: fact_id,
    subject_id,
    property,
    before,
    after,
    affected_subject_ids: [],
  })
  report.atomic_differences.push({
    id: difference_id,
    subject_role: "resource",
    subject_alignment_id: None,
    domain: structural_definition_domain(property),
    source_before: if property == "presence" && missing_side == Some("after") {
      "present"
    } else {
      declared_value_or_empty(before)
    },
    source_after: if property == "presence" && missing_side == Some("before") {
      "present"
    } else {
      declared_value_or_empty(after)
    },
    source_fact_before: before,
    source_fact_after: after,
    changed_fact_ids: [fact_id],
    evidence_layers: ["source_semantics"],
    computed_relation: {
      status: "not_applicable",
      reason_code: "unused_definition",
      missing_side,
      diagnostic_ids: [],
    },
    parameter_delta_css_px: None,
    presence_magnitude: None,
    magnitude: empty_difference_magnitude(),
    domain_ordering: empty_domain_ordering(),
  })
}

///|
fn attach_unused_definition_differences(
  report : StructuredReport,
  before_svg : String,
  after_svg : String,
) -> StructuredReport {
  let before_document = extract_structural_document_or_raise(before_svg) catch {
    _ => return report
  }
  let after_document = extract_structural_document_or_raise(after_svg) catch {
    _ => return report
  }
  let before_css = parse_static_css_document_or_raise(before_svg) catch {
    _ => return report
  }
  let after_css = parse_static_css_document_or_raise(after_svg) catch {
    _ => return report
  }
  let before_indices = unused_definition_indices(before_document)
  let after_indices = unused_definition_indices(after_document)
  let after_used = Array::make(after_indices.length(), false)
  for before_index in before_indices {
    let before_node = before_document.nodes[before_index]
    let before_authored_id = authored_subject_id(before_node.element)
    let mut matched = -1
    for candidate, after_index in after_indices {
      if after_used[candidate] {
        continue
      }
      let after_node = after_document.nodes[after_index]
      let after_authored_id = authored_subject_id(after_node.element)
      if before_node.kind == after_node.kind &&
        (
          (
            before_authored_id is Some(_) &&
            before_authored_id == after_authored_id
          ) ||
          (before_authored_id is None && after_authored_id is None)
        ) {
        matched = candidate
        break
      }
    }
    if matched < 0 {
      append_unused_definition_fact_difference(
        report,
        before_node.source_id,
        "presence",
        None,
        None,
        Some("after"),
      )
      continue
    }
    after_used[matched] = true
    let after_node = after_document.nodes[after_indices[matched]]
    let before_facts = structural_definition_facts(
      before_svg, before_css, before_node,
    )
    let after_facts = structural_definition_facts(
      after_svg, after_css, after_node,
    )
    let properties : Array[String] = []
    for fact in before_facts + after_facts {
      if !properties.contains(fact.property) {
        properties.push(fact.property)
      }
    }
    properties.sort()
    for property in properties {
      let before_fact = declared_fact_in_array(before_facts, property)
      let after_fact = declared_fact_in_array(after_facts, property)
      if declared_fact_changed(before_fact, after_fact) {
        append_unused_definition_fact_difference(
          report,
          before_node.source_id,
          property,
          before_fact,
          after_fact,
          match (before_fact, after_fact) {
            (None, Some(_)) => Some("before")
            (Some(_), None) => Some("after")
            _ => None
          },
        )
      }
    }
  }
  for candidate, after_index in after_indices {
    if !after_used[candidate] {
      append_unused_definition_fact_difference(
        report,
        after_document.nodes[after_index].source_id,
        "presence",
        None,
        None,
        Some("before"),
      )
    }
  }
  report
}
