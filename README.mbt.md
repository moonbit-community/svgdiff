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

Record an explicit opaque sRGB background for event-local displayed-color measurement with `--perceptual-background COLOR`. This profile input enables changed-pixel mean DeltaEOK but does not change transparent-canvas raw rendering. Add explicit pixels per degree to request an event-local LDR-FLIP map; no display geometry is guessed:

```sh
svgdiff before.svg after.svg --perceptual-background '#ffffff'
svgdiff before.svg after.svg --perceptual-background '#ffffff' --flip-pixels-per-degree 67
```

Supply raster bytes explicitly when an `image` locator is not a data URL. No SVG-authored path is opened automatically:

```sh
svgdiff before.svg after.svg \
  --before-resource assets/photo.png image/png before-photo.png \
  --after-resource assets/photo.png image/png after-photo.png
```

Add `--html report.html` to generate a self-contained interactive report with
side-by-side sandboxed SVG previews, the exact Impact frontier, every Atomic
Difference, non-null magnitudes, linked events, regions, conservative possible
causes, Diagnostics, persistent region highlighting, and the complete JSON
payload. The HTML only presents report evidence; it does not recompute severity,
visibility, equality, ordering, or causality.

Add `--summary summary.md` to write a deterministic natural-language orientation
as a separate Markdown file. The Markdown is derived presentation only: it
lists the Impact frontier, every Atomic Difference, and every Diagnostic, while
the Structured Report JSON remains authoritative for complete evidence.

The command exits with status `2` for invalid arguments or file I/O errors and status `1` when SVG analysis fails, including malformed input, a fixed resource-limit rejection, or an unsafe local-reference graph. A `partial` report is still emitted successfully because its Diagnostics describe exactly which evidence layers are unavailable. Admission failures return a small report rather than a truncated difference inventory; fixed budgets are documented in [`docs/resource-limits.md`](docs/resource-limits.md), and cycle plus transitive `<use>` expansion handling is documented in [`docs/reference-safety.md`](docs/reference-safety.md).

## Library API

