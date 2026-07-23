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
    await page.waitForFunction(() => document.querySelector('#report-root [data-difference-canvas]')?.dataset.state === 'ready');
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
    const difference = await page.locator('#report-root [data-difference-canvas]').evaluate(canvas => {
      const context = canvas.getContext('2d');
      return {
        headings: [...document.querySelectorAll('#report-root .preview h2')].map(node => node.textContent),
        width: canvas.width,
        height: canvas.height,
        state: canvas.dataset.state,
        statusHidden: document.querySelector('#report-root [data-difference-status]').hidden,
        equalPixel: [...context.getImageData(0, 0, 1, 1).data],
        changedPixel: [...context.getImageData(40, 60, 1, 1).data],
      };
    });
    await page.getByRole('button', { name: /Persistently highlight/ }).first().click();
    const baselineUi = {
      status: await page.locator('#run-status').textContent(),
      effectiveValues: await page.locator('.effective-value').allTextContents(),
      overlays: await page.locator('.region').count(),
      overlayLabels: await page.locator('.region-label').count(),
      effectiveValueOptions: await page.locator('#relation-filter option').allTextContents(),
    };
    await page.locator('#before-source').fill('<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"256\" height=\"256\"><rect id=\"no-viewbox-target\" x=\"32\" y=\"32\" width=\"64\" height=\"64\" fill=\"red\"/></svg>');
    await page.locator('#after-source').fill('<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"256\" height=\"256\"><rect id=\"no-viewbox-target\" x=\"32\" y=\"32\" width=\"64\" height=\"64\" fill=\"blue\"/></svg>');
    await page.getByRole('button', { name: 'Compare SVGs' }).click();
    await page.waitForFunction(() => document.querySelector('#compare-button')?.textContent === 'Compare SVGs');
    await page.locator('#result-section').waitFor({ state: 'visible' });
    await page.getByRole('button', { name: /Persistently highlight/ }).first().click();
    const noViewBoxFrameHost = page.locator('#report-root .preview-content iframe').first();
    const noViewBoxFrameBounds = await noViewBoxFrameHost.boundingBox();
    const noViewBoxSubjectBounds = await noViewBoxFrameHost.contentFrame().locator('#no-viewbox-target').evaluate(node => {
      const bounds = node.getBoundingClientRect();
      return { x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height };
    });
    const noViewBoxOverlayBounds = await page.locator('#report-root .overlay').first().locator('.region.conservative').boundingBox();
    const noViewBoxLocalizationGeometryError = Math.max(
      Math.abs(noViewBoxFrameBounds.x + noViewBoxSubjectBounds.x - noViewBoxOverlayBounds.x),
      Math.abs(noViewBoxFrameBounds.y + noViewBoxSubjectBounds.y - noViewBoxOverlayBounds.y),
      Math.abs(noViewBoxSubjectBounds.width - noViewBoxOverlayBounds.width),
      Math.abs(noViewBoxSubjectBounds.height - noViewBoxOverlayBounds.height),
    );
    const affineExpectations = [
      ['translation', ['geometry.transform.translation']],
      ['rotation', ['geometry.transform.rotation']],
      ['scale', ['geometry.transform.scale']],
      ['skew', ['geometry.transform.skew']],
      ['combined-affine', [
        'geometry.transform.translation',
        'geometry.transform.rotation',
        'geometry.transform.scale',
        'geometry.transform.skew',
      ]],
    ];
    const affineExamples = [];
    for (const [id, expectedDomains] of affineExpectations) {
      await page.locator('#example-select').selectOption(id);
      const transforms = await page.evaluate(() => {
        const parse = source => new DOMParser().parseFromString(source, 'image/svg+xml');
        return [
          parse(document.querySelector('#before-source').value).getElementById('target').getAttribute('transform'),
          parse(document.querySelector('#after-source').value).getElementById('target').getAttribute('transform'),
        ];
      });
      await page.getByRole('button', { name: 'Compare SVGs' }).click();
      await page.waitForFunction(() => document.querySelector('#compare-button')?.textContent === 'Compare SVGs');
      await page.locator('#result-section').waitFor({ state: 'visible' });
      const affineReport = JSON.parse(await page.locator('#report-data').inputValue());
      const affineDifferences = affineReport.difference_groups.flatMap(group => group.items);
      affineExamples.push({
        id,
        expectedDomains,
        transforms,
        analysisStatus: affineReport.analysis_status,
        domains: affineDifferences.map(difference => difference.kind),
        unexpectedScale: id === 'rotation' && affineDifferences.some(difference => difference.kind === 'geometry.transform.scale'),
        changedScores: await page.locator('.score-card .score-value').allTextContents(),
      });
    }
    const realExampleIds = ['bell', 'battery', 'circleDot', 'heart', 'rocket', 'visibility', 'viewBoxScale'];
    const realExamples = [];
    for (const id of realExampleIds) {
      await page.locator('#example-select').selectOption(id);
      const beforeSource = await page.locator('#before-source').inputValue();
      const afterSource = await page.locator('#after-source').inputValue();
      const source = {
        name: await page.locator('#example-source').textContent(),
        href: await page.locator('#example-source').getAttribute('href'),
        license: await page.locator('#example-license').textContent(),
        attributionVisible: await page.locator('#example-attribution').isVisible(),
        beforeBytes: await page.evaluate(value => new TextEncoder().encode(value).length, beforeSource),
        afterBytes: await page.evaluate(value => new TextEncoder().encode(value).length, afterSource),
      };
      await page.getByRole('button', { name: 'Compare SVGs' }).click();
      await page.waitForFunction(() => document.querySelector('#compare-button')?.textContent === 'Compare SVGs');
      await page.locator('#result-section').waitFor({ state: 'visible' });
      await page.waitForFunction(() => document.querySelector('#report-root [data-difference-canvas]')?.dataset.state === 'ready');
      const exampleReport = JSON.parse(await page.locator('#report-data').inputValue());
      const differencePixels = await page.locator('#report-root [data-difference-canvas]').evaluate(canvas => {
        const pixels = canvas.getContext('2d').getImageData(0, 0, canvas.width, canvas.height).data;
        let nonBlack = 0;
        for (let index = 0; index < pixels.length; index += 4) {
          if (pixels[index] !== 0 || pixels[index + 1] !== 0 || pixels[index + 2] !== 0) nonBlack += 1;
        }
        return {
          state: canvas.dataset.state,
          statusHidden: document.querySelector('#report-root [data-difference-status]').hidden,
          nonBlack,
        };
      });
      realExamples.push({
        id,
        source,
        viewport: exampleReport.comparison.viewport,
        analysisStatus: exampleReport.analysis_status,
        atomicDifferences: exampleReport.difference_groups.flatMap(group => group.items).length,
        diagnostics: exampleReport.limitations.length,
        canvasChangedPixels: exampleReport.canvas.changed_pixels,
        scores: await page.locator('.score-card .score-value').allTextContents(),
        eventOutcomes: exampleReport.events.map(event => ({
          changedPixels: event.outcome.changed_pixels,
          regionKinds: event.regions.map(region => region.kind),
        })),
        differencePixels,
      });
    }
    return {
      title: await page.title(),
      exampleOptions: await page.locator('#example-select option').allTextContents(),
      exampleSelectCount: await page.locator('#example-select').count(),
      noticesLinkCount: await page.getByRole('link', { name: 'Example notices' }).count(),
      checkpointBudget: Number(await page.locator('#max-checkpoints').inputValue()),
      sourceFacts,
      status: baselineUi.status,
      analysisStatus: report.analysis_status,
      schemaVersion: report.schema_version,
      atomicDifferences: report.difference_groups.flatMap(group => group.items).length,
      diagnostics: report.limitations.length,
      scores,
      previewSvgCounts,
      previewRootsFillViewport,
      difference,
      effectiveValues: baselineUi.effectiveValues,
      overlays: baselineUi.overlays,
      overlayLabels: baselineUi.overlayLabels,
      rawReportAvailable: reportText.length > 100,
      wasmBytes: Number(await page.locator('#report-root').getAttribute('data-compact-report-bytes')),
      errors: await page.evaluate(() => window.__svgdiffTestErrors),
      foreignRequests: await page.evaluate(() => performance.getEntriesByType('resource').map(entry => entry.name).filter(value => {
        const url = new URL(value);
        return (url.protocol === 'http:' || url.protocol === 'https:') && url.hostname !== '127.0.0.1';
      })),
      effectiveValueOptions: baselineUi.effectiveValueOptions,
      noViewBoxLocalizationGeometryError,
      affineExamples,
      realExamples,
    };
  }" >"$tmp/browser.json" 2>>"$log"

