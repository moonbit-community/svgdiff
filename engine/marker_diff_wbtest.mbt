///|
fn marker_diff_svg(marker : String, subject : String) -> String {
  "<svg width='40' height='20'><defs>" + marker + "</defs>" + subject + "</svg>"
}

///|
fn marker_difference(
  report : StructuredReport,
  domain : String,
) -> AtomicDifference raise {
  for difference in report.atomic_differences {
    if difference.domain == domain {
      return difference
    }
  }
  fail("missing marker difference domain: " + domain)
}

///|
fn marker_event(report : StructuredReport, id : String) -> VisualEvent? {
  for event in report.events {
    if event.id == id {
      return Some(event)
    }
  }
  None
}

///|
fn marker_diagnostic(report : StructuredReport, code : String) -> Diagnostic? {
  for diagnostic in report.diagnostics {
    if diagnostic.code == code {
      return Some(diagnostic)
    }
  }
  None
}

///|
test "equivalent authored marker sizes remain source-visible" {
  let before = marker_diff_svg(
    "<marker id='m' markerWidth='3' markerHeight='2'/>", "<line id='edge' x1='2' y1='10' x2='20' y2='10' marker-end='url(#m)'/>",
  )
  let after = before.replace_all(old="markerWidth='3'", new="markerWidth='3.0'")
  let report = compare(before, after, ComparisonProfile::v1_default())
  let difference = marker_difference(report, "resource.marker.viewport_size")
  assert_eq(difference.source_before, "3")
  assert_eq(difference.source_after, "3")
  assert_eq(difference.source_fact_before.unwrap().authored_value, "3")
  assert_eq(difference.source_fact_after.unwrap().authored_value, "3.0")
  assert_eq(difference.computed_relation.status, "equivalent")
  assert_eq(difference.parameter_delta_css_px, Some(0.0))
}

///|
test "marker attachment changes use a typed geometry domain" {
  let before = marker_diff_svg(
    "<marker id='a'/><marker id='b'/>", "<line id='edge' x1='2' y1='10' x2='20' y2='10' marker-end='url(#a)'/>",
  )
  let after = before.replace_all(old="url(#a)", new="url(#b)")
  let report = compare(before, after, ComparisonProfile::v1_default())
  let difference = marker_difference(report, "geometry.marker_attachment")
  assert_eq(difference.source_before, "url(#a)")
  assert_eq(difference.source_after, "url(#b)")
  assert_eq(difference.computed_relation.status, "indeterminate")
  assert_true(
    report.changed_facts.any(fact => {
      fact.property == "marker-end" && fact.affected_subject_ids == ["edge"]
    }),
  )
}

///|
test "referenced marker orientation changes localize to marker envelopes" {
  let before = marker_diff_svg(
    "<marker id='m' markerUnits='userSpaceOnUse' markerWidth='4' markerHeight='2' orient='0'/>",
    "<line id='edge' x1='2' y1='10' x2='20' y2='10' marker-end='url(#m)'/>",
  )
  let after = before.replace_all(old="orient='0'", new="orient='90deg'")
  let report = compare(before, after, ComparisonProfile::v1_default())
  let difference = marker_difference(report, "resource.marker.orientation")
  assert_eq(difference.computed_relation.status, "indeterminate")
  assert_eq(difference.parameter_delta_css_px, Some(90.0))
  assert_eq(difference.evidence_layers, ["source_semantics"])
  guard marker_event(report, "event:marker-resource:m") is Some(event) else {
    fail("marker resource change must produce an event")
  }
  assert_eq(event.rendered_outcome.status, "not_computed")
  assert_true(!event.difference_regions.is_empty())
  assert_true(
    event.difference_regions.all(region => {
      region.cause_envelope.candidate_changed_fact_ids.contains(
        difference.changed_fact_ids[0],
      )
    }),
  )
}

///|
test "unreferenced marker content changes are source-only" {
  let before = marker_diff_svg(
    "<marker id='m'><path d='M0 0L1 0'/></marker>", "<rect id='box' width='2' height='2'/>",
  )
  let after = before.replace_all(old="L1 0", new="L2 0")
  let report = compare(before, after, ComparisonProfile::v1_default())
  let difference = marker_difference(report, "resource.marker.content")
  assert_eq(difference.evidence_layers, ["source_semantics"])
  assert_eq(difference.computed_relation.status, "equivalent")
  assert_eq(
    difference.computed_relation.reason_code,
    "unreferenced_marker_resource",
  )
  assert_true(difference.changed_fact_ids.length() == 1)
}

