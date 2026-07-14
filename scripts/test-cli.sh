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
jq -e '.schema_version == "1.9" and .profile.renderer_conformance_profile_id == "svgdiff-renderer-conformance-profile/6" and .analysis_status == "complete" and (.coverage_matrix | length) > 0 and .renderer_capability_gaps == [] and (all(.coverage_matrix[]; (.source_semantics != "limited" and .computed_appearance != "limited" and .rendered_evidence != "limited"))) and (.atomic_differences | length) == 1' "$tmp/report.json" >/dev/null

moon run --target native cmd/svgdiff -- testdata/before.svg testdata/after.svg --agent-json >"$tmp/agent.json" 2>"$tmp/agent.err"
test ! -s "$tmp/agent.err"
test "$(wc -l <"$tmp/agent.json" | tr -d ' ')" -eq 1
jq -e '.schema_version == "1.9" and .profile.renderer_conformance_profile_id == "svgdiff-renderer-conformance-profile/6" and .analysis_status == "complete" and (.atomic_differences | length) == 1' "$tmp/agent.json" >/dev/null
test "$(wc -c <"$tmp/agent.json")" -lt "$(wc -c <"$tmp/report.json")"
test "$(jq -S -c . "$tmp/agent.json")" = "$(jq -S -c . "$tmp/report.json")"

moon run --target native cmd/svgdiff -- testdata/before.svg testdata/after.svg --width 32 --height 24 --output "$tmp/output.json" --html "$tmp/report.html" >"$tmp/output.stdout" 2>"$tmp/output.err"
test ! -s "$tmp/output.stdout"
test ! -s "$tmp/output.err"
jq -e '.profile.viewport_width == 32 and .profile.viewport_height == 24 and .profile.comparison_dpr == 1 and .profile.color_interpretation == "srgb" and .profile.raster_representation == "linear_srgb_premultiplied_rgba_f64" and .profile.renderer_conformance_profile_id == "svgdiff-renderer-conformance-profile/6" and (.events[0].rendered_outcome.magnitude.linear_premultiplied_rgba_rmse > 0)' "$tmp/output.json" >/dev/null
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
jq -e '.schema_version == "1.9" and .analysis_status == "complete"' "$tmp/stdin-before.json" >/dev/null

cat testdata/after.svg | moon run --target native cmd/svgdiff -- testdata/before.svg - >"$tmp/stdin-after.json" 2>"$tmp/stdin-after.err"
test ! -s "$tmp/stdin-after.err"
jq -e '.schema_version == "1.9" and .analysis_status == "complete"' "$tmp/stdin-after.json" >/dev/null

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
grep -q 'Invalid arguments or file I/O failure' "$tmp/help.txt"

moon run --target native cmd/svgdiff -- --version >"$tmp/version.txt"
grep -q '^svgdiff 0.4.3$' "$tmp/version.txt"
grep -q '^engine: 0.4.3$' "$tmp/version.txt"
grep -q '^schema: 1.9$' "$tmp/version.txt"
grep -q '^renderer: svgdiff/style-precedence-normalizer@1+stroke-used-geometry-normalizer@1+basic-shape-used-geometry-normalizer@1+mizchi/svg@0.2.1$' "$tmp/version.txt"
grep -q '^renderer-conformance-profile: svgdiff-renderer-conformance-profile/6$' "$tmp/version.txt"
grep -q '^ordering-policy: v2_domain_lexicographic$' "$tmp/version.txt"

assert_status 2 moon run --target native cmd/svgdiff -- >"$tmp/missing-args.out" 2>"$tmp/missing-args.err"
test ! -s "$tmp/missing-args.out"
grep -q '^Usage: svgdiff ' "$tmp/missing-args.err"

assert_status 2 moon run --target native cmd/svgdiff -- "$tmp/missing.svg" testdata/after.svg >"$tmp/missing-file.out" 2>"$tmp/missing-file.err"
test ! -s "$tmp/missing-file.out"
grep -q '^Failed to read ' "$tmp/missing-file.err"

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
  .schema_version == "1.9" and
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
