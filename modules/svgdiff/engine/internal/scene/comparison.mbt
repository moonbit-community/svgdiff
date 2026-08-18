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
fn scene_event(
  kind : String,
  alignment_ids : Array[String],
  index : Int,
) -> @model.VisualChangeEvent {
  {
    id: "scene-event:\{index}",
    kind,
    scope: if alignment_ids.length() > 1 {
      "systemic"
    } else if alignment_ids.length() == 1 {
      "object"
    } else {
      "comparison"
    },
    object_alignment_ids: alignment_ids,
    atomic_difference_ids: [],
    evidence_event_ids: [],
    evidence_difference_count: 0,
    evidence_domains: [],
  }
}

///|
fn difference_supports_scene_event(kind : String, domain : String) -> Bool {
  match kind {
    "content.change" => domain.has_prefix("text.")
    "object.presence" => domain.has_prefix("presence.")
    "relation.change" => domain.has_prefix("document.structure.")
    "layout.reflow" | "layout.global_affine" =>
      domain.has_prefix("geometry.position") ||
      domain.has_prefix("geometry.size") ||
      domain.has_prefix("geometry.transform") ||
      domain.has_prefix("document.viewport")
    "style.change" =>
      domain.has_prefix("paint.") ||
      domain.has_prefix("geometry.stroke") ||
      domain.has_prefix("compositing.") ||
      domain.has_prefix("opacity.") ||
      domain.has_prefix("effect.") ||
      domain.has_prefix("effects.") ||
      domain.has_prefix("filter.") ||
      domain.has_prefix("mask.") ||
      domain.has_prefix("clip.")
    "representation.change" =>
      domain.has_prefix("geometry.path.") ||
      domain.has_prefix("document.structure.")
    _ => false
  }
}

///|
fn subject_reference_id(reference : @model.SubjectReference) -> String {
  match reference.instance_context {
    Some(context) => context.instance_id
    None =>
      reference.authored_id.unwrap_or(
        "\{reference.kind}:\{reference.source_index}",
      )
  }
}

///|
fn subject_owner(
  entries : Array[(String, String)],
  reference : @model.SubjectReference,
) -> String? {
  let id = subject_reference_id(reference)
  for entry in entries {
    if entry.0 == id && entry.1.has_prefix("object-alignment:") {
      return Some(entry.1)
    }
  }
  None
}

///|
fn subject_alignment_owners(
  context : VisualSceneContext,
  alignment : @model.SubjectAlignment,
) -> Array[String] {
  let owners : Array[String] = []
  for reference in alignment.before {
    match subject_owner(context.before_subject_owner_entries, reference) {
      Some(owner) if !owners.contains(owner) => owners.push(owner)
      _ => ()
    }
  }
  for reference in alignment.after {
    match subject_owner(context.after_subject_owner_entries, reference) {
      Some(owner) if !owners.contains(owner) => owners.push(owner)
      _ => ()
    }
  }
  owners
}

///|
fn scene_change_difference(difference : @model.AtomicDifference) -> Bool {
  difference.computed_relation.status == "different" ||
  difference.computed_relation.status == "not_applicable"
}

///|
fn scene_accounted_difference(difference : @model.AtomicDifference) -> Bool {
  difference.computed_relation.status != "equivalent"
}

