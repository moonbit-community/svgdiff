///|
priv struct BlendSemanticIssue {
  code : String
  subject_id : String
  fact : DeclaredVisualFact?
}

///|
priv struct BlendSite {
  owner_id : String
  source_index : Int
  kind : String
  blend_fact : DeclaredVisualFact?
  blend_resolution : ResolvedVisualFact
  blend_dependencies : Array[StyleDependency]
  blend_mode : String
  isolation_fact : DeclaredVisualFact?
  isolation_resolution : ResolvedVisualFact
  isolation_dependencies : Array[StyleDependency]
  isolation : String
  affected_subject_ids : Array[String]
  complete : Bool
}

///|
priv struct BlendSemanticDocument {
  hierarchy : FillHierarchy
  sites : Array[BlendSite]
  issues : Array[BlendSemanticIssue]
  active : Bool
  complete : Bool
}

///|
fn blend_mode_from_keyword(value : String) -> @svg.BlendMode? {
  match value.trim().to_owned().to_lower() {
    "normal" => Some(Normal)
    "multiply" => Some(Multiply)
    "screen" => Some(Screen)
    "overlay" => Some(Overlay)
    "darken" => Some(Darken)
    "lighten" => Some(Lighten)
    "color-dodge" => Some(ColorDodge)
    "color-burn" => Some(ColorBurn)
    "hard-light" => Some(HardLight)
    "soft-light" => Some(SoftLight)
    "difference" => Some(Difference)
    "exclusion" => Some(Exclusion)
    "hue" => Some(Hue)
    "saturation" => Some(Saturation)
    "color" => Some(ColorMode)
    "luminosity" => Some(Luminosity)
    _ => None
  }
}

///|
fn blend_issue(
  issues : Array[BlendSemanticIssue],
  code : String,
  subject_id : String,
  fact : DeclaredVisualFact?,
) -> Unit {
  if !issues.any(issue => issue.code == code && issue.subject_id == subject_id) {
    issues.push({ code, subject_id, fact })
  }
}

///|
fn blend_element_is_descendant_of(
  hierarchy : FillHierarchy,
  element_index : Int,
  ancestor_index : Int,
) -> Bool {
  if element_index == ancestor_index {
    return true
  }
  let mut parent = hierarchy.elements[element_index].parent_index
  while parent is Some(index) {
    if index == ancestor_index {
      return true
    }
    parent = hierarchy.elements[index].parent_index
  }
  false
}

///|
fn blend_nearest_isolation_boundary(
  hierarchy : FillHierarchy,
  element_index : Int,
) -> Int {
  let mut current = hierarchy.elements[element_index].parent_index
  while current is Some(index) {
    match
      computed_visual_for_subject(
        hierarchy,
        hierarchy.elements[index].subject_id,
        "isolation",
      ) {
      Some(resolution) if resolution.complete &&
        resolution.reported.resolved_value == "isolate" => return index
      _ => current = hierarchy.elements[index].parent_index
    }
  }
  0
}

///|
fn blend_backdrop_prefix_ids(
  hierarchy : FillHierarchy,
  element_index : Int,
) -> Array[String] {
  let boundary = blend_nearest_isolation_boundary(hierarchy, element_index)
  let ids : Array[String] = [hierarchy.elements[element_index].subject_id]
  if boundary != element_index {
    let boundary_id = hierarchy.elements[boundary].subject_id
    if !ids.contains(boundary_id) {
      ids.push(boundary_id)
    }
  }
  for index in 0..<element_index {
    let element = hierarchy.elements[index]
    if !element.resource_content &&
      fill_entity_kind(element.kind) &&
      blend_element_is_descendant_of(hierarchy, index, boundary) &&
      !ids.contains(element.subject_id) {
      ids.push(element.subject_id)
    }
  }
  ids
}

///|
fn blend_subject_for_id(
  subjects : Array[SourceSubject],
  subject_id : String,
) -> SourceSubject? {
  for subject in subjects {
    if source_subject_id(subject) == subject_id &&
      subject.reference.instance_context is None {
      return Some(subject)
    }
  }
  None
}

