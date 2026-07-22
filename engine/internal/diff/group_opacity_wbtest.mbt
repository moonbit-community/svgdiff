///|
fn group_opacity_difference(report : StructuredReport) -> AtomicDifference? {
  for difference in report.atomic_differences {
    if difference.domain == "compositing.opacity" {
      return Some(difference)
    }
  }
  None
}

///|
fn group_opacity_event(report : StructuredReport) -> VisualEvent? {
  for event in report.events {
    if event.atomic_difference_ids.any(id => {
        id.has_prefix("diff:alignment:group-opacity:")
      }) {
      return Some(event)
    }
  }
  None
}

///|
test "group opacity source spellings retain equivalent computed evidence" {
  let before = "<svg width='16' height='16'><g opacity='50%'><rect width='8' height='8' fill='red'/></g></svg>"
  let after = "<svg width='16' height='16'><g style='opacity:.5'><rect width='8' height='8' fill='red'/></g></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "complete")
  guard group_opacity_difference(report) is Some(difference) else {
    fail("expected group opacity source difference")
  }
  assert_eq(difference.source_before, "50%")
  assert_eq(difference.source_after, ".5")
  assert_eq(
    difference.source_fact_before.unwrap().origin,
    "presentation_attribute",
  )
  assert_eq(difference.source_fact_after.unwrap().origin, "inline_style")
  assert_true(
    difference.source_fact_before.unwrap().source_span.end_offset >
    difference.source_fact_before.unwrap().source_span.start_offset,
  )
  assert_eq(difference.computed_relation.status, "equivalent")
  assert_eq(difference.magnitude.parameter_signed_user_units, Some(0.0))
  guard group_opacity_event(report) is Some(event) else {
    fail("expected group opacity event")
  }
  assert_eq(event.rendered_outcome.status, "computed")
  assert_eq(event.rendered_outcome.magnitude.unwrap().changed_pixels, 0)
  assert_true(event.difference_regions.is_empty())
}

///|
test "group opacity resolves cascade variables CSS-wide values and clamping" {
  let before =
    #|<svg width="16" height="16" style="--layer-alpha:75%">
    #|  <style>#layer { opacity: var(--layer-alpha); }</style>
    #|  <g id="layer"><rect width="8" height="8" fill="red"/></g>
    #|</svg>
  let after = before.replace_all(old="75%", new="25%")
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "complete")
  guard group_opacity_difference(report) is Some(difference) else {
    fail("expected computed group opacity difference")
  }
  assert_eq(difference.computed_relation.status, "different")
  assert_eq(difference.magnitude.parameter_signed_user_units, Some(-0.5))
  assert_eq(difference.domain_ordering.policy_id, "v2_domain_lexicographic")
  assert_true(!difference.domain_ordering.components.is_empty())
  let mut variable_fact : ChangedFact? = None
  for fact in report.changed_facts {
    if fact.property == "--layer-alpha" {
      variable_fact = Some(fact)
      break
    }
  }
  guard variable_fact is Some(variable_fact) else {
    fail("expected custom-property cause")
  }
  assert_true(difference.changed_fact_ids.contains(variable_fact.id))
  assert_true(variable_fact.affected_subject_ids.contains("layer"))
  assert_true(variable_fact.affected_subject_ids.length() > 1)
  let mut opacity_resolution : SourceResolutionPair? = None
  for resolution in report.source_resolutions {
    if resolution.subject_id == "layer" && resolution.property == "opacity" {
      opacity_resolution = Some(resolution)
      break
    }
  }
  guard opacity_resolution is Some(opacity_resolution) else {
    fail("expected group opacity source resolution")
  }
  assert_eq(opacity_resolution.before.unwrap().resolved_value, "0.75")
  assert_eq(opacity_resolution.after.unwrap().resolved_value, "0.25")

  for pair in [("2", "100%"), ("-1", "0"), ("initial", "1")] {
    let (left, right) = pair
    let left_source = "<svg><g opacity='\{left}'><rect width='4' height='4'/></g></svg>"
    let right_source = "<svg><g opacity='\{right}'><rect width='4' height='4'/></g></svg>"
    let equivalent = compare(
      left_source,
      right_source,
      ComparisonProfile::v1_default(),
    )
    assert_eq(equivalent.analysis_status, "complete")
    guard group_opacity_difference(equivalent) is Some(difference) else {
      fail("expected clamped source difference")
    }
    assert_eq(difference.computed_relation.status, "equivalent")
    assert_eq(difference.magnitude.parameter_abs_user_units, Some(0.0))
  }
}