Install module version `0.5.28` with `moon add Milky2018/svgdiff@0.5.28` after that release is published. The latest independently verified Mooncakes publication remains `0.3.3`; its focused [registry README](PACKAGE.mbt.md) and [Mooncakes page](https://mooncakes.io/docs/Milky2018/svgdiff) describe the consumable package. Repository-only design, evaluation, and maintenance artifacts are deliberately excluded from registry archives.

The root package exposes unlimited and cooperatively controlled comparison operations:

```text
compare(before_svg, after_svg, comparison_profile) -> StructuredReport
compare_with_resources(before_svg, after_svg, comparison_profile, before_resources, after_resources) -> StructuredReport
compare_with_control(before_svg, after_svg, comparison_profile, control) -> StructuredReport raises ComparisonInterrupted
compare_with_control_and_resources(before_svg, after_svg, comparison_profile, before_resources, after_resources, control) -> StructuredReport raises ComparisonInterrupted
```

The current JSON contract is version `1.44`; its contract is described by the [JSON Schema](schema/svgdiff-report.schema.json) and [core comparison model](docs/core-model.md). The v1 profile records the common viewport, optional normalized opaque sRGB8 Perceptual Background, optional bounded FLIP pixels-per-degree Viewing Conditions, an optional explicit FLIP error threshold, DPR `1.0`, sRGB interpretation, canonical linear-sRGB premultiplied-RGBA arithmetic, versioned production renderer identity, and `svgdiff-renderer-conformance-profile/25`. With the background and raw event pixels, each event reports changed-pixel mean DeltaEOK; with Viewing Conditions too, it reports a bounded event-local LDR-FLIP map plus separate whole-canvas mean, selected-event mean, response p95, and response maximum statistics. A supplied threshold additionally reports strict-above pixel count and whole-canvas fraction; no threshold is assumed, and none of these values is a severity or visibility label. Both perceptual channels composite over exactly the recorded background without changing transparent-canvas evidence. The conformance profile versions accepted renderer fixtures, dispositions, and guards independently from the report shape and renderer package. Reports retain renderer-native RGBA8 RMSE alongside the canonical linear metric.

Admitted scalar spatial changes retain exact continuous magnitudes in canonical local user units and CSS pixels, plus viewport-diagonal and entity-relative fractions when their mappings and nonzero bounds are available. Admitted two-sided entity changes can additionally retain a bounded symmetric painted-boundary displacement distribution and an alpha-only coverage difference with absolute CSS area and a normalized union fraction. These parameter, boundary, and coverage measurements remain independent from analytic geometry, RGB color, and whole-event raster outcomes, so a tiny nonzero edit is not erased when canonical pixels are unchanged and no field is treated as a visibility or severity label.

The two isolated-paint observations reuse one bounded before/after render pair per alignment. Boundary evidence records before/after sample counts plus mean, nearest-rank p95, and maximum CSS-pixel distance. Coverage evidence records before/after alpha area, absolute alpha difference, maximum-alpha union, and their ratio. Equal alpha coverage is zero even when RGB color changes; null means the isolated observation was unavailable, not measured zero.

Static same-document linear and radial gradients are compared as structured resources plus consumer-specific paint: geometry, units, spread, transforms, recursive templates, every stop, and every fill/stroke consequence remain individually reportable. Their source and computed semantics are complete for the admitted sRGB slice; the current pinned renderer still carries an explicit gradient-raster guard.

Static same-document patterns over the admitted basic-shape child slice use the same resource/consumer separation: tile and content coordinates, transforms, viewport mapping, recursive templates, child operations, and every fill/stroke consequence remain individually reportable. Their computed semantics do not depend on the pinned renderer, whose pattern rasterization remains explicitly guarded.

Inherited `paint-order`, `fill-rule`, and `clip-rule` are resolved through the same cascade and dependency model. Paint order is compared by its active operation sequence, fill rules collapse when the fill is inactive or the contour is provably simple, and clip rules outside `clipPath` are inactive. Non-inherited `clip-path` now resolves presentation, inline, and static stylesheet declarations plus CSS-wide values and custom properties. One local static non-rounded rectangle clip is complete-eligible in `userSpaceOnUse` or numeric `objectBoundingBox` coordinates, with deterministic axis transforms, leaf or ordinary container application, per-consumer fan-out, and conservative effect bounds; other clip content and locators remain source-located Diagnostics.

Non-inherited `mask` and `mask-mode` now resolve through the same cascade. One local SVG mask with zero or one direct non-rounded solid rectangle is complete-eligible for alpha or sRGB-luminance transfer, user-space or object-bounding-box region/content units, defaults, deterministic transforms, leaf or ordinary container application, shared fan-out, continuous numeric deltas, isolated composition, and conservative per-side effect bounds. Missing, wrong-kind, empty, or non-positive-region admitted masks are deterministic transparent black; broader mask syntax remains precise partial coverage.

Non-inherited `filter` now resolves through the same cascade. One local graph of direct static `feOffset` primitives on an explicit-ID, untransformed basic-shape leaf is complete-eligible. Missing or wrong-kind local targets deterministically apply no filter, while an empty admitted graph produces transparent output. The engine resolves filter and primitive units, normative regions, SourceGraphic, SourceAlpha, implicit and named inputs, separate clipped RGBA intermediates, continuous offset magnitudes, fan-out, and conservative intermediate/final bounds. Unsupported direct primitives retain position-aligned complete source subtrees, exact spans, affected consumers, and the resolved same-document filter region as a conservative localization upper bound, so every attribute, type, nested-content, text, comment, insertion, deletion, shadow, or spelling change remains a source-only Atomic Difference without a computed-pixel or causal-completeness claim. CSS filter functions, external/invalid locators without a resolved region, templates, primitive subregions, fractional device offsets, transforms, animation, reuse, and effect interactions remain precise partial coverage.

Non-inherited CSS `mix-blend-mode` and `isolation` are complete-eligible for explicit-ID, untransformed, integer non-rounded opaque solid rectangles. All sixteen standard blend keywords use browser-matched W3C formulas; ordinary groups share their parent backdrop, while `isolation:isolate` on the root SVG or an authored-ID `g` starts transparent and composites once. Reports keep modes categorical, name the foreground plus conservative ordered backdrop prefix inside the nearest isolation boundary, use the same compositor for stacking changes, and widen complete causes comparison-wide so simultaneous backdrop edits cannot be omitted. Continuous alpha, antialiasing, strokes, transforms, instances, container blend modes, anonymous or instance isolation hosts, and effect interactions remain precise partial coverage.

Admitted `g`, `defs`, `symbol`, and same-document `use` structure preserves authored definition identity separately from each rendered placement. Reports expose deterministic nested instance paths, keep definition-owned declarations and Source Spans, fan one change out to every affected instance, and resolve use-host inheritance plus symbol or SVG instance viewports. External or invalid references remain diagnosed, and the measured transform-plus-translation renderer divergence remains guarded.

Consequence-aware structure reporting links effective reparenting and use-target changes to their computed outcomes. It also reports every potentially overlapping aligned pair whose draw order is inverted and whose final pixels change, while disjoint, equal-pixel, formatting-only, and ID-only restructurings remain outside visual Atomic Differences.

A private typed resource graph now unifies gradient, pattern, marker, clip, mask, filter, symbol, image, use, attribute URL, and static stylesheet dependencies. It retains locator states and exact reference spans, supplies deterministic conservative reachability, and drives the existing cycle and use-expansion safety checks. The complete unchanged graph is not added to Agent JSON; reports continue to expose only relevant resource facts, affected consumers, and Diagnostics.

Explicit 8-bit non-interlaced PNG and single-scan baseline JPEG data URLs or exact-match caller-supplied resources on `image` are decoded under fixed byte, dimension, pixel, cumulative-pixel, and PNG decompression limits without network or path I/O. Reports distinguish locator spelling, intrinsic dimensions and RGBA8 content, placement, insertion, and deletion; content changes carry resource-local intrinsic raster metrics and conservative bounds. Embedded ICC and other non-v1 profile metadata, HDR metadata, and samples above 8 bits retain compact hashes, intrinsic dimensions, placement, exact locator spans, and precise partial Diagnostics without conversion or tone mapping; explicit PNG `sRGB` remains admitted. Other valid raster variants remain explicit partial coverage. The pinned renderer does not composite these images, so final-canvas evidence remains unavailable through an explicit capability gap. Resource types beyond bundled PNG/JPEG images, nested SVG images, general clip/mask content, and filter primitives beyond the admitted graph remain later roadmap work.

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
  assert_eq(report.schema_version, "1.44")
  assert_eq(report.analysis_status, "complete")
  assert_true(report.atomic_differences.length() >= 2)
  assert_true(report.events.length() > 0)
  assert_eq(report.impact_assessment.policy_id, "event_rendered_pareto/v1")
  assert_eq(
    report.impact_assessment.candidate_event_count,
    report.events.length(),
  )
}
```

`impact_assessment.frontier_groups` identifies every current main Visual Event under the uncalibrated two-dimensional Pareto policy. Exact ties stay grouped, tradeoffs remain incomparable, and missing rendered measurements remain explicit rather than becoming zero. Follow each group to its event and Atomic Difference IDs; do not interpret group order as a severity ranking.

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

Pure nonvisual metadata stays outside visual Atomic Differences. Audit it only when the caller explicitly needs source governance:

```mbt check
///|
test "audit nonvisual metadata separately" {
  let before = "<svg data-build='a'><title>Before</title><rect width='8' height='8'/></svg>"
  let after = "<svg data-build='b'><title>After</title><rect width='8' height='8'/></svg>"
  let visual = @svgdiff.compare(
    before,
    after,
    @svgdiff.ComparisonProfile::v1_default(),
  )
  assert_true(visual.atomic_differences.is_empty())
  let audit = @svgdiff.audit_nonvisual_metadata(before, after)
  assert_eq(audit.audit_schema_version, "1.0")
  assert_eq(audit.differences.length(), 2)
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
  let projection_jsonl = report.to_agent_projection_json_lines()
  let html = @svgdiff.render_html_report(before, after, report)
  let summary = @svgdiff.render_markdown_summary(report)
  assert_true(json.find("\"schema_version\": \"1.44\"") is Some(_))
  assert_true(compact_json.length() < json.length())
  assert_true(projection_jsonl.find("svgdiff-agent-projection/1") is Some(_))
  assert_true(html.find("<!doctype html>") is Some(_))
  assert_true(html.find("sandbox=\"\"") is Some(_))
  assert_true(summary.find("Derived presentation only") is Some(_))
}
```

The [public API guide](docs/library-api.md) groups all exported report types and documents how to inspect generated MoonBit API documentation.

The CLI option `--agent-json` emits the same schema and evidence without formatting whitespace. `--agent-projection` emits the separately versioned lossless JSONL projection so limited-context consumers can read one header or canonical section item at a time. Both modes can be combined with `--output`, are mutually exclusive with each other, and leave default indented JSON unchanged.

`render_markdown_summary` and CLI `--summary FILE` provide optional derived
presentation. They do not add report fields, recompute comparison, replace JSON,
or create severity, visibility, equality, or unique-cause claims.

## Supported static subset

- source spans, authored values, normalized declarations, presentation/inline/static-stylesheet cascade provenance including specificity, source order, duplicates, and `!important`, plus ordinary inheritance and CSS-wide defaulting for every supported visual property;
- case-sensitive inherited custom properties with bounded nested `var()` fallback, `currentColor` dependencies, and causal fan-out into supported geometry, paint, stroke, opacity, vector-effect, marker attachment, and admitted gradient stop colors;
- role-typed set-to-set alignment for Visual Entities and Visual Resources: rendered shapes and guarded paths use transform- and conservative-painted-bounds-aware exact signatures plus bounded device-space feature distance, repeated exact subjects retain equivalence classes, `use` instances retain rendered paths, groups/text/use hosts use source-structural entity alignment, and visual definitions plus intrinsic image content use independent resource alignments referenced by every resource Atomic Difference;
- geometry, exact normalized path parameter and topology, fill, stroke paint, canonical length-aware stroke width/caps/joins/miter limits/dashes/dash offsets/vector effects, local marker attachments and length-aware resource viewport/orientation properties, leaf and isolated container opacity, static alpha/luminance masks, bounded static `feOffset` graphs, opaque unsupported-filter source subtrees, opaque binary-alpha blend modes and isolation, insertion, deletion, and consequence-aware ancestry, instance-resolution, and stacking differences;
- root and nested SVG viewport declarations, nearest-viewport percentage resolution, and exact cumulative coordinate mappings under one explicit common Comparison Viewport;
- exact continuous parameter magnitudes, symmetric painted-boundary displacement distributions, alpha-only painted-coverage differences, same-domain ordering, RGBA8 raster response, connected Difference Regions, and causally complete conservative Cause Envelopes for complete reports;
- explicit `partial` or `failed` coverage with Diagnostics for unsupported or unresolved semantics.

Current Diagnostics also emit `source_locations`: each location names the `before` or `after` SVG and a half-open UTF-16 span. Malformed XML retains the parser's exact error span, and source-anchored limitations merge all applicable locations under one stable Diagnostic ID. An empty array is reserved for comparison-global or derived conditions; legacy reports may omit the optional JSON field.

Scripts, animation, event state, `foreignObject`, selectors outside the documented deterministic static scope, cascade layers and non-author origins, complete CSS tokenization and registered custom properties, system colors, complete path semantics, marker child paint/cascade/context paint, external marker references, path-length calibration, font- or environment-relative lengths, arithmetic length syntax, filter primitives beyond direct static `feOffset`, CSS filter functions, general mask content, CSS image or multi-layer masks, and deterministic font shaping are not currently evaluated. `revert-layer`, malformed or excluded variable syntax, and excessive variable expansion remain explicitly guarded. Local marker attachments and admitted marker lengths are parsed into deterministic placements and conservative clipped envelopes, but marker Chromium fixtures diverge from the pinned renderer and remain guarded. Path data is strictly parsed into normalized absolute segments with authored spans. SVG `transform` lists and root or nested viewport mappings are strictly parsed into cumulative affine matrices; authored declarations remain visible even when mappings are equivalent. Canonical typed transform effects separately report translation, rotation, signed scale, skew, or an exact singular residual matrix. Integer axis-aligned transforms and viewport mappings have accepted browser-conformance fixtures, while general affine rasterization and non-integer viewport mappings remain guarded. Transform events select pixel components through cumulative before/after conservative painted bounds; exact continuous transformed outlines remain deferred. Root intrinsic `width` and `height` never select separate before/after canvases: the profile supplies one common Comparison Viewport. Resource-local transforms and automatic viewport inference remain later roadmap items. Unsupported content is never silently treated as equal.

Container opacity, admitted container masks, bounded filter graphs, and opaque binary-alpha blend/isolation paths are rendered by project-owned compositors with deterministic RGBA8 arithmetic. Fractional geometry, fractional leaf opacity, continuous-alpha blending, and referenced gradient or pattern raster measurements remain numeric pinned-renderer observations whose Rendered Evidence coverage is limited by stable conformance Diagnostics; each admitted compositor path is a separate product capability.

Current reports project renderer-specific limitations encountered by the inputs into `renderer_capability_gaps`. Each record provides a stable capability ID, `guarded` or `unavailable` support status, and establishing Diagnostic IDs. An empty array does not claim that the renderer supports all SVG features; the coverage matrix remains authoritative.

The production renderer identity includes private style-precedence, ordinary-inheritance, CSS-computed-value, color/opacity, length-used-value, stroke-used-geometry, basic-shape-used-geometry, and static-mask normalizers plus isolated opacity, mask, filter-graph, and blend/isolation compositors in front of `mizchi/svg@0.2.1`. These adapters rewrite only the renderer-input copy; the original source remains authoritative for authored facts, provenance, and spans. Incomplete or unsupported syntax remains unchanged and keeps the affected evidence partial through stable Diagnostics.

The complete implementation boundary, including guarded partial cases, is in the [current v1 support contract](docs/v1-scope.md).

The hand-authored [evaluation corpus](evaluation/corpus/README.md) contains stable SVG pairs for equivalent, subtle, salient, structural, resource-mediated, zero-contribution, and unsupported cases. Run `sh scripts/test-corpus.sh` to validate every pair through the production CLI.

The complementary [mutation suite](evaluation/mutations/README.md) generates deterministic pairs with independently declared Changed Facts and affected subjects. Run `sh scripts/test-mutations.sh` to verify generation and report retention.

The [adversarial suite](evaluation/adversarial/README.md) checks malformed transform and viewport false-complete cases, false equality, source-order alignment, attribution leakage, magnitude ordering, and unsafe reference graphs through the production CLI. Run `sh scripts/test-adversarial.sh` to execute each safety invariant twice and verify deterministic results.

The [compatibility corpus](evaluation/compatibility/README.md) generates current, legacy-additive, future-additive, unknown-schema, unknown-ordering-policy, and unknown-Impact-policy report variants. Run `sh scripts/test-compatibility.sh` to verify deterministic consumer dispatch and validation against every entry in the [released Schema registry](schema/registry.v1.json) before semantic interpretation.

The [canonical Structured Report examples](schema/examples/README.md) are byte-for-byte production CLI outputs for equivalent spelling, cascade and inheritance equivalence, tiny numeric change, salient change, insertion, deletion, resources, viewport mapping, partial coverage, and failed admission. Run `sh scripts/test-schema-examples.sh` to validate them against the current Schema and semantic manifest.

The [determinism evaluation](evaluation/determinism/README.md) repeats equivalent, changed, structural, resource, unsupported, multi-event, and non-default-viewport comparisons in separate CLI processes. Run `sh scripts/test-report-determinism.sh` to verify byte-stable output, globally unique report-local IDs, closed references, and identical evidence in default and compact JSON. CI also compares exact canonical bundles across Ubuntu 24.04 x64, Windows Server 2025 x64, and macOS 15 arm64; `sh scripts/test-cross-platform-determinism.sh` exercises the same aggregation policy locally with positive and negative controls.

The [semantic-concern evaluation](evaluation/semantic-concern/README.md) proves that a caller-designated one-pixel event remains recoverable from the full and Agent inventories even when a larger event dominates it under context-free Impact. Run `sh scripts/test-semantic-concern-policy.sh` to verify the query-conditioned policy boundary.

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
- [Upgrade procedures](docs/upgrade-procedures.md): renderer, parser, metric, schema, ordering-policy, and Impact-policy gates;
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
sh scripts/test-semantic-concern-policy.sh
```

The browser oracle, renderer-conformance, and HTML-security validations additionally require Node.js/npm (`npx`) and launch pinned headless Chromium outside the production engine. Alternate-scale QA uses only the evaluation renderer adapter and never changes canonical report evidence.
