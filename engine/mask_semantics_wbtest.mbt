///|
fn mask_test_difference(
  report : StructuredReport,
  domain : String,
) -> AtomicDifference? {
  for difference in report.atomic_differences {
    if difference.domain == domain {
      return Some(difference)
    }
  }
  None
}

///|
fn mask_test_event(report : StructuredReport, id : String) -> VisualEvent? {
  for event in report.events {
    if event.id == id {
      return Some(event)
    }
  }
  None
}

///|
test "mask cascade spelling is source-visible and computed-equivalent" {
  let before =
    #|<svg width="16" height="16">
    #|  <defs><mask id="fade" mask-type="alpha"><rect width="8" height="16" fill="white"/></mask></defs>
    #|  <rect id="box" width="16" height="16" fill="red" mask="url( '#fade' )"/>
    #|</svg>
  let after =
    #|<svg width="16" height="16" style="--active-mask:url(#fade)">
    #|  <style>#box { mask: var(--active-mask); }</style>
    #|  <defs><mask id="fade" mask-type="alpha"><rect width="8" height="16" fill="white"/></mask></defs>
    #|  <rect id="box" width="16" height="16" fill="red"/>
    #|</svg>
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "complete")
  guard mask_test_difference(report, "masking.attachment") is Some(difference) else {
    fail("expected mask attachment source difference")
  }
  assert_eq(difference.computed_relation.status, "equivalent")
  assert_eq(
    difference.source_fact_before.unwrap().origin,
    "presentation_attribute",
  )
  assert_eq(difference.source_fact_after.unwrap().origin, "stylesheet_rule")
  assert_true(
    report.source_resolutions.any(pair => {
      pair.subject_id == "box" &&
      pair.property == "mask" &&
      pair.before.map(value => value.resolved_value) == Some("url(#fade)") &&
      pair.after.map(value => value.resolved_value) == Some("url(#fade)")
    }),
  )
  assert_true(
    report.events.any(event => {
      event.atomic_difference_ids.contains(difference.id) &&
      event.rendered_outcome.magnitude.map(value => value.changed_pixels) ==
      Some(0)
    }),
  )
}

///|
test "alpha and luminance masks derive distinct continuous values" {
  let alpha =
    #|<svg width="8" height="8">
    #|  <defs><mask id="fade" mask-type="alpha" maskUnits="userSpaceOnUse" x="0" y="0" width="8" height="8"><rect width="8" height="8" fill="red"/></mask></defs>
    #|  <rect width="8" height="8" fill="blue" mask="url(#fade)"/>
    #|</svg>
  let luminance = alpha.replace_all(
    old="mask-type=\"alpha\"",
    new="mask-type=\"luminance\"",
  )
  let profile = {
    ..ComparisonProfile::v1_default(),
    viewport_width: 8,
    viewport_height: 8,
  }
  guard render_group_compositor_test_source(alpha, profile) is Some(alpha_image) else {
    fail("expected alpha mask render")
  }
  guard render_group_compositor_test_source(luminance, profile)
    is Some(luminance_image) else {
    fail("expected luminance mask render")
  }
  assert_group_compositor_pixel(alpha_image, 2, 2, 0, 0, 255, 255)
  assert_group_compositor_pixel(luminance_image, 2, 2, 0, 0, 255, 54)

  let report = compare(alpha, luminance, profile)
  assert_eq(report.analysis_status, "complete")
  guard mask_test_difference(report, "resource.mask.type") is Some(difference) else {
    fail("expected mask type difference")
  }
  assert_eq(difference.computed_relation.status, "different")
  assert_true(
    report.events.any(event => {
      event.atomic_difference_ids.contains(difference.id) &&
      event.rendered_outcome.magnitude.map(value => value.changed_pixels) ==
      Some(64)
    }),
  )
}

