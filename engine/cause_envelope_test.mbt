///|
test "every complete difference region contains its actual changed fact" {
  let before = "<svg width='16' height='16'><rect id='box' x='1' y='2' width='4' height='4' fill='red'/></svg>"
  let after = "<svg width='16' height='16'><rect id='box' x='5' y='2' width='4' height='4' fill='red'/></svg>"
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "complete")
  assert_true(!report.changed_facts.is_empty())
  for event in report.events {
    for region in event.difference_regions {
      assert_eq(region.cause_envelope.guarantee, "sound_overapproximation")
      for difference_id in event.atomic_difference_ids {
        for difference in report.atomic_differences {
          if difference.id == difference_id {
            for fact_id in difference.changed_fact_ids {
              assert_true(
                region.cause_envelope.candidate_changed_fact_ids.contains(
                  fact_id,
                ),
              )
            }
          }
        }
      }
    }
  }
}

///|
test "inherited paint envelopes retain the ancestor changed fact" {
  let before = "<svg width='16' height='16'><g id='theme' fill='red'><rect id='box' x='2' y='2' width='4' height='4'/></g></svg>"
  let after = "<svg width='16' height='16'><g id='theme' fill='blue'><rect id='box' x='2' y='2' width='4' height='4'/></g></svg>"
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  let fact_id = report.changed_facts[0].id
  assert_true(
    report.events[0].difference_regions[0].cause_envelope.candidate_changed_fact_ids.contains(
      fact_id,
    ),
  )
}

///|
test "unsupported semantics revoke causal completeness" {
  let before = "<svg width='16' height='16'><circle cx='8' cy='8' r='3' fill='red' class='unresolved'/></svg>"
  let after = "<svg width='16' height='16'><circle cx='8' cy='8' r='3' fill='blue' class='unresolved'/></svg>"
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "partial")
  assert_true(
    report.events[0].difference_regions.all(region => {
      region.cause_envelope.guarantee == "not_established" &&
      !region.cause_envelope.diagnostic_ids.is_empty()
    }),
  )
}

///|
test "partial envelopes widen every region to the comparison fact universe" {
  let before = "<svg width='16' height='16'><circle id='left' cx='4' cy='4' r='2' fill='red' class='unresolved'/><circle id='right' cx='12' cy='12' r='2' fill='red' class='unresolved'/></svg>"
  let after = "<svg width='16' height='16'><circle id='left' cx='4' cy='4' r='2' fill='blue' class='unresolved'/><circle id='right' cx='12' cy='12' r='2' fill='green' class='unresolved'/></svg>"
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "partial")
  assert_eq(report.changed_facts.length(), 2)
  assert_true(report.events.any(event => !event.difference_regions.is_empty()))
  let all_fact_ids = [ for fact in report.changed_facts => fact.id ]
  all_fact_ids.sort()
  assert_true(
    report.events.all(event => {
      event.difference_regions.all(region => {
        let candidates = region.cause_envelope.candidate_changed_fact_ids.copy()
        candidates.sort()
        region.cause_envelope.guarantee == "not_established" &&
        region.cause_envelope.coverage == "partial" &&
        region.cause_envelope.fallback_scope == "comparison" &&
        !region.cause_envelope.diagnostic_ids.is_empty() &&
        candidates == all_fact_ids
      })
    }),
  )
}

///|
test "disjoint event regions omit irrelevant changed facts" {
  let before = "<svg width='16' height='16'><rect x='1' y='1' width='3' height='3' fill='red'/><rect x='12' y='12' width='3' height='3' fill='red'/></svg>"
  let after = "<svg width='16' height='16'><rect x='1' y='1' width='3' height='3' fill='blue'/><rect x='12' y='12' width='3' height='3' fill='green'/></svg>"
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.changed_facts.length(), 2)
  assert_true(
    report.events.all(event => {
      event.difference_regions.all(region => {
        region.cause_envelope.candidate_changed_fact_ids.length() == 1
      })
    }),
  )
}

///|
test "insertion and deletion regions retain their presence fact" {
  let empty = "<svg width='16' height='16'></svg>"
  let present = "<svg width='16' height='16'><rect id='box' x='2' y='2' width='4' height='4' fill='red'/></svg>"
  let insertion = @engine.compare(
    empty,
    present,
    @engine.ComparisonProfile::v1_default(),
  )
  let deletion = @engine.compare(
    present,
    empty,
    @engine.ComparisonProfile::v1_default(),
  )
  for report in [insertion, deletion] {
    assert_true(!report.changed_facts.is_empty())
    let fact_id = report.changed_facts[0].id
    assert_true(
      report.events[0].difference_regions.all(region => {
        region.cause_envelope.candidate_changed_fact_ids.contains(fact_id)
      }),
    )
  }
}
