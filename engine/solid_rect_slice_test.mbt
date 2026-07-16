///|
fn solid_rect_document(attributes : String) -> String {
  "<svg width='16' height='16' xmlns='http://www.w3.org/2000/svg'><rect \{attributes}/></svg>"
}

///|
test "XML formatting variation does not create a difference" {
  let before = "<svg width='16' height='16'><rect id='box' x='2' y='2' width='8' height='8' fill='red'/></svg>"
  let after = "<svg height=\"16\" width=\"16\"><rect height=\"8\" fill=\"red\" width=\"8\" y=\"2\" x=\"2\" id=\"box\"></rect></svg>"
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "complete")
  assert_eq(report.atomic_differences.length(), 0)
  assert_eq(report.events.length(), 0)
}

///|
test "declaration whitespace and XML entity spelling normalize" {
  let before = solid_rect_document(
    "id='box' style='x:2;y:2;width:8;height:8;fill:red;opacity:1'",
  )
  let after = solid_rect_document(
    "id='box' style=' opacity : 1 ; fill : r&#101;d ; height : 8 ; width : 8 ; y : 2 ; x : 2 '",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "complete")
  assert_eq(report.atomic_differences.length(), 0)
}

///|
test "renderer style precedence normalization preserves complete equality" {
  let before = solid_rect_document(
    "id='box' x='2' y='2' width='8' height='8' style='fill:red' fill='blue'",
  )
  let after = solid_rect_document(
    "id='box' x='2' y='2' width='8' height='8' fill='blue' style='fill:red'",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "complete")
  assert_eq(report.atomic_differences.length(), 0)
  assert_eq(report.events.length(), 0)
  assert_false(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "renderer_style_precedence_unresolved"
    }),
  )
}

///|
test "renderer style precedence normalization preserves a visual change" {
  let before = solid_rect_document(
    "id='box' x='2' y='2' width='8' height='8' style='fill:red' fill='blue'",
  )
  let after = solid_rect_document(
    "id='box' x='2' y='2' width='8' height='8' style='fill:green' fill='blue'",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "complete")
  assert_eq(report.atomic_differences.length(), 1)
  assert_true(
    report.atomic_differences[0].magnitude.raster_changed_pixel_fraction
    is Some(fraction) &&
    fraction > 0.0,
  )
  assert_eq(report.events.length(), 1)
  assert_true(!report.events[0].difference_regions.is_empty())
}

///|
test "inline important cascade remains complete and renderer-equivalent" {
  let before = "<svg width='16' height='16'><rect id='box' width='16' height='16' fill='blue' style='fill:red!important;fill:green'/></svg>"
  let after = "<svg width='16' height='16'><rect id='box' width='16' height='16' fill='red'/></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "complete")
  let fill = report.atomic_differences.filter(difference => {
      difference.domain == "paint.fill"
    })[0]
  assert_eq(fill.computed_relation.status, "equivalent")
  assert_eq(fill.source_fact_before.unwrap().origin, "inline_style")
  assert_eq(fill.source_fact_before.unwrap().authored_value, "red")
  assert_eq(
    report.events[0].rendered_outcome.magnitude.unwrap().changed_pixels,
    0,
  )
}

///|
test "incomplete inline style retains the renderer precedence guard" {
  let source = solid_rect_document(
    "id='box' x='2' y='2' width='8' height='8' fill='blue' style='fill:red;unknown:value'",
  )
  let report = @engine.compare(
    source,
    source,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "partial")
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "renderer_style_precedence_unresolved"
    }),
  )
}

///|
test "moving fill to inline style is a provenance difference" {
  let before = solid_rect_document(
    "id='box' x='2' y='2' width='8' height='8' fill='red'",
  )
  let after = solid_rect_document(
    "id='box' x='2' y='2' width='8' height='8' style=' fill : red ; '",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.atomic_differences.length(), 1)
  let difference = report.atomic_differences[0]
  assert_eq(difference.domain, "paint.fill")
  assert_eq(difference.computed_relation.status, "equivalent")
  match (difference.source_fact_before, difference.source_fact_after) {
    (Some(before_fact), Some(after_fact)) => {
      assert_eq(before_fact.origin, "presentation_attribute")
      assert_eq(after_fact.origin, "inline_style")
      assert_eq(before_fact.declared_value, "red")
      assert_eq(after_fact.declared_value, "red")
    }
    _ => fail("expected declared facts on both sides")
  }
  match report.events[0].rendered_outcome.magnitude {
    Some(magnitude) => assert_eq(magnitude.changed_pixels, 0)
    None => fail("expected a rendered magnitude")
  }
}

///|
test "all changed facts on one rect are enumerated" {
  let before = solid_rect_document(
    "id='box' x='1' y='2' width='8' height='8' fill='red' opacity='1'",
  )
  let after = solid_rect_document(
    "id='box' x='3' y='2' width='8' height='8' fill='blue' opacity='0.5'",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.atomic_differences.length(), 3)
  assert_eq(
    [
      for difference in report.atomic_differences => difference.domain
    ],
    ["geometry.position", "paint.fill", "paint.opacity"],
  )
  assert_eq(report.events.length(), 1)
  assert_eq(report.events[0].atomic_difference_ids.length(), 3)
}

///|
test "supported class stylesheet selector can prove equality" {
  let source = "<svg width='16' height='16'><style>.paint { fill: red; }</style><rect id='box' class='paint' x='2' y='2' width='8' height='8'/></svg>"
  let report = @engine.compare(
    source,
    source,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "complete")
  assert_eq(report.atomic_differences.length(), 0)
  assert_true(
    !report.diagnostics.any(diagnostic => {
      diagnostic.code == "css_cascade_unsupported"
    }),
  )
}

///|
test "stylesheet specificity winner is renderer-equivalent to canonical paint" {
  let before = "<svg width='16' height='16'><style>rect { fill: blue; } #box { fill: red; }</style><rect id='box' width='16' height='16'/></svg>"
  let after = "<svg width='16' height='16'><rect id='box' width='16' height='16' fill='red'/></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "complete")
  assert_eq(report.atomic_differences.length(), 1)
  let fill = report.atomic_differences[0]
  assert_eq(fill.domain, "paint.fill")
  assert_eq(fill.computed_relation.status, "equivalent")
  assert_eq(fill.source_fact_before.unwrap().origin, "stylesheet_rule")
  assert_eq(fill.source_fact_after.unwrap().origin, "presentation_attribute")
  assert_eq(
    report.events[0].rendered_outcome.magnitude.unwrap().changed_pixels,
    0,
  )
}

///|
test "declared fact provenance is serialized into JSON" {
  let before = solid_rect_document(
    "id='box' x='2' y='2' width='8' height='8' fill='red'",
  )
  let after = solid_rect_document(
    "id='box' x='2' y='2' width='8' height='8' style='fill:red'",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  match @json.parse(report.to_json_string()) {
    {
      "schema_version": "1.31",
      "atomic_differences": [
        {
          "source_fact_before": {
            "property": "fill",
            "declared_value": "red",
            "origin": "presentation_attribute",
            "source_span": {
              "start_offset": Number(_),
              "end_offset": Number(_),
              ..
            },
            ..
          },
          "source_fact_after": { "origin": "inline_style", .. },
          ..
        },
      ],
      ..
    } => ()
    _ => fail("serialized report did not retain declared fact provenance")
  }
}