///|
test "mask units and content units retain resolved numeric geometry" {
  let before =
    #|<svg width="16" height="16">
    #|  <defs><mask id="fade" mask-type="alpha" maskUnits="objectBoundingBox" maskContentUnits="objectBoundingBox" x="0" y="0" width="1" height="1"><rect id="mask-box" x="0" y="0" width="0.5" height="1" fill="white"/></mask></defs>
    #|  <rect id="box" x="2" y="2" width="8" height="8" fill="red" mask="url(#fade)"/>
    #|</svg>
  let after = before.replace_all(
    old="id=\"mask-box\" x=\"0\"",
    new="id=\"mask-box\" x=\"0.5\"",
  )
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "complete")
  guard mask_test_difference(report, "resource.mask.geometry")
    is Some(difference) else {
    fail("expected mask geometry difference")
  }
  assert_eq(difference.computed_relation.status, "different")
  assert_eq(difference.magnitude.parameter_signed_user_units, Some(0.5))
  assert_true(
    difference.changed_fact_ids.any(id => {
      report.changed_facts.any(fact => {
        fact.id == id && fact.affected_subject_ids == ["box"]
      })
    }),
  )
  assert_true(
    report.events.any(event => {
      event.atomic_difference_ids.contains(difference.id) &&
      event.difference_regions.all(region => {
        region.css_x >= 2.0 && region.css_x + region.css_width <= 10.0
      })
    }),
  )
}

///|
test "missing mask target is deterministic transparent black" {
  let before =
    #|<svg width="8" height="8"><rect id="box" width="8" height="8" fill="red"/></svg>
  let after =
    #|<svg width="8" height="8"><rect id="box" width="8" height="8" fill="red" mask="url(#missing)"/></svg>
  let profile = {
    ..ComparisonProfile::v1_default(),
    viewport_width: 8,
    viewport_height: 8,
  }
  let report = compare(before, after, profile)
  assert_eq(report.analysis_status, "complete")
  guard mask_test_difference(report, "masking.attachment") is Some(difference) else {
    fail("expected mask attachment difference")
  }
  assert_eq(difference.computed_relation.status, "different")
  assert_true(
    report.events.any(event => {
      event.atomic_difference_ids.contains(difference.id) &&
      event.rendered_outcome.magnitude.map(value => value.changed_pixels) ==
      Some(64)
    }),
  )
}

///|
test "mask-mode overrides mask-type through the host cascade" {
  let alpha =
    #|<svg width="8" height="8">
    #|  <style>#box { mask-mode: var(--mode); }</style>
    #|  <defs><mask id="fade" style="mask-type:luminance" maskUnits="userSpaceOnUse"><rect width="8" height="8" fill="red"/></mask></defs>
    #|  <rect id="box" style="--mode:alpha" width="8" height="8" fill="blue" mask="url(#fade)"/>
    #|</svg>
  let luminance = alpha.replace_all(old="--mode:alpha", new="--mode:luminance")
  let profile = {
    ..ComparisonProfile::v1_default(),
    viewport_width: 8,
    viewport_height: 8,
  }
  guard render_group_compositor_test_source(alpha, profile) is Some(alpha_image) else {
    fail("expected host alpha override render")
  }
  guard render_group_compositor_test_source(luminance, profile)
    is Some(luminance_image) else {
    fail("expected host luminance override render")
  }
  assert_group_compositor_pixel(alpha_image, 2, 2, 0, 0, 255, 255)
  assert_group_compositor_pixel(luminance_image, 2, 2, 0, 0, 255, 54)
  let report = compare(alpha, luminance, profile)
  assert_eq(report.analysis_status, "complete")
  guard mask_test_difference(report, "masking.mode") is Some(difference) else {
    fail("expected mask mode difference")
  }
  assert_eq(difference.computed_relation.status, "different")
}

