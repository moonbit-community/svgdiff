// Copyright 2026 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
test "filter reference grammar keeps local and external locators distinct" {
  assert_true(parse_filter_reference("none") is FilterNone)
  assert_true(parse_filter_reference("url('#shift')") is FilterLocal("shift"))
  assert_true(parse_filter_reference("url(asset.svg#shift)") is FilterExternal)
  assert_true(parse_filter_reference("blur(2px)") is FilterInvalid)
}

///|
test "filter graph resolves defaults named intermediates and conservative bounds" {
  let source =
    #|<svg width="16" height="16">
    #|  <defs><filter id="shift" x="-100%" y="-100%" width="300%" height="300%">
    #|    <feOffset dx="1" result="right"/>
    #|    <feOffset in="right" dy="2" result="final"/>
    #|  </filter></defs>
    #|  <rect id="box" x="2" y="3" width="4" height="5" fill="red" filter="url(#shift)"/>
    #|</svg>
  let (document, hosts) = resolve_filter_hosts_or_raise(
    source,
    ComparisonProfile::v1_default(),
  )
  assert_eq(document.resources.length(), 1)
  assert_eq(document.resources[0].filter_units, "objectBoundingBox")
  assert_eq(document.resources[0].primitive_units, "userSpaceOnUse")
  assert_eq(document.resources[0].primitives.length(), 2)
  assert_eq(document.resources[0].primitives[0].input, "SourceGraphic")
  assert_eq(document.resources[0].primitives[1].input, "right")
  assert_eq(hosts.length(), 1)
  assert_true(hosts[0].complete)
  assert_eq(hosts[0].primitive_offsets, [(1, 0), (0, 2)])
  guard hosts[0].effect_bounds is Some(bounds) else {
    fail("expected final filter bounds")
  }
  assert_eq(bounds.x, 3.0)
  assert_eq(bounds.y, 5.0)
  assert_eq(bounds.width, 4.0)
  assert_eq(bounds.height, 5.0)
}

///|
test "upstream filter renderer evaluates named intermediate surfaces" {
  let source =
    #|<svg width="8" height="8">
    #|  <defs><filter id="shift" x="-100%" y="-100%" width="400%" height="400%">
    #|    <feOffset dx="1" result="right"/>
    #|    <feOffset in="right" dy="1"/>
    #|  </filter></defs>
    #|  <rect id="box" x="1" y="1" width="2" height="2" fill="red" filter="url(#shift)"/>
    #|</svg>
  guard render_product_source_to_image(source, {
      ..ComparisonProfile::v1_default(),
      viewport_width: 8,
      viewport_height: 8,
    })
    is Some(image) else {
    fail("expected product render")
  }
  assert_group_compositor_pixel(image, 1, 1, 0, 0, 0, 0)
  assert_group_compositor_pixel(image, 2, 2, 255, 0, 0, 255)
  assert_group_compositor_pixel(image, 3, 3, 255, 0, 0, 255)
  assert_group_compositor_pixel(image, 4, 4, 0, 0, 0, 0)
}

///|
test "filtered leaf keeps ordinary sibling stacking" {
  let source =
    #|<svg width="8" height="8">
    #|  <defs><filter id="shift" x="-100%" y="-100%" width="400%" height="400%"><feOffset dx="2"/></filter></defs>
    #|  <rect id="back" width="8" height="8" fill="blue"/>
    #|  <rect id="box" x="1" y="1" width="2" height="2" fill="red" filter="url(#shift)"/>
    #|</svg>
  guard render_product_source_to_image(source, {
      ..ComparisonProfile::v1_default(),
      viewport_width: 8,
      viewport_height: 8,
    })
    is Some(image) else {
    fail("expected product render")
  }
  assert_group_compositor_pixel(image, 1, 1, 0, 0, 255, 255)
  assert_group_compositor_pixel(image, 3, 1, 255, 0, 0, 255)
}

///|
test "upstream filter renderer derives SourceAlpha and clips every intermediate" {
  let source =
    #|<svg width="8" height="8">
    #|  <defs><filter id="alpha" x="0" y="0" width="150%" height="100%">
    #|    <feOffset in="SourceAlpha" dx="2"/>
    #|  </filter></defs>
    #|  <rect id="box" x="1" y="1" width="2" height="2" fill="blue" filter="url(#alpha)"/>
    #|</svg>
  guard render_product_source_to_image(source, {
      ..ComparisonProfile::v1_default(),
      viewport_width: 8,
      viewport_height: 8,
    })
    is Some(image) else {
    fail("expected product render")
  }
  assert_group_compositor_pixel(image, 3, 1, 0, 0, 0, 255)
  assert_group_compositor_pixel(image, 4, 1, 0, 0, 0, 0)
}