///|
pub fn complete_visual_scene(
  context : VisualSceneContext,
  differences : Array[@model.AtomicDifference],
  evidence_events : Array[@model.VisualEvent],
  subject_alignments : Array[@model.SubjectAlignment],
) -> @model.VisualSceneAnalysis {
  let analysis = context.analysis
  let difference_owners : Map[String, Array[String]] = Map([])
  for alignment in subject_alignments {
    difference_owners[alignment.id] = subject_alignment_owners(
      context, alignment,
    )
  }
  let scene_differences = differences.filter(scene_change_difference)
  let accounted_differences = differences.filter(scene_accounted_difference)
  let style_changed = scene_differences.any(difference => {
    difference_supports_scene_event("style.change", difference.domain)
  })
  let summary = {
    ..analysis.summary,
    style: if analysis.summary.style == "preserved" && style_changed {
      "changed"
    } else {
      analysis.summary.style
    },
  }
  let events = analysis.events.copy()
  fn owners_for_kind(kind : String) -> Array[String] {
    let owners : Array[String] = []
    for difference in scene_differences {
      if !difference_supports_scene_event(kind, difference.domain) {
        continue
      }
      match difference.subject_alignment_id {
        Some(id) =>
          match difference_owners.get(id) {
            Some(ids) =>
              for owner in ids {
                if !owners.contains(owner) {
                  owners.push(owner)
                }
              }
            None => ()
          }
        None => ()
      }
    }
    owners.sort()
    owners
  }
  fn ensure_event(kind : String, owner_ids : Array[String]) -> Unit {
    if !events.any(event => event.kind == kind) {
      events.push(scene_event(kind, owner_ids, events.length()))
    }
  }
  if style_changed {
    ensure_event("style.change", owners_for_kind("style.change"))
  }
  let scene_events : Array[@model.VisualChangeEvent] = []
  let classified_difference_ids : Array[String] = []
  for scene_event in events {
    let supporting = scene_differences.filter(difference => {
      if !difference_supports_scene_event(scene_event.kind, difference.domain) {
        return false
      }
      if difference.domain.has_prefix("document.viewport") &&
        (
          scene_event.kind == "layout.reflow" ||
          scene_event.kind == "layout.global_affine"
        ) {
        return true
      }
      let owners = difference.subject_alignment_id
        .bind(id => difference_owners.get(id))
        .unwrap_or([])
      if scene_event.object_alignment_ids.is_empty() {
        owners.is_empty()
      } else {
        owners.any(owner => scene_event.object_alignment_ids.contains(owner))
      }
    })
    let evidence_domains : Array[@model.VisualEvidenceDomain] = []
    let representative_ids : Array[String] = []
    for difference in supporting {
      let mut found = false
      for index, evidence_domain in evidence_domains {
        if evidence_domain.domain == difference.domain {
          evidence_domains[index] = {
            ..evidence_domain,
            count: evidence_domain.count + 1,
          }
          found = true
          break
        }
      }
      if !found {
        evidence_domains.push({ domain: difference.domain, count: 1 })
        representative_ids.push(difference.id)
      }
    }
    let supporting_ids = supporting.map(difference => difference.id)
    for id in supporting_ids {
      if !classified_difference_ids.contains(id) {
        classified_difference_ids.push(id)
      }
    }
    let event_ids = [
      for event in evidence_events if event.atomic_difference_ids.any(id => {
        supporting_ids.contains(id)
      }) => event.id
    ]
    scene_events.push({
      ..scene_event,
      atomic_difference_ids: representative_ids,
      evidence_event_ids: event_ids,
      evidence_difference_count: supporting.length(),
      evidence_domains,
    })
  }
  let residual_difference_ids = [
    for difference in accounted_differences if !classified_difference_ids.contains(
      difference.id,
    ) => difference.id
  ]
  let residual_domains : Array[@model.VisualEvidenceDomain] = []
  for difference in accounted_differences {
    if !residual_difference_ids.contains(difference.id) {
      continue
    }
    let mut found = false
    for index, evidence_domain in residual_domains {
      if evidence_domain.domain == difference.domain {
        residual_domains[index] = {
          ..evidence_domain,
          count: evidence_domain.count + 1,
        }
        found = true
        break
      }
    }
    if !found {
      residual_domains.push({ domain: difference.domain, count: 1 })
    }
  }
  {
    ..analysis,
    summary,
    events: scene_events,
    evidence_coverage: {
      effective_difference_count: accounted_differences.length(),
      classified_difference_count: classified_difference_ids.length(),
      residual_difference_count: residual_difference_ids.length(),
      residual_domains,
    },
  }
}

