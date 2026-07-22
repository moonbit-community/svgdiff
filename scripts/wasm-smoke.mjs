import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const [wasmPath, beforePath, afterPath, nativeReportPath] = process.argv.slice(2);
if (!wasmPath || !beforePath || !afterPath || !nativeReportPath) {
  throw new Error(
    "usage: node scripts/wasm-smoke.mjs <wasm-path> <before.svg> <after.svg> <native-report.json>",
  );
}

const bytes = await readFile(wasmPath);
const beforeSvg = await readFile(beforePath, "utf8");
const afterSvg = await readFile(afterPath, "utf8");
const nativeReport = JSON.parse(await readFile(nativeReportPath, "utf8"));
const { instance } = await WebAssembly.instantiate(bytes);
const exports = instance.exports;
const encoder = new TextEncoder();
const decoder = new TextDecoder("utf-8", { fatal: true });

assert.ok(exports.memory instanceof WebAssembly.Memory);
assert.equal(exports.abi_version(), 1);

function invoke(request) {
  const input = encoder.encode(JSON.stringify(request));
  assert.ok(input.length <= exports.transfer_capacity());
  new Uint8Array(exports.memory.buffer, exports.transfer_ptr(), input.length).set(input);
  const status = exports.compare(input.length);
  const body = new Uint8Array(
    exports.memory.buffer,
    exports.transfer_ptr(),
    exports.result_len(),
  );
  return {
    status,
    errorKind: exports.result_error_kind(),
    text: decoder.decode(body),
  };
}

const result = invoke({
  version: 1,
  before_svg: beforeSvg,
  after_svg: afterSvg,
  viewport_width: 16,
  viewport_height: 16,
  perceptual_background: "#ffffff",
  flip_pixels_per_degree: 60,
  flip_error_threshold: 0.05,
  max_checkpoints: 1000000,
});
assert.equal(result.status, 0, result.text);
assert.equal(result.errorKind, 0);
const report = JSON.parse(result.text);
assert.equal(report.schema_version, "1.46");
assert.equal(report.analysis_status, "complete");
assert.equal(report.canvas.changed_fraction, 0.25);
assert.deepEqual(report, nativeReport);

const invalid = invoke({
  version: 1,
  before_svg: "<svg/>",
  after_svg: "<svg/>",
  viewport_width: 16,
  viewport_height: 16,
  perceptual_background: null,
  flip_pixels_per_degree: null,
  flip_error_threshold: null,
  max_checkpoints: 1000000,
  path: "before.svg",
});
assert.equal(invalid.status, 1);
assert.equal(invalid.errorKind, 5);
assert.match(invalid.text, /unknown request field/);

console.log("svgdiff WASM smoke test passed");
