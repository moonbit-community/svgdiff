# GitHub Pages browser product

This directory is the handwritten source for the local-only SVGDiff browser
product. It is a static adapter over `modules/svgdiff/cmd/svgdiff_wasm`; comparison semantics
remain owned by the MoonBit root and engine packages.

## Build and preview

```sh
sh scripts/build-pages.sh
python3 -m http.server 4173 --directory _site
```

Open <http://127.0.0.1:4173>. Do not open `web/index.html` directly: Worker and
WebAssembly loading require an HTTP origin. `_site` is generated and ignored.

## Runtime seams

- `app.js` owns input, profile controls, file/drop admission, page state, and
  mounting the Inspector over a completed report.
- `app.js` embeds local before/after examples for color and size changes plus
  translation, rotation, non-uniform scale, skew, and combined affine
  decomposition. `examples.js` adds seven pinned real-world or equivalence
  cases with attribution in `THIRD_PARTY_NOTICES.md`. Selecting an example
  performs no network request.
- `svgdiff-worker.js` is the browser adapter for one comparison transaction. It
  accepts one complete request with a deterministic checkpoint
  budget and returns an envelope containing compact Structured Report JSON and
  the canonical engine-produced Difference raster, or a host error without a
  partial report.
- `modules/svgdiff/html_report_assets.mbt` remains the canonical Report
  Inspector behavior and styling. `scripts/build-pages.mjs` extracts those raw
  assets into `_site`, so
  the native self-contained HTML and GitHub Pages do not maintain two viewer
  implementations.
- SVG previews use empty-sandbox iframes. The Difference canvas decodes the
  canonical raster captured from the same engine run as the report instead of
  rasterizing the preview SVGs in the browser. Classification, magnitude,
  ordering, regions, causes, and Diagnostics come exclusively from the
  Structured Report.

The page intentionally has no server API, upload, remote URL fetch, login,
history, telemetry, XML text diff, combined severity score, or browser-renderer
override.

## Deployment

`.github/workflows/pages.yml` builds, uploads, and deploys `_site`
with GitHub's Pages artifact workflow. Repository maintainers must select
**GitHub Actions** as the Pages publishing source in repository settings.
