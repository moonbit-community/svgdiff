const examples = [
  {
    id: "color-size",
    label: "Local color + size changes",
    before: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 160">
  <rect id="color-box" x="24" y="44" width="72" height="72" fill="#2563eb" />
  <rect id="size-box" x="152" y="52" width="56" height="56" fill="#16a34a" />
</svg>`,
    after: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 160">
  <rect id="color-box" x="24" y="44" width="72" height="72" fill="#dc2626" />
  <rect id="size-box" x="152" y="52" width="72" height="72" fill="#16a34a" />
</svg>`,
  },
  {
    id: "translation",
    label: "Affine · translation",
    before: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 160">
  <rect x="16" y="16" width="224" height="128" rx="12" fill="#f8fafc" stroke="#cbd5e1" />
  <path id="target" d="M36 54h68v18H82v34H58V72H36Z" fill="#2563eb" transform="translate(0 0)" />
</svg>`,
    after: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 160">
  <rect x="16" y="16" width="224" height="128" rx="12" fill="#f8fafc" stroke="#cbd5e1" />
  <path id="target" d="M36 54h68v18H82v34H58V72H36Z" fill="#2563eb" transform="translate(96 18)" />
</svg>`,
  },
  {
    id: "rotation",
    label: "Affine · rotation around a pivot",
    before: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 160">
  <circle cx="128" cy="80" r="3" fill="#94a3b8" />
  <path id="target" d="M76 66h64V50l40 30-40 30V94H76Z" fill="#7c3aed" transform="rotate(0 128 80)" />
</svg>`,
    after: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 160">
  <circle cx="128" cy="80" r="3" fill="#94a3b8" />
  <path id="target" d="M76 66h64V50l40 30-40 30V94H76Z" fill="#7c3aed" transform="rotate(90 128 80)" />
</svg>`,
  },
  {
    id: "scale",
    label: "Affine · non-uniform scale",
    before: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 160">
  <rect x="16" y="16" width="224" height="128" rx="12" fill="none" stroke="#cbd5e1" />
  <g transform="translate(128 80)">
    <path id="target" d="M-48-30H18L48 0 18 30H-48Z" fill="#059669" transform="scale(0.8 1.15)" />
  </g>
</svg>`,
    after: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 160">
  <rect x="16" y="16" width="224" height="128" rx="12" fill="none" stroke="#cbd5e1" />
  <g transform="translate(128 80)">
    <path id="target" d="M-48-30H18L48 0 18 30H-48Z" fill="#059669" transform="scale(1.35 0.72)" />
  </g>
</svg>`,
  },
  {
    id: "skew",
    label: "Affine · skew",
    before: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 160">
  <path d="M36 128H220" stroke="#cbd5e1" stroke-dasharray="5 5" />
  <path id="target" d="M82 38H158V122H82Z" fill="#ea580c" transform="skewX(-8)" />
</svg>`,
    after: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 160">
  <path d="M36 128H220" stroke="#cbd5e1" stroke-dasharray="5 5" />
  <path id="target" d="M82 38H158V122H82Z" fill="#ea580c" transform="skewX(22)" />
</svg>`,
  },
  {
    id: "combined-affine",
    label: "Affine · combined decomposition",
    before: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 160">
  <path id="target" d="M42 42H104V58H78V110H42Z" fill="#db2777" transform="matrix(1 0 0 1 0 0)" />
</svg>`,
    after: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 160">
  <path id="target" d="M42 42H104V58H78V110H42Z" fill="#db2777" transform="translate(42 8) rotate(18) skewX(14) scale(1.12 0.86)" />
</svg>`,
  },
];

const elements = {
  beforeSource: document.querySelector("#before-source"),
  afterSource: document.querySelector("#after-source"),
  beforeFile: document.querySelector("#before-file"),
  afterFile: document.querySelector("#after-file"),
  beforePreview: document.querySelector("#before-preview"),
  afterPreview: document.querySelector("#after-preview"),
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
  exampleSelect: document.querySelector("#example-select"),
};

let worker = null;
let pending = null;
let requestId = 0;
let comparing = false;