///|
fn blend_integral(value : Double) -> Bool {
  value == value.round().to_int().to_double()
}

///|
fn blend_rounded_rect_active(
  hierarchy : FillHierarchy,
  subject_id : String,
) -> Bool {
  for property in ["rx", "ry"] {
    match computed_visual_for_subject(hierarchy, subject_id, property) {
      Some(resolution) => {
        let value = resolution.reported.resolved_value
        if value != "auto" && parse_shape_number(value).unwrap_or(1.0) != 0.0 {
          return true
        }
      }
      None => ()
    }
  }
  false
}

///|
fn blend_subject_issue_code(
  hierarchy : FillHierarchy,
  subject : SourceSubject?,
) -> String? {
  guard subject is Some(subject) else {
    return Some("blend_backdrop_unsupported")
  }
  if subject.kind != "rect" || subject.reference.authored_id is None {
    return Some("blend_backdrop_unsupported")
  }
  if !subject.geometry_complete ||
    blend_rounded_rect_active(hierarchy, source_subject_id(subject)) {
    return Some("blend_geometry_unsupported")
  }
  guard source_subject_bounds(subject) is Some(bounds) else {
    return Some("blend_geometry_unsupported")
  }
  if !blend_integral(bounds.x) ||
    !blend_integral(bounds.y) ||
    !blend_integral(bounds.width) ||
    !blend_integral(bounds.height) {
    return Some("blend_fractional_geometry_unproven")
  }
  if !subject.transform_complete ||
    subject.cumulative_transform.signature() !=
    AffineTransform::identity().signature() {
    return Some("blend_transform_unproven")
  }
  if subject.stroke_active {
    return Some("blend_stroke_unsupported")
  }
  let subject_id = source_subject_id(subject)
  for property in ["opacity", "fill-opacity"] {
    match computed_visual_for_subject(hierarchy, subject_id, property) {
      Some(resolution) if !resolution.complete ||
        resolution.reported.resolved_value != "1" =>
        return Some("blend_alpha_unsupported")
      _ => ()
    }
  }
  match computed_visual_for_subject(hierarchy, subject_id, "fill") {
    Some(resolution) if resolution.complete =>
      match @css_color.parse_solid_color(resolution.reported.resolved_value) {
        Resolved(color) if color.alpha == 1.0 => ()
        Resolved(_) => return Some("blend_alpha_unsupported")
        _ => return Some("blend_paint_unsupported")
      }
    _ => return Some("blend_paint_unsupported")
  }
  for property in ["clip-path", "mask", "filter"] {
    match computed_visual_for_subject(hierarchy, subject_id, property) {
      Some(resolution) if resolution.reported.resolved_value != "none" =>
        return Some("blend_effect_interaction_unsupported")
      _ => ()
    }
  }
  None
}

///|
fn blend_container_effect_active(
  hierarchy : FillHierarchy,
  element_index : Int,
) -> Bool {
  let subject_id = hierarchy.elements[element_index].subject_id
  for property in ["clip-path", "mask", "filter", "opacity"] {
    match computed_visual_for_subject(hierarchy, subject_id, property) {
      Some(resolution) if (
          property == "opacity" && resolution.reported.resolved_value != "1"
        ) ||
        (property != "opacity" && resolution.reported.resolved_value != "none") =>
        return true
      _ => ()
    }
  }
  false
}