///|
test "mask region defaults partial attributes and empty regions are exact" {
  let partial =
    #|<svg width="8" height="8"><defs><mask id="fade" mask-type="alpha" maskUnits="objectBoundingBox" x="0"><rect width="8" height="8" fill="white"/></mask></defs><rect width="8" height="8" fill="red" mask="url(#fade)"/></svg>
  let profile = {
    ..ComparisonProfile::v1_default(),
    viewport_width: 8,
    viewport_height: 8,
  }
  guard render_group_compositor_test_source(partial, profile) is Some(image) else {
    fail("expected partial-region mask render")
  }
  assert_group_compositor_pixel(image, 1, 1, 255, 0, 0, 255)
  assert_group_compositor_pixel(image, 7, 7, 255, 0, 0, 255)

  let empty = partial.replace_all(old="x=\"0\"", new="x=\"0\" width=\"0\"")
  guard render_group_compositor_test_source(empty, profile) is Some(empty_image) else {
    fail("expected empty-region mask render")
  }
  assert_group_compositor_pixel(empty_image, 1, 1, 0, 0, 0, 0)
  assert_eq(compare(empty, empty, profile).analysis_status, "complete")
}

///|
test "mask color is equivalent for alpha mode but visual for luminance" {
  let alpha_red =
    #|<svg width="8" height="8"><defs><mask id="fade" mask-type="alpha" maskUnits="userSpaceOnUse"><rect width="8" height="8" fill="red" fill-opacity="0.5"/></mask></defs><rect id="box" width="8" height="8" fill="blue" mask="url(#fade)"/></svg>
  let alpha_blue = alpha_red.replace_all(
    old="fill=\"red\"",
    new="fill=\"blue\"",
  )
  let alpha_report = compare(alpha_red, alpha_blue, {
    ..ComparisonProfile::v1_default(),
    viewport_width: 8,
    viewport_height: 8,
  })
  assert_eq(alpha_report.analysis_status, "complete")
  guard mask_test_difference(alpha_report, "resource.mask.color")
    is Some(alpha_difference) else {
    fail("expected mask color source difference")
  }
  assert_eq(alpha_difference.computed_relation.status, "equivalent")
  assert_true(
    alpha_report.events.any(event => {
      event.atomic_difference_ids.contains(alpha_difference.id) &&
      event.rendered_outcome.magnitude.map(value => value.changed_pixels) ==
      Some(0)
    }),
  )

  let luminance_red = alpha_red.replace_all(
    old="mask-type=\"alpha\"",
    new="mask-type=\"luminance\"",
  )
  let luminance_blue = alpha_blue.replace_all(
    old="mask-type=\"alpha\"",
    new="mask-type=\"luminance\"",
  )
  let luminance_report = compare(luminance_red, luminance_blue, {
    ..ComparisonProfile::v1_default(),
    viewport_width: 8,
    viewport_height: 8,
  })
  guard mask_test_difference(luminance_report, "resource.mask.color")
    is Some(luminance_difference) else {
    fail("expected luminance mask color difference")
  }
  assert_eq(luminance_difference.computed_relation.status, "different")
}

