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
    if [ -f "$tmp/browser-interaction.json" ]; then
      echo "Browser interaction state:" >&2
      cat "$tmp/browser-interaction.json" >&2
    fi
    tail -80 "$log" >&2 || true
  fi
  rm -rf "$tmp"
  exit "$exit_status"
}
trap cleanup EXIT INT TERM

cd "$root"
moon build --target native --release modules/svgdiff/cmd/svgdiff >/dev/null
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

printf '%s\n' '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">' >"$tmp/many-before.svg"
printf '%s\n' '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">' >"$tmp/many-after.svg"
index=0
while [ "$index" -lt 40 ]; do
  x=$((index % 8 * 8 + 1))
  y=$((index / 8 * 8 + 1))
  printf '<rect id="item-%s" x="%s" y="%s" width="4" height="4" fill="red"/>\n' \
    "$index" "$x" "$y" >>"$tmp/many-before.svg"
  printf '<rect id="item-%s" x="%s" y="%s" width="4" height="4" fill="blue"/>\n' \
    "$index" "$x" "$y" >>"$tmp/many-after.svg"
  index=$((index + 1))
done
printf '%s\n' '</svg>' >>"$tmp/many-before.svg"
printf '%s\n' '</svg>' >>"$tmp/many-after.svg"
"$cli" "$tmp/many-before.svg" "$tmp/many-after.svg" \
  --width 64 --height 64 --agent-json \
  --output "$tmp/many.json" --html "$tmp/many.html"

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

"$cli" \
  evaluation/corpus/cases/equivalent-color-spelling/before.svg \
  evaluation/corpus/cases/equivalent-color-spelling/after.svg \
  --agent-json --output "$tmp/equivalent.json" --html "$tmp/equivalent.html"

"$cli" \
  evaluation/corpus/cases/subtle-geometry-shift/before.svg \
  evaluation/corpus/cases/subtle-geometry-shift/after.svg \
  --agent-json --output "$tmp/subtle.json" --html "$tmp/subtle.html"

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
many_url=$(python3 -c 'import pathlib, sys; print(pathlib.Path(sys.argv[1]).resolve().as_uri())' "$tmp/many.html")
many_url_json=$(printf '%s' "$many_url" | jq -Rs .)
incomparable_url=$(python3 -c 'import pathlib, sys; print(pathlib.Path(sys.argv[1]).resolve().as_uri())' "$tmp/incomparable.html")
incomparable_url_json=$(printf '%s' "$incomparable_url" | jq -Rs .)
partial_url=$(python3 -c 'import pathlib, sys; print(pathlib.Path(sys.argv[1]).resolve().as_uri())' "$tmp/partial.html")
partial_url_json=$(printf '%s' "$partial_url" | jq -Rs .)
equivalent_url=$(python3 -c 'import pathlib, sys; print(pathlib.Path(sys.argv[1]).resolve().as_uri())' "$tmp/equivalent.html")
equivalent_url_json=$(printf '%s' "$equivalent_url" | jq -Rs .)
subtle_url=$(python3 -c 'import pathlib, sys; print(pathlib.Path(sys.argv[1]).resolve().as_uri())' "$tmp/subtle.html")
subtle_url_json=$(printf '%s' "$subtle_url" | jq -Rs .)
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
      svgCount: await frame.locator('svg').count(),
      rootFillsViewport: await frame.locator('body > svg').evaluate(svg => {
        const bounds = svg.getBoundingClientRect();
        return Math.abs(bounds.left) < 0.5 && Math.abs(bounds.top) < 0.5 &&
          Math.abs(bounds.width - innerWidth) < 0.5 && Math.abs(bounds.height - innerHeight) < 0.5;
      }),
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
    .svgCount == 1 and
    .rootFillsViewport == true and
    .scriptExecuted == null and
    .handlerExecuted == null
  )
' "$tmp/browser.json" >/dev/null

