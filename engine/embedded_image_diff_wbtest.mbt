///|
let embedded_red_png_base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg=="

///|
let embedded_blue_png_base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYPj/HwADAgH/5ncLrgAAAABJRU5ErkJggg=="

///|
let embedded_red_jpeg_base64 = "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAIBAQEBAQIBAQECAgICAgQDAgICAgUEBAMEBgUGBgYFBgYGBwkIBgcJBwYGCAsICQoKCgoKBggLDAsKDAkKCgr/2wBDAQICAgICAgUDAwUKBwYHCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgr/wAARCAABAAEDAREAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD4vr+Uz/fw/9k="

///|
let embedded_indexed_transparency_png_base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAMAAAAoyzS7AAAAA1BMVEX/AAAZ4gk3AAAAAXRSTlMAQObYZgAAAApJREFUeJxjYAAAAAIAAUivpHEAAAAASUVORK5CYII="

///|
let embedded_red_png_percent = "%89PNG%0D%0A%1A%0A%00%00%00%0DIHDR%00%00%00%01%00%00%00%01%08%06%00%00%00%1F%15%C4%89%00%00%00%0DIDATx%9Cc%F8%CF%C0%F0%1F%00%05%00%01%FF%89%99=%1D%00%00%00%00IEND%AEB`%82"

///|
fn embedded_image_svg(href : String, attributes? : String = "") -> String {
  "<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16'><image id='photo' \{attributes} href='\{href}'/></svg>"
}

///|
fn embedded_png_url(payload : String) -> String {
  "data:image/png;base64,\{payload}"
}

///|
fn embedded_test_percent_encode(bytes : Bytes) -> String {
  let hex = "0123456789ABCDEF"
  let output = StringBuilder::new()
  for byte in bytes {
    let value = byte.to_int()
    output.write_string(
      "%\{hex[value >> 4].to_int().unsafe_to_char()}\{hex[value & 15].to_int().unsafe_to_char()}",
    )
  }
  output.to_string()
}

