#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
manifest="$root/evaluation/corpus/manifest.json"
tmp=${TMPDIR:-/tmp}/svgdiff-agent-harness-$$
reports="$tmp/reports"
tasks="$tmp/tasks.jsonl"
answers="$tmp/answers.jsonl"
mkdir -p "$reports"
trap 'rm -rf "$tmp"' EXIT

cd "$root"
jq -c '.cases[]' "$manifest" | while IFS= read -r case_json; do
  id=$(printf '%s' "$case_json" | jq -r '.id')
  before=$(printf '%s' "$case_json" | jq -r '.before')
  after=$(printf '%s' "$case_json" | jq -r '.after')
  width=$(printf '%s' "$case_json" | jq -r '.viewport.width')
  height=$(printf '%s' "$case_json" | jq -r '.viewport.height')
  moon run --target native cmd/svgdiff -- \
    "$root/evaluation/corpus/$before" \
    "$root/evaluation/corpus/$after" \
    --width "$width" --height "$height" >"$reports/$id.json"
done

python3 evaluation/harness/harness.py prepare \
  --reports "$reports" \
  --output "$tasks"

jq -s -e --argjson expected "$(jq '.cases | length' "$manifest")" '
  length == $expected and
  all(.[];
    (keys | sort) == ["acceptance_version", "case_id", "prompt", "report"] and
    .acceptance_version == "agent-acceptance/1" and
    (.prompt | type == "string" and length > 0) and
    (.report.schema_version == "1.32") and
    (has("before") | not) and
    (has("after") | not) and
    (has("annotations") | not) and
    (has("corpus") | not)
  )
' "$tasks" >/dev/null

python3 evaluation/harness/harness.py run \
  --tasks "$tasks" \
  --output "$answers" \
  --agent "python3 evaluation/harness/report_only_test_agent.py"

jq -s -e --argjson expected "$(jq '.cases | length' "$manifest")" '
  length == $expected and
  ([.[].case_id] | length == (unique | length)) and
  all(.[];
    .acceptance_version == "agent-acceptance/1" and
    (.coverage.analysis_status == "complete" or
     .coverage.analysis_status == "partial" or
     .coverage.analysis_status == "failed")
  )
' "$answers" >/dev/null

expect_agent_failure() {
  mode=$1
  timeout=$2
  if python3 evaluation/harness/harness.py run \
    --tasks "$tasks" \
    --output "$tmp/unexpected-$mode.jsonl" \
    --timeout "$timeout" \
    --agent "env SVGDIFF_TEST_AGENT_MODE=$mode python3 evaluation/harness/report_only_test_agent.py" \
    >/dev/null 2>&1; then
    printf 'Harness unexpectedly accepted agent mode: %s\n' "$mode" >&2
    exit 1
  fi
}

expect_agent_failure fail 1
expect_agent_failure invalid-json 1
expect_agent_failure mismatch 1
expect_agent_failure timeout 0.01

jq empty evaluation/harness/agent-answer.schema.json
printf 'Agent harness: %s report-only tasks, adapter protocol: ok\n' "$(wc -l <"$answers" | tr -d ' ')"
