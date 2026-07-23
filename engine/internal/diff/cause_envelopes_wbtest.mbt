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
fn influence_test_fact(
  id : String,
  property : String,
  affected_subject_ids : Array[String],
) -> ChangedFact {
  {
    id,
    subject_id: id,
    property,
    before: None,
    after: None,
    affected_subject_ids,
  }
}

///|
fn influence_test_alignment(
  relation : String,
  before : Array[SubjectReference],
  after : Array[SubjectReference],
) -> SubjectAlignment {
  {
    id: "alignment:test",
    subject_role: "entity",
    relation,
    before,
    after,
    basis: "test",
    evidence: {
      score_kind: "test",
      selected_score: None,
      candidate_count: 0,
      equal_score_candidate_count: 0,
      ambiguity: "not_assessed",
      confidence: None,
      confidence_status: "not_calibrated",
    },
  }
}

///|
fn influence_test_reference(
  source_index : Int,
  authored_id : String?,
  instance_id : String?,
) -> SubjectReference {
  {
    source_index,
    kind: "rect",
    authored_id,
    instance_context: instance_id.map(instance_id => {
      instance_id,
      definition_subject_id: "tile",
      use_path: ["symbol", "use"],
    }),
  }
}

///|
fn influence_test_event_for_domain(
  report : StructuredReport,
  domain : String,
) -> VisualEvent? {
  for difference in report.atomic_differences {
    if difference.domain == domain {
      for event in report.events {
        if event.atomic_difference_ids.contains(difference.id) {
          return Some(event)
        }
      }
    }
  }
  None
}

///|
test "subject influence index covers every source-input token category" {
  let facts = [
    influence_test_fact("fact:geometry", "geometry.position", ["box"]),
    influence_test_fact("fact:paint", "paint.fill", ["box"]),
    influence_test_fact("fact:resource", "resource.gradient.stop", ["box"]),
    influence_test_fact("fact:transform", "transform", ["box"]),
    influence_test_fact("fact:viewport", "viewBox", ["box"]),
    influence_test_fact("fact:structure", "structure.stacking_order", [
      "box", "backdrop",
    ]),
    influence_test_fact("fact:unrelated", "paint.fill", ["other"]),
    influence_test_fact("fact:unscoped", "resource.unused", []),
  ]
  let index = build_subject_influence_index(facts)
  assert_eq(subject_influence_fact_ids(index, ["box"]), [
    "fact:geometry", "fact:paint", "fact:resource", "fact:transform", "fact:viewport",
    "fact:structure",
  ])
  assert_eq(subject_influence_fact_ids(index, ["other"]), ["fact:unrelated"])
  assert_true(subject_influence_fact_ids(index, ["missing"]).is_empty())
}

///|
test "alignment influence identities retain both sides and use instances" {
  let before = influence_test_reference(0, Some("before"), None)
  let after = influence_test_reference(
    1,
    Some("definition"),
    Some("instance/use/tile"),
  )
  assert_eq(
    alignment_influence_subject_ids(
      influence_test_alignment("correspondence", [before], [after]),
    ),
    ["before", "instance/use/tile"],
  )
  assert_eq(
    alignment_influence_subject_ids(
      influence_test_alignment("insertion", [], [after]),
    ),
    ["instance/use/tile"],
  )
  assert_eq(
    alignment_influence_subject_ids(
      influence_test_alignment("deletion", [before], []),
    ),
    ["before"],
  )
}

