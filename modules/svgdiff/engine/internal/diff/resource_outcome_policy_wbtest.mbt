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
fn resource_policy_has_located_diagnostic(
  report : StructuredReport,
  code : String,
) -> Bool {
  report.diagnostics.any(diagnostic => {
    diagnostic.code == code && !diagnostic.source_locations.is_empty()
  })
}

///|
fn resource_policy_difference(
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
test "resource policy admits deterministic missing and wrong-kind paint fallback" {
  let direct = "<svg><rect id='box' width='8' height='8' fill='red'/></svg>"
  for
    source in [
      "<svg><rect id='box' width='8' height='8' fill='url(#missing) red'/></svg>",
      "<svg><defs><g id='not-paint'/></defs><rect id='box' width='8' height='8' fill='url(#not-paint) red'/></svg>",
    ] {
    let report = compare(source, direct, ComparisonProfile::v1_default())
    assert_eq(report.analysis_status, "complete")
    guard resource_policy_difference(report, "paint.fill") is Some(difference) else {
      fail("expected source-visible paint fallback difference")
    }
    assert_eq(difference.computed_relation.status, "equivalent")
    assert_true(difference.evidence_layers.contains("source_semantics"))
  }
  let no_fallback = "<svg><rect id='box' width='8' height='8' fill='url(#missing)'/></svg>"
  assert_eq(
    compare(no_fallback, no_fallback, ComparisonProfile::v1_default()).analysis_status,
    "complete",
  )
}

///|
test "resource policy keeps unresolved non-paint consumers partial and located" {
  let cases = [
    ("<svg><use id='placed' href='#missing'/></svg>", "use_target_missing"),
    (
      "<svg><defs><linearGradient id='paint'/></defs><use id='placed' href='#paint'/></svg>",
      "use_target_kind_unsupported",
    ),
    (
      "<svg><image id='photo' href='asset.png' width='8' height='8'/></svg>", "resource_bundle_entry_missing",
    ),
    (
      "<svg><defs><linearGradient id='paint' href='other.svg#paint'/></defs><rect id='box' width='8' height='8' fill='url(#paint)'/></svg>",
      "gradient_external_reference_unsupported",
    ),
  ]
  for item in cases {
    let (source, code) = item
    let report = compare(source, source, ComparisonProfile::v1_default())
    assert_eq(report.analysis_status, "partial")
    assert_true(resource_policy_has_located_diagnostic(report, code))
  }
}

///|
test "resource policy separates invalid content from failed admission" {
  let source = "<svg><image id='photo' href='asset.png' width='8' height='8'/></svg>"
  let invalid_content : ResourceBundle = {
    entries: [
      {
        locator: "asset.png",
        media_type: "image/png",
        bytes: @base64.decode("AA=="[:]),
      },
    ],
  }
  let partial = compare_with_resources(
    source,
    source,
    ComparisonProfile::v1_default(),
    invalid_content,
    invalid_content,
  )
  assert_eq(partial.analysis_status, "partial")
  assert_true(
    resource_policy_has_located_diagnostic(
      partial, "embedded_raster_data_invalid",
    ),
  )
  let invalid_configuration : ResourceBundle = {
    entries: [
      {
        locator: "#reserved",
        media_type: "image/png",
        bytes: @base64.decode("AA=="[:]),
      },
    ],
  }
  let failed = compare_with_resources(
    source,
    source,
    ComparisonProfile::v1_default(),
    invalid_configuration,
    ResourceBundle::empty(),
  )
  assert_eq(failed.analysis_status, "failed")
  assert_true(
    failed.diagnostics.any(diagnostic => {
      diagnostic.code == "resource_bundle_invalid" &&
      diagnostic.source_locations.is_empty()
    }),
  )
  let malformed = compare("<svg>", "<svg/>", ComparisonProfile::v1_default())
  assert_eq(malformed.analysis_status, "failed")
  assert_true(
    malformed.diagnostics.any(diagnostic => {
      diagnostic.code == "svg_parse_failed"
    }),
  )
}

///|
test "resource policy rejects active and unused accepted local cycles" {
  let unused = "<svg><defs><linearGradient id='a' href='#b'/><linearGradient id='b' href='#a'/></defs></svg>"
  let active = "<svg><defs><linearGradient id='a' href='#b'/><linearGradient id='b' href='#a'/></defs><rect width='8' height='8' fill='url(#a)'/></svg>"
  for source in [unused, active] {
    let report = compare(source, source, ComparisonProfile::v1_default())
    assert_eq(report.analysis_status, "failed")
    assert_true(
      resource_policy_has_located_diagnostic(report, "reference_cycle_detected"),
    )
  }
}

///|
test "resource policy keeps unused definitions source-only and ignores unused bundle content" {
  let before = "<svg><defs><g id='latent' fill='red'><rect width='4' height='4'/></g></defs></svg>"
  let after = before.replace_all(old="fill='red'", new="fill='blue'")
  let definition_report = compare(
    before,
    after,
    ComparisonProfile::v1_default(),
  )
  assert_eq(definition_report.analysis_status, "complete")
  assert_eq(definition_report.atomic_differences.length(), 1)
  let difference = definition_report.atomic_differences[0]
  assert_eq(difference.subject_role, "resource")
  assert_eq(difference.evidence_layers, ["source_semantics"])
  assert_eq(difference.computed_relation.reason_code, "unused_definition")
  assert_true(
    definition_report.changed_facts.all(fact => {
      fact.affected_subject_ids.is_empty()
    }),
  )
  assert_true(definition_report.events.is_empty())

  let invalid_unused = "<svg><defs><linearGradient id='latent-paint' x2='bad'/></defs></svg>"
  let invalid_unused_report = compare(
    invalid_unused,
    invalid_unused,
    ComparisonProfile::v1_default(),
  )
  assert_eq(invalid_unused_report.analysis_status, "partial")
  assert_true(
    resource_policy_has_located_diagnostic(
      invalid_unused_report, "gradient_length_syntax_unsupported",
    ),
  )

  let invalid_bytes = @base64.decode("AA=="[:])
  let unused_bundle : ResourceBundle = {
    entries: [
      { locator: "unused.png", media_type: "image/png", bytes: invalid_bytes },
    ],
  }
  let visible = "<svg><rect id='box' width='8' height='8' fill='red'/></svg>"
  let bundle_report = compare_with_resources(
    visible,
    visible,
    ComparisonProfile::v1_default(),
    unused_bundle,
    ResourceBundle::empty(),
  )
  assert_eq(bundle_report.analysis_status, "complete")
  assert_true(bundle_report.atomic_differences.is_empty())
  assert_true(
    bundle_report.diagnostics.all(diagnostic => {
      diagnostic.code != "embedded_raster_data_invalid"
    }),
  )
  let invalid_unused_bundle : ResourceBundle = {
    entries: [
      { locator: "unused.png", media_type: "image/gif", bytes: invalid_bytes },
    ],
  }
  assert_eq(
    compare_with_resources(
      visible,
      visible,
      ComparisonProfile::v1_default(),
      invalid_unused_bundle,
      ResourceBundle::empty(),
    ).analysis_status,
    "failed",
  )
}
