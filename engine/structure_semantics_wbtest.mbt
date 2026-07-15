///|
test "defs and symbols only render through distinct use instances" {
  let source =
    #|<svg xmlns="http://www.w3.org/2000/svg">
    #|  <defs>
    #|    <g id="tile"><rect id="shape" width="4" height="4"/></g>
    #|    <symbol id="badge"><circle id="dot" r="2"/></symbol>
    #|  </defs>
    #|  <use id="left" href="#tile"/>
    #|  <use id="right" href="#tile"/>
    #|  <use id="symbol-use" href="#badge"/>
    #|</svg>
  let document = extract_structural_document_or_raise(source)
  let plans = rendered_subject_plans(document)
  assert_eq(plans.length(), 3)
  assert_eq(plans[0].definition_subject_id, "shape")
  assert_eq(plans[0].use_path, ["left"])
  assert_eq(plans[0].instance_id, Some("instance/left/shape"))
  assert_eq(plans[1].definition_subject_id, "shape")
  assert_eq(plans[1].use_path, ["right"])
  assert_eq(plans[1].instance_id, Some("instance/right/shape"))
  assert_eq(plans[2].definition_subject_id, "dot")
  assert_eq(plans[2].use_path, ["symbol-use"])
}

///|
test "direct and nested use plans preserve placement paths" {
  let source =
    #|<svg xmlns="http://www.w3.org/2000/svg">
    #|  <defs>
    #|    <rect id="shape" width="4" height="4"/>
    #|    <use id="inner" href="#shape"/>
    #|  </defs>
    #|  <circle id="direct" r="2"/>
    #|  <use id="outer" href="#inner"/>
    #|</svg>
  let document = extract_structural_document_or_raise(source)
  let plans = rendered_subject_plans(document)
  assert_eq(plans.length(), 2)
  assert_eq(plans[0].definition_subject_id, "direct")
  assert_eq(plans[0].use_path, [])
  assert_eq(plans[0].instance_id, None)
  assert_eq(plans[1].definition_subject_id, "shape")
  assert_eq(plans[1].use_path, ["outer", "inner"])
  assert_eq(plans[1].instance_id, Some("instance/outer/inner/shape"))
}

///|
test "missing external wrong-kind and cyclic use targets produce no plan" {
  let source =
    #|<svg xmlns="http://www.w3.org/2000/svg">
    #|  <defs>
    #|    <linearGradient id="paint"/>
    #|    <use id="cycle-a" href="#cycle-b"/>
    #|    <use id="cycle-b" href="#cycle-a"/>
    #|  </defs>
    #|  <use href="#missing"/>
    #|  <use href="other.svg#shape"/>
    #|  <use href="#paint"/>
    #|  <use href="#cycle-a"/>
    #|</svg>
  let document = extract_structural_document_or_raise(source)
  assert_eq(rendered_subject_plans(document).length(), 0)
}

///|
test "use prefers unqualified href and accepts legacy xlink href" {
  let source =
    #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
    #|  <defs>
    #|    <rect id="red" width="2" height="2" fill="red"/>
    #|    <circle id="blue" r="1" fill="blue"/>
    #|  </defs>
    #|  <use id="preferred" xlink:href="#blue" href="#red"/>
    #|  <use id="legacy" xlink:href="#blue"/>
    #|</svg>
  let plans = rendered_subject_plans(
    extract_structural_document_or_raise(source),
  )
  assert_eq(plans.length(), 2)
  assert_eq(plans[0].definition_subject_id, "red")
  assert_eq(plans[0].instance_id, Some("instance/preferred/red"))
  assert_eq(plans[1].definition_subject_id, "blue")
  assert_eq(plans[1].instance_id, Some("instance/legacy/blue"))
}

