# svgdiff

`svgdiff` compares two deterministic static SVG sources and emits a layered, machine-readable visual difference report. It distinguishes authored source changes, canonical used geometry, deterministic sRGB solid color and opacity semantics, computed visual relations, raster response, spatial Difference Regions, and conservative Cause Envelopes. The report is designed for agents that cannot inspect images directly.

## Install locally

With MoonBit installed, build and install the native release executable into the default user bin directory:

```sh
sh scripts/install.sh
export PATH="$HOME/.local/bin:$PATH"
svgdiff before.svg after.svg
```

The installer prints whether its destination is already on `PATH`. Choose another directory, including an existing user-writable PATH directory, with:

```sh
sh scripts/install.sh --bindir "$HOME/bin"
```

`SVGDIFF_INSTALL_DIR` provides the same destination override. This source installation builds for the current operating system and architecture. For a prebuilt CLI, download the `linux-x64`, `windows-x64`, or `macos-arm64` archive and the archive-level `SHA256SUMS` from the matching versioned GitHub Release; verification and internal bundle layout are documented in [`release/README.md`](release/README.md). Package-manager installation remains separate work.

Install Bash, Zsh, or Fish completion separately with `sh scripts/install-completions.sh <shell>`. Shell-specific locations, Zsh activation, and the package-manager release prerequisite are documented in [`completions/README.md`](completions/README.md).

Generate a current-host native release bundle with `sh scripts/package-release.sh`; add `--archive` for the distributable `.tar.gz`. Version-matched tags publish tested `linux-x64`, `windows-x64`, and `macos-arm64` archives plus archive checksums through GitHub Releases. Every archive includes internal checksums, transparent build provenance, the project license, and versioned third-party notices; its exact guarantees and non-guarantees are documented in [`release/README.md`](release/README.md).

## Command line

Inspect the installed command and every version that affects report interpretation:

```sh
svgdiff --help
svgdiff --version
```

Version output identifies the `svgdiff` module and engine, Structured Report schema, pinned renderer, renderer conformance profile, and domain-ordering policy. These identities must be reviewed together when their corresponding contracts change, but they advance independently under the [compatibility and versioning contract](docs/versioning.md).

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

The command exits with status `2` for invalid arguments or file I/O errors and status `1` when SVG analysis fails, including malformed input, a fixed resource-limit rejection, or an unsafe local-reference graph. A `partial` report is still emitted successfully because its Diagnostics describe exactly which evidence layers are unavailable. Admission failures return a small report rather than a truncated difference inventory; fixed budgets are documented in [`docs/resource-limits.md`](docs/resource-limits.md), and cycle plus transitive `<use>` expansion handling is documented in [`docs/reference-safety.md`](docs/reference-safety.md).

## Library API

