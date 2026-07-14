#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
corpus="$root/evaluation/corpus/manifest.json"
regions="$root/evaluation/annotations/regions.v1.json"

jq -n -e --slurpfile corpus "$corpus" --slurpfile regions "$regions" '
  ($corpus[0].cases | map({key: .id, value: .}) | from_entries) as $case_by_id |
  ($regions[0].schema_version == "svgdiff-region-labels/1") and
  ($regions[0].corpus_version == $corpus[0].schema_version) and
  ($regions[0].coordinate_space == "comparison_css_px") and
  ([$corpus[0].cases[].id] | sort) == ([$regions[0].cases[].case_id] | sort) and
  ([$regions[0].cases[].case_id] | length == (unique | length)) and
  ([$regions[0].cases[].regions[].id] | length == (unique | length)) and
  all($regions[0].cases[];
    . as $label |
    $case_by_id[$label.case_id] as $case |
    (.reason | type == "string" and length > 0) and
    if .localization_status == "not_applicable" then
      (.regions | type == "array" and length == 0)
    elif .localization_status == "localizable" then
      (.regions | type == "array" and length > 0) and
      all(.regions[];
        (.id | test("^region-ref:[a-z0-9-]+:[a-z0-9-]+$")) and
        (.reference_kind == "exact_painted_bounds" or .reference_kind == "conservative_css_bounds") and
        (.comparison_rule == "intersection_over_union" or .comparison_rule == "predicted_region_contained_by_reference") and
        (.bounds.x | type == "number" and . >= 0) and
        (.bounds.y | type == "number" and . >= 0) and
        (.bounds.width | type == "number" and . > 0) and
        (.bounds.height | type == "number" and . > 0) and
        (.bounds.x + .bounds.width <= $case.viewport.width) and
        (.bounds.y + .bounds.height <= $case.viewport.height)
      )
    else false
    end
  )
' >/dev/null

printf 'Region annotations: %s cases, localizable: %s, structure: ok\n' \
  "$(jq '.cases | length' "$regions")" \
  "$(jq '[.cases[] | select(.localization_status == "localizable")] | length' "$regions")"
