///|
fn shape_svg(body : String) -> String {
  "<svg width='20' height='20'>\{body}</svg>"
}

///|
test "all changed facts across aligned subjects are enumerated" {
  let before = shape_svg(
    "<rect x='1' y='1' width='4' height='4' fill='red'/><rect x='10' y='1' width='4' height='4' opacity='1'/>",
  )
  let after = shape_svg(
    "<rect x='2' y='1' width='4' height='4' fill='blue'/><rect x='10' y='1' width='5' height='4' opacity='0.5'/>",
  )
  let report = @structured_report.compare(
    before,
    after,
    @structured_report.ComparisonProfile::v1_default(),
  )
  assert_eq(report.atomic_differences.length(), 4)
  assert_eq(report.changed_facts.length(), 4)
  assert_true(
    report.atomic_differences.all(difference => {
      difference.subject_alignment_id is Some(_)
    }),
  )
}

///|
test "circle geometry uses the generic aligned-subject engine" {
  let before = shape_svg("<circle id='old' cx='8' cy='8' r='2' fill='red'/>")
  let after = shape_svg("<circle id='new' cx='9' cy='8' r='3' fill='red'/>")
  let report = @structured_report.compare(
    before,
    after,
    @structured_report.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "complete")
  assert_eq(report.atomic_differences.length(), 2)
  assert_true(
    report.atomic_differences.any(difference => {
      difference.domain == "geometry.position"
    }),
  )
  assert_true(
    report.atomic_differences.any(difference => {
      difference.domain == "geometry.size"
    }),
  )
}

///|
test "ordinary fill inheritance applies to non-rect subjects" {
  let before = shape_svg(
    "<g id='theme' fill='red'><circle id='dot' cx='8' cy='8' r='2'/></g>",
  )
  let after = shape_svg(
    "<g id='theme' fill='blue'><circle id='dot' cx='8' cy='8' r='2'/></g>",
  )
  let report = @structured_report.compare(
    before,
    after,
    @structured_report.ComparisonProfile::v1_default(),
  )
  assert_eq(report.changed_facts.length(), 1)
  assert_eq(report.atomic_differences.length(), 1)
  assert_eq(report.atomic_differences[0].domain, "paint.fill")
  assert_true(report.atomic_differences[0].subject_alignment_id is Some(_))
  assert_eq(report.changed_facts[0].affected_subject_ids, ["dot"])
}

///|
test "unsupported path semantics remain partial and diagnosed" {
  let source = shape_svg("<path d='M0 0 L10 10' stroke='black'/>")
  let report = @structured_report.compare(
    source,
    source,
    @structured_report.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "partial")
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "unsupported_visual_subject"
    }),
  )
}

///|
test "ellipse line polyline and polygon share generic enumeration" {
  let before = shape_svg(
    "<ellipse cx='4' cy='4' rx='2' ry='1'/><line x1='0' y1='0' x2='2' y2='2'/><polyline points='0,0 1,1'/><polygon points='4,4 5,5 6,4'/>",
  )
  let after = shape_svg(
    "<ellipse cx='5' cy='4' rx='3' ry='1'/><line x1='0' y1='0' x2='3' y2='2'/><polyline points='0,0 2,2'/><polygon points='4,4 5,6 6,4'/>",
  )
  let report = @structured_report.compare(
    before,
    after,
    @structured_report.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "complete")
  assert_eq(report.atomic_differences.length(), 5)
}

///|
test "unsupported visual attributes reduce subject coverage" {
  let source = shape_svg(
    "<circle cx='8' cy='8' r='2' transform='translate(1 0)'/>",
  )
  let report = @structured_report.compare(
    source,
    source,
    @structured_report.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "partial")
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "unsupported_visual_attribute"
    }),
  )
}

///|
test "ordinary inherited stroke changes are reported" {
  let before = shape_svg(
    "<g stroke='red'><line id='edge' x1='1' y1='1' x2='15' y2='15'/></g>",
  )
  let after = shape_svg(
    "<g stroke='blue'><line id='edge' x1='1' y1='1' x2='15' y2='15'/></g>",
  )
  let report = @structured_report.compare(
    before,
    after,
    @structured_report.ComparisonProfile::v1_default(),
  )
  assert_true(
    report.atomic_differences.any(difference => {
      difference.domain == "paint.stroke" &&
      difference.source_before == "red" &&
      difference.source_after == "blue"
    }),
  )
}

///|
test "incomplete inline style cannot produce complete equality" {
  let source = shape_svg(
    "<rect x='1' y='1' width='8' height='8' style='fill:red;unknown-paint:blue'/>",
  )
  let report = @structured_report.compare(
    source,
    source,
    @structured_report.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "partial")
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "css_cascade_unsupported"
    }),
  )
}