///|
test "filter graph guards unresolved inputs unsupported primitives and fractional pixels" {
  let unresolved = "<svg><defs><filter id='f'><feOffset in='later'/><feOffset result='later'/></filter></defs><rect id='box' width='4' height='4' filter='url(#f)'/></svg>"
  let unsupported = "<svg><defs><filter id='f'><feGaussianBlur stdDeviation='2'/></filter></defs><rect id='box' width='4' height='4' filter='url(#f)'/></svg>"
  let fractional = "<svg><defs><filter id='f'><feOffset dx='0.5'/></filter></defs><rect id='box' width='4' height='4' filter='url(#f)'/></svg>"
  let unsupported_input = "<svg><defs><filter id='f'><feOffset in='BackgroundImage'/></filter></defs><rect id='box' width='4' height='4' filter='url(#f)'/></svg>"
  let invalid_result = "<svg><defs><filter id='f'><feOffset result='two words'/></filter></defs><rect id='box' width='4' height='4' filter='url(#f)'/></svg>"
  for
    case in [
      (unresolved, "filter_input_unresolved"),
      (unsupported, "filter_primitive_unsupported"),
      (fractional, "filter_fractional_offset_unproven"),
      (unsupported_input, "filter_input_unsupported"),
      (invalid_result, "filter_primitive_value_unsupported"),
    ] {
    let diagnostics : Array[Diagnostic] = []
    append_filter_diagnostics(
      case.0,
      ComparisonProfile::v1_default(),
      "before",
      diagnostics,
    )
    if !diagnostics.any(diagnostic => diagnostic.code == case.1) {
      fail("expected \{case.1}")
    }
  }
}

///|
test "unsupported filter primitives retain complete opaque source subtrees" {
  let source =
    #|<svg><defs><filter id="f">
    #|  <feGaussianBlur stdDeviation="2"/>
    #|  <title>ignored metadata</title>
    #|  <feMerge data-kind="paired"><feMergeNode in="SourceGraphic"/><!--keep--></feMerge>
    #|</filter></defs><rect id="box" width="4" height="4" filter="url(#f)"/></svg>
  let document = extract_filter_semantic_document_or_raise(
    source,
    ComparisonProfile::v1_default(),
  )
  guard document.resources is [resource] else {
    fail("expected one filter resource")
  }
  assert_eq(resource.primitive_sources.length(), 2)
  assert_eq(resource.primitive_sources[0].position, 0)
  assert_eq(resource.primitive_sources[0].kind, "feGaussianBlur")
  let first_fact = filter_primitive_source_fact(
    source,
    Some(resource.primitive_sources[0]),
  ).unwrap()
  assert_eq(first_fact.declared_value, "<feGaussianBlur stdDeviation=\"2\"/>")
  assert_eq(resource.primitive_sources[1].position, 1)
  assert_eq(resource.primitive_sources[1].kind, "feMerge")
  let second_fact = filter_primitive_source_fact(
    source,
    Some(resource.primitive_sources[1]),
  ).unwrap()
  assert_eq(
    second_fact.declared_value,
    "<feMerge data-kind=\"paired\"><feMergeNode in=\"SourceGraphic\"/><!--keep--></feMerge>",
  )
  assert_eq(
    source_range_slice(
      source,
      second_fact.source_span.start_offset,
      second_fact.source_span.end_offset,
    ),
    second_fact.declared_value,
  )
}

