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
cli="$root/_build/native/release/build/Milky2018/svgdiff/cmd/svgdiff/svgdiff.exe"
"$cli" \
  evaluation/html-security/before.svg \
  evaluation/html-security/after.svg \
  --agent-json --output "$tmp/report.json" --html "$tmp/report.html"

"$cli" testdata/before.svg testdata/after.svg \
  --agent-json --output "$tmp/interactive.json" --html "$tmp/interactive.html"

printf '%s\n' \
  "<svg width='16' height='16'><rect id='a' x='1' y='1' width='4' height='4' fill='red'/><rect id='b' x='10' y='10' width='4' height='4' fill='red'/></svg>" \
  >"$tmp/tied-before.svg"
printf '%s\n' \
  "<svg width='16' height='16'><rect id='a' x='1' y='1' width='4' height='4' fill='blue'/><rect id='b' x='10' y='10' width='4' height='4' fill='blue'/></svg>" \
  >"$tmp/tied-after.svg"
"$cli" "$tmp/tied-before.svg" "$tmp/tied-after.svg" \
  --agent-json --output "$tmp/tied.json" --html "$tmp/tied.html"

printf '%s\n' \
  "<svg width='16' height='16'><rect id='large' x='0' y='0' width='8' height='8' fill='#ff0000'/><rect id='small' x='12' y='12' width='2' height='2' fill='#ff0000'/></svg>" \
  >"$tmp/incomparable-before.svg"
printf '%s\n' \
  "<svg width='16' height='16'><rect id='large' x='0' y='0' width='8' height='8' fill='#fe0000'/><rect id='small' x='12' y='12' width='2' height='2' fill='#0000ff'/></svg>" \
  >"$tmp/incomparable-after.svg"
"$cli" "$tmp/incomparable-before.svg" "$tmp/incomparable-after.svg" \
  --agent-json --output "$tmp/incomparable.json" \
  --html "$tmp/incomparable.html"

"$cli" \
  evaluation/schema-examples/cases/marker-equivalent/before.svg \
  evaluation/schema-examples/cases/marker-equivalent/after.svg \
  --agent-json --output "$tmp/partial.json" --html "$tmp/partial.html"

"$cli" testdata/before.svg testdata/before.svg \
  --agent-json --output "$tmp/empty.json" --html "$tmp/empty.html"

printf '%s\n' '<svg><rect></svg>' >"$tmp/failed.svg"
set +e
"$cli" "$tmp/failed.svg" testdata/after.svg \
  --agent-json --output "$tmp/failed.json" --html "$tmp/failed.html"
failed_status=$?
set -e
test "$failed_status" -eq 1

python3 evaluation/html-security/validate.py "$tmp/report.html" "$tmp/report.json"

report_url=$(python3 -c 'import pathlib, sys; print(pathlib.Path(sys.argv[1]).resolve().as_uri())' "$tmp/report.html")
report_url_json=$(printf '%s' "$report_url" | jq -Rs .)
interactive_url=$(python3 -c 'import pathlib, sys; print(pathlib.Path(sys.argv[1]).resolve().as_uri())' "$tmp/interactive.html")
interactive_url_json=$(printf '%s' "$interactive_url" | jq -Rs .)
tied_url=$(python3 -c 'import pathlib, sys; print(pathlib.Path(sys.argv[1]).resolve().as_uri())' "$tmp/tied.html")
tied_url_json=$(printf '%s' "$tied_url" | jq -Rs .)
incomparable_url=$(python3 -c 'import pathlib, sys; print(pathlib.Path(sys.argv[1]).resolve().as_uri())' "$tmp/incomparable.html")
incomparable_url_json=$(printf '%s' "$incomparable_url" | jq -Rs .)
partial_url=$(python3 -c 'import pathlib, sys; print(pathlib.Path(sys.argv[1]).resolve().as_uri())' "$tmp/partial.html")
partial_url_json=$(printf '%s' "$partial_url" | jq -Rs .)
empty_url=$(python3 -c 'import pathlib, sys; print(pathlib.Path(sys.argv[1]).resolve().as_uri())' "$tmp/empty.html")
empty_url_json=$(printf '%s' "$empty_url" | jq -Rs .)
failed_url=$(python3 -c 'import pathlib, sys; print(pathlib.Path(sys.argv[1]).resolve().as_uri())' "$tmp/failed.html")
failed_url_json=$(printf '%s' "$failed_url" | jq -Rs .)

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

