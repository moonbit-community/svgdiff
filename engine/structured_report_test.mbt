///|
fn rect_svg(fill : String) -> String {
  positioned_rect_svg("2", fill)
}

///|
fn positioned_rect_svg(x : String, fill : String) -> String {
  "<svg width=\"16\" height=\"16\" xmlns=\"http://www.w3.org/2000/svg\"><rect id=\"box\" x=\"\{x}\" y=\"2\" width=\"8\" height=\"8\" fill=\"\{fill}\"/></svg>"
}

///|
fn gradient_rect_svg(first_stop_color : String) -> String {
  "<svg width=\"16\" height=\"16\" xmlns=\"http://www.w3.org/2000/svg\"><defs><linearGradient id=\"gradient\"><stop offset=\"0\" stop-color=\"\{first_stop_color}\"/><stop offset=\"1\" stop-color=\"blue\"/></linearGradient></defs><rect id=\"box\" x=\"2\" y=\"2\" width=\"8\" height=\"8\" fill=\"url(#gradient)\"/></svg>"
}

///|
fn unreferenced_gradient_svg(first_stop_color : String) -> String {
  "<svg width=\"16\" height=\"16\" xmlns=\"http://www.w3.org/2000/svg\"><defs><linearGradient id=\"gradient\"><stop offset=\"0\" stop-color=\"\{first_stop_color}\"/><stop offset=\"1\" stop-color=\"blue\"/></linearGradient></defs></svg>"
}

///|
fn empty_svg() -> String {
  "<svg width=\"16\" height=\"16\" xmlns=\"http://www.w3.org/2000/svg\"></svg>"
}

///|
fn transparent_rect_svg() -> String {
  "<svg width=\"16\" height=\"16\" xmlns=\"http://www.w3.org/2000/svg\"><rect id=\"box\" x=\"2\" y=\"2\" width=\"8\" height=\"8\" fill=\"red\" opacity=\"0\"/></svg>"
}

///|
fn unresolved_text_svg(content : String) -> String {
  "<svg width=\"16\" height=\"16\" xmlns=\"http://www.w3.org/2000/svg\"><text id=\"label\" x=\"1\" y=\"12\" font-family=\"Unresolved Font\">\{content}</text></svg>"
}

///|
test "equivalent paint syntax remains a source-level difference" {
  let report = @engine.compare(
    rect_svg("red"),
    rect_svg("#ff0000"),
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "complete")
  assert_eq(report.atomic_differences.length(), 1)
  let difference = report.atomic_differences[0]
  assert_eq(difference.domain, "paint.fill")
  assert_eq(difference.source_before, "red")
  assert_eq(difference.source_after, "#ff0000")
  assert_eq(difference.evidence_layers, ["source_semantics"])
  assert_eq(difference.computed_relation.status, "equivalent")
  assert_eq(difference.computed_relation.reason_code, "same_resolved_color")
  assert_eq(report.events[0].rendered_outcome.status, "computed")
  match report.events[0].rendered_outcome.magnitude {
    Some(magnitude) => {
      assert_eq(magnitude.changed_pixels, 0)
      assert_eq(magnitude.changed_pixel_fraction, 0.0)
    }
    None => fail("expected computed rendered magnitude")
  }
}

///|
test "tiny geometry changes retain continuous computed magnitude" {
  let report = @engine.compare(
    positioned_rect_svg("1.0", "red"),
    positioned_rect_svg("0.99999", "red"),
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "partial")
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "renderer_fractional_geometry_unproven" &&
      diagnostic.affected_evidence_layers == ["rendered_evidence"]
    }),
  )
  assert_eq(report.atomic_differences.length(), 1)
  let difference = report.atomic_differences[0]
  assert_eq(difference.domain, "geometry.position")
  assert_eq(difference.source_before, "1.0")
  assert_eq(difference.source_after, "0.99999")
  assert_eq(difference.computed_relation.status, "different")
  assert_eq(
    difference.computed_relation.reason_code,
    "resolved_positions_differ",
  )
  match difference.parameter_delta_css_px {
    Some(delta) => assert_true((delta - -0.00001).abs() < 0.0000000001)
    None => fail("expected a computed parameter delta")
  }
  match report.events[0].rendered_outcome.magnitude {
    Some(magnitude) => {
      assert_eq(magnitude.changed_pixels, 16)
      assert_eq(magnitude.changed_pixel_fraction, 0.0625)
    }
    None => fail("expected computed rendered magnitude")
  }
}