///|
test "unsupported filter primitive changes remain source-only differences" {
  let before = "<svg><defs><filter id='f'><feMerge><feMergeNode in='SourceGraphic'/><!--before--></feMerge></filter></defs><rect id='box' width='4' height='4' filter='url(#f)'/></svg>"
  let after = "<svg><defs><filter id='f'><feMerge><feMergeNode in='SourceAlpha'/><!--after--></feMerge></filter></defs><rect id='box' width='4' height='4' filter='url(#f)'/></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "partial")
  guard report.atomic_differences.filter(difference => {
      difference.domain == "resource.filter.primitive.source"
    })
    is [difference] else {
    fail("expected one opaque primitive source difference")
  }
  assert_eq(difference.subject_role, "resource")
  assert_eq(difference.evidence_layers, ["source_semantics"])
  assert_eq(difference.computed_relation.status, "indeterminate")
  assert_true(!difference.computed_relation.diagnostic_ids.is_empty())
  assert_eq(
    difference.source_fact_before.map(fact => fact.property),
    Some("primitive-source"),
  )
  assert_true(difference.source_before.contains("SourceGraphic"))
  assert_true(difference.source_after.contains("SourceAlpha"))
  assert_true(
    difference.magnitude.parameter_abs_user_units is None &&
    difference.magnitude.parameter_signed_user_units is None &&
    difference.magnitude.symmetric_relative is None &&
    difference.magnitude.geometry_displacement_css_px is None &&
    difference.magnitude.geometry_viewport_fraction is None &&
    difference.magnitude.presence_painted_viewport_fraction is None &&
    difference.magnitude.raster_changed_pixel_fraction is None &&
    difference.magnitude.raster_rgba8_rmse is None &&
    difference.magnitude.raster_linear_premultiplied_rgba_rmse is None &&
    difference.magnitude.intrinsic_raster is None &&
    difference.magnitude.transform_effect is None &&
    difference.presence_magnitude is None &&
    difference.domain_ordering.components.is_empty(),
  )
  guard report.events.filter(event => event.id == "event:filter:f") is [event] else {
    fail("expected one filter resource event")
  }
  assert_eq(event.rendered_outcome.status, "not_computed")
  assert_true(!event.difference_regions.is_empty())
  assert_true(
    event.difference_regions.all(region => {
      region.source == "computed_bounds" &&
      region.css_x <= 0.0 &&
      region.css_y <= 0.0 &&
      region.css_x + region.css_width >= 4.0 &&
      region.css_y + region.css_height >= 4.0
    }),
  )
  assert_true(
    report.changed_facts.any(fact => {
      fact.id == "fact:filter:f:primitive:0:source" &&
      fact.affected_subject_ids == ["box"]
    }),
  )
}

///|
test "unsupported SVG shadow primitive localizes to the resolved filter region" {
  let before = "<svg width='16' height='16'><defs><filter id='shadow'><feDropShadow dx='1' dy='1' stdDeviation='1'/></filter></defs><rect id='box' x='4' y='4' width='4' height='4' filter='url(#shadow)'/></svg>"
  let after = before.replace_all(old="stdDeviation='1'", new="stdDeviation='2'")
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "partial")
  guard report.events.filter(event => event.id == "event:filter:shadow")
    is [event] else {
    fail("expected one shadow filter resource event")
  }
  assert_eq(event.rendered_outcome.status, "not_computed")
  guard event.difference_regions is [region] else {
    fail("expected one conservative shadow region")
  }
  assert_eq(region.source, "computed_bounds")
  assert_true(
    region.css_x < 4.0 &&
    region.css_y < 4.0 &&
    region.css_x + region.css_width > 8.0 &&
    region.css_y + region.css_height > 8.0,
  )
  assert_eq(region.cause_envelope.guarantee, "not_established")
  assert_eq(region.cause_envelope.coverage, "partial")
  assert_true(!region.cause_envelope.diagnostic_ids.is_empty())
  assert_true(
    report.atomic_differences.any(difference => {
      difference.domain == "resource.filter.primitive.source" &&
      difference.evidence_layers == ["source_semantics"] &&
      difference.computed_relation.status == "indeterminate"
    }),
  )
}

///|
test "filter values without a resolved region stay unlocalized" {
  for
    entry in [
      ("blur(1px)", "blur(2px)", "filter_reference_invalid"),
      (
        "url(asset-a.svg#shadow)", "url(asset-b.svg#shadow)", "filter_external_reference_unsupported",
      ),
    ] {
    let (before_filter, after_filter, diagnostic_code) = entry
    let before = "<svg width='16' height='16'><rect id='box' x='4' y='4' width='4' height='4' filter='\{before_filter}'/></svg>"
    let after = "<svg width='16' height='16'><rect id='box' x='4' y='4' width='4' height='4' filter='\{after_filter}'/></svg>"
    let report = compare(before, after, ComparisonProfile::v1_default())
    assert_eq(report.analysis_status, "partial")
    guard report.events.filter(event => event.id == "event:filter-host:box")
      is [event] else {
      fail("expected one unsupported filter host event")
    }
    assert_eq(event.rendered_outcome.status, "not_computed")
    assert_true(event.difference_regions.is_empty())
    assert_true(
      report.diagnostics.any(diagnostic => {
        diagnostic.code == diagnostic_code &&
        !diagnostic.source_locations.is_empty()
      }),
    )
  }
}

