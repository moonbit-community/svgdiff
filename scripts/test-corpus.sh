#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
manifest="$root/evaluation/corpus/manifest.json"
tmp=${TMPDIR:-/tmp}/svgdiff-corpus-$$
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

cd "$root"

jq -e '
  .schema_version == "svgdiff-corpus/1" and
  (.cases | type == "array" and length > 0) and
  ([.cases[].id] | length == (unique | length)) and
  ([.cases[].before, .cases[].after] | length == (unique | length)) and
  ([.cases[].categories[]] | unique | contains([
    "equivalent",
    "subtle",
    "salient",
    "structural",
    "resource-mediated",
    "zero-contribution",
    "unsupported"
  ])) and
  all(.cases[];
    (.id | test("^[a-z0-9]+(-[a-z0-9]+)*$")) and
    (.categories | type == "array" and length > 0) and
    (.before | startswith("cases/") and (contains("..") | not)) and
    (.after | startswith("cases/") and (contains("..") | not)) and
    (.viewport.width | type == "number" and . > 0) and
    (.viewport.height | type == "number" and . > 0) and
    (.expected_analysis_status == "complete" or .expected_analysis_status == "partial") and
    (.minimum_atomic_differences | type == "number" and . >= 0) and
    (.required_diagnostics | type == "array")
  )
' "$manifest" >/dev/null

jq -c '.cases[]' "$manifest" | while IFS= read -r case_json; do
  id=$(printf '%s' "$case_json" | jq -r '.id')
  before=$(printf '%s' "$case_json" | jq -r '.before')
  after=$(printf '%s' "$case_json" | jq -r '.after')
  width=$(printf '%s' "$case_json" | jq -r '.viewport.width')
  height=$(printf '%s' "$case_json" | jq -r '.viewport.height')
  before_path="$root/evaluation/corpus/$before"
  after_path="$root/evaluation/corpus/$after"
  test -f "$before_path"
  test -f "$after_path"

  moon run --target native cmd/svgdiff -- \
    "$before_path" "$after_path" \
    --width "$width" --height "$height" >"$tmp/$id.json"

  if ! printf '%s' "$case_json" | jq -e --slurpfile report "$tmp/$id.json" '
      ($report[0].analysis_status == .expected_analysis_status) and
      (($report[0].atomic_differences | length) >= .minimum_atomic_differences) and
      ([.required_diagnostics[]] - [$report[0].diagnostics[].code] | length == 0)
    ' >/dev/null; then
    printf 'Corpus expectation failed: %s\n' "$id" >&2
    exit 1
  fi
done

printf 'Corpus cases: %s, required categories: 7, status: ok\n' "$(jq '.cases | length' "$manifest")"