pw --raw run-code \
  "async (page) => {
    await page.goto($interactive_url_json, { waitUntil: 'load' });
    const embedded = JSON.parse(await page.locator('#report-data').inputValue());
    const canvasScores = await page.locator('#overview .score-card').evaluateAll(cards =>
      cards.map(card => ({
        label: card.querySelector('.score-label')?.textContent,
        value: card.querySelector('.score-value')?.textContent,
      })),
    );
    await page.waitForFunction(() => document.querySelector('[data-difference-canvas]')?.dataset.state === 'ready');
    const difference = await page.locator('[data-difference-canvas]').evaluate(canvas => {
      const context = canvas.getContext('2d');
      return {
        headings: [...document.querySelectorAll('.preview h2')].map(node => node.textContent),
        width: canvas.width,
        height: canvas.height,
        state: canvas.dataset.state,
        statusHidden: document.querySelector('[data-difference-status]').hidden,
        equalPixel: [...context.getImageData(0, 0, 1, 1).data],
        changedPixel: [...context.getImageData(4, 4, 1, 1).data],
      };
    });
    const eventCount = await page.locator('.event-card[data-event-id]').count();
    const firstEvent = page.locator('.event-card[data-event-id]').first();
    const eventDetailsInitiallyHidden = await firstEvent.locator('.event-details').isHidden();
    await firstEvent.locator('[data-toggle-event]').click();
    const diffCount = await page.locator('[data-diff-id]').count();
    const firstDiff = firstEvent.locator('[data-diff-id]').first();
    const firstEventId = await firstEvent.getAttribute('data-event-id');
    const firstDiffId = await firstDiff.getAttribute('data-diff-id');
    const defaultDisclosure = {
      event: await firstEvent.locator('details.evidence').evaluate(node => node.open),
      atomic: await firstDiff.locator('details.atomic-evidence').evaluate(node => node.open),
      raw: await page.locator('details.json-panel').evaluate(node => node.open),
    };
    await firstDiff.hover();
    const hoverOverlayCount = await page.locator('.overlay .region').count();
    const conservativeOverlayCount = await page.locator('.overlay .region.conservative').count();
    await page.locator('#overview-heading').hover();
    const afterHoverOverlayCount = await page.locator('.overlay .region').count();
    const checkbox = firstDiff.locator('[data-atomic-check]');
    await checkbox.click();
    const eventCheckbox = firstEvent.locator('[data-event-check]');
    const groupCheckbox = firstEvent.locator('xpath=ancestor::section[@data-outcome-group]/*[1]/*[@data-group-check]');
    const checkboxIndependent = {
      checked: await checkbox.isChecked(),
      eventChecked: await eventCheckbox.isChecked(),
      groupChecked: await groupCheckbox.isChecked(),
      active: await firstEvent.evaluate(node => node.classList.contains('active')),
      pressed: await firstEvent.locator('[data-locate-event]').getAttribute('aria-pressed'),
    };
    await firstEvent.locator('[data-locate-event]').click();
    const selected = {
      active: await firstEvent.evaluate(node => node.classList.contains('active')),
      pressed: await firstEvent.locator('[data-locate-event]').getAttribute('aria-pressed'),
      overlayCount: await page.locator('.overlay .region').count(),
      overlayLabelCount: await page.locator('.overlay .region-label').count(),
      status: await page.locator('#selection-status').textContent(),
    };
    const beforeFrameHost = page.locator('.preview-content iframe').first();
    const beforeFrameBounds = await beforeFrameHost.boundingBox();
    const beforeSubjectBounds = await beforeFrameHost.contentFrame().locator('#box').evaluate(node => {
      const bounds = node.getBoundingClientRect();
      return { x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height };
    });
    const beforeOverlayBounds = await page.locator('.overlay').first().locator('.region.conservative').boundingBox();
    const localizationGeometryError = Math.max(
      Math.abs(beforeFrameBounds.x + beforeSubjectBounds.x - beforeOverlayBounds.x),
      Math.abs(beforeFrameBounds.y + beforeSubjectBounds.y - beforeOverlayBounds.y),
      Math.abs(beforeSubjectBounds.width - beforeOverlayBounds.width),
      Math.abs(beforeSubjectBounds.height - beforeOverlayBounds.height),
    );
    await firstEvent.locator('[data-locate-event]').click();
    const repeatedSelection = {
      active: await firstEvent.evaluate(node => node.classList.contains('active')),
      pressed: await firstEvent.locator('[data-locate-event]').getAttribute('aria-pressed'),
    };
    await firstDiff.locator('details.atomic-evidence > summary').click();
    await firstEvent.locator('details.evidence > summary').click();
    const atomicEvidenceText = await firstDiff.locator('details.atomic-evidence').textContent();
    const eventEvidenceText = await firstEvent.locator('details.evidence').textContent();
    const evidence = {
      atomicOpen: await firstDiff.locator('details.atomic-evidence').evaluate(node => node.open),
      eventOpen: await firstEvent.locator('details.evidence').evaluate(node => node.open),
      hasMagnitude: eventEvidenceText.includes('changed_pixels'),
      hasComputedReason: atomicEvidenceText.includes('computed_reason'),
      hasRegion: await firstEvent.locator('.region-card').count() > 0,
      hasFact: await firstEvent.locator('.fact-card').count() > 0,
      hasCause: eventEvidenceText.includes('Possible Causes & Limitations'),
      hasCompatibility: eventEvidenceText.includes('Schema 3.0 reports CSS-space bounds'),
    };
    await page.locator('#outcome-filter').selectOption('zero');
    const hiddenSelection = {
      visible: await page.locator('#selection-hidden').isVisible(),
      events: await page.locator('.event-card[data-event-id]').count(),
      overlays: await page.locator('.overlay .region').count(),
      status: await page.locator('#selection-status').textContent(),
    };
    await page.locator('#show-selection').click();
    const restoredSelection = {
      visible: await firstEvent.isVisible(),
      overlays: await page.locator('.overlay .region').count(),
    };
    await page.locator('#zoom-in').click();
    const transforms = await page.locator('.preview-content').evaluateAll(nodes => nodes.map(node => node.style.transform));
    const zoom = await page.locator('#zoom-value').textContent();
    await page.locator('#clear-selection-global').click();
    const clearedOverlayCount = await page.locator('.overlay .region').count();
    await firstEvent.locator('.event-identity').click();
    const cardSelection = {
      active: await firstEvent.evaluate(node => node.classList.contains('active')),
      overlayCount: await page.locator('.overlay .region').count(),
    };
    await page.locator('#clear-selection-global').click();
    await firstEvent.focus();
    await firstEvent.press('Enter');
    const keyboard = {
      active: await firstEvent.evaluate(node => node.classList.contains('active')),
      overlayCount: await page.locator('.overlay .region').count(),
    };
    await firstEvent.locator('[data-toggle-event]').click();
    const accessible = {
      checkboxLabel: await checkbox.getAttribute('aria-label'),
      eventCheckboxLabel: await eventCheckbox.getAttribute('aria-label'),
      groupCheckboxLabel: await groupCheckbox.getAttribute('aria-label'),
      locateLabel: await firstEvent.locator('[data-locate-event]').getAttribute('aria-label'),
      jsonLabel: await page.locator('#report-data').getAttribute('aria-label'),
      copyLabel: await page.locator('#copy-json').textContent(),
      downloadLabel: await page.locator('#download-json').textContent(),
    };
    await page.locator('details.json-panel > summary').click();
    const [download] = await Promise.all([
      page.waitForEvent('download'),
      page.locator('#download-json').click(),
    ]);
    const rawActions = {
      open: await page.locator('details.json-panel').evaluate(node => node.open),
      filename: download.suggestedFilename(),
    };
    await page.reload({ waitUntil: 'load' });
    await page.locator('[data-toggle-event]').first().click();
    const sessionReset = await page.locator('[data-atomic-check]').first().isChecked();
    await page.goto($tied_url_json, { waitUntil: 'load' });
    const tiedPoint = page.locator('.impact-point').first();
    const tiedCluster = {
      pointCount: await page.locator('.impact-point').count(),
      eventCount: Number(await tiedPoint.getAttribute('data-event-count')),
      label: await tiedPoint.getAttribute('aria-label'),
    };
    await tiedPoint.click();
    tiedCluster.firstSelection = await page.locator('#selection-status').textContent();
    await tiedPoint.click();
    tiedCluster.secondSelection = await page.locator('#selection-status').textContent();
    await page.goto($many_url_json, { waitUntil: 'load' });
    const manyReport = JSON.parse(await page.locator('#report-data').inputValue());
    const incrementalEvents = {
      reportEvents: manyReport.events.length,
      initialCards: await page.locator('.event-card').count(),
      initialLoadButtons: await page.locator('.load-more').count(),
      initialLoadText: await page.locator('.load-more').first().textContent(),
    };
    await page.locator('.load-more').first().click();
    incrementalEvents.finalCards = await page.locator('.event-card').count();
    incrementalEvents.finalLoadButtons = await page.locator('.load-more').count();
    const states = {};
    for (const [name, url] of Object.entries({
      tied: $tied_url_json,
      incomparable: $incomparable_url_json,
      partial: $partial_url_json,
      equivalent: $equivalent_url_json,
      subtle: $subtle_url_json,
      empty: $empty_url_json,
      failed: $failed_url_json,
    })) {
      await page.goto(url, { waitUntil: 'load' });
      const detailButtons = page.locator('[data-toggle-event]');
      for (let index = 0; index < await detailButtons.count(); index += 1) {
        await detailButtons.nth(index).click();
      }
      states[name] = {
        overview: await page.locator('#overview').textContent(),
        diffs: await page.locator('#diffs').textContent(),
        effectiveValues: await page.locator('.effective-value').allTextContents(),
        effectiveValueTitles: await page.locator('.effective-value').evaluateAll(nodes => nodes.map(node => node.title)),
        groups: await page.locator('.outcome-group').count(),
        points: await page.locator('.impact-point').count(),
      };
    }
    return {
      firstEventId,
      firstDiffId,
      diffCount,
      eventCount,
      eventDetailsInitiallyHidden,
      reportDiffCount: embedded.difference_groups.reduce((count, group) => count + group.items.length, 0),
      reportEventCount: embedded.events.length,
      canvasScores,
      difference,
      groupOrder: await page.locator('.group-header h3').allTextContents().catch(() => []),
      defaultDisclosure,
      hoverOverlayCount,
      conservativeOverlayCount,
      afterHoverOverlayCount,
      checkboxIndependent,
      selected,
      localizationGeometryError,
      repeatedSelection,
      evidence,
      hiddenSelection,
      restoredSelection,
      transforms,
      zoom,
      clearedOverlayCount,
      cardSelection,
      keyboard,
      accessible,
      rawActions,
      sessionReset,
      tiedCluster,
      incrementalEvents,
      states,
    };
  }" >"$tmp/browser-interaction.json" 2>>"$log"