///|
fn scene_events(
  before : VisualScene,
  after : VisualScene,
  summary : @model.VisualSceneSummary,
  alignments : Array[@model.VisualObjectAlignment],
  layout_kind : String,
) -> Array[@model.VisualChangeEvent] {
  let events : Array[@model.VisualChangeEvent] = []
  fn append(
    kind : String,
    selected : Array[@model.VisualObjectAlignment],
  ) -> Unit {
    events.push(
      scene_event(
        kind,
        selected.map(alignment => alignment.id),
        events.length(),
      ),
    )
  }
  if summary.content == "changed" {
    append(
      "content.change",
      alignments.filter(alignment => {
        alignment_content_changed(before, after, alignment)
      }),
    )
  }
  if summary.object_set == "changed" {
    append(
      "object.presence",
      alignments.filter(alignment => {
        alignment.relation == "insertion" || alignment.relation == "deletion"
      }),
    )
  }
  if summary.relation_graph == "changed" {
    let participating_ids : Array[String] = []
    let relations = before.relations.copy()
    relations.push_iter(after.relations.iter())
    for relation in relations {
      for object_id in relation.endpoint_object_ids {
        for alignment in alignments {
          if alignment.before_object_ids.contains(object_id) ||
            alignment.after_object_ids.contains(object_id) {
            if !participating_ids.contains(alignment.id) {
              participating_ids.push(alignment.id)
            }
            break
          }
        }
      }
    }
    append(
      "relation.change",
      alignments.filter(alignment => participating_ids.contains(alignment.id)),
    )
  }
  if summary.layout == "changed" {
    append(
      layout_kind,
      alignments.filter(alignment => {
        alignment_bounds_changed(before, after, alignment)
      }),
    )
  }
  if summary.style == "changed" {
    append(
      "style.change",
      alignments.filter(alignment => {
        alignment_style_changed(before, after, alignment)
      }),
    )
  }
  if summary.representation == "changed" {
    append(
      "representation.change",
      alignments.filter(alignment => {
        alignment_representation_changed(before, after, alignment)
      }),
    )
  }
  events
}

///|
fn relation_graph_signatures(
  relations : Array[@model.VisualRelationSummary],
  alignments : Array[@model.VisualObjectAlignment],
) -> Array[String]? {
  let signatures : Array[String] = []
  for relation in relations {
    if relation.endpoint_object_ids.length() != 2 {
      return None
    }
    let endpoints : Array[String] = []
    for object_id in relation.endpoint_object_ids {
      let mut alignment_id : String? = None
      for alignment in alignments {
        if alignment.before_object_ids.contains(object_id) ||
          alignment.after_object_ids.contains(object_id) {
          alignment_id = Some(alignment.id)
          break
        }
      }
      match alignment_id {
        Some(id) => endpoints.push(id)
        None => return None
      }
    }
    endpoints.sort()
    signatures.push(endpoints.join("--"))
  }
  signatures.sort()
  Some(signatures)
}

///|
pub fn prepare_visual_scene(
  before_svg : String,
  after_svg : String,
  profile : @model.ComparisonProfile,
) -> VisualSceneContext raise {
  let before = build_visual_scene(before_svg, "before", profile)
  let after = build_visual_scene(after_svg, "after", profile)
  let alignments = align_scene_objects(before, after)
  {
    analysis: analyze_visual_scene(before, after, alignments),
    before_subject_owners: scene_subject_ownership(before, alignments, "before"),
    after_subject_owners: scene_subject_ownership(after, alignments, "after"),
    before_subject_owner_entries: scene_subject_owner_entries(
      before, alignments, "before",
    ),
    after_subject_owner_entries: scene_subject_owner_entries(
      after, alignments, "after",
    ),
  }
}