///|
test "unsupported primitive position alignment is deterministic and conservative" {
  let host = "</filter></defs><rect id='box' width='4' height='4' filter='url(#f)'/></svg>"
  let prefix = "<svg><defs><filter id='f'>"
  let cases = [
    (
      prefix + "<feGaussianBlur stdDeviation='1'/>" + host,
      prefix + "<feFlood flood-color='red'/>" + host,
      1,
    ),
    (
      prefix + "<feGaussianBlur stdDeviation='1'/>" + host,
      prefix +
      "<feColorMatrix values='1'/><feGaussianBlur stdDeviation='1'/>" +
      host,
      2,
    ),
    (
      prefix + "<feGaussianBlur stdDeviation='1'/>" + host,
      prefix + "<feGaussianBlur stdDeviation='1'/>" + host,
      0,
    ),
  ]
  for case in cases {
    let first = compare(case.0, case.1, ComparisonProfile::v1_default())
    let second = compare(case.0, case.1, ComparisonProfile::v1_default())
    let differences = first.atomic_differences.filter(difference => {
      difference.domain == "resource.filter.primitive.source"
    })
    assert_eq(differences.length(), case.2)
    assert_eq(first.to_json(), second.to_json())
  }
}

///|
test "unsupported primitives survive whole filter resource insertion and deletion" {
  let missing = "<svg><defs></defs><rect id='box' width='4' height='4' filter='url(#f)'/></svg>"
  let present = "<svg><defs><filter id='f'><feGaussianBlur stdDeviation='2'/></filter></defs><rect id='box' width='4' height='4' filter='url(#f)'/></svg>"
  for case in [(missing, present, "before"), (present, missing, "after")] {
    let report = compare(case.0, case.1, ComparisonProfile::v1_default())
    guard report.atomic_differences.filter(difference => {
        difference.domain == "resource.filter.primitive.source"
      })
      is [difference] else {
      fail("expected one opaque primitive for resource insertion or deletion")
    }
    assert_eq(difference.computed_relation.status, "indeterminate")
    if case.2 == "before" {
      assert_true(difference.source_fact_before is None)
      assert_true(difference.source_fact_after is Some(_))
    } else {
      assert_true(difference.source_fact_before is Some(_))
      assert_true(difference.source_fact_after is None)
    }
    assert_true(
      report.changed_facts.any(fact => {
        fact.id == "fact:filter:f:primitive:0:source" &&
        fact.affected_subject_ids == ["box"]
      }),
    )
  }
}

///|
test "supported filter primitives do not emit opaque source differences" {
  let before = "<svg><defs><filter id='f'><feOffset dx='1'/></filter></defs><rect id='box' width='4' height='4' filter='url(#f)'/></svg>"
  let after = "<svg><defs><filter id='f'><feOffset dx='2'/></filter></defs><rect id='box' width='4' height='4' filter='url(#f)'/></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_true(
    !report.atomic_differences.any(difference => {
      difference.domain == "resource.filter.primitive.source"
    }),
  )
}

