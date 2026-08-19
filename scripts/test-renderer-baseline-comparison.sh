#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
baseline="$root/evaluation/renderer-conformance/baseline.v1.json"
validator="$root/evaluation/renderer-conformance/validate_baseline.py"
tmp=${TMPDIR:-/tmp}/svgdiff-renderer-baseline-comparison-$$
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

cd "$root"
python3 "$validator" --report "$baseline"

jq '
  .browser_environment.host_platform = "linux-x64" |
  (.cases[] | select(.id == "pattern-content-object-bbox") | .premultiplied_rgba8_rmse) = 0.329912590329 |
  (.cases[] | select(.id == "pattern-viewbox") | .premultiplied_rgba8_rmse) = 0.027952998875 |
  (.cases[] | select(.id == "blend-modes")) += {
    changed_pixel_fraction: 0.25,
    changed_pixels: 64,
    max_channel_delta: 2,
    premultiplied_rgba8_rmse: 0.001470588235
  }
' "$baseline" >"$tmp/linux.json"
python3 "$validator" --report "$tmp/linux.json"

jq '(.cases[] | select(.id == "equivalent-color-before") | .changed_pixels) = 1' \
  "$baseline" >"$tmp/unregistered.json"
if python3 "$validator" --report "$tmp/unregistered.json" \
  >"$tmp/unregistered.out" 2>"$tmp/unregistered.err"; then
  echo "Renderer baseline comparison accepted an unregistered change" >&2
  exit 1
fi
grep -q 'renderer conformance baseline differs' "$tmp/unregistered.err"

jq '.browser_environment.host_platform = "windows-x64"' \
  "$baseline" >"$tmp/unknown-platform.json"
if python3 "$validator" --report "$tmp/unknown-platform.json" \
  >"$tmp/unknown-platform.out" 2>"$tmp/unknown-platform.err"; then
  echo "Renderer baseline comparison accepted an unknown platform" >&2
  exit 1
fi
grep -q 'unsupported renderer conformance host platform' \
  "$tmp/unknown-platform.err"

printf 'Renderer baseline comparison policy: ok\n'
