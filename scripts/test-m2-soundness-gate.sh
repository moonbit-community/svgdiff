#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

python3 evaluation/m2-soundness-gate/validate.py
python3 -m json.tool evaluation/m2-soundness-gate/gate.v1.json >/dev/null
moon test --target native \
  modules/svgdiff/engine/alignment_test.mbt \
  modules/svgdiff/engine/difference_region_test.mbt \
  modules/svgdiff/engine/internal/diff/difference_regions_wbtest.mbt \
  modules/svgdiff/engine/cause_envelope_test.mbt \
  modules/svgdiff/engine/internal/diff/cause_envelopes_wbtest.mbt
sh scripts/test-mutations.sh
sh scripts/test-adversarial.sh
sh scripts/test-alignment-annotations.sh
sh scripts/test-region-annotations.sh
sh scripts/test-cause-annotations.sh
sh scripts/test-report-determinism.sh
