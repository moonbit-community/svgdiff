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
fn sandbox_document(source : String) -> String {
  escape_html(
    "<!doctype html><meta http-equiv='Content-Security-Policy' content=\"default-src 'none'; style-src 'unsafe-inline'\"><style>html,body{margin:0;width:100%;height:100%;overflow:hidden}svg{display:block;width:100%;height:100%}</style>\{source}",
  )
}

///|
/// Render a self-contained interactive report. The structured report remains
/// the sole source of diff classification, ordering, magnitude, and regions.
pub fn render_html_report(
  before_svg : String,
  after_svg : String,
  report : StructuredReport,
) -> String {
  let report_json = escape_html(report.to_json_string())
  let before_document = sandbox_document(before_svg)
  let after_document = sandbox_document(after_svg)
  let width = report.profile.viewport_width
  let height = report.profile.viewport_height
  let html =
    $|<!doctype html>
    $|<html lang="en"><head><meta charset="utf-8">
    $|<meta name="viewport" content="width=device-width,initial-scale=1">
    $|<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; frame-src 'self'">
    $|<title>SVG Diff Report</title>
    $|<style>
    $|:root{color-scheme:light;font-family:ui-sans-serif,system-ui,sans-serif;background:#f5f6f8;color:#17191d}*{box-sizing:border-box}body{margin:0}.layout{display:grid;grid-template-columns:minmax(0,1fr) minmax(320px,420px);height:100vh}.visuals{padding:20px;display:grid;grid-template-columns:1fr 1fr;gap:16px;align-content:start;overflow:auto}.preview h2{font-size:14px;margin:0 0 8px}.canvas{position:relative;background:white;border:1px solid #d7d9de;border-radius:8px;overflow:hidden;aspect-ratio:\{width}/\{height}}iframe{display:block;width:100%;height:100%;border:0}.overlay{position:absolute;inset:0;pointer-events:none}.region{position:absolute;border:2px solid #e11d48;background:rgba(225,29,72,.16);box-shadow:0 0 0 1px white inset}.sidebar{background:white;border-left:1px solid #d7d9de;overflow:auto;padding:18px}.summary{font-size:13px;color:#5e6470;margin-bottom:16px}.domain{margin:0 0 18px}.domain h2{font-size:13px;margin:0 0 7px;color:#424751}.diff{display:grid;grid-template-columns:auto 1fr;gap:8px;padding:9px;border:1px solid #e0e2e6;border-radius:7px;margin:6px 0;cursor:default}.diff:hover,.diff.active{border-color:#e11d48;background:#fff4f6}.diff-title{font-size:13px;font-weight:650}.diff-detail{font-size:12px;color:#696f79;margin-top:3px;word-break:break-word}.json-panel{border-top:1px solid #d7d9de;padding-top:12px;margin-top:20px}.json-panel summary{cursor:pointer;font-weight:650;font-size:13px}textarea{width:100%;height:360px;margin-top:9px;resize:vertical;border:1px solid #d7d9de;border-radius:6px;padding:10px;font:11px ui-monospace,SFMono-Regular,monospace;background:#f7f8fa}
    $|</style></head><body>
    $|<main class="layout"><section class="visuals">
    $|<article class="preview"><h2>Before</h2><div class="canvas"><iframe title="Before SVG" sandbox="" srcdoc="\{before_document}"></iframe><div class="overlay" data-overlay></div></div></article>
    $|<article class="preview"><h2>After</h2><div class="canvas"><iframe title="After SVG" sandbox="" srcdoc="\{after_document}"></iframe><div class="overlay" data-overlay></div></div></article>
    $|</section><aside class="sidebar"><div class="summary" id="summary"></div><div id="diffs"></div>
    $|<details class="json-panel"><summary>Complete JSON report</summary><textarea id="report-data" readonly>\{report_json}</textarea></details></aside></main>
    $|<script>
    $|const report=JSON.parse(document.getElementById('report-data').value);const root=document.getElementById('diffs');const overlays=[...document.querySelectorAll('[data-overlay]')];const eventsByDiff=new Map();for(const event of report.events){for(const id of event.atomic_difference_ids){const values=eventsByDiff.get(id)||[];values.push(event);eventsByDiff.set(id,values)}}function clearRegions(){for(const overlay of overlays)overlay.replaceChildren()}function showRegions(id){clearRegions();const events=eventsByDiff.get(id)||[];for(const event of events){for(const region of event.difference_regions||[]){for(const overlay of overlays){const box=document.createElement('div');box.className='region';box.style.left=`${region.css_x/report.profile.viewport_width*100}%`;box.style.top=`${region.css_y/report.profile.viewport_height*100}%`;box.style.width=`${region.css_width/report.profile.viewport_width*100}%`;box.style.height=`${region.css_height/report.profile.viewport_height*100}%`;box.title=region.id;overlay.append(box)}}}}const groups=new Map();for(const diff of report.atomic_differences){const domain=diff.domain.split('.')[0];if(!groups.has(domain))groups.set(domain,[]);groups.get(domain).push(diff)}for(const [domain,diffs] of groups){const section=document.createElement('section');section.className='domain';const heading=document.createElement('h2');heading.textContent=`${domain} (${diffs.length})`;section.append(heading);for(const diff of diffs){const item=document.createElement('div');item.className='diff';item.tabIndex=0;const check=document.createElement('input');check.type='checkbox';check.setAttribute('aria-label',`Select ${diff.id}`);const text=document.createElement('div');const title=document.createElement('div');title.className='diff-title';title.textContent=`${diff.domain} · ${diff.id}`;const detail=document.createElement('div');detail.className='diff-detail';detail.textContent=`${diff.source_before||'∅'} → ${diff.source_after||'∅'} · ${diff.domain_ordering.policy_id}`;text.append(title,detail);item.append(check,text);item.addEventListener('mouseenter',()=>showRegions(diff.id));item.addEventListener('mouseleave',()=>{if(!item.classList.contains('active'))clearRegions()});item.addEventListener('focus',()=>showRegions(diff.id));item.addEventListener('blur',()=>{if(!item.classList.contains('active'))clearRegions()});item.addEventListener('click',event=>{if(event.target===check)return;document.querySelectorAll('.diff.active').forEach(node=>{if(node!==item)node.classList.remove('active')});item.classList.toggle('active');item.classList.contains('active')?showRegions(diff.id):clearRegions()});section.append(item)}root.append(section)}document.getElementById('summary').textContent=`${report.analysis_status} · ${report.atomic_differences.length} differences · ${report.diagnostics.length} diagnostics`;
    $|</script></body></html>
  html
}
