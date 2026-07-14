///|
test "path data normalizes repeated relative and shorthand segments" {
  let source = "M1 2 3 4h5v-2c1 2 3 4 5 6s7 8 9 10q1 2 3 4t5 6a7 8 45 0 1 9 10z"
  guard parse_path_data(source, 100) is Valid(segments) else {
    fail("complete path command inventory must parse")
  }
  assert_eq(segments.length(), 10)
  assert_true(segments[0].normalized is MoveTo(1.0, 2.0))
  assert_true(segments[1].normalized is LineTo(3.0, 4.0))
  assert_true(segments[2].normalized is LineTo(8.0, 4.0))
  assert_true(segments[3].normalized is LineTo(8.0, 2.0))
  assert_true(segments[4].normalized is CubicTo(9.0, 4.0, 11.0, 6.0, 13.0, 8.0))
  assert_true(
    segments[5].normalized is CubicTo(15.0, 10.0, 20.0, 16.0, 22.0, 18.0),
  )
  assert_true(segments[6].normalized is QuadraticTo(23.0, 20.0, 25.0, 22.0))
  assert_true(segments[7].normalized is QuadraticTo(27.0, 24.0, 30.0, 28.0))
  assert_true(
    segments[8].normalized is ArcTo(7.0, 8.0, 45.0, false, true, 39.0, 38.0),
  )
  assert_true(segments[9].normalized is ClosePath)
}

///|
test "path data accepts every absolute command family" {
  let valid = [
    "M0 0L1 1", "M0 0H1", "M0 0V1", "M0 0C1 1 2 2 3 3", "M0 0S1 1 2 2", "M0 0Q1 1 2 2",
    "M0 0T1 1", "M0 0A1 2 0 0 1 3 4", "M0 0Z",
  ]
  for source in valid {
    assert_true(parse_path_data(source, 0) is Valid(_))
  }
}

///|
test "path segment evidence retains authored commands slices and spans" {
  guard parse_path_data("M1 2 3 4", 20) is Valid(segments) else {
    fail("repeated moveto coordinates must parse")
  }
  assert_eq(segments.length(), 2)
  assert_eq(segments[0].authored_command, "M")
  assert_true(segments[0].explicit_command)
  assert_eq(segments[0].authored_value, "M1 2")
  assert_eq(segments[0].source_span.start_offset, 20)
  assert_eq(segments[0].source_span.end_offset, 24)
  assert_eq(segments[1].authored_command, "L")
  assert_false(segments[1].explicit_command)
  assert_eq(segments[1].authored_value, "3 4")
  assert_eq(segments[1].source_span.start_offset, 25)
  assert_eq(segments[1].source_span.end_offset, 28)
}

///|
test "path segment spans map decoded XML entities back to authored source" {
  guard parse_path_attribute_data("M1&#32;2 3&#x20;4", 50) is Valid(segments) else {
    fail("XML whitespace entities in path data must parse")
  }
  assert_eq(segments.length(), 2)
  assert_eq(segments[0].authored_value, "M1&#32;2")
  assert_eq(segments[0].source_span.start_offset, 50)
  assert_eq(segments[0].source_span.end_offset, 58)
  assert_eq(segments[1].authored_value, "3&#x20;4")
  assert_eq(segments[1].source_span.start_offset, 59)
  assert_eq(segments[1].source_span.end_offset, 67)
}

///|
test "path data accepts compact numbers flags and multiple subpaths" {
  guard parse_path_data("m.5.5 1e1-2e0z m1 1A2 3 45 013 4", 0)
    is Valid(segments) else {
    fail("compact valid path syntax must parse")
  }
  assert_eq(segments.length(), 5)
  assert_true(segments[0].normalized is MoveTo(0.5, 0.5))
  assert_true(segments[1].normalized is LineTo(10.5, -1.5))
  assert_true(segments[2].normalized is ClosePath)
  assert_true(segments[3].normalized is MoveTo(1.5, 1.5))
  assert_true(
    segments[4].normalized is ArcTo(2.0, 3.0, 45.0, false, true, 3.0, 4.0),
  )
}

///|
test "path data distinguishes empty from invalid and rejects partial prefixes" {
  assert_true(parse_path_data("", 0) is Valid([]))
  let invalid = [
    "L0 0", "M", "M0", "M,0 0", "M0 0,", "M0 0 X", "M0 0 L1e 2", "M0 0 L1,,2", "M0 0 A-1 2 0 0 0 3 4",
    "M0 0 A1 2 0 2 0 3 4", "M1e9999 0",
  ]
  for source in invalid {
    assert_true(parse_path_data(source, 0) is Invalid)
  }
}

///|
test "path source subjects retain normalized segments behind partial coverage" {
  let source = "<svg width='16' height='16'><path id='shape' d='m1 2h3z' fill='red'/></svg>"
  let subjects = extract_source_subjects_or_raise(source)
  assert_eq(subjects.length(), 1)
  let subject = subjects[0]
  assert_eq(subject.kind, "path")
  assert_true(subject.path_data_complete)
  assert_eq(subject.path_segments.length(), 3)
  assert_true(subject.path_segments[0].normalized is MoveTo(1.0, 2.0))
  assert_true(subject.path_segments[1].normalized is LineTo(4.0, 2.0))
  let report = compare(source, source, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "partial")
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "unsupported_visual_subject"
    }),
  )
}

///|
test "malformed path subjects retain an incomplete source marker" {
  let source = "<svg><path d='M0 0 L1e 2'/></svg>"
  let subjects = extract_source_subjects_or_raise(source)
  assert_eq(subjects.length(), 1)
  assert_false(subjects[0].path_data_complete)
  assert_true(subjects[0].path_segments.is_empty())
}
