///|
fn source_audit_difference(
  report : SourceAuditReport,
  kind : String,
  name : String,
) -> SourceAuditDifference? {
  for difference in report.differences {
    if difference.kind == kind && difference.name == name {
      return Some(difference)
    }
  }
  None
}

///|
test "nonvisual content masking preserves UTF-16 offsets and outer structure" {
  let source = "<svg xmlns='http://www.w3.org/2000/svg'><text>😀</text><metadata>😀<foreign:rect xmlns:foreign='urn:test' width='bad'/></metadata><rect id='box' width='8' height='8'/></svg>"
  let masked = visual_semantic_input(source)
  assert_eq(masked.length(), source.length())
  assert_true(masked.contains("<metadata>"))
  assert_true(masked.contains("</metadata>"))
  assert_true(masked.contains("<rect id='box'"))
  assert_true(!masked.contains("foreign:rect"))
  assert_eq(masked.find("<rect id='box'"), source.find("<rect id='box'"))
}

///|
test "descriptive content stays outside visual differences and failures" {
  let before =
    #|<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16">
    #|  <title>Before</title>
    #|  <desc>Old description</desc>
    #|  <metadata>
    #|    <linearGradient id="a" href="#b"/>
    #|    <linearGradient id="b" href="#a"/>
    #|    <rect id="hidden" width="bad" style="unknown: value"/>
    #|  </metadata>
    #|  <rect id="box" width="8" height="8" fill="red"/>
    #|</svg>
  let after = before
    .replace_all(old="Before", new="After")
    .replace_all(old="Old description", new="New description")
    .replace_all(old="width=\"bad\"", new="width=\"worse\"")
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "complete")
  assert_true(report.atomic_differences.is_empty())
  assert_true(report.diagnostics.is_empty())
  assert_true(!report.to_compact_json_string().contains("Old description"))
  let self_report = compare(before, before, ComparisonProfile::v1_default())
  assert_eq(self_report.analysis_status, "complete")
  assert_true(
    self_report.diagnostics.all(diagnostic => {
      diagnostic.code != "reference_cycle_detected" &&
      diagnostic.code != "unsupported_visual_subject" &&
      diagnostic.code != "basic_shape_geometry_unsupported"
    }),
  )
}

///|
test "outer metadata and data attributes retain selector consequences" {
  let with_metadata =
    #|<svg xmlns="http://www.w3.org/2000/svg">
    #|  <style>metadata + rect { fill: red; }</style>
    #|  <metadata>source only</metadata>
    #|  <rect id="box" width="8" height="8" fill="blue"/>
    #|</svg>
  let without_metadata = with_metadata.replace_all(
    old="<metadata>source only</metadata>",
    new="",
  )
  let structural = compare(
    with_metadata,
    without_metadata,
    ComparisonProfile::v1_default(),
  )
  assert_true(
    structural.atomic_differences.any(difference => {
      difference.domain == "paint.fill" &&
      difference.computed_relation.status == "different"
    }),
  )

  let selected =
    #|<svg xmlns="http://www.w3.org/2000/svg">
    #|  <style>[data-state='on'] { fill: red; }</style>
    #|  <rect id="box" data-state="on" width="8" height="8" fill="blue"/>
    #|</svg>
  let unselected = selected.replace_all(
    old="data-state=\"on\"",
    new="data-state=\"off\"",
  )
  let selected_report = compare(
    selected,
    unselected,
    ComparisonProfile::v1_default(),
  )
  assert_true(
    selected_report.atomic_differences.any(difference => {
      difference.domain == "paint.fill" &&
      difference.computed_relation.status == "different"
    }),
  )
  let inert_before = "<svg><rect id='box' data-state='on' aria-label='old' width='8' height='8'/></svg>"
  let inert_after = inert_before
    .replace_all(old="data-state='on'", new="data-state='off'")
    .replace_all(old="aria-label='old'", new="aria-label='new'")
  let inert = compare(
    inert_before,
    inert_after,
    ComparisonProfile::v1_default(),
  )
  assert_eq(inert.analysis_status, "complete")
  assert_true(inert.atomic_differences.is_empty())
}