jq -e '
  . as $result |
  .diffCount == .reportDiffCount and
  .eventCount == .reportEventCount and
  .eventDetailsInitiallyHidden == true and
  .reportDiffCount == 1 and
  .canvasScores == [
    {"label": "Changed area", "value": "25.00%"},
    {"label": "Linear RGBA error", "value": "35.36%"},
    {"label": "Perceptual difference", "value": "Not measured"}
  ] and
  .difference == {
    "headings": ["Before", "Difference", "After"],
    "width": 16,
    "height": 16,
    "state": "ready",
    "statusHidden": true,
    "equalPixel": [0, 0, 0, 255],
    "changedPixel": [255, 0, 255, 255]
  } and
  .defaultDisclosure == {"event": false, "atomic": false, "raw": false} and
  .hoverOverlayCount == 2 and
  .conservativeOverlayCount == 2 and
  .afterHoverOverlayCount == 0 and
  .checkboxIndependent == {
    "checked": true,
    "eventChecked": true,
    "groupChecked": true,
    "active": false,
    "pressed": "false"
  } and
  .selected.active == true and
  .selected.pressed == "true" and
  .selected.overlayCount == 2 and
  .selected.overlayLabelCount == 0 and
  (.selected.status | contains($result.firstEventId)) and
  .localizationGeometryError <= 1 and
  .repeatedSelection == {"active": true, "pressed": "true"} and
  .evidence == {
    "atomicOpen": true,
    "eventOpen": true,
    "hasMagnitude": true,
    "hasComputedReason": false,
    "hasRegion": true,
    "hasFact": true,
    "hasCause": true,
    "hasCompatibility": true
  } and
  .hiddenSelection.visible == true and
  .hiddenSelection.events == 0 and
  .hiddenSelection.overlays == 0 and
  (.hiddenSelection.status | contains("selected but hidden")) and
  .restoredSelection == {"visible": true, "overlays": 2} and
  (.transforms | length == 3 and .[0] == .[1] and .[1] == .[2]) and
  .zoom == "125%" and
  .clearedOverlayCount == 0 and
  .cardSelection == {"active": true, "overlayCount": 2} and
  .keyboard == {"active": true, "overlayCount": 2} and
  (.accessible.checkboxLabel | startswith("Mark ")) and
  (.accessible.eventCheckboxLabel | startswith("Mark all Atomic Differences")) and
  (.accessible.groupCheckboxLabel | startswith("Mark all ")) and
  (.accessible.locateLabel | startswith("Persistently highlight")) and
  .accessible.jsonLabel == "Complete Structured Report JSON" and
  .accessible.copyLabel == "Copy JSON" and
  .accessible.downloadLabel == "Download JSON" and
  .rawActions == {"open": true, "filename": "svgdiff-report.json"} and
  .sessionReset == false and
  .tiedCluster.pointCount == 1 and
  .tiedCluster.eventCount == 2 and
  (.tiedCluster.label | contains("repeated activation cycles")) and
  (.tiedCluster.firstSelection != .tiedCluster.secondSelection) and
  .incrementalEvents == {
    "reportEvents": 40,
    "initialCards": 24,
    "initialLoadButtons": 1,
    "initialLoadText": "Load 16 more · 16 remaining",
    "finalCards": 40,
    "finalLoadButtons": 0
  } and
  (.states.tied.overview | contains("does not invent a universal severity ranking")) and
  (.states.incomparable.overview | contains("does not invent a universal severity ranking")) and
  .states.incomparable.points == 2 and
  (.states.partial.overview | contains("Analysis is partial")) and
  (.states.equivalent.diffs | contains("red → #ff0000")) and
  (.states.equivalent.diffs | contains("Canvas Response0 pixels (0)")) and
  (.states.subtle.diffs | contains("1.0 → 0.99999")) and
  (.states.subtle.diffs | contains("Parameter: ≈1.000e-5 CSS px")) and
  (.states.empty.diffs | contains("No Atomic Differences")) and
  (.states.failed.overview | contains("Analysis failed")) and
  (.states.failed.diffs | contains("No Atomic Differences"))
' "$tmp/browser-interaction.json" >/dev/null

printf 'HTML security browser validation: scripts, handlers, parent, network: isolated\n'
printf 'HTML evidence browser validation: measurements, details, causes, regions, controls: ok\n'