///|
fn resolve_blend_semantic_document_or_raise(
  input : String,
  profile : ComparisonProfile,
) -> BlendSemanticDocument raise {
  let hierarchy = extract_fill_hierarchy_or_raise(input)
  let subjects = extract_source_subjects_with_profile_or_raise(input, profile)
  let sites : Array[BlendSite] = []
  let issues : Array[BlendSemanticIssue] = []
  let mut active = false
  let mut surface_count = 0
  for index, element in hierarchy.elements {
    guard computed_visual_for_subject(
        hierarchy,
        element.subject_id,
        "mix-blend-mode",
      )
      is Some(blend) &&
      computed_visual_for_subject(hierarchy, element.subject_id, "isolation")
      is Some(isolation) else {
      continue
    }
    let mode = blend.reported.resolved_value
    let isolation_value = isolation.reported.resolved_value
    let issue_codes : Array[String] = []
    if !blend.complete || blend_mode_from_keyword(mode) is None {
      push_unique(issue_codes, "blend_mode_invalid")
    }
    if !isolation.complete ||
      (isolation_value != "auto" && isolation_value != "isolate") {
      push_unique(issue_codes, "isolation_invalid")
    }
    let mode_active = mode != "normal"
    let isolate_active = isolation_value == "isolate"
    if mode_active || isolate_active {
      active = active || mode_active
      surface_count += 1
    }
    let affected = if mode_active || isolate_active {
      blend_backdrop_prefix_ids(hierarchy, index)
    } else {
      [element.subject_id]
    }
    if mode_active {
      if !fill_entity_kind(element.kind) {
        push_unique(issue_codes, "blend_container_mode_unsupported")
      }
      match
        blend_subject_issue_code(
          hierarchy,
          blend_subject_for_id(subjects, element.subject_id),
        ) {
        Some(code) => push_unique(issue_codes, code)
        None => ()
      }
      for affected_id in affected {
        if affected_id == element.subject_id ||
          fill_source_element(hierarchy, affected_id)
          .map(pair => !fill_entity_kind(pair.1.kind))
          .unwrap_or(true) {
          continue
        }
        match
          blend_subject_issue_code(
            hierarchy,
            blend_subject_for_id(subjects, affected_id),
          ) {
          Some(code) => push_unique(issue_codes, code)
          None => ()
        }
      }
      let boundary = blend_nearest_isolation_boundary(hierarchy, index)
      for candidate in 0..<=index {
        if blend_element_is_descendant_of(hierarchy, candidate, boundary) &&
          blend_container_effect_active(hierarchy, candidate) {
          push_unique(issue_codes, "blend_effect_interaction_unsupported")
        }
      }
    }
    let isolation_host_supported = (index == 0 && element.kind == "svg") ||
      (element.kind == "g" && element.has_authored_id)
    if isolate_active && !isolation_host_supported {
      push_unique(issue_codes, "isolation_host_unsupported")
    }
    for code in issue_codes {
      blend_issue(
        issues,
        code,
        element.subject_id,
        if code == "isolation_invalid" || code == "isolation_host_unsupported" {
          isolation.reported.declaration
        } else {
          blend.reported.declaration
        },
      )
    }
    sites.push({
      owner_id: element.subject_id,
      source_index: index,
      kind: element.kind,
      blend_fact: blend.reported.declaration,
      blend_resolution: blend.reported,
      blend_dependencies: blend.dependencies,
      blend_mode: mode,
      isolation_fact: isolation.reported.declaration,
      isolation_resolution: isolation.reported,
      isolation_dependencies: isolation.dependencies,
      isolation: isolation_value,
      affected_subject_ids: affected,
      complete: issue_codes.is_empty(),
    })
  }
  let viewport_pixels = profile.viewport_width * profile.viewport_height
  if surface_count > 64 ||
    viewport_pixels <= 0 ||
    (surface_count > 0 && surface_count > 64 * 1024 * 1024 / viewport_pixels) {
    blend_issue(issues, "blend_surface_budget_exceeded", "document", None)
  }
  { hierarchy, sites, issues, active, complete: issues.is_empty() }
}

///|
fn append_blend_diagnostics(
  input : String,
  profile : ComparisonProfile,
  source_role : String,
  diagnostics : Array[Diagnostic],
) -> Unit raise {
  let document = resolve_blend_semantic_document_or_raise(input, profile)
  for issue in document.issues {
    merge_diagnostic_into(diagnostics, {
      ..unlocated_diagnostic(
        "diagnostic:\{issue.code}:\{issue.subject_id}",
        issue.code,
        issue.subject_id,
        ["computed_appearance", "rendered_evidence"],
      ),
      source_locations: match issue.fact {
        Some(fact) => [diagnostic_location(source_role, fact.source_span)]
        None => []
      },
    })
  }
}