///|
test "disabled marker viewports and inapplicable aspect ratios are equivalent" {
  let zero_before = marker_diff_svg(
    "<marker id='m' markerWidth='0' orient='0'/>", "<line id='edge' x1='2' y1='10' x2='20' y2='10' marker-end='url(#m)'/>",
  )
  let zero_after = zero_before.replace_all(old="orient='0'", new="orient='90'")
  let zero_report = compare(
    zero_before,
    zero_after,
    ComparisonProfile::v1_default(),
  )
  let zero_difference = marker_difference(
    zero_report, "resource.marker.orientation",
  )
  assert_eq(zero_difference.computed_relation.status, "equivalent")
  assert_eq(
    zero_difference.computed_relation.reason_code,
    "marker_viewport_suppresses_paint",
  )

  let aspect_before = marker_diff_svg(
    "<marker id='m' preserveAspectRatio='none'/>", "<line id='edge' x1='2' y1='10' x2='20' y2='10' marker-end='url(#m)'/>",
  )
  let aspect_after = aspect_before.replace_all(
    old="preserveAspectRatio='none'",
    new="preserveAspectRatio='xMaxYMax slice'",
  )
  let aspect_report = compare(
    aspect_before,
    aspect_after,
    ComparisonProfile::v1_default(),
  )
  let aspect_difference = marker_difference(
    aspect_report, "resource.marker.viewport_mapping",
  )
  assert_eq(aspect_difference.computed_relation.status, "equivalent")
  assert_eq(
    aspect_difference.computed_relation.reason_code,
    "marker_viewbox_mapping_not_applicable",
  )
}

///|
test "different marker ids are presence changes rather than positional pairs" {
  let before = marker_diff_svg(
    "<marker id='old'/>", "<rect id='box' width='2' height='2'/>",
  )
  let after = before.replace_all(old="id='old'", new="id='new'")
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_eq(
    report.atomic_differences
    .filter(difference => difference.domain == "resource.marker.presence")
    .length(),
    2,
  )
  let fact_ids : Array[String] = []
  for fact in report.changed_facts {
    assert_false(fact_ids.contains(fact.id))
    fact_ids.push(fact.id)
  }
  assert_false(
    report.atomic_differences.any(difference => {
      difference.domain == "resource.marker.content"
    }),
  )
}

///|
test "invalid marker resources produce source-located stable diagnostics" {
  let source = marker_diff_svg(
    "<marker id='m' markerWidth='2em' overflow='visible'/>", "<line id='edge' x1='2' y1='10' x2='20' y2='10' marker-end='url(#m)'/>",
  )
  let report = compare(source, source, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "partial")
  guard marker_diagnostic(report, "marker_resource_semantics_unsupported")
    is Some(diagnostic) else {
    fail("invalid marker resource diagnostic must be present")
  }
  assert_true(diagnostic.source_locations.length() >= 2)
  assert_true(
    diagnostic.source_locations.all(location => {
      location.source_span.end_offset > location.source_span.start_offset
    }),
  )
}

///|
test "marker renderer capability remains independently guarded" {
  let source = marker_diff_svg(
    "<marker id='m'><path d='M0 0L2 1L0 2Z' fill='red'/></marker>", "<line id='edge' x1='2' y1='10' x2='20' y2='10' marker-end='url(#m)'/>",
  )
  let report = compare(source, source, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "partial")
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "marker_content_semantics_unsupported" &&
      diagnostic.subject_id == "edge"
    }),
  )
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "renderer_marker_raster_unproven" &&
      diagnostic.subject_id == "edge"
    }),
  )
  assert_true(
    report.renderer_capability_gaps.any(gap => {
      gap.capability_id == "raster.marker"
    }),
  )
}

///|
test "zero-size referenced markers retain the renderer guard" {
  let source = marker_diff_svg(
    "<marker id='m' markerWidth='0' markerHeight='4'><path d='M0 0L2 1L0 2Z'/></marker>",
    "<line id='edge' x1='2' y1='10' x2='20' y2='10' marker-end='url(#m)'/>",
  )
  let report = compare(source, source, ComparisonProfile::v1_default())
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "renderer_marker_raster_unproven" &&
      diagnostic.subject_id == "edge"
    }),
  )
}
