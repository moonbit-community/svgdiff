#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cli="$root/_build/native/release/build/Milky2018/svgdiff/cmd/svgdiff/svgdiff.exe"
tmp=${TMPDIR:-/tmp}/svgdiff-renderer-dispositions-$$
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

cd "$root"
moon build --target native --release cmd/svgdiff
python3 evaluation/renderer-conformance/validate_dispositions.py --cli "$cli"

jq '.conformance_profile_id = "svgdiff-renderer-conformance-profile/mismatch"' \
  evaluation/renderer-conformance/dispositions.v1.json >"$tmp/dispositions.json"
if python3 evaluation/renderer-conformance/validate_dispositions.py \
  --cli "$cli" --dispositions "$tmp/dispositions.json" \
  >"$tmp/mismatch.out" 2>"$tmp/mismatch.err"; then
  echo "Renderer disposition validation accepted a mismatched profile" >&2
  exit 1
fi
grep -q 'baseline and dispositions use different renderer conformance profiles' \
  "$tmp/mismatch.err"
