# svgdiff

`svgdiff` compares two deterministic static SVG sources and emits a layered, machine-readable visual difference report. It distinguishes authored source changes, computed visual relations, canonical raster response, spatial Difference Regions, and conservative Cause Envelopes. The report is designed for agents that cannot inspect images directly.

## Command line

Run the native CLI from the repository root:

```sh
moon run --target native cmd/main -- before.svg after.svg
```

Set the common comparison viewport or write the report to a file:

```sh
moon run --target native cmd/main -- before.svg after.svg --width 800 --height 600 --output report.json
```

Add `--html report.html` to generate a self-contained interactive report with
side-by-side sandboxed SVG previews, report-defined diff groups, region
highlighting, and the complete JSON payload.

The command exits with status `2` for invalid arguments or file I/O errors and status `1` when SVG analysis fails. A `partial` report is still emitted successfully because its Diagnostics describe exactly which evidence layers are unavailable.

## Library API

The root package exposes one comparison operation:

```text
compare(before_svg, after_svg, comparison_profile) -> StructuredReport
```

The stable JSON contract is version `1.0`; its schema is in `schema/svgdiff-report.schema.json`.

## Supported static subset

- source spans, authored values, normalized declarations, inline-style provenance, and ordinary inherited fill;
- set-to-set alignment for rect, circle, ellipse, line, polyline, and polygon subjects without treating IDs or source order as identity;
- geometry, fill, stroke, stroke width, opacity, insertion, deletion, and basic structure differences;
- exact continuous parameter magnitudes, same-domain ordering, RGBA8 raster response, connected Difference Regions, and causally complete conservative Cause Envelopes for complete reports;
- explicit `partial` or `failed` coverage with Diagnostics for unsupported or unresolved semantics.

Scripts, animation, event state, `foreignObject`, general CSS selectors, transforms, paths, filters, masks, and deterministic font shaping are not currently evaluated. Unsupported content is never silently treated as equal. The current raster channel is renderer-native RGBA8; linear-sRGB premultiplied evidence remains a renderer-conformance follow-up.

## Validation

Run the MoonBit suite and CLI integration test:

```sh
moon test --target native
sh scripts/test-cli.sh
```