///|
test "filter resource outcomes stay deterministic and source located" {
  for
    source in [
      "<svg width='8' height='8'><rect id='box' x='1' y='1' width='2' height='2' fill='red' filter='url(#missing)'/></svg>",
      "<svg width='8' height='8'><circle id='target'/><rect id='box' x='1' y='1' width='2' height='2' fill='red' filter='url(#target)'/></svg>",
    ] {
    let diagnostics : Array[Diagnostic] = []
    append_filter_diagnostics(
      source,
      ComparisonProfile::v1_default(),
      "before",
      diagnostics,
    )
    assert_true(
      diagnostics
      .filter(diagnostic => diagnostic.code.has_prefix("filter_"))
      .is_empty(),
    )
    let (_, hosts) = resolve_filter_hosts_or_raise(
      source,
      ComparisonProfile::v1_default(),
    )
    assert_true(hosts[0].complete)
    assert_true(hosts[0].resource is None)
    guard render_product_source_to_image(source, {
        ..ComparisonProfile::v1_default(),
        viewport_width: 8,
        viewport_height: 8,
      })
      is Some(image) else {
      fail("expected deterministic no-filter render")
    }
    assert_group_compositor_pixel(image, 1, 1, 255, 0, 0, 255)
  }

  let cases = [
    (
      "<svg><rect id='box' width='4' height='4' filter='url(asset.svg#f)'/></svg>",
      "filter_external_reference_unsupported",
    ),
    (
      "<svg><rect id='box' width='4' height='4' filter='blur(2px)'/></svg>", "filter_reference_invalid",
    ),
  ]
  for case in cases {
    let diagnostics : Array[Diagnostic] = []
    append_filter_diagnostics(
      case.0,
      ComparisonProfile::v1_default(),
      "before",
      diagnostics,
    )
    guard diagnostics.filter(diagnostic => diagnostic.code == case.1)
      is [diagnostic] else {
      fail("expected \{case.1}")
    }
    assert_true(!diagnostic.source_locations.is_empty())
  }

  let unused = "<svg><defs><filter id='unused'><feOffset dx='1'/></filter></defs><rect id='box' width='4' height='4'/></svg>"
  let (unused_document, unused_hosts) = resolve_filter_hosts_or_raise(
    unused,
    ComparisonProfile::v1_default(),
  )
  assert_eq(unused_document.resources.length(), 1)
  assert_true(unused_hosts.is_empty())

  let empty = "<svg width='8' height='8'><defs><filter id='empty'/></defs><rect id='box' x='1' y='1' width='2' height='2' fill='red' filter='url(#empty)'/></svg>"
  let (_, empty_hosts) = resolve_filter_hosts_or_raise(
    empty,
    ComparisonProfile::v1_default(),
  )
  assert_true(empty_hosts[0].complete)
  assert_true(empty_hosts[0].effect_bounds is None)
  guard render_product_source_to_image(empty, {
      ..ComparisonProfile::v1_default(),
      viewport_width: 8,
      viewport_height: 8,
    })
    is Some(image) else {
    fail("expected deterministic transparent empty-filter render")
  }
  assert_group_compositor_pixel(image, 1, 1, 0, 0, 0, 0)

  let empty_without_id = "<svg width='8' height='8'><defs><filter id='empty'/></defs><rect x='1' y='1' width='2' height='2' fill='red' filter='url(#empty)'/></svg>"
  let (_, empty_without_id_hosts) = resolve_filter_hosts_or_raise(
    empty_without_id,
    ComparisonProfile::v1_default(),
  )
  assert_true(empty_without_id_hosts[0].complete)
  guard render_product_source_to_image(empty_without_id, {
      ..ComparisonProfile::v1_default(),
      viewport_width: 8,
      viewport_height: 8,
    })
    is Some(image) else {
    fail("expected id-less empty-filter host to render transparently")
  }
  assert_group_compositor_pixel(image, 1, 1, 0, 0, 0, 0)

  let empty_without_id_after_sibling = "<svg width='8' height='8'><defs><filter id='empty'/></defs><rect id='keep' x='1' y='1' width='2' height='2' fill='blue'/><rect x='4' y='1' width='2' height='2' fill='red' filter='url(#empty)'/></svg>"
  guard render_product_source_to_image(empty_without_id_after_sibling, {
      ..ComparisonProfile::v1_default(),
      viewport_width: 8,
      viewport_height: 8,
    })
    is Some(image) else {
    fail("expected empty-filter host after ordinary sibling to render")
  }
  assert_group_compositor_pixel(image, 1, 1, 0, 0, 255, 255)
  assert_group_compositor_pixel(image, 4, 1, 0, 0, 0, 0)
}

///|
test "missing filter references preserve source changes but are computed equivalent" {
  let before = "<svg><rect id='box' width='4' height='4' filter=\"url('#missing-a')\"/></svg>"
  let after = "<svg><rect id='box' width='4' height='4' filter='url(#missing-b)'/></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "complete")
  guard report.atomic_differences.filter(difference => {
      difference.domain == "filtering.attachment"
    })
    is [difference] else {
    fail("expected one host attachment source change")
  }
  assert_eq(difference.computed_relation.status, "equivalent")
  guard report.events.filter(event => event.id == "event:filter-host:box")
    is [event] else {
    fail("expected filter host event")
  }
  assert_eq(event.rendered_outcome.status, "computed")
  assert_eq(
    event.rendered_outcome.magnitude.map(value => value.changed_pixels),
    Some(0),
  )
}