///|
test "use placement reaches cumulative subject transforms" {
  let source =
    #|<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16">
    #|  <defs><rect id="tile" width="4" height="4"/></defs>
    #|  <use id="a" href="#tile" x="2" y="3"/>
    #|  <use id="b" href="#tile" x="10" y="8"/>
    #|</svg>
  let subjects = extract_source_subjects_or_raise(source)
  assert_eq(subjects.length(), 2)
  assert_eq(subjects[0].cumulative_transform.signature(), "matrix(1,0,0,1,2,3)")
  assert_eq(
    subjects[1].cumulative_transform.signature(),
    "matrix(1,0,0,1,10,8)",
  )
  let alignments = align_source_subjects_with_guard(
    subjects,
    subjects,
    ComparisonGuard::new(ComparisonControl::unlimited()),
  )
  assert_eq(alignments.length(), 2)
  assert_eq(alignment_bounds(alignments[0], subjects, subjects).unwrap().x, 2.0)
  assert_eq(
    alignment_bounds(alignments[1], subjects, subjects).unwrap().x,
    10.0,
  )
}

///|
test "symbol use width and height establish its instance viewport" {
  let source =
    #|<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16">
    #|  <symbol id="tile" viewBox="0 0 4 2">
    #|    <rect id="shape" width="4" height="2"/>
    #|  </symbol>
    #|  <use id="placed" href="#tile" x="2" y="2" width="12" height="12"/>
    #|</svg>
  let subjects = extract_source_subjects_or_raise(source)
  assert_eq(subjects.length(), 1)
  assert_eq(subjects[0].cumulative_transform.signature(), "matrix(3,0,0,3,2,5)")
  assert_eq(subjects[0].viewport.width, 4.0)
  assert_eq(subjects[0].viewport.height, 2.0)
  let bounds = source_subject_bounds(subjects[0]).unwrap()
  assert_eq(bounds.x, 2.0)
  assert_eq(bounds.y, 5.0)
  assert_eq(bounds.width, 12.0)
  assert_eq(bounds.height, 6.0)
}

///|
test "svg use width and height establish its instance viewport" {
  let source =
    #|<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16">
    #|  <defs><svg id="tile" viewBox="0 0 4 2"><rect id="shape" width="4" height="2"/></svg></defs>
    #|  <use id="placed" href="#tile" x="2" y="2" width="12" height="12"/>
    #|</svg>
  let subjects = extract_source_subjects_or_raise(source)
  assert_eq(subjects.length(), 1)
  assert_eq(subjects[0].cumulative_transform.signature(), "matrix(3,0,0,3,2,5)")
  assert_eq(source_subject_bounds(subjects[0]).unwrap().width, 12.0)
}

///|
test "one definition fact fans out to every rendered use instance" {
  let before =
    #|<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16">
    #|  <defs><rect id="tile" width="4" height="4" fill="red"/></defs>
    #|  <use id="a" href="#tile" x="2" y="3"/>
    #|  <use id="b" href="#tile" x="10" y="8"/>
    #|</svg>
  let after = before.replace_all(old="fill=\"red\"", new="fill=\"blue\"")
  assert_eq(
    subject_value(extract_source_subjects_or_raise(before)[0], "fill"),
    Some("rgba(255,0,0,1)"),
  )
  assert_eq(
    subject_value(extract_source_subjects_or_raise(after)[0], "fill"),
    Some("rgba(0,0,255,1)"),
  )
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "complete")
  assert_eq(report.subject_alignments.length(), 2)
  assert_true(
    report.subject_alignments.all(alignment => {
      alignment.basis == "use_instance_path" &&
      alignment.before[0].instance_context is Some(_)
    }),
  )
  assert_eq(report.changed_facts.length(), 1)
  assert_eq(report.changed_facts[0].subject_id, "tile")
  assert_eq(report.changed_facts[0].affected_subject_ids, [
    "instance/a/tile", "instance/b/tile",
  ])
  assert_eq(report.source_resolutions.length(), 2)
  assert_true(
    report.source_resolutions.all(pair => {
      pair.before.unwrap().declaration_owner_id == Some("tile") &&
      pair.after.unwrap().declaration_owner_id == Some("tile")
    }),
  )
  assert_eq(report.atomic_differences.length(), 2)
  assert_true(
    report.atomic_differences.all(difference => {
      difference.changed_fact_ids == ["fact:source:tile:fill"]
    }),
  )
  assert_eq(report.events.length(), 2)
  assert_eq(report.events[0].difference_regions[0].pixel_x, 2)
  assert_eq(report.events[1].difference_regions[0].pixel_x, 10)
}

