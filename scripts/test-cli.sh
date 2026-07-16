#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/svgdiff-cli-$$
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

assert_status() {
  expected=$1
  shift
  set +e
  "$@"
  actual=$?
  set -e
  if [ "$actual" -ne "$expected" ]; then
    echo "Expected exit status $expected, got $actual: $*" >&2
    exit 1
  fi
}

cd "$root"
moon run --target native cmd/svgdiff -- testdata/before.svg testdata/after.svg >"$tmp/report.json" 2>"$tmp/report.err"
test ! -s "$tmp/report.err"
jq -e '.schema_version == "1.42" and .profile.perceptual_background == null and .profile.flip_viewing_conditions == null and .profile.flip_error_threshold == null and .profile.renderer_conformance_profile_id == "svgdiff-renderer-conformance-profile/25" and .analysis_status == "complete" and (.coverage_matrix | length) > 0 and .renderer_capability_gaps == [] and (all(.coverage_matrix[]; (.source_semantics != "limited" and .computed_appearance != "limited" and .rendered_evidence != "limited"))) and (.atomic_differences | length) == 1 and all(.events[]; .rendered_outcome.perceptual_color == {"status":"not_computed","reason_code":"perceptual_background_absent"} and .rendered_outcome.perceptual_flip == {"status":"not_computed","reason_code":"flip_not_requested"})' "$tmp/report.json" >/dev/null

moon run --target native cmd/svgdiff -- testdata/before.svg testdata/after.svg --agent-json >"$tmp/agent.json" 2>"$tmp/agent.err"
test ! -s "$tmp/agent.err"
test "$(wc -l <"$tmp/agent.json" | tr -d ' ')" -eq 1
jq -e '.schema_version == "1.42" and .profile.perceptual_background == null and .profile.flip_error_threshold == null and .profile.renderer_conformance_profile_id == "svgdiff-renderer-conformance-profile/25" and .analysis_status == "complete" and (.atomic_differences | length) == 1' "$tmp/agent.json" >/dev/null
test "$(wc -c <"$tmp/agent.json")" -lt "$(wc -c <"$tmp/report.json")"
test "$(jq -S -c . "$tmp/agent.json")" = "$(jq -S -c . "$tmp/report.json")"

moon run --target native cmd/svgdiff -- \
  testdata/before.svg testdata/after.svg \
  --perceptual-background '#336699' >"$tmp/background.json" 2>"$tmp/background.err"
test ! -s "$tmp/background.err"
moon run --target native cmd/svgdiff -- \
  testdata/before.svg testdata/after.svg \
  --perceptual-background '#336699' --agent-json \
  >"$tmp/background-agent.json" 2>"$tmp/background-agent.err"
test ! -s "$tmp/background-agent.err"
jq -e '.profile.perceptual_background == {"red": 51, "green": 102, "blue": 153} and .profile.flip_viewing_conditions == null and all(.events[]; .rendered_outcome.perceptual_color.status == "computed" and .rendered_outcome.perceptual_color.magnitude.method_id == "delta_e_ok_changed_pixels_after_linear_srgb_background/v1" and .rendered_outcome.perceptual_color.magnitude.sample_count > 0 and .rendered_outcome.perceptual_color.magnitude.mean_delta_e_ok > 0 and .rendered_outcome.perceptual_flip == {"status":"not_computed","reason_code":"flip_not_requested"})' "$tmp/background.json" >/dev/null
test "$(jq -S -c . "$tmp/background-agent.json")" = "$(jq -S -c . "$tmp/background.json")"
test "$(jq -S -c 'del(.profile.perceptual_background) | del(.events[].rendered_outcome.perceptual_color)' "$tmp/background.json")" = "$(jq -S -c 'del(.profile.perceptual_background) | del(.events[].rendered_outcome.perceptual_color)' "$tmp/report.json")"

moon run --target native cmd/svgdiff -- \
  testdata/before.svg testdata/after.svg \
  --perceptual-background '#336699' --flip-pixels-per-degree 20 \
  --flip-error-threshold 0.05 \
  >"$tmp/flip.json" 2>"$tmp/flip.err"
