# GitHub Pages browser product

This directory is the handwritten source for the local-only SVGDiff browser
product. It is a static adapter over `cmd/svgdiff_wasm`; comparison semantics
remain owned by the MoonBit root and engine packages.

## Build and preview

```sh
sh scripts/build-pages.sh
python3 -m http.server 4173 --directory _site
```

Open <http://127.0.0.1:4173>. Do not open `web/index.html` directly: Worker and
WebAssembly loading require an HTTP origin. `_site` is generated and ignored.

Run the real-browser acceptance gate with:

```sh
sh scripts/test-pages.sh
```

## Runtime seams

- `app.js` owns input, profile controls, file/drop admission, page state, and
  mounting the Inspector over a completed report.
- `examples.js` embeds the seven pinned before/after examples and their source
  metadata. Selecting an example performs no third-party fetch.
- `svgdiff-worker.js` is the only browser adapter for the fixed-memory ABI 1
  transaction. It accepts one complete request with a deterministic checkpoint
  budget and returns compact Structured Report JSON or a host error without a
  partial report.
- `html_report_assets.mbt` remains the canonical Report Inspector behavior and
  styling. `scripts/build-pages.mjs` extracts those raw assets into `_site`, so
  the native self-contained HTML and GitHub Pages do not maintain two viewer
  implementations.
- SVG previews use empty-sandbox iframes. Browser pixels are presentation only;
  classification, magnitude, ordering, regions, causes, and Diagnostics come
  exclusively from the Structured Report.

The page intentionally has no server API, upload, remote URL fetch, login,
history, telemetry, XML text diff, combined severity score, or browser-renderer
override.

## Deployment

`.github/workflows/pages.yml` builds, validates, uploads, and deploys `_site`
with GitHub's Pages artifact workflow. Repository maintainers must select
**GitHub Actions** as the Pages publishing source in repository settings.
