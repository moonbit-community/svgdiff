#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

moon build cmd/svgdiff_wasm --target wasm --release
node scripts/build-pages.mjs
