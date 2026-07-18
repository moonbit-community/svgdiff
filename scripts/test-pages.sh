#!/bin/sh
set -eu

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
    test ! -f "$tmp/browser.json" || cat "$tmp/browser.json" >&2
    tail -c 16384 "$log" >&2 || true
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
    const errors = [];
    page.on('console', message => {
      if (message.type() === 'error') errors.push(message.text());
    });
    page.on('pageerror', error => errors.push(error.message));
    await page.goto('http://127.0.0.1:$port/', { waitUntil: 'load' });
    await page.getByRole('button', { name: 'Compare SVGs' }).click();
    await page.locator('#result-section').waitFor({ state: 'visible' });
    const report = JSON.parse(await page.locator('#report-data').inputValue());
    const scores = await page.locator('.score-card').evaluateAll(cards => cards.map(card => ({
      label: card.querySelector('.score-label').textContent,
      value: card.querySelector('.score-value').textContent,
    })));
    await page.getByRole('button', { name: /Persistently highlight/ }).click();
    const overlays = await page.locator('.region').count();
    return {
      errors,
      title: await page.title(),
      status: await page.locator('#run-status').textContent(),
      analysisStatus: report.analysis_status,
      schemaVersion: report.schema_version,
      profile: report.profile,
      checkpointBudget: Number(await page.locator('#max-checkpoints').inputValue()),
      scoreCount: scores.length,
      scores,
      overlays,
      rawReportAvailable: (await page.locator('#report-data').inputValue()).length > 100,
      wasmBytes: Number(await page.locator('#report-root').getAttribute('data-compact-report-bytes')),
    };
  }" >"$tmp/browser.json" 2>>"$log"

jq -e '
  .errors == [] and
  .title == "SVGDiff — visual-semantic SVG comparison" and
  (.status | contains("Complete browser transaction: complete report")) and
  .analysisStatus == "complete" and
  .schemaVersion == "1.45" and
  .profile.viewport_width == 256 and
  .profile.viewport_height == 256 and
  .profile.perceptual_background == {"red":255,"green":255,"blue":255} and
  .profile.flip_viewing_conditions == {"pixels_per_degree":60} and
  .profile.flip_error_threshold == {"value":0.05} and
  .checkpointBudget == 1000000 and
  .scoreCount == 3 and
  [.scores[].label] == ["Changed area","Linear RGBA error","Perceptual difference"] and
  all(.scores[]; (.value | endswith("%"))) and
  .overlays == 2 and
  .rawReportAvailable == true and
  .wasmBytes > 100
' "$tmp/browser.json" >/dev/null

printf 'GitHub Pages browser flow: local WASM, three scores, Inspector, localization, JSON: ok\n'