///|
test "container mask remains isolated when another opacity layer activates compositor" {
  let source =
    #|<svg width="12" height="8">
    #|  <defs><mask id="fade" mask-type="alpha" maskUnits="userSpaceOnUse"><rect width="8" height="8" fill="white" fill-opacity="0.5"/></mask></defs>
    #|  <g id="masked" mask="url(#fade)"><rect width="6" height="6" fill="red"/><rect x="2" width="6" height="6" fill="blue"/></g>
    #|  <g opacity="0.5"><rect x="10" width="2" height="2" fill="lime"/></g>
    #|</svg>
  let profile = {
    ..ComparisonProfile::v1_default(),
    viewport_width: 12,
    viewport_height: 8,
  }
  let normalized = normalize_renderer_input_with_profile(source, profile)
  guard @svg.parse_svg_document(normalized) is Some(document) else {
    fail("expected parsed normalized mask document")
  }
  assert_eq(document.root.children[1].mask_id, Some("fade"))
  guard document.masks.get("fade") is Some(mask) else {
    fail("expected parsed mask resource")
  }
  let mask_probe = @svg.render_svg_document_to_image(
    { ..document, root: { ..document.root, children: mask.content } },
    12,
    8,
  )
  assert_eq(group_compositor_test_pixel(mask_probe, 1, 1).a, 128)
  guard render_group_compositor_test_source(source, profile) is Some(image) else {
    fail("expected isolated container mask render")
  }
  let red = group_compositor_test_pixel(image, 1, 1)
  let blue = group_compositor_test_pixel(image, 3, 1)
  let green = group_compositor_test_pixel(image, 10, 1)
  assert_eq((red.r, red.g, red.b, red.a), (255, 0, 0, 128))
  assert_eq((blue.r, blue.g, blue.b, blue.a), (0, 0, 255, 128))
  assert_eq((green.r, green.g, green.b, green.a), (0, 255, 0, 128))
  assert_eq(compare(source, source, profile).analysis_status, "complete")
}

///|
test "container mask isolates nested content before backdrop and sibling composition" {
  let source =
    #|<svg width="16" height="8">
    #|  <defs><mask id="fade" mask-type="alpha" maskUnits="userSpaceOnUse"><rect width="10" height="8" fill="white" fill-opacity="0.5"/></mask></defs>
    #|  <rect width="16" height="8" fill="lime"/>
    #|  <g mask="url(#fade)"><rect width="8" height="8" fill="red"/><g><rect x="4" width="8" height="8" fill="blue"/></g></g>
    #|  <rect x="14" width="2" height="8" fill="yellow"/>
    #|</svg>
  let profile = {
    ..ComparisonProfile::v1_default(),
    viewport_width: 16,
    viewport_height: 8,
  }
  guard render_group_compositor_test_source(source, profile) is Some(image) else {
    fail("expected nested masked product render")
  }
  assert_group_compositor_pixel(image, 2, 2, 128, 127, 0, 255)
  assert_group_compositor_pixel(image, 6, 2, 0, 127, 128, 255)
  assert_group_compositor_pixel(image, 11, 2, 0, 255, 0, 255)
  assert_group_compositor_pixel(image, 15, 2, 255, 255, 0, 255)
  assert_eq(compare(source, source, profile).analysis_status, "complete")
}

///|
test "mask resource regions and cause envelopes exclude unrelated changes" {
  let before =
    #|<svg width="16" height="16">
    #|  <defs><mask id="fade" mask-type="alpha" maskUnits="userSpaceOnUse" x="0" y="0" width="10" height="8"><rect id="mask-box" width="4" height="8" fill="white"/></mask></defs>
    #|  <rect id="box" width="10" height="8" fill="red" mask="url(#fade)"/>
    #|  <rect id="outside" x="12" y="12" width="3" height="3" fill="red"/>
    #|</svg>
  let after = before
    .replace_all(old="id=\"mask-box\"", new="id=\"mask-box\" x=\"4\"")
    .replace_all(
      old="id=\"outside\" x=\"12\" y=\"12\" width=\"3\" height=\"3\" fill=\"red\"",
      new="id=\"outside\" x=\"12\" y=\"12\" width=\"3\" height=\"3\" fill=\"blue\"",
    )
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "complete")
  assert_true(
    report.atomic_differences.all(difference => {
      !difference.id.has_prefix("diff:unused-definition:mask-box:")
    }),
  )
  guard mask_test_event(report, "event:mask:fade") is Some(event) else {
    fail("expected mask resource event")
  }
  assert_true(!event.difference_regions.is_empty())
  assert_true(
    event.difference_regions.all(region => {
      region.css_x + region.css_width <= 8.0 &&
      region.cause_envelope.guarantee == "sound_overapproximation" &&
      region.cause_envelope.candidate_changed_fact_ids.any(id => {
        id.has_prefix("fact:mask:fade:")
      })
    }),
  )
}

