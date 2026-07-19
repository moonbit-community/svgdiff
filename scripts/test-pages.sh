#!/bin/sh
set -eu
exec 3>&2

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
playwright_version=${SVGDIFF_PLAYWRIGHT_CLI_VERSION:-0.1.17}
tmp=${TMPDIR:-/tmp}/svgdiff-pages-$$
log="$tmp/playwright.log"
session="svgdiff-pages-$$"
port=$((43000 + ($$ % 1000)))
mkdir -p "$tmp"

if ! command -v npx >/dev/null 2>&1; then
  echo "GitHub Pages browser gate requires npx from Node.js/npm" >&2
  exit 2
fi

pw() {
  npx --yes --package "@playwright/cli@$playwright_version" \
    playwright-cli --session "$session" "$@"
}

cleanup() {
  exit_status=$?
  trap - EXIT INT TERM
  pw close >/dev/null 2>&1 || true
  if [ -n "${server_pid:-}" ]; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
  if [ "$exit_status" -ne 0 ]; then
    test ! -f "$tmp/browser.json" || cat "$tmp/browser.json" >&3
    tail -c 16384 "$log" >&3 || true
  fi
  rm -rf "$tmp"
  exit "$exit_status"
}
trap cleanup EXIT INT TERM

cd "$root"
sh scripts/build-pages.sh >/dev/null
python3 -m http.server "$port" --bind 127.0.0.1 --directory _site \
  >"$tmp/server.log" 2>&1 &
server_pid=$!
while ! curl -fsS "http://127.0.0.1:$port/" >/dev/null 2>&1; do
  kill -0 "$server_pid"
  sleep 0.05
done

pw open about:blank >>"$log" 2>&1
pw --raw run-code \
  "async (page) => {
    await page.goto('http://127.0.0.1:$port/', { waitUntil: 'load' });
    await page.evaluate(() => {
      window.__svgdiffTestErrors = [];
      window.addEventListener('error', event => window.__svgdiffTestErrors.push(event.message));
      window.addEventListener('unhandledrejection', event => window.__svgdiffTestErrors.push(String(event.reason)));
      const originalError = console.error;
      console.error = (...values) => {
        window.__svgdiffTestErrors.push(values.map(String).join(' '));
        originalError(...values);
      };
    });
    const beforeSource = await page.locator('#before-source').inputValue();
    const afterSource = await page.locator('#after-source').inputValue();
    const sourceFacts = await page.evaluate(({ beforeSource, afterSource }) => {
      const parse = source => new DOMParser().parseFromString(source, 'image/svg+xml');
      const before = parse(beforeSource);
      const after = parse(afterSource);
      const attributes = (document, id) => {
        const element = document.getElementById(id);
        return {
          x: element.getAttribute('x'),
          y: element.getAttribute('y'),
          width: element.getAttribute('width'),
          height: element.getAttribute('height'),
          fill: element.getAttribute('fill'),
        };
      };
      return {
        beforeColor: attributes(before, 'color-box'),
        afterColor: attributes(after, 'color-box'),
        beforeSize: attributes(before, 'size-box'),
        afterSize: attributes(after, 'size-box'),
      };
    }, { beforeSource, afterSource });
    await page.getByRole('button', { name: 'Compare SVGs' }).click();
    await page.waitForFunction(() => document.querySelector('#compare-button')?.textContent === 'Compare SVGs');
    await page.locator('#result-section').waitFor({ state: 'visible' });
    const reportText = await page.locator('#report-data').inputValue();
    const report = JSON.parse(reportText);
    const scores = await page.locator('.score-card').evaluateAll(cards => cards.map(card => ({
      label: card.querySelector('.score-label').textContent,
      value: card.querySelector('.score-value').textContent,
    })));
    const previewSvgCounts = [];
    const previewRootsFillViewport = [];
    const reportFrames = page.locator('#report-root .preview-content iframe');
    for (let index = 0; index < await reportFrames.count(); index += 1) {
      const frame = reportFrames.nth(index).contentFrame();
      previewSvgCounts.push(await frame.locator('svg').count());
      previewRootsFillViewport.push(await frame.locator('body > svg').evaluate(svg => {
        const bounds = svg.getBoundingClientRect();
        return Math.abs(bounds.left) < 0.5 && Math.abs(bounds.top) < 0.5 &&
          Math.abs(bounds.width - innerWidth) < 0.5 && Math.abs(bounds.height - innerHeight) < 0.5;
      }));
    }
    await page.getByRole('button', { name: /Persistently highlight/ }).first().click();
    return {
      title: await page.title(),
      exampleLabel: await page.locator('.example-label').textContent(),
      exampleSelectCount: await page.locator('#example-select').count(),
      noticesLinkCount: await page.getByRole('link', { name: 'Example notices' }).count(),
      checkpointBudget: Number(await page.locator('#max-checkpoints').inputValue()),
      sourceFacts,
      status: await page.locator('#run-status').textContent(),
      analysisStatus: report.analysis_status,
      schemaVersion: report.schema_version,
      atomicDifferences: report.atomic_differences.length,
      diagnostics: report.diagnostics.length,
      scores,
      previewSvgCounts,
      previewRootsFillViewport,
      effectiveValues: await page.locator('.effective-value').allTextContents(),
      overlays: await page.locator('.region').count(),
      overlayLabels: await page.locator('.region-label').count(),
      rawReportAvailable: reportText.length > 100,
      wasmBytes: Number(await page.locator('#report-root').getAttribute('data-compact-report-bytes')),
      errors: await page.evaluate(() => window.__svgdiffTestErrors),
      foreignRequests: await page.evaluate(() => performance.getEntriesByType('resource').map(entry => entry.name).filter(value => {
        const url = new URL(value);
        return (url.protocol === 'http:' || url.protocol === 'https:') && url.hostname !== '127.0.0.1';
      })),
      effectiveValueOptions: await page.locator('#relation-filter option').allTextContents(),
    };
  }" >"$tmp/browser.json" 2>>"$log"