///|
fn blend_site_for_node(
  sites : Array[BlendSite],
  node : @svg.SVGNode,
) -> BlendSite? {
  if node.id == "" {
    return None
  }
  for site in sites {
    if site.owner_id == node.id {
      return Some(site)
    }
  }
  None
}

///|
fn blend_subtree_active(sites : Array[BlendSite], node : @svg.SVGNode) -> Bool {
  blend_site_for_node(sites, node)
  .map(site => site.blend_mode != "normal")
  .unwrap_or(false) ||
  node.children.any(child => blend_subtree_active(sites, child))
}

///|
priv struct BlendRgb {
  r : Double
  g : Double
  b : Double
}

///|
fn blend_rgb(r : Double, g : Double, b : Double) -> BlendRgb {
  { r, g, b }
}

///|
fn blend_lum(color : BlendRgb) -> Double {
  0.3 * color.r + 0.59 * color.g + 0.11 * color.b
}

///|
fn blend_sat(color : BlendRgb) -> Double {
  let minimum = color.r.min(color.g).min(color.b)
  let maximum = color.r.max(color.g).max(color.b)
  maximum - minimum
}

///|
fn blend_clip_color(color : BlendRgb) -> BlendRgb {
  let lum = blend_lum(color)
  let minimum = color.r.min(color.g).min(color.b)
  let maximum = color.r.max(color.g).max(color.b)
  let first = if minimum < 0.0 {
    let scale = lum / (lum - minimum)
    blend_rgb(
      lum + (color.r - lum) * scale,
      lum + (color.g - lum) * scale,
      lum + (color.b - lum) * scale,
    )
  } else {
    color
  }
  if maximum > 1.0 {
    let scale = (1.0 - lum) / (maximum - lum)
    blend_rgb(
      lum + (first.r - lum) * scale,
      lum + (first.g - lum) * scale,
      lum + (first.b - lum) * scale,
    )
  } else {
    first
  }
}

///|
fn blend_set_lum(color : BlendRgb, lum : Double) -> BlendRgb {
  let delta = lum - blend_lum(color)
  blend_clip_color(blend_rgb(color.r + delta, color.g + delta, color.b + delta))
}

///|
fn blend_set_sat(color : BlendRgb, saturation : Double) -> BlendRgb {
  let minimum = color.r.min(color.g).min(color.b)
  let maximum = color.r.max(color.g).max(color.b)
  if maximum == minimum {
    return blend_rgb(0.0, 0.0, 0.0)
  }
  let channel = fn(value) {
    if value == minimum {
      0.0
    } else if value == maximum {
      saturation
    } else {
      (value - minimum) * saturation / (maximum - minimum)
    }
  }
  blend_rgb(channel(color.r), channel(color.g), channel(color.b))
}

///|
fn blend_soft_light(backdrop : Double, source : Double) -> Double {
  if source <= 0.5 {
    backdrop - (1.0 - 2.0 * source) * backdrop * (1.0 - backdrop)
  } else {
    let d = if backdrop <= 0.25 {
      ((16.0 * backdrop - 12.0) * backdrop + 4.0) * backdrop
    } else {
      backdrop.sqrt()
    }
    backdrop + (2.0 * source - 1.0) * (d - backdrop)
  }
}