///|
test "salient paint changes retain source computed and rendered evidence" {
  let report = @engine.compare(
    rect_svg("red"),
    rect_svg("blue"),
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "complete")
  assert_eq(report.atomic_differences.length(), 1)
  let difference = report.atomic_differences[0]
  assert_eq(difference.domain, "paint.fill")
  assert_eq(difference.evidence_layers, [
    "source_semantics", "computed_appearance", "rendered_evidence",
  ])
  assert_eq(difference.computed_relation.status, "different")
  assert_eq(difference.computed_relation.reason_code, "resolved_colors_differ")
  assert_eq(difference.parameter_delta_css_px, None)
  match report.events[0].rendered_outcome.magnitude {
    Some(magnitude) => {
      assert_eq(magnitude.changed_pixels, 64)
      assert_eq(magnitude.changed_pixel_fraction, 0.25)
    }
    None => fail("expected computed rendered magnitude")
  }
}

///|
test "resource changes and entity outcomes share one rendered event" {
  let report = @engine.compare(
    gradient_rect_svg("red"),
    gradient_rect_svg("green"),
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "partial")
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "renderer_gradient_raster_unproven" &&
      diagnostic.affected_evidence_layers == ["rendered_evidence"]
    }),
  )
  assert_eq(report.atomic_differences.length(), 2)
  let resource_difference = report.atomic_differences[0]
  assert_eq(resource_difference.id, "diff:resource:gradient:stop:0")
  assert_eq(resource_difference.subject_role, "resource")
  assert_eq(resource_difference.domain, "resource.gradient.stop_color")
  assert_eq(resource_difference.source_before, "red")
  assert_eq(resource_difference.source_after, "green")
  assert_eq(resource_difference.evidence_layers, [
    "source_semantics", "computed_appearance",
  ])
  assert_eq(resource_difference.computed_relation.status, "different")
  let entity_difference = report.atomic_differences[1]
  assert_eq(entity_difference.id, "diff:entity:box:fill")
  assert_eq(entity_difference.subject_role, "entity")
  assert_eq(entity_difference.domain, "paint.fill")
  assert_eq(entity_difference.source_before, "url(#gradient)")
  assert_eq(entity_difference.source_after, "url(#gradient)")
  assert_eq(entity_difference.evidence_layers, ["computed_appearance"])
  assert_eq(entity_difference.computed_relation.status, "different")
  assert_eq(report.events.length(), 1)
  let event = report.events[0]
  assert_eq(event.primary_subject_id, "box")
  assert_eq(event.atomic_difference_ids, [
    "diff:resource:gradient:stop:0", "diff:entity:box:fill",
  ])
  match event.rendered_outcome.magnitude {
    Some(magnitude) => assert_true(magnitude.changed_pixels > 0)
    None => fail("expected computed rendered magnitude")
  }
}

///|
test "fractional leaf opacity retains numeric evidence behind a renderer guard" {
  let report = @engine.compare(
    "<svg width='16' height='16'><rect id='box' x='2' y='2' width='8' height='8' fill='red' opacity='0.5'/></svg>",
    "<svg width='16' height='16'><rect id='box' x='2' y='2' width='8' height='8' fill='red' opacity='0.75'/></svg>",
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "partial")
  assert_eq(report.atomic_differences.length(), 1)
  assert_eq(report.atomic_differences[0].domain, "paint.opacity")
  assert_eq(report.atomic_differences[0].computed_relation.status, "different")
  match report.events[0].rendered_outcome.magnitude {
    Some(magnitude) => assert_true(magnitude.rgba8_rmse > 0.0)
    None => fail("expected numeric renderer observation")
  }
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "renderer_fractional_opacity_unproven" &&
      diagnostic.affected_evidence_layers == ["rendered_evidence"]
    }),
  )
  assert_true(
    report.coverage_matrix.any(row => {
      row.feature_id == "guard.renderer_fractional_opacity_unproven" &&
      row.rendered_evidence == "limited"
    }),
  )
}