///|
test "cause attachment reaches same-subject tokens outside direct event links" {
  let before =
    #|<svg width="16" height="16"><rect id="left" x="1" y="1" width="3" height="3" fill="red"/><rect id="right" x="12" y="12" width="3" height="3" fill="red"/></svg>
  let after =
    #|<svg width="16" height="16"><rect id="left" x="1" y="1" width="3" height="3" fill="blue"/><rect id="right" x="12" y="12" width="3" height="3" fill="green"/></svg>
  let report = compare(before, after, ComparisonProfile::v1_default())
  guard report.changed_facts.filter(fact => {
      fact.affected_subject_ids == ["left"]
    })
    is [left_fact] else {
    fail("expected one left changed fact")
  }
  let propagated_id = "fact:propagated:left-transform"
  let changed_facts = report.changed_facts.copy()
  changed_facts.push({ ..left_fact, id: propagated_id, property: "transform" })
  let attached = attach_cause_envelopes({ ..report, changed_facts, })
  guard attached.events.filter(event => {
      event.difference_regions.any(region => {
        region.cause_envelope.candidate_changed_fact_ids.contains(propagated_id)
      })
    })
    is [left_event] else {
    fail("expected the propagated token on exactly one event")
  }
  assert_true(
    left_event.atomic_difference_ids.any(id => {
      report.atomic_differences.any(difference => {
        difference.id == id &&
        difference.changed_fact_ids.contains(left_fact.id)
      })
    }),
  )
  assert_true(
    attached.events
    .filter(event => event.id != left_event.id)
    .all(event => {
      event.difference_regions.all(region => {
        !region.cause_envelope.candidate_changed_fact_ids.contains(
          propagated_id,
        )
      })
    }),
  )
}

///|
test "resource and relationship events query direct-fact subject fan-out" {
  let clip_before =
    #|<svg width="16" height="16"><defs><clipPath id="clip"><rect width="4" height="8"/></clipPath></defs><rect id="left" width="8" height="8" fill="red" clip-path="url(#clip)"/><rect id="right" x="8" width="8" height="8" fill="blue" clip-path="url(#clip)"/></svg>
  let clip_after = clip_before.replace_all(
    old="<rect width=\"4\"",
    new="<rect x=\"1\" width=\"4\"",
  )
  let clip_report = compare(
    clip_before,
    clip_after,
    ComparisonProfile::v1_default(),
  )
  guard clip_report.events.filter(event => event.id == "event:clip:clip")
    is [clip_event] else {
    fail("expected one clip resource event")
  }
  let clip_direct = event_changed_fact_ids(
    clip_event,
    clip_report.atomic_differences,
  )
  assert_eq(event_influence_subject_ids(clip_event, clip_report, clip_direct), [
    "left", "right",
  ])
  let clip_facts = clip_report.changed_facts.copy()
  clip_facts.push(
    influence_test_fact("fact:left:extra", "paint.fill", ["left"]),
  )
  clip_facts.push(
    influence_test_fact("fact:unrelated:extra", "paint.fill", ["other"]),
  )
  let clip_augmented = { ..clip_report, changed_facts: clip_facts }
  let clip_candidates = event_may_influence_fact_ids(
    clip_event,
    clip_augmented,
    build_subject_influence_index(clip_facts),
  )
  assert_true(clip_candidates.contains("fact:left:extra"))
  assert_true(!clip_candidates.contains("fact:unrelated:extra"))

  let stacking_before =
    #|<svg><rect id="red" width="12" height="12" fill="red"/><rect id="blue" x="4" y="4" width="12" height="12" fill="blue"/></svg>
  let stacking_after =
    #|<svg><rect id="blue" x="4" y="4" width="12" height="12" fill="blue"/><rect id="red" width="12" height="12" fill="red"/></svg>
  let stacking = compare(
    stacking_before,
    stacking_after,
    ComparisonProfile::v1_default(),
  )
  guard stacking.atomic_differences.filter(difference => {
      difference.domain == "document.structure.stacking_order"
    })
    is [stacking_difference] else {
    fail("expected one stacking relationship")
  }
  guard stacking.events.filter(event => {
      event.atomic_difference_ids.contains(stacking_difference.id)
    })
    is [stacking_event] else {
    fail("expected one stacking relationship event")
  }
  let stacking_direct = event_changed_fact_ids(
    stacking_event,
    stacking.atomic_differences,
  )
  assert_eq(
    event_influence_subject_ids(stacking_event, stacking, stacking_direct),
    ["red", "blue"],
  )
}

