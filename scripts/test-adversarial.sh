#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/svgdiff-adversarial-$$
cli="$root/_build/native/release/build/cmd/svgdiff/svgdiff.exe"
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

cd "$root"
moon build --target native --release cmd/svgdiff
python3 evaluation/adversarial/validate.py --cli "$cli" --output "$tmp/first.json"
python3 evaluation/adversarial/validate.py --cli "$cli" --output "$tmp/second.json"
cmp "$tmp/first.json" "$tmp/second.json"
jq -e '
  .schema_version == "svgdiff-adversarial-results/1" and
  (.cases | length) == 9 and
  all(.cases[]; .status == "passed")
' "$tmp/first.json" >/dev/null

printf 'Adversarial corpus: deterministic results: ok\n'