///|
test "gradient semantics beyond the first stop are coverage guarded" {
  let before = gradient_rect_svg("red")
  let after = before.replace_all(
    old="stop-color=\"blue\"",
    new="stop-color=\"green\"",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "partial")
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "gradient_semantics_unsupported"
    }),
  )
}

///|
test "paired gradient stop semantics are coverage guarded" {
  let before = "<svg width=\"16\" height=\"16\" xmlns=\"http://www.w3.org/2000/svg\"><defs><linearGradient id=\"gradient\"><stop offset=\"0\" stop-color=\"red\"></stop><stop offset=\"1\" stop-color=\"blue\" stop-opacity=\"1\"></stop></linearGradient></defs><rect id=\"box\" x=\"2\" y=\"2\" width=\"8\" height=\"8\" fill=\"url(#gradient)\"/></svg>"
  for
    after in [
      before.replace_all(old="stop-color=\"blue\"", new="stop-color=\"green\""),
      before.replace_all(old="offset=\"1\"", new="offset=\"0.9\""),
      before.replace_all(old="stop-opacity=\"1\"", new="stop-opacity=\"0.5\""),
    ] {
    let report = @engine.compare(
      before,
      after,
      @engine.ComparisonProfile::v1_default(),
    )
    assert_eq(report.analysis_status, "partial")
    assert_true(
      report.diagnostics.any(diagnostic => {
        diagnostic.code == "gradient_semantics_unsupported"
      }),
    )
  }
}

///|
test "zero-contribution insertion retains numeric presence footprint" {
  let report = @engine.compare(
    empty_svg(),
    transparent_rect_svg(),
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "complete")
  assert_eq(report.atomic_differences.length(), 1)
  let difference = report.atomic_differences[0]
  assert_eq(difference.subject_role, "entity")
  assert_eq(difference.domain, "presence.insertion")
  assert_eq(difference.computed_relation.status, "not_applicable")
  assert_eq(difference.computed_relation.reason_code, "before_fact_absent")
  assert_eq(difference.computed_relation.missing_side, Some("before"))
  match difference.presence_magnitude {
    Some(magnitude) => {
      assert_eq(magnitude.affected_entity_count, 1)
      assert_eq(magnitude.bounds_area_css_px2, 64.0)
      assert_eq(magnitude.bounds_viewport_fraction, 0.25)
      assert_eq(magnitude.painted_area_css_px2, 0.0)
      assert_eq(magnitude.painted_viewport_fraction, 0.0)
    }
    None => fail("expected numeric presence magnitude")
  }
  assert_eq(report.events.length(), 1)
  match report.events[0].rendered_outcome.magnitude {
    Some(magnitude) => assert_eq(magnitude.changed_pixels, 0)
    None => fail("expected computed rendered magnitude")
  }
}

///|
test "unreferenced resource changes remain reportable without entity outcomes" {
  let report = @engine.compare(
    unreferenced_gradient_svg("red"),
    unreferenced_gradient_svg("green"),
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "complete")
  assert_eq(report.atomic_differences.length(), 1)
  let difference = report.atomic_differences[0]
  assert_eq(difference.id, "diff:resource:gradient:stop:0")
  assert_eq(difference.subject_role, "resource")
  assert_eq(difference.domain, "resource.gradient.stop_color")
  assert_eq(difference.evidence_layers, [
    "source_semantics", "computed_appearance",
  ])
  assert_eq(report.events.length(), 1)
  assert_eq(report.events[0].primary_subject_id, "gradient")
  assert_eq(report.events[0].atomic_difference_ids, [
    "diff:resource:gradient:stop:0",
  ])
  match report.events[0].rendered_outcome.magnitude {
    Some(magnitude) => assert_eq(magnitude.changed_pixels, 0)
    None => fail("expected computed rendered magnitude")
  }
}