jq -e '
  .errors == [] and
  .foreignRequests == [] and
  .title == "SVGDiff — visual-semantic SVG comparison" and
  .exampleOptions == [
    "Local color + size changes",
    "Affine · translation",
    "Affine · rotation around a pivot",
    "Affine · non-uniform scale",
    "Affine · skew",
    "Affine · combined decomposition",
    "Real-world · Lucide Bell repair",
    "Real-world · Lucide Battery Charging repair",
    "Real-world · Lucide Circle → Circle Dot",
    "Real-world · Heroicons Heart outline → solid",
    "Real-world · Fluent Emoji Rocket flat → color",
    "Real-world · Material Visibility → Visibility Off",
    "Equivalent · scaled coordinates, same rendering"
  ] and
  .exampleSelectCount == 1 and
  .noticesLinkCount == 1 and
  .checkpointBudget == 1000000 and
  .sourceFacts.beforeColor == {"x":"24","y":"44","width":"72","height":"72","fill":"#2563eb"} and
  .sourceFacts.afterColor == {"x":"24","y":"44","width":"72","height":"72","fill":"#dc2626"} and
  .sourceFacts.beforeSize == {"x":"152","y":"52","width":"56","height":"56","fill":"#16a34a"} and
  .sourceFacts.afterSize == {"x":"152","y":"52","width":"72","height":"72","fill":"#16a34a"} and
  .effectiveValueOptions == ["Any effective value","Different","Same","Unknown"] and
  .analysisStatus == "complete" and
  .schemaVersion == "2.0" and
  .atomicDifferences == 3 and
  .diagnostics == 0 and
  .effectiveValues == ["Different effective value","Different effective value","Different effective value"] and
  [.scores[].label] == ["Changed area","Linear RGBA error","Perceptual difference"] and
  all(.scores[]; (.value | endswith("%"))) and
  all(.scores[]; .value != "0.00%") and
  .previewSvgCounts == [1, 1] and
  .previewRootsFillViewport == [true, true] and
  .difference == {
    "headings": ["Before", "Difference", "After"],
    "width": 256,
    "height": 160,
    "state": "ready",
    "statusHidden": true,
    "equalPixel": [0, 0, 0, 255],
    "changedPixel": [255, 255, 255, 255]
  } and
  .overlays > 0 and
  .overlayLabels == 0 and
  .noViewBoxLocalizationGeometryError <= 1 and
  .rawReportAvailable == true and
  .wasmBytes > 100 and
  (.affineExamples | length) == 5 and
  all(.affineExamples[];
    .transforms[0] != .transforms[1] and
    (.analysisStatus == "complete" or .analysisStatus == "partial") and
    ((.expectedDomains - .domains) | length == 0) and
    (.unexpectedScale | not) and
    all(.changedScores[]; endswith("%") and . != "0.00%")
  ) and
  (.realExamples | map(.id)) == ["bell","battery","circleDot","heart","rocket","visibility","viewBoxScale"] and
  all(.realExamples[];
    .source.attributionVisible == true and
    (.source.href | startswith("https://github.com/")) and
    (.source.name | length) > 0 and
    (.source.license | length) > 0 and
    .source.beforeBytes > 100 and
    .source.afterBytes > 100 and
    .viewport == {"width":256,"height":256} and
    (.analysisStatus == "complete" or .analysisStatus == "partial") and
    .differencePixels.state == "ready" and
    .differencePixels.statusHidden == true and
    [.scores[] | endswith("%")] == [true,true,true]
  ) and
  all(.realExamples[] | select(.id != "viewBoxScale");
    .atomicDifferences > 0 and
    .differencePixels.nonBlack > 0 and
    any(.scores[]; . != "0.00%")
  ) and
  (.realExamples[] | select(.id == "viewBoxScale") |
    .differencePixels.nonBlack == 0 and
    .scores == ["0.00%","0.00%","0.00%"] and
    (.eventOutcomes | length) == 2 and
    all(.eventOutcomes[]; .changedPixels == 0 and (.regionKinds | length) == 0)
  ) and
  (.realExamples[] | select(.id == "visibility") |
    . as $example |
    ([.eventOutcomes[] | select(.changedPixels == 0 and (.regionKinds | length) == 0)] | length) == 1 and
    all(.eventOutcomes[] | select(.changedPixels > 0);
      .changedPixels == $example.canvasChangedPixels and
      (.regionKinds | length) > 0 and all(.regionKinds[]; . == "conservative")
    )
  ) and
  (.realExamples[] | select(.id == "bell") |
    . as $example |
    (.eventOutcomes | length) == 2 and
    ([.eventOutcomes[].changedPixels] | unique | length) == 2 and
    all(.eventOutcomes[]; .changedPixels < $example.canvasChangedPixels)
  ) and
  (.realExamples[] | select(.id == "battery") |
    . as $example |
    (.eventOutcomes | length) == 6 and
    ([.eventOutcomes[].changedPixels] | unique | length) >= 5 and
    ([.eventOutcomes[] | select(.changedPixels == $example.canvasChangedPixels)] | length) == 2
  ) and
  all(.realExamples[] | select(.id == "circleDot" or .id == "heart");
    . as $example |
    (.eventOutcomes | length) == 1 and
    .eventOutcomes[0].changedPixels == $example.canvasChangedPixels
  ) and
  (.realExamples[] | select(.id == "rocket") |
    (.eventOutcomes | length) == 64 and
    ([.eventOutcomes[] | select(.changedPixels == null)] | length) > 0 and
    ([.eventOutcomes[].changedPixels | select(. != null)] | unique | length) >= 10
  ) and
  all(.realExamples[];
    all(.eventOutcomes[].regionKinds[]; . == "conservative") and
    all(.eventOutcomes[] | select(.changedPixels > 0); (.regionKinds | length) > 0)
  )
' "$tmp/browser.json" >/dev/null

printf 'GitHub Pages browser flow: base, affine, and seven pinned examples, isolated and conservative localization, WASM reports, Difference, attribution, JSON: ok\n'
