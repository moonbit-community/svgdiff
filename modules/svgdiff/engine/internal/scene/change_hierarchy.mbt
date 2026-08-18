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
fn difference_supports_object_change(kind : String, domain : String) -> Bool {
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
fn evidence_created_object_change_kinds(domain : String) -> Array[String] {
  let kinds = ["content.change", "style.change", "representation.change"]
  kinds.filter(kind => difference_supports_object_change(kind, domain))
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
fn owners_for_subject_id(
  context : VisualSceneContext,
  subject_id : String,
) -> Array[String] {
  let owners : Array[String] = []
  for entry in context.before_subject_owner_entries {
    if entry.0 == subject_id &&
      entry.1.has_prefix("object-alignment:") &&
      !owners.contains(entry.1) {
      owners.push(entry.1)
    }
  }
  for entry in context.after_subject_owner_entries {
    if entry.0 == subject_id &&
      entry.1.has_prefix("object-alignment:") &&
      !owners.contains(entry.1) {
      owners.push(entry.1)
    }
  }
  owners
}

///|
fn difference_object_owners(
  context : VisualSceneContext,
  difference : @model.AtomicDifference,
  direct_owners : Map[String, Array[String]],
  changed_facts : Array[@model.ChangedFact],
) -> Array[String] {
  let direct = match difference.subject_alignment_id {
    Some(id) => direct_owners.get(id).unwrap_or([])
    None => []
  }
  if direct.length() == 1 {
    return direct
  }
  if direct.length() > 1 {
    return []
  }
  let consumers : Array[String] = []
  for fact in changed_facts {
    if !difference.changed_fact_ids.contains(fact.id) {
      continue
    }
    for subject_id in fact.affected_subject_ids {
      for owner in owners_for_subject_id(context, subject_id) {
        if !consumers.contains(owner) {
          consumers.push(owner)
        }
      }
    }
  }
  consumers
}

///|
fn change_evidence(difference : @model.AtomicDifference) -> Bool {
  difference.computed_relation.status == "different" ||
  difference.computed_relation.status == "not_applicable"
}

///|
fn effective_evidence(difference : @model.AtomicDifference) -> Bool {
  difference.computed_relation.status != "equivalent"
}

///|
fn add_plan(
  plans : Array[(String, String)],
  kind : String,
  object_alignment_id : String,
) -> Unit {
  if !plans.any(plan => plan.0 == kind && plan.1 == object_alignment_id) {
    plans.push((kind, object_alignment_id))
  }
}

///|
fn evidence_domains(
  differences : Array[@model.AtomicDifference],
) -> Array[@model.VisualEvidenceDomain] {
  let domains : Array[@model.VisualEvidenceDomain] = []
  for difference in differences {
    let mut found = false
    for index, domain in domains {
      if domain.domain == difference.domain {
        domains[index] = { ..domain, count: domain.count + 1 }
        found = true
        break
      }
    }
    if !found {
      domains.push({ domain: difference.domain, count: 1 })
    }
  }
  domains
}

///|
fn changed_summary(
  summary : @model.VisualSceneSummary,
  object_changes : Array[@model.VisualObjectChange],
) -> @model.VisualSceneSummary {
  fn changed(axis : String, kind : String) -> String {
    if axis == "preserved" &&
      object_changes.any(change => {
        change.kind == kind ||
        (kind == "layout" && change.kind.has_prefix("layout."))
      }) {
      "changed"
    } else {
      axis
    }
  }
  {
    ..summary,
    content: changed(summary.content, "content.change"),
    object_set: changed(summary.object_set, "object.presence"),
    relation_graph: changed(summary.relation_graph, "relation.change"),
    layout: changed(summary.layout, "layout"),
    style: changed(summary.style, "style.change"),
    representation: changed(summary.representation, "representation.change"),
  }
}

///|
fn object_change_coverage(
  object_changes : Array[@model.VisualObjectChange],
  scene_changes : Array[@model.VisualSceneChange],
) -> @model.VisualObjectChangeCoverage {
  let assigned_ids : Array[String] = []
  for change in scene_changes {
    for id in change.object_change_ids {
      if !assigned_ids.contains(id) {
        assigned_ids.push(id)
      }
    }
  }
  let residual = object_changes.filter(change => {
    !assigned_ids.contains(change.id)
  })
  let residual_kinds : Array[@model.VisualEvidenceDomain] = []
  for change in residual {
    let mut found = false
    for index, item in residual_kinds {
      if item.domain == change.kind {
        residual_kinds[index] = { ..item, count: item.count + 1 }
        found = true
        break
      }
    }
    if !found {
      residual_kinds.push({ domain: change.kind, count: 1 })
    }
  }
  {
    object_change_count: object_changes.length(),
    assigned_object_change_count: assigned_ids.length(),
    residual_object_change_count: residual.length(),
    residual_kinds,
  }
}

///|
fn scene_changes_from_objects(
  object_changes : Array[@model.VisualObjectChange],
  evidence_events : Array[@model.VisualEvent],
) -> Array[@model.VisualSceneChange] {
  let changes : Array[@model.VisualSceneChange] = []
  let assigned : Array[String] = []
  for seed in object_changes {
    if assigned.contains(seed.id) {
      continue
    }
    let selected = [seed]
    assigned.push(seed.id)
    let mut expanded = true
    while expanded {
      expanded = false
      for candidate in object_changes {
        if candidate.kind != seed.kind || assigned.contains(candidate.id) {
          continue
        }
        let connected = candidate.changed_fact_ids.any(fact_id => {
          selected.any(change => change.changed_fact_ids.contains(fact_id))
        })
        if connected {
          selected.push(candidate)
          assigned.push(candidate.id)
          expanded = true
        }
      }
    }
    let object_change_ids = selected.map(change => change.id)
    let changed_fact_ids : Array[String] = []
    let difference_ids : Array[String] = []
    let subject_ids : Array[String] = []
    for change in selected {
      for id in change.changed_fact_ids {
        if !changed_fact_ids.contains(id) {
          changed_fact_ids.push(id)
        }
      }
      for id in change.atomic_difference_ids {
        if !difference_ids.contains(id) {
          difference_ids.push(id)
        }
      }
      for event_id in change.evidence_event_ids {
        for event in evidence_events {
          if event.id == event_id &&
            !subject_ids.contains(event.primary_subject_id) {
            subject_ids.push(event.primary_subject_id)
            break
          }
        }
      }
    }
    changes.push({
      id: "scene-change:\{changes.length()}",
      kind: seed.kind,
      scope: if selected.length() > 1 {
        "systemic"
      } else if selected.length() == 1 {
        "object"
      } else {
        "comparison"
      },
      object_change_ids,
      changed_fact_ids,
      effect_count: difference_ids.length(),
      affected_subject_count: subject_ids.length(),
    })
  }
  changes
}

///|
/// Complete the typed causal hierarchy without allowing Scene Changes to read
/// Atomic Differences directly. Directly ambiguous ownership stays unresolved;
/// an explicit Changed Fact consumer list may fan one cause out to many objects.
pub fn complete_visual_scene(
  context : VisualSceneContext,
  changed_facts : Array[@model.ChangedFact],
  differences : Array[@model.AtomicDifference],
  evidence_events : Array[@model.VisualEvent],
  subject_alignments : Array[@model.SubjectAlignment],
) -> @model.VisualSceneAnalysis {
  let difference_owners : Map[String, Array[String]] = Map([])
  for alignment in subject_alignments {
    difference_owners[alignment.id] = subject_alignment_owners(
      context, alignment,
    )
  }
  let change_differences = differences.filter(change_evidence)
  let effective_differences = differences.filter(effective_evidence)
  let owners_by_difference : Map[String, Array[String]] = Map([])
  for difference in change_differences {
    owners_by_difference[difference.id] = difference_object_owners(
      context, difference, difference_owners, changed_facts,
    )
  }
  let plans = context.object_change_plans.copy()
  for difference in change_differences {
    let owners = owners_by_difference.get(difference.id).unwrap_or([])
    for owner in owners {
      for kind in evidence_created_object_change_kinds(difference.domain) {
        add_plan(plans, kind, owner)
      }
    }
  }
  let valid_fact_ids = changed_facts.map(fact => fact.id)
  let object_changes : Array[@model.VisualObjectChange] = []
  for plan in plans {
    let supporting = change_differences.filter(difference => {
      if !difference_supports_object_change(plan.0, difference.domain) {
        return false
      }
      owners_by_difference.get(difference.id).unwrap_or([]).contains(plan.1)
    })
    let difference_ids = supporting.map(difference => difference.id)
    let fact_ids : Array[String] = []
    for difference in supporting {
      for id in difference.changed_fact_ids {
        if valid_fact_ids.contains(id) && !fact_ids.contains(id) {
          fact_ids.push(id)
        }
      }
    }
    let event_ids : Array[String] = []
    for event in evidence_events {
      if event.atomic_difference_ids.any(id => difference_ids.contains(id)) {
        event_ids.push(event.id)
      }
    }
    object_changes.push({
      id: "object-change:\{object_changes.length()}",
      kind: plan.0,
      object_alignment_id: plan.1,
      changed_fact_ids: fact_ids,
      atomic_difference_ids: difference_ids,
      evidence_event_ids: event_ids,
      evidence_domains: evidence_domains(supporting),
    })
  }
  let scene_changes = scene_changes_from_objects(
    object_changes, evidence_events,
  )
  let assigned_ids : Array[String] = []
  for change in object_changes {
    for id in change.atomic_difference_ids {
      if !assigned_ids.contains(id) {
        assigned_ids.push(id)
      }
    }
  }
  let unresolved = effective_differences.filter(difference => {
    !assigned_ids.contains(difference.id)
  })
  let analysis = context.analysis
  {
    ..analysis,
    summary: changed_summary(analysis.summary, object_changes),
    object_changes,
    events: scene_changes,
    evidence_coverage: {
      difference_to_object: {
        effective_difference_count: effective_differences.length(),
        assigned_difference_count: assigned_ids.length(),
        unresolved_difference_count: unresolved.length(),
        unresolved_domains: evidence_domains(unresolved),
      },
      object_to_scene: object_change_coverage(object_changes, scene_changes),
    },
  }
}
