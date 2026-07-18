///|
fn escape_html(value : String) -> String {
  value
  .replace_all(old="&", new="&amp;")
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
  .replace_all(old="\"", new="&quot;")
  .replace_all(old="'", new="&#39;")
}

///|
fn sandbox_document(source : String, width : Int, height : Int) -> String {
  escape_html(
    "<!doctype html><meta http-equiv='Content-Security-Policy' content=\"default-src 'none'; style-src 'unsafe-inline'\"><style>html,body{margin:0;width:100%;height:100%;overflow:hidden}body>svg{display:block;width:100%;height:100%}</style><svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 \{width} \{height}' preserveAspectRatio='xMidYMid meet'><g>\{source}</g></svg>",
  )
}

///|
/// Render a self-contained interactive HTML presentation of a report.
///
/// The original SVG sources are embedded as sandboxed preview documents. The
/// supplied Structured Report remains the sole source of classification,
/// ordering, magnitude, localization, and Diagnostics; this function does not
/// run comparison again. Review marks and navigation are session-only UI state.
pub fn render_html_report(
  before_svg : String,
  after_svg : String,
  report : StructuredReport,
) -> String {
  let width = report.profile.viewport_width
  let height = report.profile.viewport_height
  let report_json = escape_html(report.to_json_string())
  let before_document = sandbox_document(before_svg, width, height)
  let after_document = sandbox_document(after_svg, width, height)
  let styles = html_report_styles()
  let script = html_report_script()
  let html =
    $|<!doctype html>
    $|<html lang="en"><head><meta charset="utf-8">
    $|<meta name="viewport" content="width=device-width,initial-scale=1">
    $|<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; frame-src 'self'">
    $|<title>SVG Diff Report</title><style>
    $|\{styles}
    $|</style></head><body style="--canvas-ratio:\{width}/\{height}">
    $|<main class="layout"><section class="visuals" aria-label="SVG previews">
    $|<header class="visual-header"><div><h1>SVG previews</h1><p id="selection-status">No localization selected</p></div><div class="view-controls" aria-label="Synchronized preview controls"><button type="button" id="fit-selection">Fit selected</button><button type="button" id="fit-canvas">Fit canvas</button><button type="button" id="reset-view">Reset</button><button type="button" id="clear-selection-global">Clear selection</button><button type="button" id="zoom-out" aria-label="Zoom out">−</button><output id="zoom-value">100%</output><button type="button" id="zoom-in" aria-label="Zoom in">+</button></div></header>
    $|<div class="preview-grid"><article class="preview"><h2>Before</h2><div class="canvas" data-canvas><div class="preview-content"><iframe title="Before SVG" sandbox="" srcdoc="\{before_document}"></iframe><div class="overlay" data-overlay aria-hidden="true"></div></div><div class="pan-shield" title="Drag to pan synchronized previews"></div></div></article>
    $|<article class="preview"><h2>After</h2><div class="canvas" data-canvas><div class="preview-content"><iframe title="After SVG" sandbox="" srcdoc="\{after_document}"></iframe><div class="overlay" data-overlay aria-hidden="true"></div></div><div class="pan-shield" title="Drag to pan synchronized previews"></div></div></article></div>
    $|<div class="localization-legend"><span><i class="observed"></i>Observed bounds</span><span><i class="conservative"></i>Conservative outcome</span><span><i class="before-footprint"></i>Before footprint unavailable in Schema 1.44</span><span><i class="after-footprint"></i>After footprint unavailable in Schema 1.44</span></div>
    $|<aside id="selection-hidden" class="selection-hidden" hidden><span>The selected Event is hidden by filters; its overlay is suspended.</span><button type="button" id="show-selection">Show selected</button><button type="button" id="clear-selection">Clear</button></aside>
    $|</section><aside class="sidebar" aria-label="Visual-semantic review">
  $|<header class="report-header"><div><h1>Visual-semantic review</h1><p id="summary" class="summary"></p></div><span id="compatibility" class="compatibility">Schema compatibility</span></header>
    $|<section id="overview" aria-labelledby="overview-heading"><h2 id="overview-heading" class="section-title">Report overview</h2><div id="impact"></div></section>
    $|<section id="filters" class="filters" aria-label="Review filters"></section>
    $|<section id="diffs" aria-labelledby="events-heading"><h2 id="events-heading" class="section-title">Visual Events</h2></section>
    $|<details class="diagnostics-panel"><summary id="diagnostics-summary">Diagnostics</summary><div id="diagnostics"></div></details>
  $|<details class="json-panel"><summary>Raw Report JSON</summary><p class="raw-help">Canonical evidence for programs and text-only Agents. Search, copy, or download it directly.</p><div class="raw-actions"><button type="button" id="copy-json">Copy JSON</button><button type="button" id="download-json">Download JSON</button><span id="raw-status" role="status"></span></div><textarea id="report-data" readonly aria-label="Complete Structured Report JSON">\{report_json}</textarea></details>
    $|</aside></main><script>
    $|\{script}
    $|</script></body></html>
  html
}
