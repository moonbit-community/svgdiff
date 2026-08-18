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
fn object_change_plans(
  before : VisualScene,
  after : VisualScene,
  summary : @model.VisualSceneSummary,
  alignments : Array[@model.VisualObjectAlignment],
  layout_kind : String,
) -> Array[(String, String)] {
  let plans : Array[(String, String)] = []
  fn append(
    kind : String,
    selected : Array[@model.VisualObjectAlignment],
  ) -> Unit {
    for alignment in selected {
      plans.push((kind, alignment.id))
    }
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
  plans
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
  let (analysis, object_change_plans) = analyze_visual_scene(
    before, after, alignments,
  )
  {
    analysis,
    object_change_plans,
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
) -> (@model.VisualSceneAnalysis, Array[(String, String)]) {
  if before.objects.is_empty() &&
    after.objects.is_empty() &&
    before.semantic_text.is_empty() &&
    after.semantic_text.is_empty() &&
    before.relations.is_empty() &&
    after.relations.is_empty() {
    return (@model.empty_visual_scene_analysis(), [])
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
  let analysis : @model.VisualSceneAnalysis = {
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
    object_changes: [],
    events: [],
    evidence_coverage: {
      difference_to_object: {
        effective_difference_count: 0,
        assigned_difference_count: 0,
        unresolved_difference_count: 0,
        unresolved_domains: [],
      },
      object_to_scene: {
        object_change_count: 0,
        assigned_object_change_count: 0,
        residual_object_change_count: 0,
        residual_kinds: [],
      },
    },
  }
  (
    analysis,
    object_change_plans(before, after, summary, alignments, layout_kind),
  )
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
  complete_visual_scene(
    prepare_visual_scene(before_svg, after_svg, profile),
    [],
    [],
    [],
    [],
  )
}