///|
test "operation classifier covers every supported effect and compositing family" {
  assert_true(influence_operation_for_domain("paint.fill") is LeafInput)
  assert_true(
    influence_operation_for_domain("compositing.opacity") is GroupSurface,
  )
  assert_true(influence_operation_for_domain("clipping.path") is ClipEffect)
  assert_true(
    influence_operation_for_domain("resource.clip.geometry") is ClipEffect,
  )
  assert_true(
    influence_operation_for_domain("masking.attachment") is MaskEffect,
  )
  assert_true(
    influence_operation_for_domain("resource.mask.geometry") is MaskEffect,
  )
  assert_true(
    influence_operation_for_domain("filtering.attachment") is FilterEffect,
  )
  assert_true(
    influence_operation_for_domain("resource.filter.primitive.offset")
    is FilterEffect,
  )
  assert_true(
    influence_operation_for_domain("compositing.blend_mode") is BlendEffect,
  )
  assert_true(
    influence_operation_for_domain("compositing.isolation") is IsolationEffect,
  )
  assert_true(
    influence_operation_for_domain("document.structure.stacking_order")
    is CompositingOrder,
  )
}

///|
test "group and blend transfer retain backdrop but exclude disjoint later facts" {
  let group_before =
    #|<svg width="16" height="16"><rect id="backdrop" width="8" height="8" fill="green"/><g id="layer" opacity="1"><rect id="front" width="8" height="8" fill="red"/></g><rect id="outside" x="13" y="1" width="2" height="2" fill="blue"/></svg>
  let group_after = group_before
    .replace_all(old="fill=\"green\"", new="fill=\"yellow\"")
    .replace_all(old="opacity=\"1\"", new="opacity=\"0.5\"")
    .replace_all(old="fill=\"blue\"", new="fill=\"lime\"")
  let group = compare(
    group_before,
    group_after,
    ComparisonProfile::v1_default(),
  )
  assert_eq(group.analysis_status, "complete")
  guard influence_test_event_for_domain(group, "compositing.opacity")
    is Some(group_event) else {
    fail("expected one group-opacity event")
  }
  guard group.changed_facts.filter(fact => {
      fact.property == "fill" && fact.affected_subject_ids == ["backdrop"]
    })
    is [backdrop_fact] else {
    fail("expected one backdrop fact")
  }
  guard group.changed_facts.filter(fact => {
      fact.property == "fill" && fact.affected_subject_ids == ["outside"]
    })
    is [outside_fact] else {
    fail("expected one outside fact")
  }
  assert_true(
    group_event.difference_regions.all(region => {
      region.cause_envelope.candidate_changed_fact_ids.contains(
        backdrop_fact.id,
      ) &&
      !region.cause_envelope.candidate_changed_fact_ids.contains(
        outside_fact.id,
      )
    }),
  )

  let blend_before =
    #|<svg width="16" height="16"><rect id="back" width="8" height="8" fill="#c86432"/><rect id="front" width="4" height="4" fill="#6496c8" style="mix-blend-mode:multiply"/><rect id="outside" x="13" y="1" width="2" height="2" fill="blue"/></svg>
  let blend_after = blend_before
    .replace_all(old="fill=\"#c86432\"", new="fill=\"#c86433\"")
    .replace_all(old="mix-blend-mode:multiply", new="mix-blend-mode:screen")
    .replace_all(old="fill=\"blue\"", new="fill=\"lime\"")
  let blend = compare(
    blend_before,
    blend_after,
    ComparisonProfile::v1_default(),
  )
  assert_eq(blend.analysis_status, "complete")
  guard influence_test_event_for_domain(blend, "compositing.blend_mode")
    is Some(blend_event) else {
    fail("expected one blend event")
  }
  guard blend.changed_facts.filter(fact => {
      fact.property == "fill" && fact.affected_subject_ids == ["back"]
    })
    is [blend_backdrop_fact] else {
    fail("expected one blend backdrop fact")
  }
  guard blend.changed_facts.filter(fact => {
      fact.property == "fill" && fact.affected_subject_ids == ["outside"]
    })
    is [blend_outside_fact] else {
    fail("expected one blend outside fact")
  }
  assert_true(
    blend_event.difference_regions.all(region => {
      region.cause_envelope.candidate_changed_fact_ids.contains(
        blend_backdrop_fact.id,
      ) &&
      !region.cause_envelope.candidate_changed_fact_ids.contains(
        blend_outside_fact.id,
      )
    }),
  )
}

