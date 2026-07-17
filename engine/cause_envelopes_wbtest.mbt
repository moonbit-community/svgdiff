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