function previewSource(source, viewportWidth, viewportHeight) {
  if (!Number.isFinite(viewportWidth) || viewportWidth <= 0 || !Number.isFinite(viewportHeight) || viewportHeight <= 0) return source;
  const document = new DOMParser().parseFromString(source, "image/svg+xml");
  const root = document.documentElement;
  if (root.localName !== "svg" || root.hasAttribute("viewBox")) return source;
  // CSS sizing alone does not scale no-viewBox user space. Adapt only this sandbox copy.
  root.setAttribute("viewBox", `0 0 ${viewportWidth} ${viewportHeight}`);
  return new XMLSerializer().serializeToString(document);
}

function previewDocument(source, viewportWidth, viewportHeight) {
  const adaptedSource = previewSource(source, viewportWidth, viewportHeight);
  return `<!doctype html><meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'"><style>html,body{margin:0;width:100%;height:100%;overflow:hidden}body{display:grid;place-items:center}body>svg{display:block;width:100%!important;height:100%!important}</style>${adaptedSource}`;
}

function refreshPreviews() {
  const viewportWidth = Number(elements.width.value);
  const viewportHeight = Number(elements.height.value);
  elements.beforePreview.srcdoc = previewDocument(elements.beforeSource.value, viewportWidth, viewportHeight);
  elements.afterPreview.srcdoc = previewDocument(elements.afterSource.value, viewportWidth, viewportHeight);
}

function loadExample() {
  const example = examples.find((candidate) => candidate.id === elements.exampleSelect.value) || examples[0];
  elements.beforeSource.value = example.before;
  elements.afterSource.value = example.after;
  elements.width.value = "256";
  elements.height.value = "160";
  refreshPreviews();
  elements.resultSection.hidden = true;
  elements.resultRoot.replaceChildren();
  setStatus(`${example.label} loaded locally.`, "");
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

function renderReport(report, reportText) {
  const fragment = elements.reportTemplate.content.cloneNode(true);
  elements.resultRoot.replaceChildren(fragment);
  elements.resultRoot.style.setProperty("--canvas-ratio", `${report.comparison.viewport.width}/${report.comparison.viewport.height}`);
  const frames = elements.resultRoot.querySelectorAll(".preview-content iframe");
  frames[0].srcdoc = previewDocument(elements.beforeSource.value, report.comparison.viewport.width, report.comparison.viewport.height);
  frames[1].srcdoc = previewDocument(elements.afterSource.value, report.comparison.viewport.width, report.comparison.viewport.height);
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
    const differenceCount = report.difference_groups.reduce((count, group) => count + group.items.length, 0);
    const perceptual = typeof report.canvas?.perceptual_difference === "number" ? "three canvas scores computed" : "perceptual score not requested";
    setStatus(`Complete browser transaction: ${report.analysis_status} report, ${differenceCount} Atomic Differences, ${perceptual}.`, "");
  } catch (error) {
    if (error.name === "AbortError") setStatus("Comparison cancelled. No partial report was presented.", "");
    else setStatus(error.message || String(error), "error");
  } finally {
    setComparing(false);
  }
}

elements.beforeSource.addEventListener("input", refreshPreviews);
elements.afterSource.addEventListener("input", refreshPreviews);
elements.width.addEventListener("input", refreshPreviews);
elements.height.addEventListener("input", refreshPreviews);
elements.beforeFile.addEventListener("change", () => readSvgFile(elements.beforeFile.files[0], "before"));
elements.afterFile.addEventListener("change", () => readSvgFile(elements.afterFile.files[0], "after"));
elements.background.addEventListener("change", () => {
  elements.customBackgroundLabel.hidden = elements.background.value !== "custom";
});
elements.compare.addEventListener("click", compare);
elements.exampleSelect.addEventListener("change", loadExample);
elements.editInputs.addEventListener("click", () => {
  elements.inputSection.scrollIntoView({ behavior: "smooth", block: "start" });
  elements.beforeSource.focus();
});
for (const panel of document.querySelectorAll("[data-drop-side]")) bindDropPanel(panel);

for (const example of examples) {
  const option = document.createElement("option");
  option.value = example.id;
  option.textContent = example.label;
  elements.exampleSelect.append(option);
}
loadExample();