///|
fn analyze_visual_scene(
  before : VisualScene,
  after : VisualScene,
  alignments : Array[@model.VisualObjectAlignment],
) -> @model.VisualSceneAnalysis {
  if before.objects.is_empty() &&
    after.objects.is_empty() &&
    before.semantic_text.is_empty() &&
    after.semantic_text.is_empty() &&
    before.relations.is_empty() &&
    after.relations.is_empty() {
    return @model.empty_visual_scene_analysis()
  }
  let unresolved = alignments.any(alignment => {
    alignment.relation == "unresolved"
  })
  let object_set_preserved = before.objects.length() == after.objects.length() &&
    alignments.all(alignment => {
      alignment.relation == "correspondence" ||
      alignment.relation == "equivalence_class"
    })
  let content_preserved = before.semantic_text == after.semantic_text &&
    !alignments.any(alignment => {
      alignment_content_changed(before, after, alignment)
    })
  let relation_graph = if before.relations.is_empty() &&
    after.relations.is_empty() {
    "preserved"
  } else if unresolved {
    "indeterminate"
  } else if before.relations.length() != after.relations.length() {
    "changed"
  } else {
    match
      (
        relation_graph_signatures(before.relations, alignments),
        relation_graph_signatures(after.relations, alignments),
      ) {
      (Some(left), Some(right)) =>
        if left == right {
          "preserved"
        } else {
          "changed"
        }
      _ => "indeterminate"
    }
  }
  let layout_changed = aligned_bounds_changed(before, after, alignments)
  let layout_kind = if shared_axis_aligned_transform(before, after, alignments) {
    "layout.global_affine"
  } else {
    "layout.reflow"
  }
  let style_changed = aligned_style_changed(before, after, alignments)
  let representation_changed = aligned_representation_changed(
    before, after, alignments,
  )
  let summary : @model.VisualSceneSummary = {
    status: "computed",
    content: if content_preserved {
      "preserved"
    } else {
      "changed"
    },
    object_set: if unresolved {
      "indeterminate"
    } else if object_set_preserved {
      "preserved"
    } else {
      "changed"
    },
    relation_graph,
    layout: if unresolved {
      "indeterminate"
    } else if layout_changed {
      "changed"
    } else {
      "preserved"
    },
    style: if unresolved {
      "indeterminate"
    } else if style_changed {
      "changed"
    } else {
      "preserved"
    },
    representation: if unresolved {
      "indeterminate"
    } else if representation_changed {
      "changed"
    } else {
      "preserved"
    },
    before_object_count: before.objects.length(),
    after_object_count: after.objects.length(),
    before_relation_count: before.relations.length(),
    after_relation_count: after.relations.length(),
  }
  {
    summary,
    before_objects: [
      for object in before.objects => object.summary
    ],
    after_objects: [
      for object in after.objects => object.summary
    ],
    before_relations: before.relations,
    after_relations: after.relations,
    alignments,
    events: scene_events(before, after, summary, alignments, layout_kind),
    evidence_coverage: {
      effective_difference_count: 0,
      classified_difference_count: 0,
      residual_difference_count: 0,
      residual_domains: [],
    },
  }
}

///|
fn scene_object_owner(
  object : SceneObject,
  alignments : Array[@model.VisualObjectAlignment],
  side : String,
) -> String {
  let mut owner = "unresolved:\{side}:\{object.summary.id}"
  for alignment in alignments {
    let contains = if side == "before" {
      alignment.before_object_ids.contains(object.summary.id)
    } else {
      alignment.after_object_ids.contains(object.summary.id)
    }
    if contains {
      if alignment.relation != "unresolved" {
        owner = alignment.id
      }
      break
    }
  }
  owner
}

///|
fn scene_subject_ownership(
  scene : VisualScene,
  alignments : Array[@model.VisualObjectAlignment],
  side : String,
) -> Array[String?] {
  let subject_count = scene.objects.fold(init=0, fn(count, object) {
    object.primitive_indices.fold(init=count, fn(current, index) {
      current.max(index + 1)
    })
  })
  let owners : Array[String?] = Array::make(subject_count, None)
  for object in scene.objects {
    let owner = scene_object_owner(object, alignments, side)
    let constrain_graphic = object.summary.role == "graphic" &&
      alignments.any(alignment => {
        alignment.id == owner && alignment.basis == "authored_identity/v1"
      })
    if object.summary.role != "entity" && !constrain_graphic {
      continue
    }
    for index in object.primitive_indices {
      owners[index] = Some(owner)
    }
  }
  owners
}

///|
fn scene_subject_owner_entries(
  scene : VisualScene,
  alignments : Array[@model.VisualObjectAlignment],
  side : String,
) -> Array[(String, String)] {
  let entries : Array[(String, String)] = []
  for object in scene.objects {
    let owner = scene_object_owner(object, alignments, side)
    for subject_id in object.summary.subject_ids {
      if !entries.any(entry => entry.0 == subject_id) {
        entries.push((subject_id, owner))
      }
    }
  }
  entries
}

///|
/// Return the accepted Visual Object Alignment that owns each rendered subject.
/// Unresolved or one-sided objects receive side-specific keys so they cannot be
/// paired accidentally. Subjects outside an extracted object remain unowned.
pub fn VisualSceneContext::subject_ownership(
  self : VisualSceneContext,
) -> (Array[String?], Array[String?]) {
  (self.before_subject_owners, self.after_subject_owners)
}

///|
pub fn VisualSceneContext::analysis(
  self : VisualSceneContext,
) -> @model.VisualSceneAnalysis {
  self.analysis
}

///|
pub fn compare_visual_scenes(
  before_svg : String,
  after_svg : String,
  profile : @model.ComparisonProfile,
) -> @model.VisualSceneAnalysis raise {
  prepare_visual_scene(before_svg, after_svg, profile).analysis()
}