///|
fn difference_in_domain(
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
fn embedded_image_event(report : StructuredReport) -> VisualEvent? {
  for event in report.events {
    if event.primary_subject_id.has_prefix("alignment:image:") {
      return Some(event)
    }
  }
  None
}

///|
test "equivalent embedded PNG encodings remain a source-only difference" {
  let before = embedded_image_svg(embedded_png_url(embedded_red_png_base64))
  let after = embedded_image_svg("data:image/png,\{embedded_red_png_percent}")
  let report = compare(before, after, ComparisonProfile::v1_default())
  guard difference_in_domain(report, "resource.image.source") is Some(source) else {
    fail("expected an embedded image source difference")
  }
  assert_eq(source.computed_relation.status, "equivalent")
  assert_true(difference_in_domain(report, "resource.image.content") is None)
  assert_true(
    report.renderer_capability_gaps.any(gap => {
      gap.capability_id == "raster.embedded_images" &&
      gap.support_status == "unavailable"
    }),
  )
  assert_true(
    report.to_compact_json_string().find(embedded_red_png_base64) is None,
  )
}

///|
test "decoded embedded PNG content reports intrinsic pixel magnitude" {
  let before = embedded_image_svg(embedded_png_url(embedded_red_png_base64))
  let after = embedded_image_svg(embedded_png_url(embedded_blue_png_base64))
  let report = compare(before, after, ComparisonProfile::v1_default())
  guard difference_in_domain(report, "resource.image.content") is Some(content) else {
    fail("expected decoded image content difference")
  }
  assert_eq(content.computed_relation.status, "different")
  guard content.magnitude.intrinsic_raster is Some(magnitude) else {
    fail("expected intrinsic raster magnitude")
  }
  assert_eq(magnitude.compared_pixels, Some(1))
  assert_eq(magnitude.changed_pixels, Some(1))
  assert_eq(magnitude.changed_pixel_fraction, Some(1.0))
  assert_true(magnitude.rgba8_rmse.unwrap() > 0.7)
  assert_true(magnitude.linear_premultiplied_rgba_rmse.unwrap() > 0.7)
  guard embedded_image_event(report) is Some(event) else {
    fail("expected embedded image event")
  }
  assert_eq(event.rendered_outcome.status, "not_computed")
  assert_eq(
    event.rendered_outcome.reason_code,
    Some("renderer_embedded_raster_unavailable"),
  )
  assert_eq(event.difference_regions.length(), 1)
}

///|
test "JPEG base64 and percent forms decode to the same intrinsic pixels" {
  let decoded = @base64.decode(embedded_red_jpeg_base64[:])
  let before = embedded_image_svg(
    "data:image/jpeg;base64,\{embedded_red_jpeg_base64}",
  )
  let after = embedded_image_svg(
    "data:image/jpeg,\{embedded_test_percent_encode(decoded)}",
  )
  let report = compare(before, after, ComparisonProfile::v1_default())
  guard difference_in_domain(report, "resource.image.source") is Some(source) else {
    fail("expected distinct JPEG source encodings")
  }
  assert_eq(source.computed_relation.status, "equivalent")
  assert_true(difference_in_domain(report, "resource.image.content") is None)
}

///|
test "small embedded image placement delta remains numeric" {
  let href = embedded_png_url(embedded_red_png_base64)
  let before = embedded_image_svg(
    href,
    attributes="x='1.0' width='8' height='8'",
  )
  let after = embedded_image_svg(
    href,
    attributes="x='0.99999' width='8' height='8'",
  )
  let report = compare(before, after, ComparisonProfile::v1_default())
  guard difference_in_domain(report, "geometry.position") is Some(position) else {
    fail("expected numeric image placement difference")
  }
  assert_eq(position.computed_relation.status, "different")
  assert_true(position.magnitude.parameter_abs_user_units.unwrap() < 0.00002)
  assert_true(position.magnitude.parameter_abs_user_units.unwrap() > 0.0)
}

///|
test "invalid and external embedded image sources are explicit" {
  let invalid = compare(
    embedded_image_svg("data:image/png;base64,not-base64"),
    embedded_image_svg("data:image/png;base64,not-base64"),
    ComparisonProfile::v1_default(),
  )
  assert_true(
    invalid.diagnostics.any(diagnostic => {
      diagnostic.code == "embedded_raster_data_invalid"
    }),
  )
  let external = compare(
    embedded_image_svg("photo.png"),
    embedded_image_svg("photo.png"),
    ComparisonProfile::v1_default(),
  )
  assert_true(
    external.diagnostics.any(diagnostic => {
      diagnostic.code == "external_raster_resource_unsupported"
    }),
  )
  let signature = compare(
    embedded_image_svg("data:image/jpeg;base64,\{embedded_red_png_base64}"),
    embedded_image_svg("data:image/jpeg;base64,\{embedded_red_png_base64}"),
    ComparisonProfile::v1_default(),
  )
  assert_true(
    signature.diagnostics.any(diagnostic => {
      diagnostic.code == "embedded_raster_data_invalid"
    }),
  )
  let unsupported = compare(
    embedded_image_svg(
      "data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==",
    ),
    embedded_image_svg(
      "data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==",
    ),
    ComparisonProfile::v1_default(),
  )
  assert_true(
    unsupported.diagnostics.any(diagnostic => {
      diagnostic.code == "embedded_raster_media_type_unsupported"
    }),
  )
  let decompression = compare(
    embedded_image_svg(
      "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADElEQVR4nGOIoAMAAMivImE71Vn5AAAAAElFTkSuQmCC",
    ),
    embedded_image_svg(
      "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADElEQVR4nGOIoAMAAMivImE71Vn5AAAAAElFTkSuQmCC",
    ),
    ComparisonProfile::v1_default(),
  )
  assert_true(
    decompression.diagnostics.any(diagnostic => {
      diagnostic.code == "embedded_raster_data_invalid"
    }),
  )
  let variant = compare(
    embedded_image_svg(
      "data:image/png;base64,\{embedded_indexed_transparency_png_base64}",
    ),
    embedded_image_svg(
      "data:image/png;base64,\{embedded_indexed_transparency_png_base64}",
    ),
    ComparisonProfile::v1_default(),
  )
  assert_true(
    variant.diagnostics.any(diagnostic => {
      diagnostic.code == "embedded_raster_variant_unsupported"
    }),
  )
  let non_progressing_jpeg = compare(
    embedded_image_svg("data:image/jpeg;base64,/9j/4AAA"),
    embedded_image_svg("data:image/jpeg;base64,/9j/4AAA"),
    ComparisonProfile::v1_default(),
  )
  assert_true(
    non_progressing_jpeg.diagnostics.any(diagnostic => {
      diagnostic.code == "embedded_raster_data_invalid"
    }),
  )
}

///|
test "embedded image identity, insertion, and deletion are deterministic" {
  let href = embedded_png_url(embedded_red_png_base64)
  let empty = "<svg xmlns='http://www.w3.org/2000/svg'/>"
  let image = embedded_image_svg(href)
  let insertion = compare(empty, image, ComparisonProfile::v1_default())
  guard difference_in_domain(insertion, "presence.insertion") is Some(added) else {
    fail("expected embedded image insertion")
  }
  assert_eq(added.subject_alignment_id, Some("alignment:image:0"))
  assert_true(
    !insertion.diagnostics.any(diagnostic => {
      diagnostic.code == "analysis_coverage_unproven"
    }),
  )
  let deletion = compare(image, empty, ComparisonProfile::v1_default())
  guard difference_in_domain(deletion, "presence.deletion") is Some(removed) else {
    fail("expected embedded image deletion")
  }
  assert_eq(removed.subject_alignment_id, Some("alignment:image:0"))
  assert_true(
    !deletion.diagnostics.any(diagnostic => {
      diagnostic.code == "analysis_coverage_unproven"
    }),
  )
  assert_eq(
    compare(empty, image, ComparisonProfile::v1_default()).to_compact_json_string(),
    insertion.to_compact_json_string(),
  )
}

///|
test "embedded image gaps downgrade rendered outcomes in mixed scenes" {
  let before = "<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16'><rect id='box' width='8' height='8' fill='red'/><image id='photo' x='8' width='8' height='8' href='\{embedded_png_url(embedded_red_png_base64)}'/></svg>"
  let after = "<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16'><rect id='box' width='8' height='8' fill='blue'/><image id='photo' x='8' width='8' height='8' href='\{embedded_png_url(embedded_red_png_base64)}'/></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_true(report.events.length() > 0)
  assert_true(
    report.events.all(event => {
      event.rendered_outcome.status == "not_computed" &&
      event.rendered_outcome.reason_code ==
      Some("renderer_embedded_raster_unavailable")
    }),
  )
}

///|
test "unsupported embedded image placement and instances remain explicit" {
  let href = embedded_png_url(embedded_red_png_base64)
  let invalid_placement = compare(
    embedded_image_svg(href, attributes="width='bad'"),
    embedded_image_svg(href, attributes="width='bad'"),
    ComparisonProfile::v1_default(),
  )
  assert_true(
    invalid_placement.diagnostics.any(diagnostic => {
      diagnostic.code == "embedded_image_placement_unsupported"
    }),
  )
  let deferred = "<svg xmlns='http://www.w3.org/2000/svg'><defs><image id='photo' href='\{href}'/></defs></svg>"
  let instance = compare(deferred, deferred, ComparisonProfile::v1_default())
  assert_true(
    instance.diagnostics.any(diagnostic => {
      diagnostic.code == "embedded_image_instance_resolution_unsupported"
    }),
  )
}

///|
test "embedded raster admission enforces decoded byte limit" {
  let svg = embedded_image_svg(embedded_png_url(embedded_red_png_base64))
  let limits = { ..default_resource_limits(), max_embedded_data_bytes: 8 }
  let report = compare_with_resource_limits(
    svg,
    svg,
    ComparisonProfile::v1_default(),
    limits,
  )
  assert_eq(report.analysis_status, "failed")
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.subject_id == "embedded_raster_data_bytes.before"
    }),
  )
}