///|
test "shared mask resources retain every consumer" {
  let before =
    #|<svg width="16" height="8"><defs><mask id="fade" mask-type="alpha" maskUnits="userSpaceOnUse"><rect id="mask-box" width="6" height="8" fill="white"/></mask></defs><rect id="left" width="8" height="8" fill="red" mask="url(#fade)"/><rect id="right" x="8" width="8" height="8" fill="blue" mask="url(#fade)"/></svg>
  let after = before.replace_all(old="width=\"6\"", new="width=\"7\"")
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "complete")
  guard mask_test_difference(report, "resource.mask.geometry")
    is Some(difference) else {
    fail("expected shared mask geometry difference")
  }
  assert_true(
    difference.changed_fact_ids.any(id => {
      report.changed_facts.any(fact => {
        fact.id == id && fact.affected_subject_ids == ["left", "right"]
      })
    }),
  )
}

///|
test "mask unsupported boundaries are precise and source located" {
  let cases = [
    (
      "<svg><rect id='box' width='8' height='8' mask='url(asset.svg#fade)'/></svg>",
      "mask_external_reference_unsupported",
    ),
    (
      "<svg><rect id='box' width='8' height='8' mask='url()'/></svg>", "mask_reference_invalid",
    ),
    (
      "<svg><rect id='box' width='8' height='8' mask='linear-gradient(black,white)'/></svg>",
      "mask_image_unsupported",
    ),
    (
      "<svg><rect id='box' width='8' height='8' mask='url(#left),url(#right)'/></svg>",
      "mask_multiple_layers_unsupported",
    ),
    (
      "<svg><rect id='box' width='8' height='8' mask-image='linear-gradient(black,white)'/></svg>",
      "mask_image_unsupported",
    ),
    (
      "<svg><rect id='box' width='8' height='8' mask-border-source='url(border.png)'/></svg>",
      "mask_border_unsupported",
    ),
    (
      "<svg><rect id='box' width='8' height='8' mask-composite='exclude'/></svg>",
      "mask_layer_subproperty_unsupported",
    ),
    (
      "<svg><defs><mask id='fade'><rect width='8' height='8'/></mask></defs><rect id='box' width='8' height='8' mask='url(#fade)' mask-mode='invalid'/></svg>",
      "mask_mode_invalid",
    ),
    (
      "<svg><defs><mask id='fade'><circle r='4'/></mask></defs><rect id='box' width='8' height='8' mask='url(#fade)'/></svg>",
      "mask_content_unsupported",
    ),
    (
      "<svg><defs><mask id='fade'><rect width='4' height='4'/><rect x='4' width='4' height='4'/></mask></defs><rect id='box' width='8' height='8' mask='url(#fade)'/></svg>",
      "mask_content_multiple_unsupported",
    ),
    (
      "<svg><defs><mask id='fade'><rect width='4' height='4'/><animate attributeName='x' values='0;1'/></mask></defs><rect id='box' width='8' height='8' mask='url(#fade)'/></svg>",
      "mask_dynamic_unsupported",
    ),
    (
      "<svg><defs><linearGradient id='paint'/><mask id='fade'><rect width='4' height='4' fill='url(#paint)'/></mask></defs><rect id='box' width='8' height='8' mask='url(#fade)'/></svg>",
      "mask_paint_unsupported",
    ),
    (
      "<svg><defs><mask id='fade'><rect width='4' height='4' rx='1'/></mask></defs><rect id='box' width='8' height='8' mask='url(#fade)'/></svg>",
      "mask_geometry_unsupported",
    ),
    (
      "<svg><defs><mask id='fade' maskUnits='invalid'><rect width='4' height='4'/></mask></defs><rect id='box' width='8' height='8' mask='url(#fade)'/></svg>",
      "mask_units_invalid",
    ),
    (
      "<svg><defs><mask id='fade' maskContentUnits='invalid'><rect width='4' height='4'/></mask></defs><rect id='box' width='8' height='8' mask='url(#fade)'/></svg>",
      "mask_content_units_invalid",
    ),
    (
      "<svg><defs><mask id='fade' mask-type='invalid'><rect width='4' height='4'/></mask></defs><rect id='box' width='8' height='8' mask='url(#fade)'/></svg>",
      "mask_type_invalid",
    ),
    (
      "<svg><defs><mask id='fade' color-interpolation='linearRGB'><rect width='4' height='4'/></mask></defs><rect id='box' width='8' height='8' mask='url(#fade)'/></svg>",
      "mask_linear_rgb_unsupported",
    ),
    (
      "<svg><defs><mask id='fade' color-interpolation='display-p3'><rect width='4' height='4'/></mask></defs><rect id='box' width='8' height='8' mask='url(#fade)'/></svg>",
      "mask_color_interpolation_invalid",
    ),
    (
      "<svg><defs><mask id='fade'><rect width='4' height='4' transform='rotate(45)'/></mask></defs><rect id='box' width='8' height='8' mask='url(#fade)'/></svg>",
      "mask_transform_unproven",
    ),
    (
      "<svg><defs><mask id='fade'><rect width='4' height='4' clip-path='url(#cut)'/></mask><clipPath id='cut'><rect width='2' height='2'/></clipPath></defs><rect id='box' width='8' height='8' mask='url(#fade)'/></svg>",
      "mask_nested_effect_unsupported",
    ),
  ]
  for entry in cases {
    let (source, code) = entry
    let report = compare(source, source, ComparisonProfile::v1_default())
    assert_eq(report.analysis_status, "partial")
    if !report.diagnostics.any(diagnostic => {
        diagnostic.code == code && !diagnostic.source_locations.is_empty()
      }) {
      fail("expected located diagnostic \{code} for \{source}")
    }
  }
}

