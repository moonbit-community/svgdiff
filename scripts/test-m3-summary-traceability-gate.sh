#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/svgdiff-m3-summary-gate.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

assert_status() {
  expected=$1
  shift
  set +e
  "$@"
  actual=$?
  set -e
  if [ "$actual" -ne "$expected" ]; then
    printf 'Expected exit status %s, got %s: %s\n' "$expected" "$actual" "$*" >&2
    exit 1
  fi
}

validate_summary_case() {
  name=$1
  expected_status=$2
  shift 2
  assert_status "$expected_status" "$cli" "$@" --summary "$tmp/$name.md" >"$tmp/$name.json"
  python3 evaluation/m3-summary-traceability-gate/validate_summary.py \
    --report "$tmp/$name.json" --summary "$tmp/$name.md"
}

cd "$root"
python3 evaluation/m3-summary-traceability-gate/validate.py \
  evaluation/m3-summary-traceability-gate/manifest.v1.json
jq 'del(.obligations[0])' \
  evaluation/m3-summary-traceability-gate/manifest.v1.json \
  >"$tmp/missing-obligation.json"
assert_status 1 python3 evaluation/m3-summary-traceability-gate/validate.py \
  "$tmp/missing-obligation.json" >/dev/null 2>&1
jq 'del(.obligations[0].commands[0])' \
  evaluation/m3-summary-traceability-gate/manifest.v1.json \
  >"$tmp/missing-command.json"
assert_status 1 python3 evaluation/m3-summary-traceability-gate/validate.py \
  "$tmp/missing-command.json" >/dev/null 2>&1
jq 'del(.obligations[0].negative_controls[0])' \
  evaluation/m3-summary-traceability-gate/manifest.v1.json \
  >"$tmp/missing-control.json"
assert_status 1 python3 evaluation/m3-summary-traceability-gate/validate.py \
  "$tmp/missing-control.json" >/dev/null 2>&1
jq '.agent_projection_version = "unknown"' \
  evaluation/m3-summary-traceability-gate/manifest.v1.json \
  >"$tmp/wrong-identity.json"
assert_status 1 python3 evaluation/m3-summary-traceability-gate/validate.py \
  "$tmp/wrong-identity.json" >/dev/null 2>&1

moon build --target native --release modules/svgdiff/cmd/svgdiff >/dev/null
cli="$root/_build/native/release/build/Milky2018/svgdiff/cmd/svgdiff/svgdiff.exe"

validate_summary_case complete 0 testdata/before.svg testdata/after.svg
validate_summary_case partial 0 \
  evaluation/corpus/cases/unsupported-path-change/before.svg \
  evaluation/corpus/cases/unsupported-path-change/after.svg \
  --width 16 --height 16
printf '%s\n' '<svg><rect></svg>' >"$tmp/malformed.svg"
validate_summary_case failed 1 "$tmp/malformed.svg" testdata/after.svg \
  --width 16 --height 16
python3 evaluation/m3-summary-traceability-gate/negative_summary_controls.py \
  --report "$tmp/complete.json" --summary "$tmp/complete.md"

assert_status 0 "$cli" testdata/before.svg testdata/after.svg \
  --agent-json >"$tmp/complete-compact.json"
assert_status 0 "$cli" \
  evaluation/corpus/cases/unsupported-path-change/before.svg \
  evaluation/corpus/cases/unsupported-path-change/after.svg \
  --width 16 --height 16 --agent-json >"$tmp/partial-compact.json"
assert_status 1 "$cli" "$tmp/malformed.svg" testdata/after.svg \
  --width 16 --height 16 --agent-json >"$tmp/failed-compact.json"
for name in complete partial failed; do
  test "$(jq -S -c . "$tmp/$name-compact.json")" = \
    "$(jq -S -c . "$tmp/$name.json")"
done

jq '.analysis_status = "failed"' "$tmp/complete-compact.json" >"$tmp/compact-mismatch.json"
test "$(jq -S -c . "$tmp/compact-mismatch.json")" != \
  "$(jq -S -c . "$tmp/complete.json")"

"$cli" testdata/before.svg testdata/before.svg >"$tmp/empty.json"
"$cli" testdata/before.svg testdata/before.svg --agent-projection >"$tmp/empty.jsonl"
test "$(jq '[.difference_groups[].items[]] | length' "$tmp/empty.json")" -eq 0
python3 evaluation/agent-projection/validate.py \
  --report "$tmp/empty.json" --projection "$tmp/empty.jsonl"

jq -c 'if input_line_number == 1 then .projection_version = "unknown" else . end' \
  "$tmp/empty.jsonl" >"$tmp/unknown-projection.jsonl"
assert_status 1 python3 evaluation/agent-projection/validate.py \
  --report "$tmp/empty.json" --projection "$tmp/unknown-projection.jsonl" \
  >/dev/null 2>&1
jq -c 'if input_line_number == 1 then .source_schema_version = "0" else . end' \
  "$tmp/empty.jsonl" >"$tmp/wrong-schema.jsonl"
assert_status 1 python3 evaluation/agent-projection/validate.py \
  --report "$tmp/empty.json" --projection "$tmp/wrong-schema.jsonl" \
  >/dev/null 2>&1

sh scripts/test-cli.sh
sh scripts/test-agent-projection.sh
sh scripts/test-report-determinism.sh
sh scripts/test-impact-assessment.sh

printf 'M3 compact-summary traceability gate: passed\n'
