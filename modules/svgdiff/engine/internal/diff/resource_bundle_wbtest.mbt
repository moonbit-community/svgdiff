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
fn test_raster_bundle(
  locator : String,
  media_type : String,
  payload : String,
) -> ResourceBundle raise {
  { entries: [{ locator, media_type, bytes: @base64.decode(payload[:]) }] }
}

///|
test "separate bundles can replace pixels behind one opaque locator" {
  let svg = embedded_image_svg(
    "assets/photo.png",
    attributes="width='8' height='8'",
  )
  let report = compare_with_resources(
    svg,
    svg,
    ComparisonProfile::v1_default(),
    test_raster_bundle("assets/photo.png", "image/png", embedded_red_png_base64),
    test_raster_bundle(
      "assets/photo.png", "IMAGE/PNG", embedded_blue_png_base64,
    ),
  )
  guard difference_in_domain(report, "resource.image.content") is Some(content) else {
    fail("expected caller-supplied raster content difference")
  }
  assert_eq(content.computed_relation.status, "different")
  assert_true(content.magnitude.intrinsic_raster is Some(_))
  assert_true(
    !report.diagnostics.any(diagnostic => {
      diagnostic.code == "resource_bundle_entry_missing"
    }),
  )
  assert_true(
    report.to_compact_json_string().find(embedded_red_png_base64) is None,
  )
  assert_eq(
    compare_with_resources(
      svg,
      svg,
      ComparisonProfile::v1_default(),
      test_raster_bundle(
        "assets/photo.png", "image/png", embedded_red_png_base64,
      ),
      test_raster_bundle(
        "assets/photo.png", "image/png", embedded_blue_png_base64,
      ),
    ).to_compact_json_string(),
    report.to_compact_json_string(),
  )
}

///|
test "bundle bytes can be visually equivalent to a data URL" {
  let before = embedded_image_svg("asset.png")
  let after = embedded_image_svg(embedded_png_url(embedded_red_png_base64))
  let report = compare_with_resources(
    before,
    after,
    ComparisonProfile::v1_default(),
    test_raster_bundle("asset.png", "image/png", embedded_red_png_base64),
    ResourceBundle::empty(),
  )
  guard difference_in_domain(report, "resource.image.source") is Some(source) else {
    fail("expected source locator difference")
  }
  assert_eq(source.computed_relation.status, "equivalent")
  assert_true(difference_in_domain(report, "resource.image.content") is None)
  let jpeg = compare_with_resources(
    embedded_image_svg("asset.jpg"),
    embedded_image_svg("data:image/jpeg;base64,\{embedded_red_jpeg_base64}"),
    ComparisonProfile::v1_default(),
    test_raster_bundle("asset.jpg", "image/jpeg", embedded_red_jpeg_base64),
    ResourceBundle::empty(),
  )
  guard difference_in_domain(jpeg, "resource.image.source") is Some(jpeg_source) else {
    fail("expected JPEG locator difference")
  }
  assert_eq(jpeg_source.computed_relation.status, "equivalent")
  assert_true(difference_in_domain(jpeg, "resource.image.content") is None)
}

///|
test "bundle raster color metadata uses the same precise diagnostics" {
  let svg = embedded_image_svg("asset.png", attributes="width='8' height='8'")
  let report = compare_with_resources(
    svg,
    svg,
    ComparisonProfile::v1_default(),
    test_raster_bundle("asset.png", "image/png", embedded_icc_png_base64),
    test_raster_bundle("asset.png", "image/png", embedded_hdr_png_base64),
  )
  for
    code in [
      "embedded_raster_color_profile_unsupported", "embedded_raster_hdr_unsupported",
    ] {
    assert_true(
      report.diagnostics.any(diagnostic => {
        diagnostic.code == code && !diagnostic.source_locations.is_empty()
      }),
    )
  }
  guard difference_in_domain(report, "resource.image.source") is Some(source) else {
    fail("expected profile-bearing bundle difference")
  }
  assert_true(source.source_before.find("bundle:image/png") is Some(_))
  assert_true(source.source_after.find("bundle:image/png") is Some(_))
}