///|
test "mask stays non-inherited while an ancestor mask remains active" {
  let source =
    #|<svg width="16" height="16"><style>#box { mask: unset; }</style><defs><mask id="fade" mask-type="alpha" maskUnits="userSpaceOnUse"><rect width="8" height="16" fill="white"/></mask></defs><g id="layer" mask="url(#fade)"><rect id="box" width="16" height="16" fill="red"/></g></svg>
  let subjects = extract_source_subjects_with_profile_or_raise(
    source,
    ComparisonProfile::v1_default(),
  )
  guard subjects is [subject] else { fail("expected one masked leaf") }
  assert_eq(
    source_subject_resolution(subject, "mask").map(value => value.resolved_value),
    Some("none"),
  )
  assert_eq(subject.mask_owner_id, Some("layer"))
  assert_eq(subject.mask_resource_id, Some("fade"))
  assert_true(subject.mask_effect_bounds is Some(_))
}

///|
test "container mask attachment changes retain host and descendant fan-out" {
  let before =
    #|<svg width="8" height="8"><defs><mask id="fade" mask-type="alpha" maskUnits="userSpaceOnUse"><rect width="4" height="8" fill="white"/></mask></defs><g id="layer"><rect id="box" width="8" height="8" fill="red"/></g></svg>
  let after = before.replace_all(
    old="<g id=\"layer\">",
    new="<g id=\"layer\" mask=\"url(#fade)\">",
  )
  let profile = {
    ..ComparisonProfile::v1_default(),
    viewport_width: 8,
    viewport_height: 8,
  }
  let report = compare(before, after, profile)
  assert_eq(report.analysis_status, "complete")
  guard render_group_compositor_test_source(after, profile) is Some(image) else {
    fail("expected container mask render")
  }
  assert_group_compositor_pixel(image, 2, 2, 255, 0, 0, 255)
  assert_group_compositor_pixel(image, 6, 2, 0, 0, 0, 0)
  guard mask_test_event(report, "event:mask-host:layer") is Some(event) else {
    fail("expected container mask host event")
  }
  guard event.atomic_difference_ids is [difference_id] else {
    fail("expected one host attachment difference")
  }
  guard report.atomic_differences.any(difference => {
    difference.id == difference_id &&
    difference.domain == "masking.attachment" &&
    difference.computed_relation.status == "different"
  }) else {
    fail("expected computed container mask attachment")
  }
  assert_true(
    report.changed_facts.any(fact => {
      fact.id == "fact:mask-host:layer:mask" &&
      fact.affected_subject_ids == ["box"]
    }),
  )
  assert_eq(
    event.rendered_outcome.magnitude.map(value => value.changed_pixels),
    Some(32),
  )
}