Install module version `0.4.14` with `moon add Milky2018/svgdiff@0.4.14` after that release is published. The latest independently verified Mooncakes publication remains `0.3.3`; its focused [registry README](PACKAGE.mbt.md) and [Mooncakes page](https://mooncakes.io/docs/Milky2018/svgdiff) describe the consumable package. Repository-only design, evaluation, and maintenance artifacts are deliberately excluded from registry archives.

The root package exposes unlimited and cooperatively controlled comparison operations:

```text
compare(before_svg, after_svg, comparison_profile) -> StructuredReport
compare_with_control(before_svg, after_svg, comparison_profile, control) -> StructuredReport raises ComparisonInterrupted
```

The current JSON contract is version `1.20`; its contract is described by the [JSON Schema](schema/svgdiff-report.schema.json) and [core comparison model](docs/core-model.md). The v1 profile records the common viewport, DPR `1.0`, sRGB interpretation, canonical linear-sRGB premultiplied-RGBA arithmetic, versioned production renderer identity, and `svgdiff-renderer-conformance-profile/17`. The conformance profile versions accepted renderer fixtures, dispositions, and guards independently from the report shape and renderer package. Reports retain renderer-native RGBA8 RMSE alongside the canonical linear metric.

Static same-document linear and radial gradients are compared as structured resources plus consumer-specific paint: geometry, units, spread, transforms, recursive templates, every stop, and every fill/stroke consequence remain individually reportable. Their source and computed semantics are complete for the admitted sRGB slice; the current pinned renderer still carries an explicit gradient-raster guard.

Static same-document patterns over the admitted basic-shape child slice use the same resource/consumer separation: tile and content coordinates, transforms, viewport mapping, recursive templates, child operations, and every fill/stroke consequence remain individually reportable. Their computed semantics do not depend on the pinned renderer, whose pattern rasterization remains explicitly guarded.

`fill` and `stroke` also implement the SVG 2 URL fallback grammar. A valid same-document gradient or pattern wins; a missing or wrong-kind local target selects its optional solid color, `currentColor`, or `none` fallback, and an absent fallback deterministically means no paint. Inactive fallbacks remain source-visible without creating computed dependencies, while external target validity stays guarded.

Inherited `paint-order`, `fill-rule`, and `clip-rule` are resolved through the same cascade and dependency model. Paint order is compared by its active operation sequence, fill rules collapse when the fill is inactive or the contour is provably simple, and clip rules outside `clipPath` are inactive. Clip-path construction and host application remain explicitly guarded until the later clipping milestone.

The root package is the stable product seam. Its implementation lives in the formal `engine` package; historical experiment findings are retained under `docs/research`.

Embedding agents may construct a `ComparisonControl` with a cancellation predicate and optional elapsed-time budget. `compare_with_control` raises typed `Cancelled` or `TimeBudgetExceeded` control flow and returns no report on interruption; it never presents truncated evidence as a failed analysis. Checks are cooperative, so a synchronous dependency parse or render call may finish before expiry is observed. The ordinary `compare` and CLI remain unlimited.

### Compare SVG sources

This example is compiled and run as part of `moon check` and `moon test`:

```mbt check
///|
test "compare two SVG strings" {
  let before = "<svg width='32' height='24'><rect id='box' x='2' y='2' width='8' height='8' fill='red'/></svg>"
  let after = "<svg width='32' height='24'><rect id='box' x='3' y='2' width='8' height='8' fill='blue'/></svg>"
  let profile = {
    ..@svgdiff.ComparisonProfile::v1_default(),
    viewport_width: 32,
    viewport_height: 24,
  }
  let report = @svgdiff.compare(before, after, profile)
  assert_eq(report.schema_version, "1.20")
  assert_eq(report.analysis_status, "complete")
  assert_true(report.atomic_differences.length() >= 2)
  assert_true(report.events.length() > 0)
}
```

Always inspect `analysis_status` and `diagnostics` before treating an empty difference list as equality:

```mbt check
///|
test "partial analysis does not imply equality" {
  let unsupported = "<svg width='16' height='16'><path d='M0 0 L8 8'/></svg>"
  let report = @svgdiff.compare(
    unsupported,
    unsupported,
    @svgdiff.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "partial")
  assert_eq(report.atomic_differences.length(), 0)
  assert_true(report.diagnostics.length() > 0)
}
```

### Serialize or render the result

```mbt check
///|
test "serialize JSON and build the HTML presentation" {
  let before = "<svg width='16' height='16'><rect width='8' height='8' fill='red'/></svg>"
  let after = "<svg width='16' height='16'><rect width='8' height='8' fill='blue'/></svg>"
  let report = @svgdiff.compare(
    before,
    after,
    @svgdiff.ComparisonProfile::v1_default(),
  )
  let json = report.to_json_string()
  let compact_json = report.to_compact_json_string()
  let html = @svgdiff.render_html_report(before, after, report)
  assert_true(json.find("\"schema_version\": \"1.20\"") is Some(_))
  assert_true(compact_json.length() < json.length())
  assert_true(html.find("<!doctype html>") is Some(_))
  assert_true(html.find("sandbox=\"\"") is Some(_))
}
```

The [public API guide](docs/library-api.md) groups all exported report types and documents how to inspect generated MoonBit API documentation.

The CLI option `--agent-json` emits the same schema and evidence without formatting whitespace. It can be combined with `--output`; default output remains the indented canonical representation.

## Supported static subset

- source spans, authored values, normalized declarations, presentation/inline/static-stylesheet cascade provenance including specificity, source order, duplicates, and `!important`, plus ordinary inheritance and CSS-wide defaulting for every supported visual property;
- case-sensitive inherited custom properties with bounded nested `var()` fallback, `currentColor` dependencies, and causal fan-out into supported geometry, paint, stroke, opacity, vector-effect, marker attachment, and admitted gradient stop colors;
- set-to-set alignment for rect, circle, ellipse, line, polyline, polygon, and guarded path subjects without treating IDs or source order as identity;
- geometry, exact normalized path parameter and topology, fill, stroke paint, canonical length-aware stroke width/caps/joins/miter limits/dashes/dash offsets/vector effects, local marker attachments and length-aware resource viewport/orientation properties, opacity, insertion, deletion, and basic structure differences;
- root and nested SVG viewport declarations, nearest-viewport percentage resolution, and exact cumulative coordinate mappings under one explicit common Comparison Viewport;
- exact continuous parameter magnitudes, same-domain ordering, RGBA8 raster response, connected Difference Regions, and causally complete conservative Cause Envelopes for complete reports;
- explicit `partial` or `failed` coverage with Diagnostics for unsupported or unresolved semantics.

Current Diagnostics also emit `source_locations`: each location names the `before` or `after` SVG and a half-open UTF-16 span. Malformed XML retains the parser's exact error span, and source-anchored limitations merge all applicable locations under one stable Diagnostic ID. An empty array is reserved for comparison-global or derived conditions; legacy reports may omit the optional JSON field.

Scripts, animation, event state, `foreignObject`, selectors outside the documented deterministic static scope, cascade layers and non-author origins, complete CSS tokenization and registered custom properties, system colors, complete path semantics, marker child paint/cascade/context paint, external marker references, path-length calibration, font- or environment-relative lengths, arithmetic length syntax, filters, masks, and deterministic font shaping are not currently evaluated. `revert-layer`, malformed or excluded variable syntax, and excessive variable expansion remain explicitly guarded. Local marker attachments and admitted marker lengths are parsed into deterministic placements and conservative clipped envelopes, but marker Chromium fixtures diverge from the pinned renderer and remain guarded. Path data is strictly parsed into normalized absolute segments with authored spans. SVG `transform` lists and root or nested viewport mappings are strictly parsed into cumulative affine matrices; authored declarations remain visible even when mappings are equivalent. Canonical typed transform effects separately report translation, rotation, signed scale, skew, or an exact singular residual matrix. Integer axis-aligned transforms and viewport mappings have accepted browser-conformance fixtures, while general affine rasterization and non-integer viewport mappings remain guarded. Root intrinsic `width` and `height` never select separate before/after canvases: the profile supplies one common Comparison Viewport. Resource-local transforms, automatic viewport inference, and precise transform-aware bounds remain later roadmap items. Unsupported content is never silently treated as equal.

Fractional geometry, fractional leaf opacity, and referenced gradient or pattern raster measurements currently remain numeric pinned-renderer observations, but their Rendered Evidence coverage is limited by stable conformance Diagnostics. Exact source and computed differences remain available; consumers must not treat those raster values as browser-conformant.

Current reports project renderer-specific limitations encountered by the inputs into `renderer_capability_gaps`. Each record provides a stable capability ID, `guarded` or `unavailable` support status, and establishing Diagnostic IDs. An empty array does not claim that the renderer supports all SVG features; the coverage matrix remains authoritative.

The production renderer identity includes private style-precedence, ordinary-inheritance, CSS-computed-value, length-used-value, stroke-used-geometry, and basic-shape-used-geometry normalizers in front of `mizchi/svg@0.2.1`. These adapters rewrite only the renderer-input copy; the original source remains authoritative for authored facts, provenance, and spans. Incomplete or unsupported syntax remains unchanged and keeps the affected evidence partial through stable Diagnostics.

The complete implementation boundary, including guarded partial cases, is in the [current v1 support contract](docs/v1-scope.md).

The hand-authored [evaluation corpus](evaluation/corpus/README.md) contains stable SVG pairs for equivalent, subtle, salient, structural, resource-mediated, zero-contribution, and unsupported cases. Run `sh scripts/test-corpus.sh` to validate every pair through the production CLI.

The complementary [mutation suite](evaluation/mutations/README.md) generates deterministic pairs with independently declared Changed Facts and affected subjects. Run `sh scripts/test-mutations.sh` to verify generation and report retention.

The [adversarial suite](evaluation/adversarial/README.md) checks malformed transform and viewport false-complete cases, false equality, source-order alignment, attribution leakage, magnitude ordering, and unsafe reference graphs through the production CLI. Run `sh scripts/test-adversarial.sh` to execute each safety invariant twice and verify deterministic results.

The [compatibility corpus](evaluation/compatibility/README.md) generates current, legacy-additive, future-additive, unknown-schema, and unknown-ordering-policy report variants. Run `sh scripts/test-compatibility.sh` to verify deterministic consumer dispatch and validation against every entry in the [released Schema registry](schema/registry.v1.json) before semantic interpretation.

The [canonical Structured Report examples](schema/examples/README.md) are byte-for-byte production CLI outputs for equivalent spelling, cascade and inheritance equivalence, tiny numeric change, salient change, insertion, deletion, resources, viewport mapping, partial coverage, and failed admission. Run `sh scripts/test-schema-examples.sh` to validate them against the current Schema and semantic manifest.

The [determinism evaluation](evaluation/determinism/README.md) repeats equivalent, changed, structural, resource, unsupported, multi-event, and non-default-viewport comparisons in separate CLI processes. Run `sh scripts/test-report-determinism.sh` to verify byte-stable output, globally unique report-local IDs, closed references, and identical evidence in default and compact JSON. CI also compares exact canonical bundles across Ubuntu 24.04 x64, Windows Server 2025 x64, and macOS 15 arm64; `sh scripts/test-cross-platform-determinism.sh` exercises the same aggregation policy locally with positive and negative controls.

The [performance suites](evaluation/performance/README.md) independently time parse/admission, alignment, rendering, region extraction, provenance, and serialization through native release microbenchmarks, then enforce representative small, medium, and large end-to-end native CLI wall-time and peak-RSS ceilings. Run `sh scripts/run-stage-benchmarks.sh --output /tmp/svgdiff-stage-benchmarks.json` for stage diagnostics and `sh scripts/run-performance-budgets.sh --output /tmp/svgdiff-performance-budgets.json` for the regression gate. Both are distinct from the Agent-quality benchmark.

## Documentation

- [Documentation guide](docs/README.md): authority, reading order, and maintenance rules;
- [Current v1 support](docs/v1-scope.md): implemented, partial, unsupported, and deferred capabilities;
- [Feature coverage matrix](docs/feature-coverage.md): links support claims to Diagnostics and tests;
- [Analysis status contract](docs/analysis-status.md): exact guarantees for complete, partial, and failed reports;
- [Text-only agent guide](docs/agent-report-guide.md): report reading procedure and worked examples;
- [Structured Report examples](schema/examples/README.md): complete machine-readable examples for core agent interpretation cases;
- [Report determinism](docs/report-determinism.md): repeated-output, report-local ID, reference-closure, and source-subject identity guarantees;
- [MoonBit library API](docs/library-api.md): public operations, report types, and generated documentation commands;
- [Upgrade procedures](docs/upgrade-procedures.md): renderer, parser, metric, schema, and ordering-policy gates;
- [Dependency and security status](docs/dependency-security.md): licenses, security gaps, and live upstream blockers;
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
sh scripts/test-install.sh
sh scripts/test-browser-oracle.sh
sh scripts/test-renderer-conformance.sh
sh scripts/test-renderer-dispositions.sh
sh scripts/test-alternate-scale-qa.sh
sh scripts/test-adversarial.sh
sh scripts/test-fuzz-smoke.sh
sh scripts/test-stage-benchmarks.sh
sh scripts/test-performance-budgets.sh
sh scripts/test-html-security.sh
sh scripts/test-compatibility.sh
sh scripts/test-schema-examples.sh
sh scripts/test-completions.sh
```

The browser oracle, renderer-conformance, and HTML-security validations additionally require Node.js/npm (`npx`) and launch pinned headless Chromium outside the production engine. Alternate-scale QA uses only the evaluation renderer adapter and never changes canonical report evidence.
