#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/svgdiff-agent-projection-$$
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
    printf 'Expected exit status %s, got %s: %s\n' "$expected" "$actual" "$*" >&2
    exit 1
  fi
}

validate_case() {
  name=$1
  shift
  moon run --target native modules/svgdiff/cmd/svgdiff -- "$@" >"$tmp/$name-report.json"
  moon run --target native modules/svgdiff/cmd/svgdiff -- \
    "$@" --agent-projection >"$tmp/$name-projection.jsonl"
  python3 evaluation/agent-projection/validate.py \
    --report "$tmp/$name-report.json" \
    --projection "$tmp/$name-projection.jsonl"
}

cd "$root"
jq -c '.cases[]' evaluation/corpus/manifest.json | while IFS= read -r case_json; do
  id=$(printf '%s' "$case_json" | jq -r '.id')
  before=$(printf '%s' "$case_json" | jq -r '.before')
  after=$(printf '%s' "$case_json" | jq -r '.after')
  width=$(printf '%s' "$case_json" | jq -r '.viewport.width')
  height=$(printf '%s' "$case_json" | jq -r '.viewport.height')
  validate_case "corpus-$id" \
    "$root/evaluation/corpus/$before" \
    "$root/evaluation/corpus/$after" \
    --width "$width" --height "$height"
done
validate_case flip \
  testdata/before.svg testdata/after.svg \
  --perceptual-background '#336699' \
  --flip-pixels-per-degree 20 \
  --flip-error-threshold 0.05

printf '%s\n' '<svg><rect></svg>' >"$tmp/malformed.svg"
set +e
moon run --target native modules/svgdiff/cmd/svgdiff -- \
  "$tmp/malformed.svg" testdata/after.svg >"$tmp/failed-report.json"
report_status=$?
moon run --target native modules/svgdiff/cmd/svgdiff -- \
  "$tmp/malformed.svg" testdata/after.svg --agent-projection \
  >"$tmp/failed-projection.jsonl"
projection_status=$?
set -e
test "$report_status" -eq 1
test "$projection_status" -eq 1
python3 evaluation/agent-projection/validate.py \
  --report "$tmp/failed-report.json" \
  --projection "$tmp/failed-projection.jsonl"

assert_status 2 moon run --target native modules/svgdiff/cmd/svgdiff -- \
  testdata/before.svg testdata/after.svg \
  --agent-json --agent-projection \
  >"$tmp/conflict.out" 2>"$tmp/conflict.err"
test ! -s "$tmp/conflict.out"
grep -q '^error: conflicting arguments: agent-json and agent-projection$' \
  "$tmp/conflict.err"

moon run --target native modules/svgdiff/cmd/svgdiff -- --version >"$tmp/version.txt"
grep -q '^agent-projection: svgdiff-agent-projection/1$' "$tmp/version.txt"

python3 evaluation/agent-projection/negative_controls.py \
  --validator evaluation/agent-projection/validate.py \
  --report "$tmp/corpus-salient-fill-change-report.json" \
  --projection "$tmp/corpus-salient-fill-change-projection.jsonl" \
  --output-dir "$tmp/negative-controls"

moon run --target native modules/svgdiff/cmd/svgdiff -- \
  evaluation/corpus/cases/salient-fill-change/before.svg \
  evaluation/corpus/cases/salient-fill-change/after.svg \
  --width 16 --height 16 --agent-projection \
  --output "$tmp/repeated-projection.jsonl" \
  >"$tmp/repeated-projection.stdout"
test ! -s "$tmp/repeated-projection.stdout"
cmp "$tmp/corpus-salient-fill-change-projection.jsonl" \
  "$tmp/repeated-projection.jsonl"

printf 'Agent projection: lossless JSONL reconstruction and negative controls: ok\n'
