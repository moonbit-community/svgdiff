// Copyright 2026 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
pub(all) struct BlendSemanticIssue {
  code : String
  subject_id : String
  fact : DeclaredVisualFact?
}

///|
pub(all) struct BlendSite {
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
pub(all) struct BlendSemanticDocument {
  hierarchy : FillHierarchy
  sites : Array[BlendSite]
  issues : Array[BlendSemanticIssue]
  active : Bool
  complete : Bool
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
pub fn resolve_blend_semantic_document_or_raise(
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
pub fn append_blend_diagnostics(
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
