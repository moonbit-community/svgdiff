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
pub fn attach_visual_scene_evidence(
  analysis : @model.VisualSceneAnalysis,
  differences : Array[@model.AtomicDifference],
  evidence_events : Array[@model.VisualEvent],
) -> @model.VisualSceneAnalysis {
  let effective_differences = differences.filter(difference => {
    difference.computed_relation.status == "different"
  })
  let style_changed = effective_differences.any(difference => {
    difference_supports_scene_event("style.change", difference.domain)
  })
  let summary = {
    ..analysis.summary,
    style: if style_changed {
      "changed"
    } else {
      analysis.summary.style
    },
  }
  let events = analysis.events.copy()
  fn ensure_event(kind : String) -> Unit {
    if !events.any(event => event.kind == kind) {
      events.push(scene_event(kind, [], events.length()))
    }
  }
  if style_changed {
    ensure_event("style.change")
  }
  let scene_events : Array[@model.VisualChangeEvent] = []
  for scene_event in events {
    let supporting = differences.filter(difference => {
      difference_supports_scene_event(scene_event.kind, difference.domain)
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
    let event_ids = [
      for event in evidence_events if event.atomic_difference_ids.any(id => {
        representative_ids.contains(id)
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
  { ..analysis, summary, events: scene_events }
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
pub fn compare_visual_scenes(
  before_svg : String,
  after_svg : String,
  profile : @model.ComparisonProfile,
) -> @model.VisualSceneAnalysis raise {
  let before = build_visual_scene(before_svg, "before", profile)
  let after = build_visual_scene(after_svg, "after", profile)
  if before.objects.is_empty() &&
    after.objects.is_empty() &&
    before.semantic_text.is_empty() &&
    after.semantic_text.is_empty() &&
    before.relations.is_empty() &&
    after.relations.is_empty() {
    return @model.empty_visual_scene_analysis()
  }
  let alignments = align_scene_objects(before, after)
  let object_set_preserved = before.objects.length() == after.objects.length() &&
    alignments.all(alignment => {
      alignment.relation == "correspondence" ||
      alignment.relation == "equivalence_class"
    })
  let content_preserved = before.semantic_text == after.semantic_text &&
    !alignments.any(alignment => {
      alignment_content_changed(before, after, alignment)
    })
  let relation_graph = if before.relations.length() != after.relations.length() {
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
    object_set: if object_set_preserved {
      "preserved"
    } else {
      "changed"
    },
    relation_graph,
    layout: if layout_changed {
      "changed"
    } else {
      "preserved"
    },
    style: if style_changed {
      "changed"
    } else {
      "preserved"
    },
    representation: if representation_changed {
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
  }
}