///|
test "font-dependent text analysis is explicitly deferred" {
  let report = @engine.compare(
    unresolved_text_svg("A"),
    unresolved_text_svg("B"),
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "partial")
  assert_eq(report.atomic_differences.length(), 1)
  let difference = report.atomic_differences[0]
  assert_eq(difference.subject_role, "entity")
  assert_eq(difference.domain, "text.content")
  assert_eq(difference.source_before, "A")
  assert_eq(difference.source_after, "B")
  assert_eq(difference.evidence_layers, ["source_semantics"])
  assert_eq(difference.computed_relation.status, "indeterminate")
  assert_eq(difference.computed_relation.reason_code, "font_analysis_deferred")
  assert_eq(difference.computed_relation.diagnostic_ids, [
    "diagnostic:font-analysis-deferred:label",
  ])
  assert_eq(report.events.length(), 1)
  assert_eq(report.events[0].rendered_outcome.status, "not_computed")
  assert_true(report.events[0].rendered_outcome.magnitude is None)
  assert_eq(report.diagnostics.length(), 1)
  assert_eq(report.diagnostics[0].code, "font_analysis_deferred")
  assert_eq(report.diagnostics[0].subject_id, "label")
}

///|
test "structured report serializes the complete layered result as JSON" {
  let report = @engine.compare(
    unresolved_text_svg("A"),
    unresolved_text_svg("B"),
    @engine.ComparisonProfile::v1_default(),
  )
  match @json.parse(report.to_json_string()) {
    {
      "schema_version": "1.6",
      "analysis_status": "partial",
      "coverage_matrix": _,
      "renderer_capability_gaps": [],
      "profile": { "viewport_width": 16, "viewport_height": 16, .. },
      "atomic_differences": [
        { "domain": "text.content", "subject_role": "entity", .. },
      ],
      "events": [
        {
          "primary_subject_id": "label",
          "rendered_outcome": { "status": "not_computed", .. },
          ..
        },
      ],
      "diagnostics": [
        { "code": "font_analysis_deferred", "subject_id": "label", .. },
      ],
      ..
    } => ()
    _ => fail("serialized report did not preserve the layered result")
  }
}

///|
test "required unavailable report fields serialize as JSON null" {
  let magnitude_report = @engine.compare(
    rect_svg("red"),
    rect_svg("#ff0000"),
    @engine.ComparisonProfile::v1_default(),
  )
  match @json.parse(magnitude_report.to_json_string()) {
    {
      "atomic_differences": [
        {
          "magnitude": {
            "parameter_abs_user_units": Null,
            "parameter_signed_user_units": Null,
            "symmetric_relative": Null,
            "geometry_displacement_css_px": Null,
            "geometry_viewport_fraction": Null,
            "presence_painted_viewport_fraction": Null,
            ..
          },
          ..
        },
      ],
      ..
    } => ()
    _ => fail("unavailable magnitude components must serialize as null")
  }
  let presence_report = @engine.compare(
    empty_svg(),
    rect_svg("red"),
    @engine.ComparisonProfile::v1_default(),
  )
  match @json.parse(presence_report.to_json_string()) {
    { "changed_facts": [{ "before": Null, "after": Null, .. }], .. } => ()
    _ => fail("absent changed facts must serialize as null")
  }
  let resource_report = @engine.compare(
    unreferenced_gradient_svg("red"),
    unreferenced_gradient_svg("green"),
    @engine.ComparisonProfile::v1_default(),
  )
  match @json.parse(resource_report.to_json_string()) {
    { "atomic_differences": [{ "subject_alignment_id": Null, .. }], .. } => ()
    _ => fail("an unaligned difference must serialize its subject as null")
  }
}

///|
test "compact JSON preserves the complete structured report" {
  let report = @engine.compare(
    unresolved_text_svg("A"),
    unresolved_text_svg("B"),
    @engine.ComparisonProfile::v1_default(),
  )
  let indented = report.to_json_string()
  let compact = report.to_compact_json_string()
  assert_true(compact.length() < indented.length())
  assert_true(compact.find("\n") is None)
  match @json.parse(compact) {
    {
      "schema_version": "1.6",
      "analysis_status": "partial",
      "coverage_matrix": _,
      "renderer_capability_gaps": [],
      "profile": { "viewport_width": 16, "viewport_height": 16, .. },
      "subject_alignments": _,
      "changed_facts": _,
      "source_resolutions": _,
      "atomic_differences": [
        { "domain": "text.content", "subject_role": "entity", .. },
      ],
      "events": [_],
      "diagnostics": [_],
      ..
    } => ()
    _ => fail("compact JSON did not preserve every report section")
  }
}