///|
fn blend_separable_channel(
  backdrop : Double,
  source : Double,
  mode : String,
) -> Double {
  match mode {
    "normal" => source
    "multiply" => backdrop * source
    "screen" => backdrop + source - backdrop * source
    "overlay" =>
      if backdrop <= 0.5 {
        2.0 * backdrop * source
      } else {
        1.0 - 2.0 * (1.0 - backdrop) * (1.0 - source)
      }
    "darken" => backdrop.min(source)
    "lighten" => backdrop.max(source)
    "color-dodge" =>
      if backdrop == 0.0 {
        0.0
      } else if source == 1.0 {
        1.0
      } else {
        (backdrop / (1.0 - source)).min(1.0)
      }
    "color-burn" =>
      if backdrop == 1.0 {
        1.0
      } else if source == 0.0 {
        0.0
      } else {
        (1.0 - (1.0 - backdrop) / source).max(0.0)
      }
    "hard-light" =>
      if source <= 0.5 {
        2.0 * backdrop * source
      } else {
        1.0 - 2.0 * (1.0 - backdrop) * (1.0 - source)
      }
    "soft-light" => blend_soft_light(backdrop, source)
    "difference" => (backdrop - source).abs()
    "exclusion" => backdrop + source - 2.0 * backdrop * source
    _ => source
  }
}

///|
fn blend_opaque_color(
  backdrop : @svg.Color,
  source : @svg.Color,
  mode : String,
) -> @svg.Color {
  let backdrop_rgb = blend_rgb(
    backdrop.r.to_double() / 255.0,
    backdrop.g.to_double() / 255.0,
    backdrop.b.to_double() / 255.0,
  )
  let source_rgb = blend_rgb(
    source.r.to_double() / 255.0,
    source.g.to_double() / 255.0,
    source.b.to_double() / 255.0,
  )
  let result = match mode {
    "hue" =>
      blend_set_lum(
        blend_set_sat(source_rgb, blend_sat(backdrop_rgb)),
        blend_lum(backdrop_rgb),
      )
    "saturation" =>
      blend_set_lum(
        blend_set_sat(backdrop_rgb, blend_sat(source_rgb)),
        blend_lum(backdrop_rgb),
      )
    "color" => blend_set_lum(source_rgb, blend_lum(backdrop_rgb))
    "luminosity" => blend_set_lum(backdrop_rgb, blend_lum(source_rgb))
    _ =>
      blend_rgb(
        blend_separable_channel(backdrop_rgb.r, source_rgb.r, mode),
        blend_separable_channel(backdrop_rgb.g, source_rgb.g, mode),
        blend_separable_channel(backdrop_rgb.b, source_rgb.b, mode),
      )
  }
  @svg.Color::rgba(
    (result.r * 255.0).round().to_int().clamp(min=0, max=255),
    (result.g * 255.0).round().to_int().clamp(min=0, max=255),
    (result.b * 255.0).round().to_int().clamp(min=0, max=255),
    255,
  )
}

///|
fn blend_binary_source_over(
  destination : @svg.Image,
  source : @svg.Image,
  mode : String,
) -> Bool {
  for index in 0..<destination.pixels.length() {
    let backdrop = destination.pixels[index]
    let foreground = source.pixels[index]
    if (backdrop.a != 0 && backdrop.a != 255) ||
      (foreground.a != 0 && foreground.a != 255) {
      return false
    }
    destination.pixels[index] = if foreground.a == 0 {
      backdrop
    } else if backdrop.a == 0 {
      foreground
    } else {
      blend_opaque_color(backdrop, foreground, mode)
    }
  }
  true
}

///|
fn blend_render_inactive_subtree(
  document : @svg.SVGDocument,
  filter_hosts : Array[ResolvedFilterHost],
  ancestors : Array[@svg.SVGNode],
  node : @svg.SVGNode,
  width : Int,
  height : Int,
) -> @svg.Image {
  if filter_subtree_active(filter_hosts, node) {
    if group_compositor_container(node) {
      filter_render_container(
        document, filter_hosts, ancestors, node, width, height,
      )
    } else {
      filter_render_leaf(document, filter_hosts, ancestors, node, width, height)
    }
  } else if group_compositor_atomic_container(node) {
    group_compositor_render_masked_container(
      document, ancestors, node, width, height,
    )
  } else if group_compositor_container(node) {
    group_compositor_render_container(document, ancestors, node, width, height)
  } else {
    group_compositor_render_leaf(document, ancestors, node, width, height)
  }
}

