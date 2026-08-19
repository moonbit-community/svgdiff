#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/svgdiff-terminal-magnitude.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
manifest=evaluation/terminal-magnitude-gate/manifest.v1.json
validator=evaluation/terminal-magnitude-gate/validate.py

assert_status() {
  expected=$1
  shift
  set +e
  "$@"
  actual=$?
  set -e
  if [ "$actual" -ne "$expected" ]; then
    printf 'Expected exit status %s, got %s: %s\n' "$expected" "$actual" "$*" >&2
    exit 1
  fi
}

cd "$root"
python3 "$validator" "$manifest"
python3 -m json.tool "$manifest" >/dev/null

jq 'del(.dimensions[0])' "$manifest" >"$tmp/missing-dimension.json"
assert_status 1 python3 "$validator" "$tmp/missing-dimension.json" >/dev/null 2>&1
for field in fields units_or_denominators availability_rule authorities tests; do
  jq --arg field "$field" 'del(.dimensions[0][$field])' "$manifest" \
    >"$tmp/missing-$field.json"
  assert_status 1 python3 "$validator" "$tmp/missing-$field.json" >/dev/null 2>&1
done
jq 'del(.anti_collapse_rules[0])' "$manifest" >"$tmp/missing-rule.json"
assert_status 1 python3 "$validator" "$tmp/missing-rule.json" >/dev/null 2>&1
jq '.dimensions[0].tests[0] = "modules/svgdiff/engine/not-a-real-test.mbt"' "$manifest" \
  >"$tmp/missing-test-path.json"
assert_status 1 python3 "$validator" "$tmp/missing-test-path.json" >/dev/null 2>&1

moon test --target native \
  modules/svgdiff/engine/magnitude_test.mbt \
  modules/svgdiff/engine/internal/measurement/difference_magnitudes_wbtest.mbt \
  modules/svgdiff/engine/internal/diff/difference_regions_wbtest.mbt \
  modules/svgdiff/engine/internal/measurement/difference_ordering_wbtest.mbt \
  modules/svgdiff/engine/internal/diff/path_geometry_wbtest.mbt \
  modules/svgdiff/engine/internal/diff/transform_diff_wbtest.mbt \
  modules/svgdiff/engine/internal/diff/embedded_image_diff_wbtest.mbt \
  modules/svgdiff/engine/internal/diff/perceptual_color_wbtest.mbt \
  modules/svgdiff/engine/internal/diff/perceptual_flip_wbtest.mbt \
  modules/svgdiff/engine/internal/diff/impact_assessment_wbtest.mbt \
  modules/svgdiff/engine/structured_report_test.mbt
sh scripts/test-schema-examples.sh
sh scripts/test-mutations.sh
sh scripts/test-impact-assessment.sh
sh scripts/test-evaluation-metrics.sh
sh scripts/test-language-model-observation.sh

moon build --target native --release modules/svgdiff/cmd/svgdiff >/dev/null
cli=$root/_build/native/release/build/Milky2018/svgdiff/cmd/svgdiff/svgdiff.exe
printf '%s\n' '<svg xmlns="http://www.w3.org/2000/svg"><rect id="box" x="1" y="1" width="8" height="8" fill="red"/></svg>' >"$tmp/geometry-before.svg"
printf '%s\n' '<svg xmlns="http://www.w3.org/2000/svg"><rect id="box" x="0.99999" y="1" width="8" height="8" fill="red"/></svg>' >"$tmp/geometry-after.svg"
"$cli" "$tmp/geometry-before.svg" "$tmp/geometry-after.svg" \
  --width 16 --height 16 >"$tmp/geometry.json"
"$cli" testdata/before.svg testdata/after.svg \
  --perceptual-background white \
  --flip-pixels-per-degree 67 \
  --flip-error-threshold 0.1 >"$tmp/paint.json"
printf '%s\n' '<svg xmlns="http://www.w3.org/2000/svg"><text id="label">A</text></svg>' >"$tmp/text-before.svg"
printf '%s\n' '<svg xmlns="http://www.w3.org/2000/svg"><text id="label">B</text></svg>' >"$tmp/text-after.svg"
"$cli" "$tmp/text-before.svg" "$tmp/text-after.svg" \
  --width 16 --height 16 >"$tmp/text.json"

