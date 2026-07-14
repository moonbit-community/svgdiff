#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
corpus="$root/evaluation/corpus/manifest.json"
regions="$root/evaluation/annotations/regions.v1.json"
causes="$root/evaluation/annotations/actual-causes.v1.json"

jq -n -e \
  --slurpfile corpus "$corpus" \
  --slurpfile regions "$regions" \
  --slurpfile causes "$causes" '
  ([$regions[0].cases[].regions[].id] | unique) as $region_ids |
  ($causes[0].schema_version == "svgdiff-actual-cause-labels/1") and
  ($causes[0].corpus_version == $corpus[0].schema_version) and
  ($causes[0].region_labels_version == $regions[0].schema_version) and
  ([$corpus[0].cases[].id] | sort) == ([$causes[0].cases[].case_id] | sort) and
  ([$causes[0].cases[].case_id] | length == (unique | length)) and
  ([$causes[0].cases[].actual_causes[].id] | length == (unique | length)) and
  all($causes[0].cases[];
    (.reason | type == "string" and length > 0) and
    if .evaluation_status == "not_applicable" then
      (.reference_region_ids | length == 0) and (.actual_causes | length == 0)
    elif .evaluation_status == "eligible" then
      (.reference_region_ids | type == "array" and length > 0) and
      all(.reference_region_ids[]; . as $id | $region_ids | index($id) != null) and
      (.actual_causes | type == "array" and length > 0) and
      all(.actual_causes[];
        (.id | test("^actual:[a-z0-9-]+:[a-z0-9-]+$")) and
        (.rationale | type == "string" and length > 0) and
        (.fact_locator.report_property | type == "string" and length > 0) and
        ((.fact_locator.source_property == null) or (.fact_locator.source_property | type == "string" and length > 0)) and
        ((.fact_locator.before_declared_value == null) or (.fact_locator.before_declared_value | type == "string")) and
        ((.fact_locator.after_declared_value == null) or (.fact_locator.after_declared_value | type == "string")) and
        (.fact_locator.affected_subject_ids | type == "array" and length > 0)
      )
    else false
    end
  )
' >/dev/null

printf 'Actual-cause annotations: %s eligible cases, exclusions explicit, structure: ok\n' \
  "$(jq '[.cases[] | select(.evaluation_status == "eligible")] | length' "$causes")"