///|
test "embedded raster resource boundaries are exact and cumulative" {
  let href = embedded_png_url(embedded_red_png_base64)
  let svg = embedded_image_svg(href)
  guard parse_embedded_raster_data_url(href)
    is EmbeddedRasterDataUrlAccepted(data) else {
    fail("fixture data URL must decode")
  }
  let exact = {
    ..default_resource_limits(),
    max_embedded_data_uri_bytes: href.length(),
    max_embedded_data_bytes: data.bytes.length(),
    max_embedded_raster_pixels: 1,
    max_embedded_raster_dimension: 1,
  }
  assert_not_resource_failure(
    compare_with_resource_limits(
      svg,
      svg,
      ComparisonProfile::v1_default(),
      exact,
    ),
  )
  assert_true(
    has_resource_limit(
      compare_with_resource_limits(svg, svg, ComparisonProfile::v1_default(), {
        ..exact,
        max_embedded_data_uri_bytes: href.length() - 1,
      }),
      "embedded_raster_data_uri_bytes.before",
    ),
  )
  let spaced = embedded_image_svg("  \{href}  ")
  assert_true(
    has_resource_limit(
      compare_with_resource_limits(
        spaced,
        spaced,
        ComparisonProfile::v1_default(),
        { ..exact, max_embedded_data_uri_bytes: href.length() - 1 },
      ),
      "embedded_raster_data_uri_bytes.before",
    ),
  )
  assert_true(
    has_resource_limit(
      compare_with_resource_limits(svg, svg, ComparisonProfile::v1_default(), {
        ..exact,
        max_embedded_data_bytes: data.bytes.length() - 1,
      }),
      "embedded_raster_data_bytes.before",
    ),
  )
  assert_true(
    has_resource_limit(
      compare_with_resource_limits(svg, svg, ComparisonProfile::v1_default(), {
        ..exact,
        max_embedded_raster_dimension: 0,
      }),
      "embedded_raster_dimension.before",
    ),
  )
  let two = "<svg xmlns='http://www.w3.org/2000/svg'><image href='\{href}'/><image href='\{href}'/></svg>"
  assert_not_resource_failure(
    compare_with_resource_limits(two, two, ComparisonProfile::v1_default(), {
      ..exact,
      max_embedded_raster_pixels: 2,
    }),
  )
  assert_true(
    has_resource_limit(
      compare_with_resource_limits(
        two,
        two,
        ComparisonProfile::v1_default(),
        exact,
      ),
      "embedded_raster_pixels.before",
    ),
  )
}