///|
test "stacking transfer follows shared region identity without contamination" {
  let before =
    #|<svg width="16" height="16"><rect id="red" width="12" height="12" fill="red"/><rect id="blue" x="4" y="4" width="12" height="12" fill="blue"/><rect id="outside" x="13" y="1" width="2" height="2" fill="green"/></svg>
  let after =
    #|<svg width="16" height="16"><rect id="blue" x="4" y="4" width="12" height="12" fill="blue"/><rect id="red" width="12" height="12" fill="red"/><rect id="outside" x="13" y="1" width="2" height="2" fill="yellow"/></svg>
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "complete")
  guard influence_test_event_for_domain(
      report, "document.structure.stacking_order",
    )
    is Some(stacking_event) else {
    fail("expected one stacking event")
  }
  guard report.changed_facts.filter(fact => {
      fact.property == "fill" && fact.affected_subject_ids == ["outside"]
    })
    is [outside_fact] else {
    fail("expected one outside fact")
  }
  assert_true(stacking_event.difference_regions.length() >= 2)
  assert_true(
    stacking_event.difference_regions.any(region => {
      region.css_x < 12.0 &&
      !region.cause_envelope.candidate_changed_fact_ids.contains(
        outside_fact.id,
      )
    }),
  )
  assert_true(
    stacking_event.difference_regions.any(region => {
      region.css_x >= 12.0 &&
      region.cause_envelope.candidate_changed_fact_ids.contains(outside_fact.id)
    }),
  )
}

///|
test "mask and filter transfer reaches effect consumers and descendants" {
  let mask_before =
    #|<svg width="8" height="8"><defs><mask id="fade" mask-type="alpha" maskUnits="userSpaceOnUse"><rect width="4" height="8" fill="white"/></mask></defs><g id="layer"><rect id="box" width="8" height="8" fill="red"/></g></svg>
  let mask_after = mask_before.replace_all(
    old="<g id=\"layer\">",
    new="<g id=\"layer\" mask=\"url(#fade)\">",
  )
  let mask = compare(mask_before, mask_after, {
    ..ComparisonProfile::v1_default(),
    viewport_width: 8,
    viewport_height: 8,
  })
  guard influence_test_event_for_domain(mask, "masking.attachment")
    is Some(mask_event) else {
    fail("expected one mask host event")
  }
  let mask_direct = event_changed_fact_ids(mask_event, mask.atomic_differences)
  assert_eq(event_influence_subject_ids(mask_event, mask, mask_direct), [
    "layer", "box",
  ])
  let mask_facts = mask.changed_facts.copy()
  mask_facts.push(
    influence_test_fact("fact:mask-child-input", "paint.fill", ["box"]),
  )
  let mask_augmented = { ..mask, changed_facts: mask_facts }
  assert_true(
    event_may_influence_fact_ids(
      mask_event,
      mask_augmented,
      build_subject_influence_index(mask_facts),
    ).contains("fact:mask-child-input"),
  )

  let filter_before =
    #|<svg width="16" height="16"><defs><filter id="shift" x="-100%" y="-100%" width="400%" height="400%"><feOffset dx="1"/></filter></defs><rect id="box" x="2" y="2" width="4" height="4" fill="red" filter="url(#shift)"/></svg>
  let filter_after = filter_before.replace_all(old="dx=\"1\"", new="dx=\"3\"")
  let filter = compare(
    filter_before,
    filter_after,
    ComparisonProfile::v1_default(),
  )
  guard filter.events.filter(event => event.id == "event:filter:shift")
    is [filter_event] else {
    fail("expected one filter resource event")
  }
  let filter_direct = event_changed_fact_ids(
    filter_event,
    filter.atomic_differences,
  )
  assert_eq(event_influence_subject_ids(filter_event, filter, filter_direct), [
    "box",
  ])
  let filter_facts = filter.changed_facts.copy()
  filter_facts.push(
    influence_test_fact("fact:filter-input", "paint.fill", ["box"]),
  )
  let filter_augmented = { ..filter, changed_facts: filter_facts }
  assert_true(
    event_may_influence_fact_ids(
      filter_event,
      filter_augmented,
      build_subject_influence_index(filter_facts),
    ).contains("fact:filter-input"),
  )
}