///|
test "group opacity regions exclude unrelated scene changes" {
  let before =
    #|<svg width="16" height="16">
    #|  <g id="layer" opacity="1"><rect id="inside" x="1" y="1" width="4" height="4" fill="red"/></g>
    #|  <rect id="outside" x="11" y="11" width="3" height="3" fill="red"/>
    #|</svg>
  let after = before
    .replace_all(old="opacity=\"1\"", new="opacity=\"0.5\"")
    .replace_all(
      old="id=\"outside\" x=\"11\" y=\"11\" width=\"3\" height=\"3\" fill=\"red\"",
      new="id=\"outside\" x=\"11\" y=\"11\" width=\"3\" height=\"3\" fill=\"blue\"",
    )
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "complete")
  guard group_opacity_event(report) is Some(event) else {
    fail("expected localized group event")
  }
  assert_true(!event.difference_regions.is_empty())
  assert_true(
    event.difference_regions.all(region => {
      region.css_x + region.css_width <= 6.0
    }),
  )
}

///|
test "group opacity cause envelope retains overlapping backdrop change" {
  let before =
    #|<svg width="16" height="16">
    #|  <rect id="backdrop" width="8" height="8" fill="green"/>
    #|  <g id="layer" opacity="1"><rect id="front" width="8" height="8" fill="red"/></g>
    #|</svg>
  let after = before
    .replace_all(old="fill=\"green\"", new="fill=\"yellow\"")
    .replace_all(old="opacity=\"1\"", new="opacity=\"0.5\"")
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "complete")
  guard group_opacity_event(report) is Some(event) else {
    fail("expected group opacity event")
  }
  let candidates : Array[String] = []
  for region in event.difference_regions {
    for id in region.cause_envelope.candidate_changed_fact_ids {
      if !candidates.contains(id) {
        candidates.push(id)
      }
    }
  }
  assert_true(
    report.changed_facts.any(fact => {
      fact.property == "opacity" && candidates.contains(fact.id)
    }),
  )
  assert_true(
    report.changed_facts.any(fact => {
      fact.affected_subject_ids.contains("backdrop") &&
      fact.property == "fill" &&
      candidates.contains(fact.id)
    }),
  )
}

///|
test "use and symbol container opacity remains instance-aware" {
  let symbol_before =
    #|<svg width="16" height="16">
    #|  <defs><symbol id="badge" opacity="1"><rect id="tile" width="4" height="4" fill="red"/></symbol></defs>
    #|  <use id="placed" href="#badge" x="4" y="3"/>
    #|</svg>
  let symbol_after = symbol_before.replace_all(
    old="opacity=\"1\"",
    new="opacity=\"0.5\"",
  )
  let symbol_report = compare(
    symbol_before,
    symbol_after,
    ComparisonProfile::v1_default(),
  )
  assert_eq(symbol_report.analysis_status, "complete")
  assert_true(group_opacity_difference(symbol_report) is Some(_))
  guard group_opacity_event(symbol_report) is Some(symbol_event) else {
    fail("expected symbol opacity event")
  }
  assert_true(!symbol_event.difference_regions.is_empty())
  assert_true(
    symbol_event.difference_regions.all(region => {
      region.css_x >= 4.0 && region.css_y >= 3.0
    }),
  )

  let use_before = symbol_before.replace_all(
    old="id=\"placed\" href=\"#badge\" x=\"4\" y=\"3\"",
    new="id=\"placed\" href=\"#badge\" x=\"4\" y=\"3\" opacity=\"1\"",
  )
  let use_after = use_before.replace_all(
    old="x=\"4\" y=\"3\" opacity=\"1\"",
    new="x=\"4\" y=\"3\" opacity=\"0.5\"",
  )
  let use_report = compare(
    use_before,
    use_after,
    ComparisonProfile::v1_default(),
  )
  assert_eq(use_report.analysis_status, "complete")
  assert_true(group_opacity_difference(use_report) is Some(_))
}
