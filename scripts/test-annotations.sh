#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
corpus="$root/evaluation/corpus/manifest.json"
labels="$root/evaluation/annotations/main-changes.v1.json"

jq -n -e --slurpfile corpus "$corpus" --slurpfile labels "$labels" '
  ($labels[0].schema_version == "svgdiff-main-change-labels/1") and
  ($labels[0].corpus_version == $corpus[0].schema_version) and
  ($labels[0].review_status == "initial_single_pass") and
  ([$corpus[0].cases[].id] | sort) == ([$labels[0].cases[].case_id] | sort) and
  ([$labels[0].cases[].case_id] | length == (unique | length)) and
  ([$labels[0].cases[].main_visual_changes[].id] | length == (unique | length)) and
  all($labels[0].cases[];
    (.reference_summary | type == "string" and length > 0) and
    (.main_visual_changes | type == "array" and length > 0) and
    ([.main_visual_changes[].relative_importance.rank] | sort) == [range(1; (.main_visual_changes | length) + 1)] and
    all(.main_visual_changes[];
      (.id | test("^main:[a-z0-9-]+:[a-z0-9-]+$")) and
      (.description | type == "string" and length > 0) and
      (.relative_importance.tier == "none" or
       .relative_importance.tier == "low" or
       .relative_importance.tier == "medium" or
       .relative_importance.tier == "high") and
      (.relative_importance.rationale | type == "string" and length > 0) and
      (.acceptable_alternative_descriptions | type == "array" and length >= 2) and
      all(.acceptable_alternative_descriptions[]; type == "string" and length > 0)
    )
  )
' >/dev/null

printf 'Main-change annotations: %s cases, coverage: complete, structure: ok\n' "$(jq '.cases | length' "$labels")"
