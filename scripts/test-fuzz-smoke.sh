#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/svgdiff-fuzz-smoke-$$
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

cd "$root"
moon build --target native --release cmd/svgdiff >/dev/null
cli="$root/_build/native/release/build/cmd/svgdiff/svgdiff.exe"
test -x "$cli"

python3 evaluation/fuzz/run.py \
  --cli "$cli" --seed 20260714 --cases 24 --output "$tmp/first.json"
python3 evaluation/fuzz/run.py \
  --cli "$cli" --seed 20260714 --cases 24 --output "$tmp/second.json"
cmp "$tmp/first.json" "$tmp/second.json"
jq -e '
  .schema_version == "svgdiff-fuzz-smoke-results/1" and
  .seed == 20260714 and
  .configured_case_count == 24 and
  .selected_case_index == null and
  .executed_case_count == 24 and
  .categories == {"hostile": 6, "limited": 6, "malformed": 6, "supported": 6} and
  ([.cases[].analysis_status] | index("complete")) != null and
  ([.cases[].analysis_status] | index("partial")) != null and
  ([.cases[].analysis_status] | index("failed")) != null
' "$tmp/first.json" >/dev/null

python3 evaluation/fuzz/run.py \
  --cli "$cli" --seed 20260714 --cases 24 --case-index 7 \
  --output "$tmp/replay.json" >/dev/null
jq -e '
  .selected_case_index == 7 and
  .executed_case_count == 1 and
  .cases[0].id == "seed-20260714-case-7"
' "$tmp/replay.json" >/dev/null

printf 'Fuzz smoke: deterministic seed, four boundary families, single-case replay: ok\n'