///|
test "use host inheritance remains host owned inside cloned content" {
  let before =
    #|<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16">
    #|  <defs><g id="tile"><rect id="shape" width="4" height="4"/></g></defs>
    #|  <use id="placed" href="#tile" fill="red" x="2" y="3"/>
    #|</svg>
  let after = before.replace_all(old="fill=\"red\"", new="fill=\"blue\"")
  assert_eq(
    subject_value(extract_source_subjects_or_raise(before)[0], "fill"),
    Some("rgba(255,0,0,1)"),
  )
  assert_eq(
    subject_value(extract_source_subjects_or_raise(after)[0], "fill"),
    Some("rgba(0,0,255,1)"),
  )
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "complete")
  assert_eq(report.changed_facts.length(), 1)
  assert_eq(report.changed_facts[0].subject_id, "placed")
  assert_eq(report.changed_facts[0].affected_subject_ids, [
    "instance/placed/shape",
  ])
  assert_eq(report.source_resolutions.length(), 1)
  let resolution = report.source_resolutions[0]
  assert_eq(resolution.subject_id, "instance/placed/shape")
  assert_eq(resolution.before.unwrap().resolution, "inherited")
  assert_eq(resolution.before.unwrap().declaration_owner_id, Some("placed"))
}

///|
test "stylesheet cascade remains source matched across use ancestry" {
  let before =
    #|<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16">
    #|  <style>.placed { fill: red }</style>
    #|  <defs><g id="tile"><rect id="shape" width="4" height="4"/></g></defs>
    #|  <use id="placed" class="placed" href="#tile"/>
    #|</svg>
  let after = before.replace_all(old="fill: red", new="fill: blue")
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "complete")
  assert_eq(report.changed_facts.length(), 1)
  assert_eq(report.changed_facts[0].subject_id, "placed")
  assert_eq(report.changed_facts[0].affected_subject_ids, [
    "instance/placed/shape",
  ])
  assert_eq(
    report.source_resolutions[0].before.unwrap().resolution,
    "inherited",
  )
  assert_eq(
    report.source_resolutions[0].before.unwrap().declaration_owner_id,
    Some("placed"),
  )
}

///|
test "use target changes preserve placement and definition identities" {
  let before =
    #|<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16">
    #|  <defs>
    #|    <rect id="red-shape" width="4" height="4" fill="red"/>
    #|    <rect id="blue-shape" width="4" height="4" fill="blue"/>
    #|  </defs>
    #|  <use id="placed" href="#red-shape"/>
    #|</svg>
  let after = before.replace_all(old="#red-shape", new="#blue-shape")
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "complete")
  assert_eq(report.subject_alignments.length(), 1)
  let alignment = report.subject_alignments[0]
  assert_eq(alignment.basis, "use_instance_path")
  assert_eq(
    alignment.before[0].instance_context.unwrap().definition_subject_id,
    "red-shape",
  )
  assert_eq(
    alignment.after[0].instance_context.unwrap().definition_subject_id,
    "blue-shape",
  )
  assert_true(
    report.atomic_differences.any(difference => {
      difference.domain == "paint.fill" &&
      difference.computed_relation.status == "different"
    }),
  )
}

