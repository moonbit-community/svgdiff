# Browser Rendering Oracle

Status: deterministic fixture oracle

Last verified: 2026-07-14

The browser oracle renders supported deterministic SVG fixtures in headless Chromium without entering the core comparison engine. It provides an independent raster source for renderer-conformance work; it does not by itself decide whether the pinned renderer is conformant.

## Profile

- pinned `@playwright/cli@0.1.17` by default;
- Chromium, with the exact user agent recorded in every output;
- device pixel ratio `1`;
- explicit fixture CSS viewport;
- transparent page background; PNGs retain RGBA when transparency is present, while fully opaque fixtures may be encoded as RGB;
- SVG loaded from a base64 data URL while the browser context is offline;
- no font, network, animation-time, or interaction-state fixture.

The workflow uses Playwright CLI commands. Exact transparent-background capture uses `run-code` because the ordinary CLI screenshot command does not expose `omitBackground`.

## Run

```sh
sh scripts/run-browser-oracle.sh /tmp/svgdiff-browser-oracle
python3 evaluation/browser-oracle/validate.py /tmp/svgdiff-browser-oracle
```

The output contains one PNG per manifest fixture plus `oracle-report.json` with source and PNG SHA-256 values, dimensions, browser identity, CLI version, and DPR. The output directory must be empty so stale artifacts cannot be mistaken for current evidence. The current 82-fixture set includes canonical pairs for HSL syntax, multiplied color/paint alpha, inherited paint opacity, and clamped opacity.

Run `sh scripts/test-browser-oracle.sh` to capture the fixture set twice and require byte-identical PNGs and reports. The manifest includes corpus pairs plus focused basic-shape, alpha, clipping, compositing, six-function transform, viewport, cascade, ordinary-inheritance, CSS-wide, custom-property, and `currentColor` conformance fixtures. Category and coverage-claim metadata feed the separate [renderer conformance comparison](../renderer-conformance/README.md); guarded and exploratory fixtures do not expand production coverage.