///|
test "filter excluded semantics retain precise diagnostics" {
  let cases = [
    (
      "<svg><defs><filter id='base'><feOffset/></filter><filter id='f' href='#base'><feOffset/></filter></defs><rect id='box' width='4' height='4' filter='url(#f)'/></svg>",
      "filter_template_unsupported",
    ),
    (
      "<svg><defs><filter id='f'><feOffset x='0'/></filter></defs><rect id='box' width='4' height='4' filter='url(#f)'/></svg>",
      "filter_primitive_region_unsupported",
    ),
    (
      "<svg><defs><filter id='f'><feOffset/></filter></defs><rect id='box' width='4' height='4' transform='translate(1)' filter='url(#f)'/></svg>",
      "filter_transform_unproven",
    ),
    (
      "<svg><defs><filter id='f'><feOffset/></filter></defs><rect id='box' width='4' height='4' opacity='.5' filter='url(#f)'/></svg>",
      "filter_effect_interaction_unsupported",
    ),
    (
      "<svg><defs><filter id='f'><feOffset/></filter><rect id='shape' width='4' height='4'/></defs><use id='box' href='#shape' filter='url(#f)'/></svg>",
      "filter_instance_unsupported",
    ),
    (
      "<svg><defs><filter id='f'><feOffset><animate attributeName='dx'/></feOffset></filter></defs><rect id='box' width='4' height='4' filter='url(#f)'/></svg>",
      "filter_dynamic_unsupported",
    ),
  ]
  for case in cases {
    let diagnostics : Array[Diagnostic] = []
    append_filter_diagnostics(
      case.0,
      ComparisonProfile::v1_default(),
      "before",
      diagnostics,
    )
    if !diagnostics.any(diagnostic => diagnostic.code == case.1) {
      fail("expected \{case.1}")
    }
  }
}

///|
test "filter graph execution has a fixed primitive budget" {
  let source = StringBuilder::new()
  source.write_string("<svg><defs><filter id='f'>")
  for _ in 0..<257 {
    source.write_string("<feOffset/>")
  }
  source.write_string(
    "</filter></defs><rect id='box' width='4' height='4' filter='url(#f)'/></svg>",
  )
  let diagnostics : Array[Diagnostic] = []
  append_filter_diagnostics(
    source.to_string(),
    ComparisonProfile::v1_default(),
    "before",
    diagnostics,
  )
  assert_true(
    diagnostics.any(diagnostic => {
      diagnostic.code == "filter_graph_budget_exceeded"
    }),
  )
}

///|
test "filter graph reports primitive presence input and result separately" {
  let before = "<svg><defs><filter id='f'><feOffset in='SourceGraphic' result='first'/></filter></defs><rect id='box' width='4' height='4' filter='url(#f)'/></svg>"
  let after = "<svg><defs><filter id='f'><feOffset in='SourceAlpha' result='alpha'/><feOffset in='alpha'/></filter></defs><rect id='box' width='4' height='4' filter='url(#f)'/></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_true(
    report.atomic_differences.any(difference => {
      difference.domain == "resource.filter.primitive.graph" &&
      difference.source_fact_before.map(fact => fact.property) == Some("in")
    }),
  )
  assert_true(
    report.atomic_differences.any(difference => {
      difference.domain == "resource.filter.primitive.graph" &&
      difference.source_fact_before.map(fact => fact.property) == Some("result")
    }),
  )
  assert_true(
    report.atomic_differences.any(difference => {
      difference.domain == "resource.filter.primitive.presence"
    }),
  )
}