test ! -s "$tmp/flip.err"
jq -e '
  .profile.flip_viewing_conditions == {"pixels_per_degree": 20} and
  .profile.flip_error_threshold == {"value": 0.05} and
  all(.events[];
    .rendered_outcome.perceptual_flip.status == "computed" and
    .rendered_outcome.perceptual_flip.map.method_id ==
      "nvlabs_ldr_flip/v1.7-b475eb4b" and
    .rendered_outcome.perceptual_flip.map.encoding == "uint16_be_base64" and
    .rendered_outcome.perceptual_flip.map.quantization_step ==
      0.000015259021896696422 and
    (.rendered_outcome.perceptual_flip.map.values_base64 | length) > 0 and
    .rendered_outcome.perceptual_flip.statistics.method_id ==
      "event_local_ldr_flip_pooling/v1" and
    .rendered_outcome.perceptual_flip.statistics.canvas_pixel_count == 256 and
    .rendered_outcome.perceptual_flip.statistics.event_region_sample_count > 0 and
    .rendered_outcome.perceptual_flip.statistics.response_sample_count > 0 and
    .rendered_outcome.perceptual_flip.statistics.canvas_mean > 0 and
    .rendered_outcome.perceptual_flip.statistics.event_region_mean > 0 and
    .rendered_outcome.perceptual_flip.statistics.response_p95 >= 0 and
    .rendered_outcome.perceptual_flip.statistics.response_maximum >=
      .rendered_outcome.perceptual_flip.statistics.response_p95 and
    .rendered_outcome.perceptual_flip.statistics.area_above_threshold.threshold == 0.05 and
    .rendered_outcome.perceptual_flip.statistics.area_above_threshold.pixel_count > 0 and
    .rendered_outcome.perceptual_flip.statistics.area_above_threshold.canvas_fraction > 0)
' "$tmp/flip.json" >/dev/null
test "$(jq -S -c '.profile.flip_viewing_conditions = null | .profile.flip_error_threshold = null | .events[].rendered_outcome.perceptual_flip = {"status":"not_computed","reason_code":"flip_not_requested"}' "$tmp/flip.json")" = "$(jq -S -c . "$tmp/background.json")"

moon run --target native cmd/svgdiff -- testdata/before.svg testdata/after.svg --width 32 --height 24 --output "$tmp/output.json" --html "$tmp/report.html" >"$tmp/output.stdout" 2>"$tmp/output.err"
test ! -s "$tmp/output.stdout"
test ! -s "$tmp/output.err"
jq -e '.profile.viewport_width == 32 and .profile.viewport_height == 24 and .profile.comparison_dpr == 1 and .profile.color_interpretation == "srgb" and .profile.raster_representation == "linear_srgb_premultiplied_rgba_f64" and .profile.renderer_conformance_profile_id == "svgdiff-renderer-conformance-profile/25" and (.events[0].rendered_outcome.magnitude.linear_premultiplied_rgba_rmse > 0)' "$tmp/output.json" >/dev/null
grep -q '<!doctype html>' "$tmp/report.html"
grep -q 'sandbox=""' "$tmp/report.html"
grep -q 'id="report-data"' "$tmp/report.html"
jq empty schema/svgdiff-report.schema.json
jq -e '
  .properties.profile.properties.renderer_conformance_profile_id ==
    {"type": "string", "minLength": 1} and
  .properties.profile.properties.renderer_id ==
    {"type": "string", "minLength": 1} and
  (.properties.profile.required | index("renderer_conformance_profile_id") == null)
' schema/svgdiff-report.schema.json >/dev/null
jq -e '
  (.properties.events.items."$ref" == "#/$defs/visualEvent") and
  (.["$defs"].visualEvent.properties.rendered_outcome.required |
    index("perceptual_color") != null and index("perceptual_flip") != null) and
  (.["$defs"].perceptualColorMagnitude.properties.method_id.const ==
    "delta_e_ok_changed_pixels_after_linear_srgb_background/v1") and
  (.["$defs"].perceptualFlipMap.properties.method_id.const ==
    "nvlabs_ldr_flip/v1.7-b475eb4b")
