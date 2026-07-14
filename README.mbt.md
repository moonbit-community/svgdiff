# svgdiff

`svgdiff` compares two deterministic static SVG sources and emits a layered, machine-readable visual difference report. It distinguishes authored source changes, computed visual relations, canonical raster response, spatial Difference Regions, and conservative Cause Envelopes. The report is designed for agents that cannot inspect images directly.

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

`SVGDIFF_INSTALL_DIR` provides the same destination override. This source installation builds for the current operating system and architecture. Published cross-platform binaries and package-manager installation remain roadmap work.

Install Bash, Zsh, or Fish completion separately with `sh scripts/install-completions.sh <shell>`. Shell-specific locations, Zsh activation, and the package-manager release prerequisite are documented in [`completions/README.md`](completions/README.md).

Generate a current-host native release bundle with `sh scripts/package-release.sh`. The bundle includes checksums, transparent build provenance, the project license, and versioned third-party notices; its exact guarantees and non-guarantees are documented in [`release/README.md`](release/README.md). Binary publication remains separate roadmap work.

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

The command exits with status `2` for invalid arguments or file I/O errors and status `1` when SVG analysis fails. A `partial` report is still emitted successfully because its Diagnostics describe exactly which evidence layers are unavailable.

## Library API

The root package exposes one comparison operation:

```text
compare(before_svg, after_svg, comparison_profile) -> StructuredReport
```

The stable JSON contract is version `1.0`; its contract is described by the [JSON Schema](schema/svgdiff-report.schema.json) and [core comparison model](docs/core-model.md). The v1 profile records the common viewport, DPR `1.0`, sRGB interpretation, canonical linear-sRGB premultiplied-RGBA arithmetic, pinned renderer identity, and `svgdiff-renderer-conformance-profile/1`. The conformance profile versions accepted renderer fixtures, dispositions, and guards independently from the report shape and renderer package. Reports retain renderer-native RGBA8 RMSE alongside the canonical linear metric.

The root package is the stable product seam. Its implementation lives in the formal `engine` package; historical experiment findings are retained under `docs/research`.

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
  assert_eq(report.schema_version, "1.0")
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
  assert_true(json.find("\"schema_version\": \"1.0\"") is Some(_))
  assert_true(compact_json.length() < json.length())
  assert_true(html.find("<!doctype html>") is Some(_))
  assert_true(html.find("sandbox=\"\"") is Some(_))
}
```

The [public API guide](docs/library-api.md) groups all exported report types and documents how to inspect generated MoonBit API documentation.

The CLI option `--agent-json` emits the same schema and evidence without formatting whitespace. It can be combined with `--output`; default output remains the indented canonical representation.

## Supported static subset

- source spans, authored values, normalized declarations, inline-style provenance, and ordinary inherited fill;
- set-to-set alignment for rect, circle, ellipse, line, polyline, and polygon subjects without treating IDs or source order as identity;
- geometry, fill, stroke, stroke width, opacity, insertion, deletion, and basic structure differences;
- exact continuous parameter magnitudes, same-domain ordering, RGBA8 raster response, connected Difference Regions, and causally complete conservative Cause Envelopes for complete reports;
- explicit `partial` or `failed` coverage with Diagnostics for unsupported or unresolved semantics.

Scripts, animation, event state, `foreignObject`, general CSS selectors, transforms, paths, filters, masks, and deterministic font shaping are not currently evaluated. Unsupported content is never silently treated as equal.

Fractional geometry, fractional leaf opacity, and referenced-gradient raster measurements currently remain numeric pinned-renderer observations, but their Rendered Evidence coverage is limited by stable conformance Diagnostics. Exact source and computed differences remain available; consumers must not treat those raster values as browser-conformant.

Current reports project renderer-specific limitations encountered by the inputs into `renderer_capability_gaps`. Each record provides a stable capability ID, `guarded` or `unavailable` support status, and establishing Diagnostic IDs. An empty array does not claim that the renderer supports all SVG features; the coverage matrix remains authoritative.

The current renderer dependency does not yet guarantee that inline `style`
overrides a conflicting presentation attribute independently of XML attribute
order. Such overlap emits `renderer_style_precedence_unresolved` and reduces
the report to `partial`; Source Semantics remains normalized, while Computed
Appearance and Rendered Evidence must be treated as unavailable until the
upstream fix is released.

The complete implementation boundary, including guarded partial cases, is in the [current v1 support contract](docs/v1-scope.md).

The hand-authored [evaluation corpus](evaluation/corpus/README.md) contains stable SVG pairs for equivalent, subtle, salient, structural, resource-mediated, zero-contribution, and unsupported cases. Run `sh scripts/test-corpus.sh` to validate every pair through the production CLI.

The complementary [mutation suite](evaluation/mutations/README.md) generates deterministic pairs with independently declared Changed Facts and affected subjects. Run `sh scripts/test-mutations.sh` to verify generation and report retention.

The [adversarial suite](evaluation/adversarial/README.md) checks false-complete, false-equality, source-order alignment, attribution-leakage, and magnitude-ordering counterexamples through the production CLI. Run `sh scripts/test-adversarial.sh` to execute each safety invariant twice and verify deterministic results.

The [compatibility corpus](evaluation/compatibility/README.md) generates current, legacy-additive, future-additive, unknown-schema, and unknown-ordering-policy report variants. Run `sh scripts/test-compatibility.sh` to verify deterministic consumer dispatch before semantic interpretation.

## Documentation

- [Documentation guide](docs/README.md): authority, reading order, and maintenance rules;
- [Current v1 support](docs/v1-scope.md): implemented, partial, unsupported, and deferred capabilities;
- [Feature coverage matrix](docs/feature-coverage.md): links support claims to Diagnostics and tests;
- [Analysis status contract](docs/analysis-status.md): exact guarantees for complete, partial, and failed reports;
- [Text-only agent guide](docs/agent-report-guide.md): report reading procedure and worked examples;
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
sh scripts/test-compatibility.sh
sh scripts/test-completions.sh
```

The browser oracle and renderer-conformance validations additionally require Node.js/npm (`npx`) and launch pinned headless Chromium outside the production engine. Alternate-scale QA uses only the evaluation renderer adapter and never changes canonical report evidence.
