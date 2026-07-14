#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
playwright_version=${SVGDIFF_PLAYWRIGHT_CLI_VERSION:-0.1.17}
tmp=${TMPDIR:-/tmp}/svgdiff-html-security-$$
log="$tmp/playwright.log"
session="svgdiff-html-security-$$"
mkdir -p "$tmp"

if ! command -v npx >/dev/null 2>&1; then
  echo "HTML security gate requires npx from Node.js/npm" >&2
  exit 2
fi

pw() {
  npx --yes --package "@playwright/cli@$playwright_version" \
    playwright-cli --session "$session" "$@"
}

cleanup() {
  exit_status=$?
  trap - EXIT INT TERM
  pw close >>"$log" 2>&1 || true
  if [ "$exit_status" -ne 0 ]; then
    if [ -f "$tmp/browser.json" ]; then
      echo "Browser security state:" >&2
      cat "$tmp/browser.json" >&2
    fi
    tail -80 "$log" >&2 || true
  fi
  rm -rf "$tmp"
  exit "$exit_status"
}
trap cleanup EXIT INT TERM

cd "$root"
moon build --target native --release cmd/svgdiff >/dev/null
cli="$root/_build/native/release/build/cmd/svgdiff/svgdiff.exe"
"$cli" \
  evaluation/html-security/before.svg \
  evaluation/html-security/after.svg \
  --agent-json --output "$tmp/report.json" --html "$tmp/report.html"

python3 evaluation/html-security/validate.py "$tmp/report.html" "$tmp/report.json"

report_url=$(python3 -c 'import pathlib, sys; print(pathlib.Path(sys.argv[1]).resolve().as_uri())' "$tmp/report.html")
report_url_json=$(printf '%s' "$report_url" | jq -Rs .)

cd "$tmp"
pw open about:blank >>"$log" 2>&1
pw network-state-set offline >>"$log" 2>&1
pw --raw run-code \
  "async (page) => {
    const hostileRequests = [];
    page.on('request', request => {
      if (request.url().includes('svgdiff.invalid')) hostileRequests.push(request.url());
    });
    await page.goto($report_url_json, { waitUntil: 'load' });
    await page.waitForTimeout(300);
    const previews = page.frames().filter(frame => frame !== page.mainFrame());
    const previewStates = await Promise.all(previews.map(async frame => ({
      hasSvg: await frame.evaluate(() => document.querySelector('svg') !== null),
      scriptExecuted: await frame.evaluate(() => document.documentElement.getAttribute('data-script-executed')),
      handlerExecuted: await frame.evaluate(() => document.documentElement.getAttribute('data-handler-executed')),
    })));
    return {
      hostileRequests,
      parentMutated: await page.evaluate(() => window.__svgdiff_attack === true),
      summary: await page.locator('#summary').textContent(),
      previewStates,
    };
  }" >"$tmp/browser.json" 2>>"$log"

jq -e '
  .hostileRequests == [] and
  .parentMutated == false and
  (.summary | type == "string" and contains("differences")) and
  (.previewStates | length) == 2 and
  all(.previewStates[];
    .hasSvg == true and
    .scriptExecuted == null and
    .handlerExecuted == null
  )
' "$tmp/browser.json" >/dev/null

printf 'HTML security browser validation: scripts, handlers, parent, network: isolated\n'