python3 - \
  "$tmp/geometry.json" \
  "$tmp/paint.json" \
  schema/examples/subject-insertion.json \
  schema/examples/group-transform-change.json \
  schema/examples/embedded-raster-change.json \
  "$tmp/text.json" <<'PY'
import json
import math
from pathlib import Path
import sys

geometry, paint, insertion, transform, raster, text = [
    json.loads(Path(path).read_text(encoding="utf-8")) for path in sys.argv[1:]
]

def differences(report):
    return [item for group in report["difference_groups"] for item in group["items"]]

geometry_difference = next(
    value for value in differences(geometry) if value["kind"] == "geometry.position"
)
magnitude = geometry_difference["magnitude"]
for field in (
    "parameter_abs_user_units",
    "parameter_signed_user_units",
    "symmetric_relative",
    "parameter_abs_css_px",
    "parameter_viewport_fraction",
    "parameter_entity_fraction",
):
    if magnitude[field] is None or not math.isfinite(magnitude[field]):
        raise SystemExit(f"exact parameter scale missing: {field}")
if not math.isclose(magnitude["parameter_abs_css_px"], 0.00001, rel_tol=1e-8):
    raise SystemExit("tiny exact CSS-pixel parameter magnitude changed")
if magnitude["parameter_signed_user_units"] >= 0:
    raise SystemExit("signed tiny parameter direction was not preserved")
geometry_outcome = geometry["events"][0]["outcome"]
isolated = geometry_outcome["isolated_subject"]
boundary = isolated["painted_boundary_displacement"]
if boundary["max_css_px"] == magnitude["parameter_abs_css_px"]:
    raise SystemExit("renderer boundary response collapsed into exact parameter magnitude")
coverage = isolated["painted_coverage_difference"]
if coverage["union_css_px2"] <= 0 or coverage["fraction"] < 0:
    raise SystemExit("tiny geometry alpha-coverage evidence missing")
if geometry_outcome["changed_fraction"] < 0:
    raise SystemExit("tiny geometry raster evidence is invalid")

paint_difference = next(
    value for value in differences(paint) if value["kind"] == "paint.fill"
)
paint_outcome = paint["events"][0]["outcome"]
if paint_outcome["isolated_subject"]["painted_coverage_difference"]["fraction"] != 0:
    raise SystemExit("alpha-only coverage incorrectly treated RGB change as area change")
for field in ("changed_fraction", "linear_rgba_rmse"):
    if paint_outcome[field] is None or paint_outcome[field] <= 0:
        raise SystemExit(f"paint raster magnitude missing: {field}")
color = paint_outcome["perceptual_color"]
flip = paint_outcome["perceptual_difference"]
if color["sample_count"] <= 0 or color["mean_delta_e_ok"] <= 0:
    raise SystemExit("event-local DeltaEOK evidence missing")
if flip["canvas_mean"] <= 0 or flip["response_maximum"] < flip["response_p95"]:
    raise SystemExit("event-local FLIP statistics missing")
if flip["area_above_threshold"]["threshold"] != 0.1:
    raise SystemExit("explicit FLIP threshold evidence changed")

presence = next(
    value["magnitude"]["presence"]
    for value in differences(insertion)
    if value.get("magnitude", {}).get("presence") is not None
)
if presence["affected_entity_count"] != 1 or presence["painted_area_css_px2"] <= 0:
    raise SystemExit("presence magnitude evidence missing")
effect = next(
    value["magnitude"].get("transform")
    for value in differences(transform)
    if value.get("magnitude", {}).get("transform") is not None
)
if effect["kind"] != "translation" or effect["norm_css_px"] != 4:
    raise SystemExit("tagged transform-effect magnitude changed")
intrinsic = next(
    value["magnitude"]["intrinsic_raster"]
    for value in differences(raster)
    if value.get("magnitude", {}).get("intrinsic_raster") is not None
)
if intrinsic["changed_fraction"] != 1 or intrinsic["compared_pixels"] != 1:
    raise SystemExit("intrinsic raster magnitude changed")

if text["analysis_status"] != "partial":
    raise SystemExit("unsupported text report must remain partial")
text_difference = differences(text)[0]
if "magnitude" in text_difference:
    raise SystemExit("unavailable text magnitude was fabricated")
if text["events"][0]["outcome"]["status"] != "not_computed":
    raise SystemExit("unavailable text rendering was measured as zero")
PY

printf 'Terminal multidimensional magnitude gate: passed\n'