///|
test "empty and wrong-kind masks are complete transparent black outcomes" {
  let empty =
    #|<svg width="8" height="8"><defs><mask id="fade"/></defs><rect id="box" width="8" height="8" fill="red" mask="url(#fade)"/></svg>
  let wrong =
    #|<svg width="8" height="8"><defs><linearGradient id="fade"/></defs><rect id="box" width="8" height="8" fill="red" mask="url(#fade)"/></svg>
  let profile = {
    ..ComparisonProfile::v1_default(),
    viewport_width: 8,
    viewport_height: 8,
  }
  for source in [empty, wrong] {
    let report = compare(source, source, profile)
    assert_eq(report.analysis_status, "complete")
    guard render_group_compositor_test_source(source, profile) is Some(image) else {
      fail("expected deterministic transparent mask render")
    }
    assert_group_compositor_pixel(image, 2, 2, 0, 0, 0, 0)
  }
}

///|
test "mask alpha changes retain tiny continuous magnitude before raster quantization" {
  let before =
    #|<svg width="8" height="8"><defs><mask id="fade" mask-type="alpha" maskUnits="userSpaceOnUse"><rect width="8" height="8" fill="white" fill-opacity="0.5"/></mask></defs><rect id="box" width="8" height="8" fill="red" mask="url(#fade)"/></svg>
  let after = before.replace_all(
    old="fill-opacity=\"0.5\"",
    new="fill-opacity=\"0.50001\"",
  )
  let report = compare(before, after, {
    ..ComparisonProfile::v1_default(),
    viewport_width: 8,
    viewport_height: 8,
  })
  assert_eq(report.analysis_status, "complete")
  guard mask_test_difference(report, "resource.mask.alpha") is Some(difference) else {
    fail("expected mask alpha difference")
  }
  guard difference.magnitude.parameter_signed_user_units is Some(delta) else {
    fail("expected signed mask alpha delta")
  }
  assert_true((delta - 0.00001).abs() < 0.000000001)
  assert_true(
    difference.magnitude.symmetric_relative is Some(value) && value > 0.0,
  )
  assert_true(
    report.events.any(event => {
      event.atomic_difference_ids.contains(difference.id) &&
      event.rendered_outcome.magnitude.map(value => value.changed_pixels) ==
      Some(0)
    }),
  )
}

///|
test "clipping precedes transformed alpha masking for admitted leaf effects" {
  let source =
    #|<svg width="8" height="8"><defs><clipPath id="cut"><rect x="1" y="1" width="6" height="6"/></clipPath><mask id="fade" mask-type="alpha" maskUnits="userSpaceOnUse"><rect x="0" y="0" width="3" height="4" fill="white" transform="translate(2 1)"/></mask></defs><rect id="box" width="8" height="8" fill="blue" clip-path="url(#cut)" mask="url(#fade)"/></svg>
  let profile = {
    ..ComparisonProfile::v1_default(),
    viewport_width: 8,
    viewport_height: 8,
  }
  let report = compare(source, source, profile)
  assert_eq(report.analysis_status, "complete")
  guard render_group_compositor_test_source(source, profile) is Some(image) else {
    fail("expected clipped masked leaf render")
  }
  assert_group_compositor_pixel(image, 1, 2, 0, 0, 0, 0)
  assert_group_compositor_pixel(image, 2, 2, 0, 0, 255, 255)
  assert_group_compositor_pixel(image, 4, 4, 0, 0, 255, 255)
  assert_group_compositor_pixel(image, 5, 4, 0, 0, 0, 0)
}

