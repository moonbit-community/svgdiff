#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/svgdiff-compatibility-$$
cli="$root/_build/native/release/build/cmd/svgdiff/svgdiff.exe"
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

cd "$root"
moon build --target native --release cmd/svgdiff
python3 evaluation/compatibility/validate.py --cli "$cli" --output "$tmp/first.json"
python3 evaluation/compatibility/validate.py --cli "$cli" --output "$tmp/second.json"
cmp "$tmp/first.json" "$tmp/second.json"
jq -e '
  .schema_version == "svgdiff-compatibility-results/1" and
  .consumer_policy_id == "svgdiff-consumer-compatibility/1" and
  ([.cases[] | select(.decision == "accepted")] | length) == 19 and
  ([.cases[] | select(.decision == "rejected")] | length) == 4
' "$tmp/first.json" >/dev/null

printf 'Compatibility corpus: deterministic migration decisions: ok\n'
