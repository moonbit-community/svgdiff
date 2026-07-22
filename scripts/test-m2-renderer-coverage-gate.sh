#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

python3 evaluation/m2-renderer-coverage-gate/validate.py
python3 -m json.tool evaluation/m2-renderer-coverage-gate/gate.v1.json >/dev/null
sh scripts/test-renderer-dispositions.sh
moon test --target native \
  engine/internal/diff/coverage_proof_wbtest.mbt \
  engine/feature_coverage_test.mbt \
  engine/internal/diff/feature_coverage_wbtest.mbt \
  engine/renderer_capabilities_test.mbt \
  engine/unsupported_input_property_test.mbt
