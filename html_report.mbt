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
fn preview_element_insert_offset(
  source : String,
  span : @xml.SourceSpan,
) -> Int {
  let mut offset = span.end.offset - 1
  while offset > span.start.offset && source[offset] != '>' {
    offset -= 1
  }
  if offset > span.start.offset && source[offset - 1] == '/' {
    offset - 1
  } else {
    offset
  }
}

///|
fn preview_source(source : String, width : Int, height : Int) -> String {
  let reader = @xml.NamespaceReader::from_string(source)
  let events = reader.read_events_until_eof() catch { _ => return source }
  for event in events {
    match event.kind {
      Start(element) | Empty(element) => {
        if element.name.local_name != "svg" {
          return source
        }
        for attribute in element.attributes {
          if attribute.name.local_name == "viewBox" &&
            attribute.name.namespace_uri is None {
            return source
          }
        }
        // CSS sizing alone does not scale the user space of a root SVG without
        // viewBox. Adapt only the sandbox copy to the Comparison Viewport.
        let offset = preview_element_insert_offset(source, event.span)
        return "\{source.view(end_offset=offset)} viewBox=\"0 0 \{width} \{height}\"\{source.view(start_offset=offset)}"
      }
      _ => ()
    }
  }
  source
}

///|
fn sandbox_document(source : String, width : Int, height : Int) -> String {
  escape_html(
    "<!doctype html><meta http-equiv='Content-Security-Policy' content=\"default-src 'none'; style-src 'unsafe-inline'\"><style>html,body{margin:0;width:100%;height:100%;overflow:hidden}body>svg{display:block;width:100%!important;height:100%!important}</style>\{preview_source(source, width, height)}",
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
    $|<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; frame-src 'self'; img-src data:">
    $|<title>SVG Diff Report</title><style>
    $|\{styles}
    $|</style></head><body style="--canvas-ratio:\{width}/\{height}">
    $|<main class="layout"><section class="visuals" aria-label="SVG previews">
    $|<header class="visual-header"><div><h1>SVG previews</h1><p id="selection-status">No localization selected</p></div><div class="view-controls" aria-label="Synchronized preview controls"><button type="button" id="fit-selection">Fit selected</button><button type="button" id="fit-canvas">Fit canvas</button><button type="button" id="reset-view">Reset</button><button type="button" id="clear-selection-global">Clear selection</button><button type="button" id="zoom-out" aria-label="Zoom out">−</button><output id="zoom-value">100%</output><button type="button" id="zoom-in" aria-label="Zoom in">+</button></div></header>
    $|<div class="preview-grid"><article class="preview"><h2>Before</h2><div class="canvas" data-canvas><div class="preview-content"><iframe title="Before SVG" sandbox="" srcdoc="\{before_document}"></iframe><div class="overlay" data-overlay aria-hidden="true"></div></div><div class="pan-shield" title="Drag to pan synchronized previews"></div></div></article>
    $|<article class="preview"><h2>Difference</h2><div class="canvas difference-canvas" data-canvas><div class="preview-content"><canvas data-difference-canvas aria-label="RGB channel difference; black pixels are equal" aria-busy="true"></canvas></div><div class="difference-status" data-difference-status role="status">Rendering difference…</div><div class="pan-shield" title="Drag to pan synchronized previews"></div></div></article>
    $|<article class="preview"><h2>After</h2><div class="canvas" data-canvas><div class="preview-content"><iframe title="After SVG" sandbox="" srcdoc="\{after_document}"></iframe><div class="overlay" data-overlay aria-hidden="true"></div></div><div class="pan-shield" title="Drag to pan synchronized previews"></div></div></article></div>
    $|<div class="localization-legend"><span><i class="observed"></i>Observed contribution</span><span><i class="conservative"></i>Conservative candidate</span></div>
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
    $|SvgdiffReportInspector.mount(document);
    $|</script></body></html>
  html
}
