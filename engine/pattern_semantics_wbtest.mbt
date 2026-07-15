///|
fn pattern_test_field(
  pattern : ComputedPattern,
  name : String,
) -> ComputedPatternField? {
  for field in pattern.fields {
    if field.name == name {
      return Some(field)
    }
  }
  None
}

///|
fn pattern_test_number(pattern : ComputedPattern, name : String) -> Double? {
  match pattern_test_field(pattern, name) {
    Some(field) => field.number
    None => None
  }
}

///|
test "pattern defaults produce an explicit zero tile and hide resource children from entity alignment" {
  let source = "<svg width='20' height='10'><defs><pattern id='tile'><rect id='dot' width='1' height='1' fill='red'/></pattern></defs><rect id='box' width='20' height='10' fill='url(#tile)'/></svg>"
  let profile = {
    ..ComparisonProfile::v1_default(),
    viewport_width: 20,
    viewport_height: 10,
  }
  let subjects = extract_source_subjects_with_profile_or_raise(source, profile)
  assert_eq(subjects.length(), 1)
  assert_eq(subjects[0].reference.authored_id, Some("box"))
  let document = extract_pattern_document_or_raise(source, profile)
  guard resolve_pattern_by_id(document, "tile", Some(subjects[0]))
    is PatternResolved(pattern) else {
    fail("expected resolved pattern")
  }
  assert_eq(
    pattern_test_field(pattern, "patternUnits").map(f => f.value),
    Some("objectBoundingBox"),
  )
  assert_eq(
    pattern_test_field(pattern, "patternContentUnits").map(f => f.value),
    Some("userSpaceOnUse"),
  )
  assert_eq(pattern_test_number(pattern, "x"), Some(0.0))
  assert_eq(pattern_test_number(pattern, "width"), Some(0.0))
  assert_eq(pattern.paint_mode, "none_zero_tile")
  assert_eq(pattern.children.length(), 1)
}

///|
test "pattern units transform and viewBox establish separate tile and content matrices" {
  let source = "<svg width='40' height='20'><defs><pattern id='tile' patternUnits='userSpaceOnUse' x='2' y='3' width='10' height='5' patternTransform='translate(4)' viewBox='0 0 20 10' preserveAspectRatio='none'><rect id='dot' width='20' height='10' fill='red'/></pattern></defs><rect id='box' width='40' height='20' fill='url(#tile)'/></svg>"
  let profile = {
    ..ComparisonProfile::v1_default(),
    viewport_width: 40,
    viewport_height: 20,
  }
  let subjects = extract_source_subjects_with_profile_or_raise(source, profile)
  let document = extract_pattern_document_or_raise(source, profile)
  guard resolve_pattern_by_id(document, "tile", Some(subjects[0]))
    is PatternResolved(pattern) else {
    fail("expected resolved pattern")
  }
  assert_eq(pattern.tile_matrix.signature(), "matrix(1,0,0,1,4,0)")
  assert_eq(pattern.content_matrix.signature(), "matrix(0.5,0,0,0.5,6,3)")
  assert_eq(pattern.children.length(), 1)
  assert_true(pattern.children[0].signature.find("width=20") is Some(_))
  assert_true(pattern.complete)
}

///|
test "pattern templates inherit attributes and clone content through the referencing host" {
  let source = "<svg width='20' height='20'><defs><pattern id='base' width='.25' height='.25' color='red'><rect id='dot' width='1' height='1' fill='currentColor'/></pattern><pattern id='tile' href='#base' color='blue'/></defs><rect id='box' width='20' height='20' fill='url(#tile)'/></svg>"
  let profile = {
    ..ComparisonProfile::v1_default(),
    viewport_width: 20,
    viewport_height: 20,
  }
  let subjects = extract_source_subjects_with_profile_or_raise(source, profile)
  let document = extract_pattern_document_or_raise(source, profile)
  guard resolve_pattern_by_id(document, "tile", Some(subjects[0]))
    is PatternResolved(pattern) else {
    fail("expected resolved pattern")
  }
  assert_eq(pattern.template_chain, ["tile", "base"])
  assert_eq(pattern_test_number(pattern, "width"), Some(0.25))
  assert_eq(pattern.children.length(), 1)
  assert_true(pattern.children[0].signature.find("0,0,255") is Some(_))
}

///|
test "pattern invalid lengths and external references retain precise issues" {
  let source = "<svg><defs><pattern id='bad' width='-1' height='nope' href='other.svg#tile'/></defs></svg>"
  let document = extract_pattern_document_or_raise(
    source,
    ComparisonProfile::v1_default(),
  )
  guard resolve_pattern_by_id(document, "bad", None) is PatternResolved(pattern) else {
    fail("expected bounded fallback pattern")
  }
  assert_false(pattern.complete)
  assert_true(
    document.issues.any(issue => {
      issue.code == "pattern_length_syntax_unsupported"
    }),
  )
  assert_true(
    document.issues.any(issue => {
      issue.code == "pattern_external_reference_unsupported"
    }),
  )
}

