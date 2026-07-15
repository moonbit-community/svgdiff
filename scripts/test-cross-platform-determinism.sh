#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/svgdiff-cross-platform-determinism-$$
cli="$root/_build/native/release/build/Milky2018/svgdiff/cmd/svgdiff/svgdiff.exe"
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

cd "$root"
moon build --target native --release cmd/svgdiff >/dev/null
python3 evaluation/determinism/validate.py \
  --cli "$cli" \
  --output "$tmp/results.json" \
  --bundle "$tmp/source"

for platform in linux-x64 windows-x64 macos-arm64; do
  cp -R "$tmp/source" "$tmp/$platform"
done

compare() {
  python3 evaluation/determinism/compare_platforms.py \
    --platform "linux-x64=$tmp/linux-x64" \
    --platform "windows-x64=$tmp/windows-x64" \
    --platform "macos-arm64=$tmp/macos-arm64" \
    "$@"
}

compare --output "$tmp/comparison.json"
jq -e '
  .schema_version == "svgdiff-cross-platform-determinism-results/1" and
  .platforms == ["linux-x64", "macos-arm64", "windows-x64"] and
  .file_count == 17 and
  .status == "passed"
' "$tmp/comparison.json" >/dev/null

if python3 evaluation/determinism/compare_platforms.py \
  --platform "linux-x64=$tmp/linux-x64" \
  --platform "macos-arm64=$tmp/macos-arm64" >/dev/null 2>&1; then
  printf 'cross-platform comparator accepted an incomplete platform matrix\n' >&2
  exit 1
fi

printf 'unexpected\n' > "$tmp/macos-arm64/extra.json"
if compare >/dev/null 2>&1; then
  printf 'cross-platform comparator accepted an extra report file\n' >&2
  exit 1
fi
rm "$tmp/macos-arm64/extra.json"

divergent="$tmp/windows-x64/reports/equivalent-color-spelling.compact.json"
printf '\n' >> "$divergent"
if compare >/dev/null 2>&1; then
  printf 'cross-platform comparator accepted divergent report bytes\n' >&2
  exit 1
fi

rm "$divergent"
if compare >/dev/null 2>&1; then
  printf 'cross-platform comparator accepted a missing report\n' >&2
  exit 1
fi

printf 'Cross-platform Structured Report comparator controls: ok\n'
