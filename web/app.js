import { examples } from "./examples.js";

const elements = {
  beforeSource: document.querySelector("#before-source"),
  afterSource: document.querySelector("#after-source"),
  beforeFile: document.querySelector("#before-file"),
  afterFile: document.querySelector("#after-file"),
  beforePreview: document.querySelector("#before-preview"),
  afterPreview: document.querySelector("#after-preview"),
  example: document.querySelector("#example-select"),
  exampleSource: document.querySelector("#example-source"),
  exampleLicense: document.querySelector("#example-license"),
  width: document.querySelector("#viewport-width"),
  height: document.querySelector("#viewport-height"),
  background: document.querySelector("#background-select"),
  customBackground: document.querySelector("#custom-background"),
  customBackgroundLabel: document.querySelector("#custom-background-label"),
  flipPpd: document.querySelector("#flip-ppd"),
  flipThreshold: document.querySelector("#flip-threshold"),
  maxCheckpoints: document.querySelector("#max-checkpoints"),
  compare: document.querySelector("#compare-button"),
  status: document.querySelector("#run-status"),
  inputSection: document.querySelector("#input-section"),
  resultSection: document.querySelector("#result-section"),
  resultRoot: document.querySelector("#report-root"),
  reportTemplate: document.querySelector("#report-template"),
  editInputs: document.querySelector("#edit-inputs"),
};

let worker = null;
let pending = null;
let requestId = 0;
let comparing = false;

function previewDocument(source) {
  return `<!doctype html><meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'"><style>html,body{margin:0;width:100%;height:100%;overflow:hidden}body{display:grid;place-items:center}body>svg{display:block;width:100%;height:100%}</style>${source}`;
}

function refreshPreviews() {
  elements.beforePreview.srcdoc = previewDocument(elements.beforeSource.value);
  elements.afterPreview.srcdoc = previewDocument(elements.afterSource.value);
}

function loadExample(name) {
  const example = examples[name] || examples.bell;
  elements.beforeSource.value = example.before;
  elements.afterSource.value = example.after;
  elements.exampleSource.textContent = example.source.name;
  elements.exampleSource.href = example.source.url;
  elements.exampleLicense.textContent = example.source.license;
  refreshPreviews();
}

async function readSvgFile(file, side) {
  if (!file) return;
  const source = await file.text();
  if (side === "before") elements.beforeSource.value = source;
  else elements.afterSource.value = source;
  refreshPreviews();
  setStatus(`${file.name} loaded locally.`, "");
}

function bindDropPanel(panel) {
  const side = panel.dataset.dropSide;
  for (const eventName of ["dragenter", "dragover"]) {
    panel.addEventListener(eventName, (event) => {
      event.preventDefault();
      panel.classList.add("dragging");
    });
  }
  for (const eventName of ["dragleave", "drop"]) {
    panel.addEventListener(eventName, (event) => {
      event.preventDefault();
      panel.classList.remove("dragging");
    });
  }
  panel.addEventListener("drop", (event) => readSvgFile(event.dataTransfer.files[0], side));
}

function setStatus(message, kind) {
  elements.status.textContent = message;
  elements.status.className = `run-status ${kind}`.trim();
}

function createWorker() {
  const next = new Worker(new URL("./svgdiff-worker.js", import.meta.url), { type: "module" });
  next.addEventListener("message", (event) => {
    if (!pending || event.data.id !== pending.id) return;
    const current = pending;
    pending = null;
    if (event.data.ok) current.resolve(event.data.reportText);
    else current.reject(new Error(event.data.message));
  });
  next.addEventListener("error", (event) => {
    if (!pending) return;
    const current = pending;
    pending = null;
    current.reject(new Error(event.message || "The WebAssembly worker failed."));
  });
  return next;
}

function runInWorker(request) {
  if (pending) throw new Error("A comparison is already running.");
  if (!worker) worker = createWorker();
  const id = ++requestId;
  return new Promise((resolve, reject) => {
    pending = { id, resolve, reject };
    worker.postMessage({ id, request });
  });
}

function cancelComparison() {
  if (worker) worker.terminate();
  worker = null;
  if (pending) {
    const current = pending;
    pending = null;
    current.reject(new DOMException("Comparison cancelled", "AbortError"));
  }
}

function finiteNumber(input, label) {
  const value = Number(input.value);
  if (!Number.isFinite(value)) throw new Error(`${label} must be a finite number.`);
  return value;
}