///|
test "source audit reports deterministic metadata changes with exact spans" {
  let before =
    #|<svg xmlns="http://www.w3.org/2000/svg" data-build="a">
    #|  <title>😀 Before</title>
    #|  <metadata><title>nested</title><rdf:RDF xmlns:rdf="urn:rdf">old</rdf:RDF></metadata>
    #|  <g aria-label="old"/>
    #|</svg>
  let after =
    #|<svg xmlns="http://www.w3.org/2000/svg" data-build="b">
    #|  <title>😀 After</title>
    #|  <desc>Added</desc>
    #|  <metadata><title>nested changed</title><rdf:RDF xmlns:rdf="urn:rdf">new</rdf:RDF></metadata>
    #|  <g/>
    #|</svg>
  let report = audit_nonvisual_metadata(before, after)
  assert_eq(report.audit_schema_version, "1.0")
  assert_eq(report.analysis_status, "complete")
  assert_eq(report.differences.length(), 5)
  assert_eq(report.differences.map(difference => difference.id), [
    "source-audit:0", "source-audit:1", "source-audit:2", "source-audit:3", "source-audit:4",
  ])
  guard source_audit_difference(report, "attribute", "data-build")
    is Some(build) else {
    fail("expected data-build audit difference")
  }
  assert_eq(build.before.unwrap().authored_value, "a")
  assert_eq(build.after.unwrap().authored_value, "b")
  guard source_audit_difference(report, "attribute", "aria-label")
    is Some(label) else {
    fail("expected aria-label audit difference")
  }
  assert_true(label.before is Some(_))
  assert_true(label.after is None)
  guard source_audit_difference(
      report, "element_content", "{http://www.w3.org/2000/svg}title",
    )
    is Some(title) else {
    fail("expected title audit difference")
  }
  assert_eq(title.before.unwrap().authored_value, "😀 Before")
  assert_eq(title.after.unwrap().authored_value, "😀 After")
  assert_eq(
    report_span_slice(before, title.before.unwrap().source_span),
    "😀 Before",
  )
  guard source_audit_difference(
      report, "element_content", "{http://www.w3.org/2000/svg}metadata",
    )
    is Some(metadata) else {
    fail("expected metadata audit difference")
  }
  assert_true(
    metadata.before.unwrap().authored_value.contains("<title>nested</title>"),
  )
  assert_true(
    !report.differences.any(difference => {
      difference.path.contains("/metadata[1]/") &&
      difference.name == "{http://www.w3.org/2000/svg}title"
    }),
  )
  assert_eq(
    report.to_compact_json_string(),
    audit_nonvisual_metadata(before, after).to_compact_json_string(),
  )

  let empty = audit_nonvisual_metadata("<svg/>", "<svg><desc/></svg>")
  assert_eq(empty.differences.length(), 1)
  guard empty.differences[0].after is Some(empty_desc) else {
    fail("expected inserted empty description")
  }
  assert_eq(empty_desc.authored_value, "")
  assert_eq(
    empty_desc.source_span.start_offset,
    empty_desc.source_span.end_offset,
  )
  assert_eq(report_span_slice("<svg><desc/></svg>", empty_desc.source_span), "")
}

///|
test "source audit paths are namespace-aware and failures are bounded" {
  let before =
    #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:x="urn:other">
    #|  <title>SVG title</title>
    #|  <x:title data-note="foreign">Foreign title</x:title>
    #|</svg>
  let after = before
    .replace_all(old="SVG title", new="Changed SVG title")
    .replace_all(old="Foreign title", new="Changed foreign title")
    .replace_all(old="data-note=\"foreign\"", new="data-note=\"changed\"")
  let report = audit_nonvisual_metadata(before, after)
  assert_eq(report.differences.length(), 2)
  assert_true(
    report.differences.any(difference => {
      difference.name == "{http://www.w3.org/2000/svg}title"
    }),
  )
  assert_true(
    report.differences.any(difference => {
      difference.name == "data-note" &&
      difference.path.contains("{urn:other}title[1]")
    }),
  )

  let failed = audit_nonvisual_metadata("<svg><title>", "<svg>")
  assert_eq(failed.analysis_status, "failed")
  assert_true(failed.differences.is_empty())
  assert_eq(failed.diagnostics.map(diagnostic => diagnostic.source_role), [
    "before", "after",
  ])
  assert_true(
    failed.diagnostics.all(diagnostic => {
      diagnostic.code == "svg_parse_failed" && diagnostic.source_span is Some(_)
    }),
  )
}
