#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
corpus="$root/evaluation/corpus/manifest.json"
labels="$root/evaluation/annotations/subject-alignments.v1.json"

jq -n -e --slurpfile corpus "$corpus" --slurpfile labels "$labels" '
  [$corpus[0].cases[] |
    select(.required_subject_alignments != null) |
    {
      case_id: .id,
      expected_alignment: .required_subject_alignments[0]
    }
  ] as $corpus_expectations |
  ($labels[0].schema_version == "svgdiff-subject-alignment-labels/1") and
  ($labels[0].corpus_version == $corpus[0].schema_version) and
  ($labels[0].annotation_method | type == "string" and length > 0) and
  ([$labels[0].cases[].case_id] | length == (unique | length)) and
  ([$labels[0].cases[].shape] | sort) == [
    "deletion",
    "insertion",
    "many-to-many",
    "merge",
    "one-to-one",
    "split"
  ] and
  ([$labels[0].cases[] | {case_id, expected_alignment}] | sort_by(.case_id)) ==
    ($corpus_expectations | sort_by(.case_id)) and
  all($labels[0].cases[];
    (.pairwise_identity == "not_authoritative" or
     .pairwise_identity == "not_applicable" or
     .pairwise_identity == "undefined")
  ) and
  any($labels[0].cases[];
    .shape == "many-to-many" and
    .expected_alignment.before_count > 1 and
    .expected_alignment.after_count > 1 and
    .expected_alignment.basis == "exact_visual_equivalence_class" and
    .pairwise_identity == "undefined"
  )
' >/dev/null

printf 'Subject-alignment annotations: 6 shapes, cardinalities and identity boundary: ok\n'