///|
test "unsupported visual subjects cannot produce complete equality" {
  let source = "<svg width='16' height='16'><path d='M0 0 L8 8'/></svg>"
  let report = @engine.compare(
    source,
    source,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "partial")
  assert_eq(report.atomic_differences.length(), 0)
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "unsupported_visual_subject"
    }),
  )
}

///|
test "parse failure is diagnosed" {
  let report = @engine.compare(
    "<svg>😀<rect></svg>",
    "<svg><rect/></svg>",
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "failed")
  assert_true(
    report.diagnostics.any(diagnostic => diagnostic.code == "svg_parse_failed"),
  )
}

///|
test "malformed inputs retain parser spans for both source roles" {
  let report = @engine.compare(
    "<svg>😀<rect></svg>",
    "<svg><circle></svg>",
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "failed")
  assert_eq(report.diagnostics.length(), 1)
  let locations = report.diagnostics[0].source_locations
  assert_eq(locations.length(), 2)
  assert_eq(locations[0].source_role, "before")
  assert_eq(locations[0].source_span.start_offset, 13)
  assert_eq(locations[0].source_span.end_offset, 18)
  assert_eq(locations[1].source_role, "after")
  assert_eq(locations[1].source_span.start_offset, 13)
  assert_eq(locations[1].source_span.end_offset, 18)
}

///|
test "limited diagnostics merge narrow locations across both sources" {
  let report = @engine.compare(
    "<svg width='16' height='16'><path id='shape' d='M0 0 L1 1'/></svg>",
    "<svg width='16' height='16'><path id='shape' d='M0 0 L2 2'/></svg>",
    @engine.ComparisonProfile::v1_default(),
  )
  let mut found : @engine.Diagnostic? = None
  for diagnostic in report.diagnostics {
    if diagnostic.code == "unsupported_visual_subject" {
      found = Some(diagnostic)
    }
  }
  match found {
    Some(diagnostic) => {
      assert_eq(diagnostic.source_locations.length(), 2)
      assert_eq(diagnostic.source_locations[0].source_role, "before")
      assert_eq(diagnostic.source_locations[0].source_span.start_offset, 28)
      assert_eq(diagnostic.source_locations[0].source_span.end_offset, 60)
      assert_eq(diagnostic.source_locations[1].source_role, "after")
      assert_eq(diagnostic.source_locations[1].source_span.start_offset, 28)
      assert_eq(diagnostic.source_locations[1].source_span.end_offset, 60)
    }
    None => fail("expected unsupported path Diagnostic")
  }
}

///|
test "attribute, value, and renderer guards retain declaration locations" {
  let before = "<svg width='16' height='16'><rect id='box' x='1.5' filter='url(#f)' fill='red' style='fill:blue;unknown:value'/></svg>"
  let after = "<svg width='16' height='16'><rect id='box' x='2.5' filter='url(#f)' fill='red' style='fill:green;unknown:value'/></svg>"
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  let expectations = [
    ("unsupported_visual_attribute", 2),
    ("renderer_fractional_geometry_unproven", 2),
    ("renderer_style_precedence_unresolved", 4),
  ]
  for expectation in expectations {
    let (code, expected_locations) = expectation
    let mut found : @engine.Diagnostic? = None
    for diagnostic in report.diagnostics {
      if diagnostic.code == code {
        found = Some(diagnostic)
      }
    }
    match found {
      Some(diagnostic) => {
        assert_eq(diagnostic.source_locations.length(), expected_locations)
        assert_true(
          diagnostic.source_locations.any(location => {
            location.source_role == "before"
          }),
        )
        assert_true(
          diagnostic.source_locations.any(location => {
            location.source_role == "after"
          }),
        )
      }
      None => fail("expected located Diagnostic \{code}")
    }
  }
}
