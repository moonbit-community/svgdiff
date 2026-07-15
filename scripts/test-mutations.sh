#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/svgdiff-mutations-$$
first="$tmp/first"
second="$tmp/second"
mkdir -p "$first" "$second"
trap 'rm -rf "$tmp"' EXIT

cd "$root"
python3 evaluation/mutations/generate.py --output "$first"
python3 evaluation/mutations/generate.py --output "$second"

first_hashes=$(find "$first" -type f -print | sort | while IFS= read -r path; do shasum -a 256 "$path" | awk '{print $1}'; done)
second_hashes=$(find "$second" -type f -print | sort | while IFS= read -r path; do shasum -a 256 "$path" | awk '{print $1}'; done)
test "$first_hashes" = "$second_hashes"

manifest="$first/generated-manifest.json"
jq -e '
  .schema_version == "svgdiff-generated-mutations/1" and
  (.cases | length == 58) and
  (.coverage_contract.subject_kinds | sort) == ["circle", "ellipse", "line", "polygon", "polyline", "rect"] and
  (.coverage_contract.source_properties | sort) == ["--paint", "clip-rule", "color", "cx", "cy", "fill", "fill-opacity", "fill-rule", "gradientTransform", "gradientUnits", "height", "marker-end", "markerUnits", "markerWidth", "opacity", "orient", "paint-order", "patternTransform", "patternUnits", "points", "r", "refX", "rx", "ry", "stop-color", "stroke", "stroke-dasharray", "stroke-dashoffset", "stroke-linecap", "stroke-linejoin", "stroke-miterlimit", "stroke-opacity", "stroke-width", "transform", "vector-effect", "viewBox", "width", "x", "x1", "x2", "y", "y1", "y2"] and
  ([.cases[].expected_changed_fact.subject_kind] | unique | sort) == (.coverage_contract.subject_kinds | sort) and
  ([.cases[].expected_changed_fact.source_property] | unique | sort) == (.coverage_contract.source_properties | sort) and
  ([.cases[].id] | length == (unique | length))
' "$manifest" >/dev/null

jq -c '.cases[]' "$manifest" | while IFS= read -r case_json; do
  id=$(printf '%s' "$case_json" | jq -r '.id')
  before=$(printf '%s' "$case_json" | jq -r '.before')
  after=$(printf '%s' "$case_json" | jq -r '.after')
  width=$(printf '%s' "$case_json" | jq -r '.viewport.width')
  height=$(printf '%s' "$case_json" | jq -r '.viewport.height')

  moon run --target native cmd/svgdiff -- \
    "$first/$before" "$first/$after" \
    --width "$width" --height "$height" >"$tmp/$id-report.json"
  moon run --target native cmd/svgdiff -- \
    "$first/$after" "$first/$before" \
    --width "$width" --height "$height" >"$tmp/$id-reverse-report.json"

  if ! printf '%s' "$case_json" | jq -e --slurpfile report "$tmp/$id-report.json" '
      ($report[0].analysis_status == .expected_analysis_status) and
      (.expected_changed_fact as $expected |
        any($report[0].subject_alignments[];
          any((.before + .after)[]; .kind == $expected.subject_kind)
        ) and
        any($report[0].changed_facts[];
          .property == $expected.report_property and
          .before.property == $expected.source_property and
          .after.property == $expected.source_property and
          .before.declared_value == $expected.before_declared_value and
          .after.declared_value == $expected.after_declared_value and
          .affected_subject_ids == $expected.affected_subject_ids
        )
      )
    ' >/dev/null; then
    printf 'Mutation expectation failed: %s\n' "$id" >&2
    exit 1
  fi
done

python3 evaluation/mutations/validate_causality.py \
  --manifest "$manifest" \
  --reports "$tmp"

printf 'Mutation cases: %s, subject kinds: 6, source properties: 43, deterministic generation: ok, changed facts: ok\n' "$(jq '.cases | length' "$manifest")"