' schema/svgdiff-report.schema.json >/dev/null
jq -e '
  (.properties.profile.required | index("perceptual_background") != null) and
  (.properties.profile.required | index("flip_viewing_conditions") != null) and
  (.properties.profile.properties.perceptual_background."$ref" ==
    "#/$defs/nullablePerceptualBackground") and
  (.["$defs"].perceptualBackground.required == ["red", "green", "blue"]) and
  (.["$defs"].perceptualBackground.properties.red ==
    {"type": "integer", "minimum": 0, "maximum": 255})
' schema/svgdiff-report.schema.json >/dev/null
jq -e '
  (.properties.renderer_capability_gaps.items."$ref" ==
    "#/$defs/rendererCapabilityGap") and
  (.required | index("renderer_capability_gaps") == null)
' schema/svgdiff-report.schema.json >/dev/null
jq -e '
  (."$defs".diagnostic.properties.source_locations.items."$ref" ==
    "#/$defs/diagnosticSourceLocation") and
  (."$defs".diagnostic.required | index("source_locations") == null) and
  (."$defs".diagnosticSourceLocation.properties.source_role.enum ==
    ["before", "after"])
' schema/svgdiff-report.schema.json >/dev/null

printf '%s\n' "<svg width='16' height='16'><rect id='box' width='8' height='8' fill='red' stroke='red' style='fill:blue;stroke:blue;unknown:value'/></svg>" >"$tmp/renderer-gap.svg"
moon run --target native cmd/svgdiff -- \
  "$tmp/renderer-gap.svg" "$tmp/renderer-gap.svg" --agent-json \
  >"$tmp/renderer-gap.json"
jq -e '
  .analysis_status == "partial" and
  any(.renderer_capability_gaps[];
    .capability_id == "css.inline_style_precedence" and
    .support_status == "guarded" and
    .diagnostic_ids == [
      "diagnostic:renderer-style-precedence-unresolved:box:fill",
      "diagnostic:renderer-style-precedence-unresolved:box:stroke"
    ]
  )
' "$tmp/renderer-gap.json" >/dev/null

cat testdata/before.svg | moon run --target native cmd/svgdiff -- - testdata/after.svg >"$tmp/stdin-before.json" 2>"$tmp/stdin-before.err"
test ! -s "$tmp/stdin-before.err"
jq -e '.schema_version == "1.42" and .analysis_status == "complete"' "$tmp/stdin-before.json" >/dev/null

cat testdata/after.svg | moon run --target native cmd/svgdiff -- testdata/before.svg - >"$tmp/stdin-after.json" 2>"$tmp/stdin-after.err"
test ! -s "$tmp/stdin-after.err"
jq -e '.schema_version == "1.42" and .analysis_status == "complete"' "$tmp/stdin-after.json" >/dev/null

printf '%s\n' "<svg xmlns='http://www.w3.org/2000/svg'><image id='photo' width='8' height='8' href='asset.png'/></svg>" >"$tmp/bundle.svg"
printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==' | base64 -d >"$tmp/red.png"
printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYPj/HwADAgH/5ncLrgAAAABJRU5ErkJggg==' | base64 -d >"$tmp/blue.png"
moon run --target native cmd/svgdiff -- \
  "$tmp/bundle.svg" "$tmp/bundle.svg" \
  --before-resource asset.png image/png "$tmp/red.png" \
  --after-resource asset.png image/png "$tmp/blue.png" \
  --agent-json >"$tmp/bundle.json" 2>"$tmp/bundle.err"
test ! -s "$tmp/bundle.err"
jq -e '
  .analysis_status == "partial" and
  any(.atomic_differences[]; .domain == "resource.image.content") and
  any(.diagnostics[]; .code == "renderer_embedded_raster_unavailable") and
  all(.diagnostics[]; .code != "resource_bundle_entry_missing")
' "$tmp/bundle.json" >/dev/null
! grep -q 'iVBORw0KGgo' "$tmp/bundle.json"