pw --raw run-code \
  "async (page) => {
    await page.goto($interactive_url_json, { waitUntil: 'load' });
    const embedded = JSON.parse(await page.locator('#report-data').inputValue());
    const diffCount = await page.locator('[data-diff-id]').count();
    const first = page.locator('[data-diff-id]').first();
    const firstId = await first.getAttribute('data-diff-id');
    await first.hover();
    const hoverOverlayCount = await page.locator('.overlay .region').count();
    await page.locator('#impact-heading').hover();
    const afterHoverOverlayCount = await page.locator('.overlay .region').count();
    const checkbox = first.locator('input[type=checkbox]');
    await checkbox.click();
    const checkboxIndependent = {
      checked: await checkbox.isChecked(),
      active: await first.evaluate(node => node.classList.contains('active')),
      pressed: await first.locator('[data-locate]').getAttribute('aria-pressed'),
    };
    await first.locator('[data-locate]').click();
    const selected = {
      active: await first.evaluate(node => node.classList.contains('active')),
      pressed: await first.locator('[data-locate]').getAttribute('aria-pressed'),
      overlayCount: await page.locator('.overlay .region').count(),
      status: await page.locator('#selection-status').textContent(),
    };
    await first.locator('details.evidence > summary').click();
    const evidenceText = await first.locator('details.evidence').textContent();
    const evidence = {
      open: await first.locator('details.evidence').evaluate(node => node.open),
      hasMagnitude: evidenceText.includes('magnitude.raster_changed_pixel_fraction'),
      hasEvent: await first.locator('.event-card').count() > 0,
      hasRegion: await first.locator('.region-card').count() > 0,
      hasFact: await first.locator('.fact-card').count() > 0,
      hasCause: evidenceText.includes('Possible Changed Fact causes'),
    };
    await page.locator('#clear-selection').click();
    const clearedOverlayCount = await page.locator('.overlay .region').count();
    await first.focus();
    await first.press('Enter');
    const keyboard = {
      active: await first.evaluate(node => node.classList.contains('active')),
      overlayCount: await page.locator('.overlay .region').count(),
    };
    const accessible = {
      checkboxLabel: await checkbox.getAttribute('aria-label'),
      locateLabel: await first.locator('[data-locate]').getAttribute('aria-label'),
      jsonLabel: await page.locator('#report-data').getAttribute('aria-label'),
    };
    const states = {};
    for (const [name, url] of Object.entries({
      tied: $tied_url_json,
      incomparable: $incomparable_url_json,
      partial: $partial_url_json,
      empty: $empty_url_json,
      failed: $failed_url_json,
    })) {
      await page.goto(url, { waitUntil: 'load' });
      states[name] = {
        impact: await page.locator('#impact').textContent(),
        diffs: await page.locator('#diffs').textContent(),
        groups: await page.locator('.frontier-group').count(),
      };
    }
    return {
      firstId,
      diffCount,
      reportDiffCount: embedded.atomic_differences.length,
      impactPolicy: embedded.impact_assessment.policy_id,
      hoverOverlayCount,
      afterHoverOverlayCount,
      checkboxIndependent,
      selected,
      evidence,
      clearedOverlayCount,
      keyboard,
      accessible,
      states,
    };
  }" >"$tmp/browser-interaction.json" 2>>"$log"

jq -e '
  . as $result |
  .diffCount == .reportDiffCount and
  .reportDiffCount == 1 and
  .impactPolicy == "event_rendered_pareto/v1" and
  .hoverOverlayCount == 2 and
  .afterHoverOverlayCount == 0 and
  .checkboxIndependent == {"checked": true, "active": false, "pressed": "false"} and
  .selected.active == true and
  .selected.pressed == "true" and
  .selected.overlayCount == 2 and
  (.selected.status | contains($result.firstId)) and
  .evidence == {
    "open": true,
    "hasMagnitude": true,
    "hasEvent": true,
    "hasRegion": true,
    "hasFact": true,
    "hasCause": true
  } and
  .clearedOverlayCount == 0 and
  .keyboard == {"active": true, "overlayCount": 2} and
  (.accessible.checkboxLabel | startswith("Mark ")) and
  (.accessible.locateLabel | startswith("Persistently highlight")) and
  .accessible.jsonLabel == "Complete Structured Report JSON" and
  (.states.tied.impact | contains("exactly tied")) and
  .states.tied.groups == 1 and
  (.states.incomparable.impact | contains("incomparable under this policy")) and
  .states.incomparable.groups == 2 and
  (.states.partial.impact | contains("Analysis is partial")) and
  (.states.partial.impact | contains("unavailable is not zero")) and
  (.states.empty.impact | contains("No candidate Visual Events")) and
  (.states.empty.diffs | contains("No Atomic Differences")) and
  (.states.failed.impact | contains("Analysis failed")) and
  (.states.failed.diffs | contains("No Atomic Differences"))
' "$tmp/browser-interaction.json" >/dev/null

printf 'HTML security browser validation: scripts, handlers, parent, network: isolated\n'
printf 'HTML evidence browser validation: impact, details, causes, regions, controls: ok\n'
