# svgdiff

`svgdiff` compares two deterministic static SVG sources and emits a layered, machine-readable visual difference report. It distinguishes authored source changes, computed visual relations, canonical raster response, spatial Difference Regions, and conservative Cause Envelopes. The report is designed for agents that cannot inspect images directly.

## Command line

Run the native CLI from the repository root:

```sh
moon run --target native cmd/svgdiff -- before.svg after.svg
```

Set the common comparison viewport or write the report to a file:

```sh
moon run --target native cmd/svgdiff -- before.svg after.svg --width 800 --height 600 --output report.json
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

The stable JSON contract is version `1.0`; its contract is described by the [JSON Schema](schema/svgdiff-report.schema.json) and [core comparison model](docs/core-model.md). The v1 profile records the common viewport, DPR `1.0`, sRGB interpretation, canonical linear-sRGB premultiplied-RGBA arithmetic, and the pinned renderer identity. Reports retain renderer-native RGBA8 RMSE alongside the canonical linear metric.

The root package is the stable product seam. Its implementation lives in the formal `engine` package; only renderer and provenance experiments remain under `prototype`.

## Supported static subset

- source spans, authored values, normalized declarations, inline-style provenance, and ordinary inherited fill;
- set-to-set alignment for rect, circle, ellipse, line, polyline, and polygon subjects without treating IDs or source order as identity;
- geometry, fill, stroke, stroke width, opacity, insertion, deletion, and basic structure differences;
- exact continuous parameter magnitudes, same-domain ordering, RGBA8 raster response, connected Difference Regions, and causally complete conservative Cause Envelopes for complete reports;
- explicit `partial` or `failed` coverage with Diagnostics for unsupported or unresolved semantics.

Scripts, animation, event state, `foreignObject`, general CSS selectors, transforms, paths, filters, masks, and deterministic font shaping are not currently evaluated. Unsupported content is never silently treated as equal.

The current renderer dependency does not yet guarantee that inline `style`
overrides a conflicting presentation attribute independently of XML attribute
order. Such overlap emits `renderer_style_precedence_unresolved` and reduces
the report to `partial`; Source Semantics remains normalized, while Computed
Appearance and Rendered Evidence must be treated as unavailable until the
upstream fix is released.

The complete implementation boundary, including guarded partial cases, is in the [current v1 support contract](docs/v1-scope.md).

## Documentation

- [Documentation guide](docs/README.md): authority, reading order, and maintenance rules;
- [Current v1 support](docs/v1-scope.md): implemented, partial, unsupported, and deferred capabilities;
- [Feature coverage matrix](docs/feature-coverage.md): links support claims to Diagnostics and tests;
- [Analysis status contract](docs/analysis-status.md): exact guarantees for complete, partial, and failed reports;
- [Core comparison model](docs/core-model.md): report concepts and invariants;
- [Post-v1 roadmap](roadmap.md): all known unfinished product work;
- [ADR index](docs/adr/README.md): architectural decisions and supersession status;
- [Research index](docs/research/README.md): dated experiments and rejected alternatives;
- [Issue index](issues/README.md): generated execution history.

## Validation

Run the MoonBit suite and CLI integration test:

```sh
moon test --target native
sh scripts/test-cli.sh
```