function positiveInteger(input, label) {
  const value = finiteNumber(input, label);
  if (!Number.isInteger(value) || value <= 0) throw new Error(`${label} must be a positive integer.`);
  return value;
}

function comparisonRequest() {
  const viewportWidth = positiveInteger(elements.width, "Viewport width");
  const viewportHeight = positiveInteger(elements.height, "Viewport height");
  const transparent = elements.background.value === "transparent";
  const custom = elements.background.value === "custom";
  const background = transparent ? null : custom ? elements.customBackground.value : elements.background.value;
  const ppd = transparent ? null : finiteNumber(elements.flipPpd, "FLIP pixels per degree");
  const threshold = transparent ? null : finiteNumber(elements.flipThreshold, "FLIP error threshold");
  return {
    version: 1,
    before_svg: elements.beforeSource.value,
    after_svg: elements.afterSource.value,
    viewport_width: viewportWidth,
    viewport_height: viewportHeight,
    perceptual_background: background,
    flip_pixels_per_degree: ppd,
    flip_error_threshold: threshold,
    max_checkpoints: positiveInteger(elements.maxCheckpoints, "Checkpoint budget"),
  };
}

function sandboxReportDocument(source, width, height) {
  return `<!doctype html><meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'"><style>html,body{margin:0;width:100%;height:100%;overflow:hidden}body>svg{display:block;width:100%;height:100%}</style><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${width} ${height}" preserveAspectRatio="xMidYMid meet"><g>${source}</g></svg>`;
}

function renderReport(report, reportText) {
  const fragment = elements.reportTemplate.content.cloneNode(true);
  elements.resultRoot.replaceChildren(fragment);
  elements.resultRoot.style.setProperty("--canvas-ratio", `${report.profile.viewport_width}/${report.profile.viewport_height}`);
  const frames = elements.resultRoot.querySelectorAll(".preview-content iframe");
  frames[0].srcdoc = sandboxReportDocument(elements.beforeSource.value, report.profile.viewport_width, report.profile.viewport_height);
  frames[1].srcdoc = sandboxReportDocument(elements.afterSource.value, report.profile.viewport_width, report.profile.viewport_height);
  elements.resultRoot.querySelector("#report-data").value = JSON.stringify(report, null, 2);
  window.SvgdiffReportInspector.mount(elements.resultRoot);
  elements.resultSection.hidden = false;
  elements.resultSection.scrollIntoView({ behavior: "smooth", block: "start" });
  elements.resultRoot.dataset.compactReportBytes = String(new TextEncoder().encode(reportText).length);
}

function setComparing(value) {
  comparing = value;
  elements.compare.textContent = value ? "Cancel comparison" : "Compare SVGs";
  elements.compare.classList.toggle("cancel", value);
  for (const control of elements.inputSection.querySelectorAll("textarea,input,select,summary")) control.disabled = value;
}

async function compare() {
  if (comparing) {
    cancelComparison();
    return;
  }
  try {
    const request = comparisonRequest();
    setComparing(true);
    setStatus("Comparing in a dedicated Web Worker…", "running");
    const reportText = await runInWorker(request);
    const report = JSON.parse(reportText);
    renderReport(report, reportText);
    const perceptual = report.canvas_outcome?.perceptual_flip?.status === "computed" ? "three canvas scores computed" : "perceptual score unavailable for this profile";
    setStatus(`Complete browser transaction: ${report.analysis_status} report, ${report.atomic_differences.length} Atomic Differences, ${perceptual}.`, "");
  } catch (error) {
    if (error.name === "AbortError") setStatus("Comparison cancelled. No partial report was presented.", "");
    else setStatus(error.message || String(error), "error");
  } finally {
    setComparing(false);
  }
}

elements.example.addEventListener("change", () => loadExample(elements.example.value));
elements.beforeSource.addEventListener("input", refreshPreviews);
elements.afterSource.addEventListener("input", refreshPreviews);
elements.beforeFile.addEventListener("change", () => readSvgFile(elements.beforeFile.files[0], "before"));
elements.afterFile.addEventListener("change", () => readSvgFile(elements.afterFile.files[0], "after"));
elements.background.addEventListener("change", () => {
  elements.customBackgroundLabel.hidden = elements.background.value !== "custom";
});
elements.compare.addEventListener("click", compare);
elements.editInputs.addEventListener("click", () => {
  elements.inputSection.scrollIntoView({ behavior: "smooth", block: "start" });
  elements.beforeSource.focus();
});
for (const panel of document.querySelectorAll("[data-drop-side]")) bindDropPanel(panel);

loadExample("bell");