///|
fn blend_render_node_into(
  destination : @svg.Image,
  document : @svg.SVGDocument,
  filter_hosts : Array[ResolvedFilterHost],
  sites : Array[BlendSite],
  ancestors : Array[@svg.SVGNode],
  node : @svg.SVGNode,
  width : Int,
  height : Int,
) -> Bool {
  if !blend_subtree_active(sites, node) {
    group_compositor_over_image(
      destination,
      blend_render_inactive_subtree(
        document, filter_hosts, ancestors, node, width, height,
      ),
    )
    return true
  }
  if group_compositor_container(node) {
    let child_ancestors = ancestors.copy()
    child_ancestors.push(node)
    let isolated = blend_site_for_node(sites, node)
      .map(site => site.isolation == "isolate")
      .unwrap_or(false)
    let target = if isolated {
      @svg.Image::new(width, height)
    } else {
      destination
    }
    for child in group_compositor_children(node) {
      if !blend_render_node_into(
          target, document, filter_hosts, sites, child_ancestors, child, width, height,
        ) {
        return false
      }
    }
    if isolated {
      group_compositor_over_image(destination, target)
    }
    return true
  }
  let source = filter_render_leaf(
    document, filter_hosts, ancestors, node, width, height,
  )
  match blend_site_for_node(sites, node) {
    Some(site) if site.blend_mode != "normal" =>
      match blend_mode_from_keyword(site.blend_mode) {
        Some(_) =>
          blend_binary_source_over(destination, source, site.blend_mode)
        None => false
      }
    _ => {
      group_compositor_over_image(destination, source)
      true
    }
  }
}

///|
fn render_blend_product_source_to_image(
  source : String,
  profile : ComparisonProfile,
  semantic : BlendSemanticDocument,
) -> @svg.Image? {
  guard semantic.complete &&
    @svg.parse_svg_document(
      normalize_renderer_input_with_profile(source, profile),
    )
    is Some(document) else {
    return None
  }
  let filter_hosts = try resolve_filter_hosts_or_raise(source, profile) catch {
    _ => return None
  } noraise {
    value => value.1.filter(host => host.complete)
  }
  let output = @svg.Image::new(profile.viewport_width, profile.viewport_height)
  if blend_render_node_into(
      output,
      document,
      filter_hosts,
      semantic.sites,
      [],
      document.root,
      profile.viewport_width,
      profile.viewport_height,
    ) {
    Some(output)
  } else {
    None
  }
}

///|
fn render_product_source_to_image(
  source : String,
  profile : ComparisonProfile,
) -> @svg.Image? {
  let semantic = try
    resolve_blend_semantic_document_or_raise(source, profile)
  catch {
    _ => return None
  } noraise {
    value => value
  }
  if semantic.active {
    render_blend_product_source_to_image(source, profile, semantic)
  } else {
    render_filter_product_source_to_image(source, profile)
  }
}

///|
fn blend_site_for_owner(
  sites : Array[BlendSite],
  owner_id : String,
) -> BlendSite? {
  for site in sites {
    if site.owner_id == owner_id {
      return Some(site)
    }
  }
  None
}

///|
fn blend_report_diagnostic_ids(
  report : StructuredReport,
  subject_ids : Array[String],
) -> Array[String] {
  let ids : Array[String] = []
  for diagnostic in report.diagnostics {
    if subject_ids.contains(diagnostic.subject_id) ||
      diagnostic.subject_id == "document" {
      ids.push(diagnostic.id)
    }
  }
  ids
}

///|
fn blend_rendered_evidence(
  before_svg : String,
  after_svg : String,
  profile : ComparisonProfile,
) -> RenderedEvidence {
  match
    (
      render_product_source_to_image(before_svg, profile),
      render_product_source_to_image(after_svg, profile),
    ) {
    (Some(before), Some(after)) =>
      computed_rendered_evidence(rendered_image_difference(before, after))
    _ => not_computed_rendered_evidence("blend_renderer_unavailable")
  }
}

///|
fn blend_property_fact(
  site : BlendSite,
  property : String,
) -> DeclaredVisualFact? {
  if property == "mix-blend-mode" {
    site.blend_fact
  } else {
    site.isolation_fact
  }
}