assert_status 0 moon run --target native cmd/svgdiff -- \
  evaluation/corpus/cases/unsupported-path-change/before.svg \
  evaluation/corpus/cases/unsupported-path-change/after.svg \
  --output "$tmp/partial.json"
jq -e '.analysis_status == "partial" and (.diagnostics | length) > 0' "$tmp/partial.json" >/dev/null
jq -e '
  any(.renderer_capability_gaps[];
    .capability_id == "raster.stroke_outline" and
    .support_status == "guarded"
  ) and
  all(.renderer_capability_gaps[];
    .capability_id != "analysis.unsupported_visual_subject"
  )
' "$tmp/partial.json" >/dev/null
jq -e 'any(.coverage_matrix[]; .computed_appearance == "limited" or .rendered_evidence == "limited")' "$tmp/partial.json" >/dev/null
jq -e '
  any(.diagnostics[];
    .code == "unsupported_visual_subject" and
    [.source_locations[].source_role] == ["before", "after"] and
    all(.source_locations[];
      .source_span.start_offset >= 0 and
      .source_span.end_offset > .source_span.start_offset
    )
  )
' "$tmp/partial.json" >/dev/null

moon run --target native cmd/svgdiff -- --help >"$tmp/help.txt"
grep -q '^Usage: svgdiff ' "$tmp/help.txt"
grep -q -- '--version' "$tmp/help.txt"
grep -q -- '--perceptual-background COLOR' "$tmp/help.txt"
grep -q -- '--flip-pixels-per-degree PPD' "$tmp/help.txt"
grep -q -- '--flip-error-threshold VALUE' "$tmp/help.txt"
grep -q 'Invalid arguments or file I/O failure' "$tmp/help.txt"

moon run --target native cmd/svgdiff -- --version >"$tmp/version.txt"
grep -q '^svgdiff 0.5.22$' "$tmp/version.txt"
grep -q '^engine: 0.5.22$' "$tmp/version.txt"
grep -q '^schema: 1.42$' "$tmp/version.txt"
grep -q '^renderer: svgdiff/style-precedence-normalizer@3+ordinary-inheritance-normalizer@1+css-computed-value-normalizer@3+css-color3-opacity-normalizer@1+length-used-value-normalizer@1+stroke-used-geometry-normalizer@1+basic-shape-used-geometry-normalizer@1+isolated-group-compositor@1+static-mask-normalizer@1+static-mask-compositor@1+static-filter-graph-compositor@1+static-blend-compositor@1+mizchi/svg@0.2.1$' "$tmp/version.txt"
grep -q '^renderer-conformance-profile: svgdiff-renderer-conformance-profile/25$' "$tmp/version.txt"
grep -q '^ordering-policy: v2_domain_lexicographic$' "$tmp/version.txt"

assert_status 2 moon run --target native cmd/svgdiff -- >"$tmp/missing-args.out" 2>"$tmp/missing-args.err"
test ! -s "$tmp/missing-args.out"
grep -q '^Usage: svgdiff ' "$tmp/missing-args.err"

assert_status 2 moon run --target native cmd/svgdiff -- \
  testdata/before.svg testdata/after.svg \
  --perceptual-background transparent \
  >"$tmp/invalid-background.out" 2>"$tmp/invalid-background.err"
test ! -s "$tmp/invalid-background.out"
grep -q '^--perceptual-background requires an opaque deterministic sRGB color$' "$tmp/invalid-background.err"

for invalid_ppd in 0 4097 nan inf invalid; do
  assert_status 2 moon run --target native cmd/svgdiff -- \
    testdata/before.svg testdata/after.svg \
    --flip-pixels-per-degree "$invalid_ppd" \
    >"$tmp/invalid-ppd.out" 2>"$tmp/invalid-ppd.err"
  test ! -s "$tmp/invalid-ppd.out"
  grep -q '^--flip-pixels-per-degree requires a finite number in \[1, 4096\]$' "$tmp/invalid-ppd.err"
done

