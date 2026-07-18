#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/svgdiff-wasm-$$
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT
cd "$root"

moon build cmd/svgdiff --target native --release
moon build cmd/svgdiff_wasm --target wasm --release
native_cli=_build/native/release/build/Milky2018/svgdiff/cmd/svgdiff/svgdiff.exe
"$native_cli" testdata/before.svg testdata/after.svg --agent-json \
  >"$tmp/native-report.json"
node scripts/wasm-smoke.mjs \
  _build/wasm/release/build/Milky2018/svgdiff/cmd/svgdiff_wasm/svgdiff_wasm.wasm \
  testdata/before.svg testdata/after.svg "$tmp/native-report.json"