///|
test "invalid use references remain partial with located diagnostics" {
  let cases = [
    ("<svg><use id='placed'/></svg>", "use_href_missing"),
    (
      "<svg><use id='placed' href='other.svg#shape'/></svg>", "use_external_reference_unsupported",
    ),
    ("<svg><use id='placed' href='#missing'/></svg>", "use_target_missing"),
    (
      "<svg><defs><linearGradient id='paint'/></defs><use id='placed' href='#paint'/></svg>",
      "use_target_kind_unsupported",
    ),
    (
      "<svg><defs><rect id='shape'/></defs><use id='placed' href='#shape' x='1em'/></svg>",
      "use_length_semantics_unsupported",
    ),
  ]
  for item in cases {
    let (source, code) = item
    let report = compare(source, source, ComparisonProfile::v1_default())
    assert_eq(report.analysis_status, "partial")
    assert_true(
      report.diagnostics.any(diagnostic => {
        diagnostic.code == code && !diagnostic.source_locations.is_empty()
      }),
    )
  }
  let cyclic =
    #|<svg><defs>
    #|  <use id="a" href="#b"/>
    #|  <use id="b" href="#a"/>
    #|</defs><use href="#a"/></svg>
  let cyclic_report = compare(cyclic, cyclic, ComparisonProfile::v1_default())
  assert_eq(cyclic_report.analysis_status, "failed")
  assert_true(
    cyclic_report.diagnostics.any(diagnostic => {
      diagnostic.code == "reference_cycle_detected" &&
      !diagnostic.source_locations.is_empty()
    }),
  )
}

///|
test "use width and height are ignored for non viewport targets" {
  let source =
    #|<svg xmlns="http://www.w3.org/2000/svg">
    #|  <defs><rect id="shape" width="2" height="2"/></defs>
    #|  <use id="placed" href="#shape" width="not-a-length" height="also-invalid"/>
    #|</svg>
  let report = compare(source, source, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "complete")
  assert_true(
    report.diagnostics.all(diagnostic => {
      diagnostic.code != "use_length_semantics_unsupported"
    }),
  )
}

///|
test "use transform plus supplemental translation retains a renderer guard" {
  let source =
    #|<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16">
    #|  <defs><rect id="shape" width="3" height="2"/></defs>
    #|  <use id="placed" href="#shape" x="3" y="4" transform="scale(2)"/>
    #|</svg>
  let report = compare(source, source, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "partial")
  let mut selected : Diagnostic? = None
  for diagnostic in report.diagnostics {
    if diagnostic.code == "renderer_use_transform_raster_unproven" {
      selected = Some(diagnostic)
      break
    }
  }
  guard selected is Some(diagnostic) else {
    fail("expected transformed use renderer guard")
  }
  assert_eq(diagnostic.affected_evidence_layers, ["rendered_evidence"])
  assert_eq(diagnostic.source_locations.length(), 6)
}

///|
test "unused definitions remain source visible without rendered subjects" {
  let before =
    #|<svg xmlns="http://www.w3.org/2000/svg">
    #|  <defs><g id="tile" fill="red"><rect id="shape" width="4" height="4"/></g></defs>
    #|</svg>
  let after = before.replace_all(old="fill=\"red\"", new="fill=\"blue\"")
  let unchanged = compare(before, before, ComparisonProfile::v1_default())
  assert_eq(unchanged.analysis_status, "complete")
  assert_true(unchanged.subject_alignments.is_empty())
  assert_true(unchanged.atomic_differences.is_empty())
  let changed = compare(before, after, ComparisonProfile::v1_default())
  assert_eq(changed.analysis_status, "complete")
  assert_true(changed.subject_alignments.is_empty())
  assert_eq(changed.changed_facts.length(), 1)
  assert_eq(changed.changed_facts[0].subject_id, "tile")
  assert_true(changed.changed_facts[0].affected_subject_ids.is_empty())
  assert_eq(changed.atomic_differences.length(), 1)
  assert_eq(changed.atomic_differences[0].subject_role, "resource")
  assert_eq(
    changed.atomic_differences[0].computed_relation.reason_code,
    "unused_definition",
  )
  assert_true(changed.events.is_empty())

  let inserted = compare(
    "<svg/>",
    "<svg><defs><rect id='unused' width='2' height='2'/></defs></svg>",
    ComparisonProfile::v1_default(),
  )
  assert_eq(inserted.analysis_status, "complete")
  assert_eq(inserted.atomic_differences.length(), 2)
  assert_true(
    inserted.atomic_differences.all(difference => {
      difference.source_before == "" &&
      difference.source_after == "present" &&
      difference.computed_relation.missing_side == Some("before")
    }),
  )
}