for invalid_threshold in -0.001 1.001 nan inf invalid; do
  assert_status 2 moon run --target native cmd/svgdiff -- \
    testdata/before.svg testdata/after.svg \
    --flip-error-threshold "$invalid_threshold" \
    >"$tmp/invalid-threshold.out" 2>"$tmp/invalid-threshold.err"
  test ! -s "$tmp/invalid-threshold.out"
  grep -q '^--flip-error-threshold requires a finite number in \[0, 1\]$' "$tmp/invalid-threshold.err"
done

assert_status 2 moon run --target native cmd/svgdiff -- "$tmp/missing.svg" testdata/after.svg >"$tmp/missing-file.out" 2>"$tmp/missing-file.err"
test ! -s "$tmp/missing-file.out"
grep -q '^Failed to read ' "$tmp/missing-file.err"

assert_status 2 moon run --target native cmd/svgdiff -- \
  testdata/before.svg testdata/after.svg \
  --before-resource asset.png image/png "$tmp/missing.png" \
  >"$tmp/missing-resource.out" 2>"$tmp/missing-resource.err"
test ! -s "$tmp/missing-resource.out"
grep -q '^Failed to read resource ' "$tmp/missing-resource.err"

assert_status 2 moon run --target native cmd/svgdiff -- - - <testdata/before.svg >"$tmp/double-stdin.out" 2>"$tmp/double-stdin.err"
test ! -s "$tmp/double-stdin.out"
grep -q '^Only one SVG input may use stdin (-)$' "$tmp/double-stdin.err"

assert_status 2 moon run --target native cmd/svgdiff -- testdata/before.svg testdata/after.svg --output "$tmp" >"$tmp/output-failure.out" 2>"$tmp/output-failure.err"
test ! -s "$tmp/output-failure.out"
grep -q '^Failed to write ' "$tmp/output-failure.err"

assert_status 1 moon run --target native cmd/svgdiff -- \
  testdata/before.svg testdata/after.svg --width 8193 --agent-json \
  >"$tmp/resource-failed.json" 2>"$tmp/resource-failed.err"
test ! -s "$tmp/resource-failed.err"
jq -e '
  .schema_version == "1.42" and
  .analysis_status == "failed" and
  .subject_alignments == [] and
  .atomic_differences == [] and
  .events == [] and
  .diagnostics == [{
    "id": "diagnostic:resource-limit-exceeded:raster_dimensions",
    "code": "resource_limit_exceeded",
    "subject_id": "raster_dimensions",
    "affected_evidence_layers": [
      "source_semantics", "computed_appearance", "rendered_evidence"
    ],
    "source_locations": []
  }] and
  .coverage_matrix == [{
    "feature_id": "resource.raster_dimensions",
    "subject_id": "raster_dimensions",
    "source_semantics": "failed",
    "computed_appearance": "failed",
    "rendered_evidence": "failed",
    "diagnostic_ids": [
      "diagnostic:resource-limit-exceeded:raster_dimensions"
    ]
  }]
' "$tmp/resource-failed.json" >/dev/null

printf '%s\n' '<svg><rect></svg>' >"$tmp/malformed.svg"
assert_status 1 moon run --target native cmd/svgdiff -- "$tmp/malformed.svg" testdata/after.svg >"$tmp/failed.json" 2>"$tmp/failed.err"
test ! -s "$tmp/failed.err"
jq -e '.analysis_status == "failed" and (.diagnostics | length) > 0' "$tmp/failed.json" >/dev/null
jq -e '
  .diagnostics == [{
    "id": "diagnostic:svg-parse-failed:document",
    "code": "svg_parse_failed",
    "subject_id": "document",
    "affected_evidence_layers": [
      "source_semantics", "computed_appearance", "rendered_evidence"
    ],
    "source_locations": [{
      "source_role": "before",
      "source_span": {"start_offset": 11, "end_offset": 16}
    }]
  }]
' "$tmp/failed.json" >/dev/null
jq -e '.renderer_capability_gaps == []' "$tmp/failed.json" >/dev/null
jq -e 'all(.coverage_matrix[]; .source_semantics == "failed" and .computed_appearance == "failed" and .rendered_evidence == "failed")' "$tmp/failed.json" >/dev/null