///|
test "bundle locator matching is exact after outer SVG whitespace" {
  let svg = embedded_image_svg(" asset.png ")
  let resolved = compare_with_resources(
    svg,
    svg,
    ComparisonProfile::v1_default(),
    test_raster_bundle("asset.png", "image/png", embedded_red_png_base64),
    test_raster_bundle("asset.png", "image/png", embedded_red_png_base64),
  )
  assert_true(
    !resolved.diagnostics.any(diagnostic => {
      diagnostic.code == "resource_bundle_entry_missing"
    }),
  )
  let distinct = compare_with_resources(
    embedded_image_svg("ASSET.png"),
    embedded_image_svg("ASSET.png"),
    ComparisonProfile::v1_default(),
    test_raster_bundle("asset.png", "image/png", embedded_red_png_base64),
    test_raster_bundle("asset.png", "image/png", embedded_red_png_base64),
  )
  assert_true(
    distinct.diagnostics.any(diagnostic => {
      diagnostic.code == "resource_bundle_entry_missing" &&
      !diagnostic.source_locations.is_empty()
    }),
  )
}

///|
test "invalid bundle configuration fails before source comparison" {
  let bytes = @base64.decode(embedded_red_png_base64[:])
  let duplicate : ResourceBundle = {
    entries: [
      { locator: "asset.png", media_type: "image/png", bytes },
      { locator: " asset.png ", media_type: "image/png", bytes },
    ],
  }
  let report = compare_with_resources(
    embedded_image_svg("asset.png"),
    embedded_image_svg("asset.png"),
    ComparisonProfile::v1_default(),
    duplicate,
    ResourceBundle::empty(),
  )
  assert_eq(report.analysis_status, "failed")
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "resource_bundle_invalid" &&
      diagnostic.subject_id == "bundle.before.entry.1.duplicate_locator"
    }),
  )
  for locator in ["", "#local", "data:image/png;base64,x"] {
    assert_true(
      validate_resource_bundle(
        { entries: [{ locator, media_type: "image/png", bytes }] },
        "before",
        default_resource_limits(),
      )
      is Some(_),
    )
  }
  assert_true(
    validate_resource_bundle(
      { entries: [{ locator: "asset", media_type: "image/gif", bytes }] },
      "before",
      default_resource_limits(),
    )
    is Some(_),
  )
}

///|
test "bundle admission budgets have exact boundaries" {
  let bytes = @base64.decode(embedded_red_png_base64[:])
  let bundle : ResourceBundle = {
    entries: [{ locator: "asset.png", media_type: "image/png", bytes }],
  }
  let exact = {
    ..default_resource_limits(),
    max_resource_bundle_entries: 1,
    max_resource_bundle_entry_bytes: bytes.length(),
    max_resource_bundle_bytes: bytes.length(),
  }
  assert_true(validate_resource_bundle(bundle, "before", exact) is None)
  assert_true(
    validate_resource_bundle(bundle, "before", {
      ..exact,
      max_resource_bundle_entries: 0,
    })
    is Some(_),
  )
  assert_true(
    validate_resource_bundle(bundle, "before", {
      ..exact,
      max_resource_bundle_entry_bytes: bytes.length() - 1,
    })
    is Some(_),
  )
  assert_true(
    validate_resource_bundle(bundle, "before", {
      ..exact,
      max_resource_bundle_bytes: bytes.length() - 1,
    })
    is Some(_),
  )
}

///|
test "bundled rasters share decoder dimension and cumulative pixel limits" {
  let bundle = test_raster_bundle(
    "asset.png", "image/png", embedded_red_png_base64,
  )
  let bytes = bundle.entries[0].bytes.length()
  assert_true(
    decode_embedded_raster("asset.png", bundle, 0, 0, bytes, 0, 1)
    is EmbeddedRasterLimitExceeded("embedded_raster_dimension"),
  )
  let svg = embedded_image_svg("asset.png")
  assert_true(
    embedded_raster_source_limit(svg, "before", bundle, {
      ..default_resource_limits(),
      max_embedded_raster_pixels: 0,
    })
    is Some(_),
  )
}

///|
test "controlled bundle comparison observes cancellation" {
  let svg = embedded_image_svg("asset.png")
  let bundle = test_raster_bundle(
    "asset.png", "image/png", embedded_red_png_base64,
  )
  try
    compare_with_control_and_resources(
      svg,
      svg,
      ComparisonProfile::v1_default(),
      bundle,
      bundle,
      { should_cancel: () => true, max_checkpoints: None },
    )
  catch {
    Cancelled => ()
    _ => fail("expected cancellation")
  } noraise {
    _ => fail("expected controlled comparison to raise")
  }
}