///|
test "viewBox normalizes equivalent syntax and ignores pattern content units" {
  let before = "<svg width='20' height='20'><defs><pattern id='tile' width='.5' height='.5' patternContentUnits='objectBoundingBox' viewBox='0 0 10 10' preserveAspectRatio='xMidYMid meet'><rect width='10' height='10' fill='red'/></pattern></defs><rect id='box' width='20' height='20' fill='url(#tile)'/></svg>"
  let after = before
    .replace_all(
      old="patternContentUnits='objectBoundingBox'",
      new="patternContentUnits='userSpaceOnUse'",
    )
    .replace_all(old="viewBox='0 0 10 10'", new="viewBox='0, 0, 10, 10'")
  let report = compare(before, after, {
    ..ComparisonProfile::v1_default(),
    viewport_width: 20,
    viewport_height: 20,
  })
  assert_true(
    report.atomic_differences.any(diff => {
      diff.domain == "resource.pattern.content_units" &&
      diff.evidence_layers == ["source_semantics"] &&
      diff.computed_relation.status == "equivalent"
    }),
  )
  assert_true(
    report.atomic_differences.any(diff => {
      diff.domain == "resource.pattern.viewport.view_box" &&
      diff.evidence_layers == ["source_semantics"] &&
      diff.computed_relation.status == "equivalent"
    }),
  )
  assert_true(
    report.atomic_differences.any(diff => {
      diff.domain == "paint.fill" &&
      diff.computed_relation.status == "equivalent"
    }),
  )
}

///|
test "unsupported nested content and visible overflow remain precise guards" {
  let source = "<svg><defs><pattern id='tile' overflow='visible'><g><text>label</text></g></pattern></defs></svg>"
  let document = extract_pattern_document_or_raise(
    source,
    ComparisonProfile::v1_default(),
  )
  assert_true(
    document.issues.any(issue => {
      issue.code == "pattern_child_semantics_unsupported"
    }),
  )
  assert_true(
    document.issues.any(issue => {
      issue.code == "pattern_visible_overflow_unsupported"
    }),
  )
}

///|
test "pattern child transforms are relative to their content provider" {
  let source = "<svg width='16' height='16' viewBox='0 0 8 8'><defs><pattern id='tile' patternUnits='userSpaceOnUse' width='4' height='4'><g transform='translate(1 2)'><rect id='dot' width='1' height='1' transform='scale(2)'/></g></pattern></defs><rect id='box' width='8' height='8' fill='url(#tile)'/></svg>"
  let profile = {
    ..ComparisonProfile::v1_default(),
    viewport_width: 16,
    viewport_height: 16,
  }
  let subjects = extract_source_subjects_with_profile_or_raise(source, profile)
  let document = extract_pattern_document_or_raise(source, profile)
  guard resolve_pattern_by_id(document, "tile", Some(subjects[0]))
    is PatternResolved(pattern) else {
    fail("expected resolved pattern")
  }
  assert_true(
    pattern.children[0].signature.find("matrix(4,0,0,4,2,4)") is Some(_),
  )
}

///|
test "unqualified pattern href wins over xlink and xlink remains supported" {
  let source = "<svg xmlns:xlink='http://www.w3.org/1999/xlink'><defs><pattern id='red' width='.5' height='.5'><rect width='1' height='1' fill='red'/></pattern><pattern id='blue' width='.25' height='.25'><rect width='1' height='1' fill='blue'/></pattern><pattern id='preferred' href='#red' xlink:href='#blue'/><pattern id='legacy' xlink:href='#blue'/></defs></svg>"
  let document = extract_pattern_document_or_raise(
    source,
    ComparisonProfile::v1_default(),
  )
  guard resolve_pattern_by_id(document, "preferred", None)
    is PatternResolved(preferred) else {
    fail("expected preferred pattern")
  }
  guard resolve_pattern_by_id(document, "legacy", None)
    is PatternResolved(legacy) else {
    fail("expected legacy pattern")
  }
  assert_eq(pattern_test_number(preferred, "width"), Some(0.5))
  assert_eq(pattern_test_number(legacy, "width"), Some(0.25))
}

///|
test "pattern preserveAspectRatio slice changes the resolved content mapping" {
  let meet_source = "<svg><defs><pattern id='tile' patternUnits='userSpaceOnUse' width='8' height='4' viewBox='0 0 4 4' preserveAspectRatio='xMidYMid meet'><rect width='4' height='4'/></pattern></defs></svg>"
  let slice_source = meet_source.replace_all(old="meet'", new="slice'")
  let meet_document = extract_pattern_document_or_raise(
    meet_source,
    ComparisonProfile::v1_default(),
  )
  let slice_document = extract_pattern_document_or_raise(
    slice_source,
    ComparisonProfile::v1_default(),
  )
  guard resolve_pattern_by_id(meet_document, "tile", None)
    is PatternResolved(meet) else {
    fail("expected meet pattern")
  }
  guard resolve_pattern_by_id(slice_document, "tile", None)
    is PatternResolved(slice) else {
    fail("expected slice pattern")
  }
  assert_true(meet.content_matrix != slice.content_matrix)
}