///|
test "filter report exposes attachment graph offsets magnitudes and localized regions" {
  let before =
    #|<svg width="16" height="16"><defs><filter id="shift" x="-100%" y="-100%" width="400%" height="400%"><feOffset dx="1" result="moved"/></filter></defs><rect id="box" x="2" y="2" width="4" height="4" fill="red" filter="url(#shift)"/></svg>
  let after =
    #|<svg width="16" height="16"><defs><filter id="shift" x="-100%" y="-100%" width="400%" height="400%"><feOffset dx="3" result="moved"/></filter></defs><rect id="box" x="2" y="2" width="4" height="4" fill="red" filter="url(#shift)"/></svg>
  let report = compare(before, after, ComparisonProfile::v1_default())
  let offsets = report.atomic_differences.filter(difference => {
    difference.domain == "resource.filter.primitive.offset"
  })
  assert_eq(offsets.length(), 1)
  assert_eq(offsets[0].computed_relation.status, "different")
  assert_eq(offsets[0].magnitude.parameter_abs_user_units, Some(2.0))
  assert_true(offsets[0].magnitude.parameter_abs_css_px is None)
  assert_true(offsets[0].magnitude.parameter_viewport_fraction is None)
  assert_true(offsets[0].magnitude.parameter_entity_fraction is None)
  assert_true(
    report.changed_facts.any(fact => {
      fact.id == "fact:filter:shift:primitive:0:dx" &&
      fact.affected_subject_ids == ["box"]
    }),
  )
  guard report.events.filter(event => event.id == "event:filter:shift")
    is [event] else {
    fail("expected one filter resource event")
  }
  assert_eq(event.rendered_outcome.status, "computed")
  assert_true(!event.difference_regions.is_empty())
  assert_true(
    event.difference_regions.all(region => {
      region.cause_envelope.guarantee == "sound_overapproximation"
    }),
  )
}

///|
test "filter source spelling stays reportable when the computed offset is equal" {
  let before = "<svg><defs><filter id='f'><feOffset dx='1'/></filter></defs><rect id='box' width='4' height='4' filter='url(#f)'/></svg>"
  let after = "<svg><defs><filter id='f'><feOffset dx='1.0'/></filter></defs><rect id='box' width='4' height='4' filter='url(#f)'/></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  guard report.atomic_differences.filter(difference => {
      difference.domain == "resource.filter.primitive.offset"
    })
    is [difference] else {
    fail("expected one source-level offset rewrite")
  }
  assert_eq(difference.computed_relation.status, "equivalent")
  assert_eq(difference.magnitude.parameter_abs_user_units, Some(0.0))
}

///|
test "filter attachment participates in cascade without inheritance" {
  let source =
    #|<svg><style>#box { filter: url(#second) } .parent { filter: url(#first) }</style><defs><filter id="first"><feOffset dx="1"/></filter><filter id="second"><feOffset dx="2"/></filter></defs><g class="parent"><rect id="box" width="4" height="4" filter="url(#first)"/></g></svg>
  let (document, hosts) = resolve_filter_hosts_or_raise(
    source,
    ComparisonProfile::v1_default(),
  )
  guard hosts.filter(value => value.owner_id == "box") is [host] else {
    fail("expected one explicit leaf filter host")
  }
  assert_eq(host.resource_id, Some("second"))
  assert_eq(host.primitive_offsets, [(2, 0)])
  assert_true(
    computed_visual_for_subject(document.hierarchy, "g:0", "filter")
    .map(value => value.reported.resolved_value)
    .unwrap_or("none") ==
    "url(#first)",
  )
  assert_true(!hosts.filter(value => value.owner_id == "g:0")[0].complete)
  assert_eq(
    computed_visual_for_subject(document.hierarchy, "box", "filter").map(value => {
      value.reported.resolved_value
    }),
    Some("url(#second)"),
  )
}

///|
test "filter inline CSS-wide and custom-property values use non-inherited cascade rules" {
  let source =
    #|<svg><defs><filter id="first"><feOffset dx="1"/></filter><filter id="second"><feOffset dx="2"/></filter></defs>
    #|<g id="parent" filter="url(#first)">
    #|  <rect id="inline" width="4" height="4" filter="url(#first)" style="--chosen:url(#second);filter:var(--chosen)"/>
    #|  <rect id="ordinary" width="4" height="4"/>
    #|  <rect id="reset" width="4" height="4" filter="url(#first)" style="filter:initial"/>
    #|  <rect id="explicit" width="4" height="4" style="filter:inherit"/>
    #|</g></svg>
  let (document, hosts) = resolve_filter_hosts_or_raise(
    source,
    ComparisonProfile::v1_default(),
  )
  guard hosts.filter(host => host.owner_id == "inline") is [inline] else {
    fail("expected inline filter host")
  }
  assert_eq(inline.resource_id, Some("second"))
  guard hosts.filter(host => host.owner_id == "explicit") is [explicit] else {
    fail("expected explicit inherit filter host")
  }
  assert_eq(explicit.resource_id, Some("first"))
  for id in ["ordinary", "reset"] {
    assert_eq(
      computed_visual_for_subject(document.hierarchy, id, "filter").map(value => {
        value.reported.resolved_value
      }),
      Some("none"),
    )
    assert_true(hosts.filter(host => host.owner_id == id).is_empty())
  }
}