///|
fn blend_property_resolution(
  site : BlendSite,
  property : String,
) -> ResolvedVisualFact {
  if property == "mix-blend-mode" {
    site.blend_resolution
  } else {
    site.isolation_resolution
  }
}

///|
fn blend_property_dependencies(
  site : BlendSite,
  property : String,
) -> Array[StyleDependency] {
  if property == "mix-blend-mode" {
    site.blend_dependencies
  } else {
    site.isolation_dependencies
  }
}

///|
fn blend_property_value(site : BlendSite, property : String) -> String {
  if property == "mix-blend-mode" {
    site.blend_mode
  } else {
    site.isolation
  }
}

///|
fn blend_append_dependency_facts(
  changed_facts : Array[ChangedFact],
  changed_fact_ids : Array[String],
  before : BlendSemanticDocument,
  after : BlendSemanticDocument,
  dependencies : Array[StyleDependency],
  affected_subject_ids : Array[String],
  direct_owner_id : String,
  direct_property : String,
) -> Unit {
  for dependency in dependencies {
    if dependency.owner_id == direct_owner_id &&
      dependency.property == direct_property {
      continue
    }
    let before_fact = local_property_declaration(
      before.hierarchy,
      dependency.owner_id,
      dependency.property,
    )
    let after_fact = local_property_declaration(
      after.hierarchy,
      dependency.owner_id,
      dependency.property,
    )
    if !declared_fact_changed(before_fact, after_fact) {
      continue
    }
    let fact_id = "changed:source:\{dependency.owner_id}:\{dependency.property}"
    if !changed_fact_ids.contains(fact_id) {
      changed_fact_ids.push(fact_id)
    }
    let mut found = false
    for index, fact in changed_facts {
      if fact.id == fact_id {
        let merged = fact.affected_subject_ids.copy()
        append_unique_subjects(merged, affected_subject_ids)
        changed_facts[index] = { ..fact, affected_subject_ids: merged }
        found = true
        break
      }
    }
    if !found {
      changed_facts.push({
        id: fact_id,
        subject_id: dependency.owner_id,
        property: dependency.property,
        before: before_fact,
        after: after_fact,
        affected_subject_ids,
      })
    }
  }
}