///|
test "mask insertion deletion and unused resources retain deterministic outcomes" {
  let missing =
    #|<svg width="8" height="8"><rect id="box" width="8" height="8" fill="red" mask="url(#fade)"/></svg>
  let present =
    #|<svg width="8" height="8"><defs><mask id="fade" mask-type="alpha" maskUnits="userSpaceOnUse"><rect width="4" height="8" fill="white"/></mask></defs><rect id="box" width="8" height="8" fill="red" mask="url(#fade)"/></svg>
  let profile = {
    ..ComparisonProfile::v1_default(),
    viewport_width: 8,
    viewport_height: 8,
  }
  for pair in [(missing, present), (present, missing)] {
    let report = compare(pair.0, pair.1, profile)
    assert_eq(report.analysis_status, "complete")
    guard mask_test_difference(report, "resource.mask.presence")
      is Some(difference) else {
      fail("expected mask resource presence difference")
    }
    assert_true(
      report.events.any(event => {
        event.atomic_difference_ids.contains(difference.id) &&
        event.rendered_outcome.magnitude.map(value => value.changed_pixels) ==
        Some(32)
      }),
    )
  }

  let unused_before = "<svg width='8' height='8'><rect id='box' width='2' height='2'/></svg>"
  let unused_after = "<svg width='8' height='8'><defs><mask id='fade'><rect width='4' height='4'/></mask></defs><rect id='box' width='2' height='2'/></svg>"
  let unused = compare(unused_before, unused_after, profile)
  assert_eq(unused.analysis_status, "complete")
  guard mask_test_difference(unused, "resource.mask.presence")
    is Some(unused_difference) else {
    fail("expected unused mask insertion")
  }
  assert_eq(unused_difference.computed_relation.status, "equivalent")
}

///|
test "non-admitted mask compositing interactions stay precise partial" {
  let cases = [
    (
      "<svg><defs><mask id='fade' mask-type='alpha'><rect width='8' height='8' fill='white'/></mask></defs><g mask='url(#fade)' opacity='0.5'><rect id='box' width='8' height='8'/></g></svg>",
      "mask_group_opacity_interaction_unsupported",
    ),
    (
      "<svg><defs><mask id='fade' mask-type='alpha' maskContentUnits='objectBoundingBox'><rect width='.5' height='1' fill='white'/></mask></defs><g mask='url(#fade)'><rect id='box' width='8' height='8'/></g></svg>",
      "mask_object_bbox_container_unsupported",
    ),
    (
      "<svg><defs><mask id='fade' mask-type='alpha'><rect width='8' height='8' fill='white'/></mask><rect id='shape' width='8' height='8'/></defs><use href='#shape' mask='url(#fade)'/></svg>",
      "mask_instance_unsupported",
    ),
    (
      "<svg><defs><mask id='fade' mask-type='luminance'><rect width='8' height='8' fill='red'/></mask></defs><rect id='left' width='4' height='8' mask='url(#fade)' mask-mode='alpha'/><rect id='right' x='4' width='4' height='8' mask='url(#fade)' mask-mode='luminance'/></svg>",
      "mask_shared_mode_override_unsupported",
    ),
  ]
  for entry in cases {
    let report = compare(entry.0, entry.0, ComparisonProfile::v1_default())
    if report.analysis_status != "partial" {
      fail("expected partial analysis for \{entry.1}")
    }
    if !report.diagnostics.any(diagnostic => {
        diagnostic.code == entry.1 && !diagnostic.source_locations.is_empty()
      }) {
      fail("expected located diagnostic \{entry.1}")
    }
  }
}
