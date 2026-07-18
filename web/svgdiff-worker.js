const wasmUrl = new URL("./assets/svgdiff_wasm.wasm", import.meta.url);
const encoder = new TextEncoder();
const decoder = new TextDecoder("utf-8", { fatal: true });

const instancePromise = fetch(wasmUrl)
  .then((response) => {
    if (!response.ok) throw new Error(`Unable to load WebAssembly: HTTP ${response.status}`);
    return response.arrayBuffer();
  })
  .then((bytes) => WebAssembly.instantiate(bytes))
  .then(({ instance }) => {
    if (instance.exports.abi_version() !== 1) throw new Error("Unsupported SVGDiff WebAssembly ABI.");
    return instance;
  });

function invoke(instance, request) {
  const exports = instance.exports;
  const input = encoder.encode(JSON.stringify(request));
  if (input.length > exports.transfer_capacity()) {
    throw new Error(`Request requires ${input.length} bytes; WebAssembly accepts ${exports.transfer_capacity()}.`);
  }
  new Uint8Array(exports.memory.buffer, exports.transfer_ptr(), input.length).set(input);
  const status = exports.compare(input.length);
  const body = new Uint8Array(exports.memory.buffer, exports.transfer_ptr(), exports.result_len());
  const text = decoder.decode(body);
  if (status !== 0) throw new Error(`WebAssembly request ${exports.result_error_kind()}: ${text}`);
  return text;
}

self.addEventListener("message", async (event) => {
  const { id, request } = event.data;
  try {
    const instance = await instancePromise;
    const reportText = invoke(instance, request);
    self.postMessage({ id, ok: true, reportText });
  } catch (error) {
    self.postMessage({ id, ok: false, message: error.message || String(error) });
  }
});