///|
fn attach_blend_differences(
  report : StructuredReport,
  before_svg : String,
  after_svg : String,
) -> (StructuredReport, Array[SubjectAlignment]) {
  let before = try
    resolve_blend_semantic_document_or_raise(before_svg, report.profile)
  catch {
    _ => return (report, [])
  } noraise {
    value => value
  }
  let after = try
    resolve_blend_semantic_document_or_raise(after_svg, report.profile)
  catch {
    _ => return (report, [])
  } noraise {
    value => value
  }
  let owner_ids : Array[String] = []
  for site in before.sites + after.sites {
    if (site.blend_fact is Some(_) || site.isolation_fact is Some(_)) &&
      !owner_ids.contains(site.owner_id) {
      owner_ids.push(site.owner_id)
    }
  }
  owner_ids.sort()
  if owner_ids.is_empty() {
    return (report, [])
  }
  let changed_facts = report.changed_facts.copy()
  let resolutions = report.source_resolutions.copy()
  let differences = report.atomic_differences.copy()
  let events = report.events.copy()
  let alignments : Array[SubjectAlignment] = []
  let rendered = blend_rendered_evidence(before_svg, after_svg, report.profile)
  for owner_id in owner_ids {
    guard blend_site_for_owner(before.sites, owner_id) is Some(left) &&
      blend_site_for_owner(after.sites, owner_id) is Some(right) else {
      continue
    }
    let alignment_id = "alignment:compositing:\{owner_id}"
    alignments.push({
      id: alignment_id,
      subject_role: "entity",
      relation: "correspondence",
      before: [
        {
          source_index: left.source_index,
          kind: left.kind,
          authored_id: Some(owner_id),
          instance_context: None,
        },
      ],
      after: [
        {
          source_index: right.source_index,
          kind: right.kind,
          authored_id: Some(owner_id),
          instance_context: None,
        },
      ],
      basis: "group_identity_or_singleton",
      evidence: {
        score_kind: "group_identity_or_singleton",
        selected_score: None,
        candidate_count: 0,
        equal_score_candidate_count: 0,
        ambiguity: "not_assessed",
        confidence: None,
        confidence_status: "not_calibrated",
      },
    })
    let affected = left.affected_subject_ids.copy()
    append_unique_subjects(affected, right.affected_subject_ids)
    for property in ["mix-blend-mode", "isolation"] {
      let left_fact = blend_property_fact(left, property)
      let right_fact = blend_property_fact(right, property)
      let left_resolution = blend_property_resolution(left, property)
      let right_resolution = blend_property_resolution(right, property)
      if !declared_fact_changed(left_fact, right_fact) &&
        !resolution_source_changed(
          Some(left_resolution),
          Some(right_resolution),
        ) {
        continue
      }
      let fact_id = "fact:compositing:\{owner_id}:\{property}"
      let difference_id = "diff:compositing:\{owner_id}:\{property}"
      let changed_fact_ids : Array[String] = []
      if declared_fact_changed(left_fact, right_fact) {
        changed_facts.push({
          id: fact_id,
          subject_id: owner_id,
          property,
          before: left_fact,
          after: right_fact,
          affected_subject_ids: affected,
        })
        changed_fact_ids.push(fact_id)
      }
      let dependencies = blend_property_dependencies(left, property)
      append_style_dependencies(
        dependencies,
        blend_property_dependencies(right, property),
      )
      blend_append_dependency_facts(
        changed_facts, changed_fact_ids, before, after, dependencies, affected, owner_id,
        property,
      )
      resolutions.push({
        subject_id: owner_id,
        property,
        before: Some(left_resolution),
        after: Some(right_resolution),
      })
      let left_value = blend_property_value(left, property)
      let right_value = blend_property_value(right, property)
      let diagnostic_ids = blend_report_diagnostic_ids(report, affected)
      let complete = left.complete &&
        right.complete &&
        diagnostic_ids.is_empty()
      let relation = if complete {
        {
          status: if left_value == right_value {
            "equivalent"
          } else {
            "different"
          },
          reason_code: if left_value == right_value {
            "same_resolved_compositing_value"
          } else {
            "resolved_compositing_values_differ"
          },
          missing_side: None,
          diagnostic_ids: [],
        }
      } else {
        {
          status: "indeterminate",
          reason_code: "compositing_coverage_partial",
          missing_side: None,
          diagnostic_ids,
        }
      }
      differences.push({
        id: difference_id,
        subject_role: if fill_entity_kind(left.kind) {
          "entity"
        } else {
          "container"
        },
        subject_alignment_id: Some(alignment_id),
        domain: if property == "mix-blend-mode" {
          "compositing.blend_mode"
        } else {
          "compositing.isolation"
        },
        source_before: declared_value_or_empty(left_fact),
        source_after: declared_value_or_empty(right_fact),
        source_fact_before: left_fact,
        source_fact_after: right_fact,
        changed_fact_ids,
        evidence_layers: if complete && left_value != right_value {
          ["source_semantics", "computed_appearance", "rendered_evidence"]
        } else {
          ["source_semantics"]
        },
        computed_relation: relation,
        parameter_delta_css_px: None,
        presence_magnitude: None,
        magnitude: empty_difference_magnitude(),
        domain_ordering: empty_domain_ordering(),
      })
      events.push({
        id: "event:compositing:\{owner_id}:\{property}",
        primary_subject_id: owner_id,
        atomic_difference_ids: [difference_id],
        rendered_outcome: if complete {
          rendered
        } else {
          not_computed_rendered_evidence("compositing_renderer_unavailable")
        },
        difference_regions: [],
      })
    }
  }
  (
    {
      ..report,
      changed_facts,
      source_resolutions: resolutions,
      atomic_differences: differences,
      events,
    },
    alignments,
  )
}