jq -e '
  .errors == [] and
  .foreignRequests == [] and
  .title == "SVGDiff — visual-semantic SVG comparison" and
  (.exampleLabel | contains("Local color + size changes")) and
  .exampleSelectCount == 0 and
  .noticesLinkCount == 0 and
  .checkpointBudget == 1000000 and
  .sourceFacts.beforeColor == {"x":"24","y":"44","width":"72","height":"72","fill":"#2563eb"} and
  .sourceFacts.afterColor == {"x":"24","y":"44","width":"72","height":"72","fill":"#dc2626"} and
  .sourceFacts.beforeSize == {"x":"152","y":"52","width":"56","height":"56","fill":"#16a34a"} and
  .sourceFacts.afterSize == {"x":"152","y":"52","width":"72","height":"72","fill":"#16a34a"} and
  .effectiveValueOptions == ["Any effective value","Different","Same","Unknown"] and
  .analysisStatus == "complete" and
  .schemaVersion == "1.45" and
  .atomicDifferences == 3 and
  .diagnostics == 0 and
  .effectiveValues == ["Different effective value","Different effective value","Different effective value"] and
  [.scores[].label] == ["Changed area","Linear RGBA error","Perceptual difference"] and
  all(.scores[]; (.value | endswith("%"))) and
  all(.scores[]; .value != "0.00%") and
  .previewSvgCounts == [1, 1] and
  .previewRootsFillViewport == [true, true] and
  .overlays > 0 and
  .overlayLabels > 0 and
  .overlayLabels <= .overlays and
  .rawReportAvailable == true and
  .wasmBytes > 100
' "$tmp/browser.json" >/dev/null

printf 'GitHub Pages browser flow: local color-and-size example, WASM report, Inspector, JSON: ok\n'
