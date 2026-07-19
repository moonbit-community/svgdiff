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
    for state_file in "$tmp"/meta.json "$tmp"/example-*.json "$tmp"/final.json; do
      if [ -f "$state_file" ]; then
        echo "$(basename "$state_file"):" >&3
        cat "$state_file" >&3
      fi
    done
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
    return {
      title: await page.title(),
      optionValues: await page.locator('#example-select option').evaluateAll(options => options.map(option => option.value)),
      optionLabels: await page.locator('#example-select option').allTextContents(),
      checkpointBudget: Number(await page.locator('#max-checkpoints').inputValue()),
    };
  }" >"$tmp/meta.json" 2>>"$log"

for value in bell battery circleDot heart rocket visibility viewBoxScale; do
  pw --raw run-code \
    "async (page) => {
      const value = '$value';
      await page.locator('#example-select').selectOption(value);
      const beforeSource = await page.locator('#before-source').inputValue();
      const afterSource = await page.locator('#after-source').inputValue();
      const beforeBytes = await page.evaluate(source => new TextEncoder().encode(source).length, beforeSource);
      const afterBytes = await page.evaluate(source => new TextEncoder().encode(source).length, afterSource);
      const sourceName = await page.locator('#example-source').textContent();
      const sourceHref = await page.locator('#example-source').getAttribute('href');
      const license = await page.locator('#example-license').textContent();
      await page.getByRole('button', { name: 'Compare SVGs' }).click();
      await page.waitForFunction(() => document.querySelector('#compare-button')?.textContent === 'Compare SVGs');
      await page.locator('#result-section').waitFor({ state: 'visible' });
      const report = JSON.parse(await page.locator('#report-data').inputValue());
      const scores = await page.locator('.score-card').evaluateAll(cards => cards.map(card => ({
        label: card.querySelector('.score-label').textContent,
        value: card.querySelector('.score-value').textContent,
      })));
      let overlays = null;
      if (value === 'bell') {
        await page.getByRole('button', { name: /Persistently highlight/ }).first().click();
        overlays = await page.locator('.region').count();
      }
      return {
        key: value,
        status: await page.locator('#run-status').textContent(),
        analysisStatus: report.analysis_status,
        schemaVersion: report.schema_version,
        atomicDifferences: report.atomic_differences.length,
        diagnostics: report.diagnostics.length,
        scores,
        effectiveValueCounts: await page.locator('.effective-value').evaluateAll(nodes => nodes.reduce((counts, node) => {
          const value = node.textContent;
          counts[value] = (counts[value] || 0) + 1;
          return counts;
        }, {})),
        sourceName,
        sourceHref,
        license,
        beforeBytes,
        afterBytes,
        overlays,
        rawReportAvailable: (await page.locator('#report-data').inputValue()).length > 100,
        wasmBytes: Number(await page.locator('#report-root').getAttribute('data-compact-report-bytes')),
      };
    }" >"$tmp/example-$value.json" 2>>"$log"
done

pw --raw run-code \
  "async (page) => {
    return {
      errors: await page.evaluate(() => window.__svgdiffTestErrors),
      foreignRequests: await page.evaluate(() => performance.getEntriesByType('resource').map(entry => entry.name).filter(value => {
        const url = new URL(value);
        return (url.protocol === 'http:' || url.protocol === 'https:') && url.hostname !== '127.0.0.1';
      })),
      effectiveValueOptions: await page.locator('#relation-filter option').allTextContents(),
    };
  }" >"$tmp/final.json" 2>>"$log"

jq -s '
  .[0] as $meta |
  .[-1] as $final |
  $meta + $final + {
    examples: (.[1:-1] | map({(.key): (del(.key))}) | add)
  }
' "$tmp/meta.json" "$tmp"/example-*.json "$tmp/final.json" >"$tmp/browser.json"

jq -e '
  .errors == [] and
  .foreignRequests == [] and
  .title == "SVGDiff — visual-semantic SVG comparison" and
  .optionValues == ["bell","battery","circleDot","heart","rocket","visibility","viewBoxScale"] and
  .optionLabels == [
    "Lucide Bell — real repair",
    "Lucide Battery Charging — real repair",
    "Lucide Circle → Circle Dot",
    "Heroicons Heart — outline → solid",
    "Fluent Emoji Rocket — flat → color",
    "Material Visibility → Visibility Off",
    "SVGO — scaled coordinates, same rendering"
  ] and
  .checkpointBudget == 1000000 and
  .effectiveValueOptions == ["Any effective value","Different","Same","Unknown"] and
  (.examples | keys) == ["battery","bell","circleDot","heart","rocket","viewBoxScale","visibility"] and
  all(.examples[];
    (.analysisStatus == "complete" or .analysisStatus == "partial") and
    .schemaVersion == "1.45" and
    .atomicDifferences >= 0 and
    .rawReportAvailable == true and
    .wasmBytes > 100 and
    .beforeBytes > 100 and
    .afterBytes > 100 and
    (.sourceHref | startswith("https://github.com/")) and
    (.sourceName | length) > 0 and
    (.license | length) > 0 and
    [.scores[].label] == ["Changed area","Linear RGBA error","Perceptual difference"] and
    all(.scores[]; (.value == "Not measured" or (.value | endswith("%"))))
  ) and
  all(.examples | to_entries[] | select(.value.analysisStatus == "partial"); .value.diagnostics > 0) and
  .examples.bell.overlays > 0 and
  .examples.bell.atomicDifferences > 0 and
  .examples.battery.atomicDifferences > 0 and
  .examples.circleDot.atomicDifferences == 0 and
  .examples.circleDot.diagnostics > 0 and
  .examples.heart.atomicDifferences > 0 and
  .examples.rocket.atomicDifferences > 0 and
  .examples.visibility.atomicDifferences > 0 and
  .examples.viewBoxScale.atomicDifferences > 0 and
  (.examples.bell.scores | any(.value != "0.00%" and .value != "Not measured")) and
  (.examples.battery.scores | any(.value != "0.00%" and .value != "Not measured")) and
  (.examples.circleDot.scores | any(.value != "0.00%" and .value != "Not measured")) and
  (.examples.heart.scores | any(.value != "0.00%" and .value != "Not measured")) and
  (.examples.rocket.scores | any(.value != "0.00%" and .value != "Not measured")) and
  (.examples.visibility.scores | any(.value != "0.00%" and .value != "Not measured")) and
  [.examples.viewBoxScale.scores[].value] == ["0.00%","0.00%","0.00%"]
' "$tmp/browser.json" >/dev/null

printf 'GitHub Pages browser flow: seven local examples, WASM reports, Inspector, attribution, JSON: ok\n'
