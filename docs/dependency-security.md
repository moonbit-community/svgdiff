# Dependency, Security, and Upstream Status

Status: current maintenance ledger

Last verified: 2026-07-21

This ledger records the licenses shipped with the currently resolved packages, the security boundary implemented by schema `3.0`, and external blockers that still affect development or coverage. It is not a release SBOM or legal opinion.

The opt-in report-only language-model benchmark uses a separately installed pinned Codex CLI and authenticated remote model. Neither is linked, vendored, resolved by MoonBit, shipped in release archives, or used by the comparison engine. Each evaluated case gets an empty working directory and isolated temporary Codex home containing only authentication; user configuration, project rules, prior sessions, and model caches are excluded. Strict feature overrides disable shell, browser, apps, MCP, memory, and related tools before the request, while any residual tool event rejects the run. This protects benchmark validity, not hostile multi-tenant execution: the benchmark requires trusted operator credentials and network access and must not be exposed as an unauthenticated service.

The M3 compact-summary traceability gate adds no runtime or release dependency. It executes the existing local CLI, JSON validators, and deterministic evaluation scripts over generated temporary artifacts; it does not evaluate report-controlled text as commands or promote Markdown/HTML presentation to evidence authority.

The [M5 explicit non-goal coverage gate](../evaluation/m5-nongoal-coverage-gate/README.md) likewise adds no product dependency or execution path. It validates decision artifacts, current Diagnostics, zero implicit comparison-time I/O, and production false-equality probes. Future identity strings in its manifest are reservations only: they do not vendor font, color, browser, script, interaction, animation, layout, renderer, resolver, or acquisition runtimes.

The [terminal operational gate](../evaluation/terminal-operational-gate/README.md) composes the current local threat model with installation, determinism, versioning, and supported-native-matrix evidence. Its hostile-input claim is limited to strict bounded admission, no script execution or implicit network access, unsafe reference-graph rejection, bounded failed reports, deterministic fuzz/adversarial regressions, and sandboxed offline HTML previews. The known gaps below remain explicit and prevent treating the CLI as a process-isolated multi-tenant or unauthenticated upload service.

## Resolved dependencies and licenses

| Dependency | Relationship | Resolved version | Manifest license | License file in installed package |
| --- | --- | ---: | --- | --- |
| `Milky2018/xml` | Direct; authored XML and Source Spans | `0.4.0` | Apache-2.0 | Yes |
| `Milky2018/svg` | Direct; scene and canonical v1 renderer | `0.3.1` | Apache-2.0 | No |
| `mizchi/css` | Transitive through `Milky2018/svg` | `0.7.3` | Apache-2.0 | No |
| `mizchi/pixelmatch` | Direct; baseline image difference support | `0.6.1` | Apache-2.0 | Yes |
| `moonbitlang/async` | Direct module dependency | `0.19.1` | Apache-2.0 | Yes |
| `moonbitlang/x` | Direct module dependency | `0.4.40` | Apache-2.0 | No |
| `moonbitlang/quickcheck` | Direct module dependency retained by `moon info` | `0.14.0` | Apache-2.0 | Yes |
| `Milky2018/svgdiff-raster-codec` | Direct local workspace module; bounded admitted PNG/JPEG subset decoding and color-metadata inspection | `0.1.1` | Apache-2.0 | Project-owned source and LICENSE |
| `mizchi/image` | Transitive through `pixelmatch` | `0.1.2` | Apache-2.0 | No |
| `mizchi/zlib` | Transitive through `image` and the raster-codec module | `0.4.6` | Apache-2.0 | Yes |

Evidence comes from `moon tree`, the resolved `.mooncakes` manifests, the local workspace module, and packaged LICENSE files on 2026-07-20. The root project declares Apache-2.0 and includes its own [`LICENSE`](../LICENSE).

All resolved manifests declare Apache-2.0, but four installed package archives omit a LICENSE file. The current [release dependency manifest](../release/dependencies.v1.json) preserves that evidence distinction instead of pretending every archive carried its own text. The [native release bundle](../release/README.md) includes the complete Apache-2.0 text and generates versioned third-party notices for all ten resolved packages. This is transparent packaging evidence, not a legal opinion.

`mizchi/canvas@0.9.0` and its `mizchi/image@0.4.2` dependency were used only in an experiment. They are not part of the production dependency graph above. The project-owned raster-codec module is derived from the Apache-2.0 production decoder sources in `mizchi/image@0.1.2`; its narrow bounded API and attribution are documented in [`modules/raster_codec/README.mbt.md`](../modules/raster_codec/README.mbt.md).

The private MoonBit LDR-FLIP implementation follows the equations and constants documented by NVIDIA's BSD-3-Clause reference implementation v1.7 at commit `b475eb4bf394ab877c42166c9eb0a84a02cc5b14`. The project does not link, vendor, or ship that implementation; focused tests compare quantized output against values generated by the pinned reference.

## Current security boundary

### Input parsing

- `Milky2018/xml@0.4.0` enforces document well-formedness, rejects duplicate attributes and trailing content, bounds entity expansion, and does not implicitly resolve external entities.
- Namespace-aware UTF-16 Source Spans allow parse failures and authored facts to be localized without reparsing untrusted text through a second XML implementation.
- Unsupported SVG elements, attributes, CSS, resources, and dynamic behavior reduce analysis coverage through Diagnostics rather than being executed or treated as equality.
- Canonical comparison permanently disables SVG script execution. Sandbox and CSP protection are not treated as deterministic runtime semantics; any future script-enabled capture is a separately versioned external observation running outside the comparison process under the [script execution boundary](script-execution-boundary.md).
- Canonical comparison also declares no focus, pointer, activation, navigation-target, or browser action state. Future [interaction checkpoints](interaction-state-profiles.md) must derive matches from bounded typed inputs, while action replay remains process-isolated external observation evidence with achieved-state postconditions.
- Canonical comparison has no animation clock and does not equate animation-disabled processing with `t = 0`. A future [animation timeline](animation-timeline-model.md) must use exact logical checkpoints and closed declarative evaluators; script-driven or browser-specific captures remain process-isolated observations with requested and achieved temporal state.
- Canonical comparison has no host-language layout engine for `foreignObject`. A future [Foreign Object Layout Profile](foreign-object-layout-boundary.md) must close namespaces, UA style, CSS layout, fonts, resources, processing axes, paint, SVG integration, evaluator identity, and limits; unknown content remains unsupported rather than executing through the HTML preview or an ambient browser.
- The comparison engine performs no implicit network fetches.
- The comparison engine has no persistent or shared cache. Its report-local paint-measurement memoization never accepts paths, network state, or cross-request bytes. A future exact-result cache must treat stored data as untrusted, validate complete request and implementation identity plus digest and size, and fall back to full recomputation on every miss or error.
- The accepted future [Resource Snapshot Bundle](general-resource-snapshot-bundles.md) preserves zero comparison-time filesystem and network I/O. It separates side-qualified response snapshots from a future explicit, user-invoked, allowlisted, credential-free prefetch profile and sanitized transcript; no generalized resolver or prefetch dependency is selected or implemented.
- Embedded raster loading admits only an explicit 8-bit non-interlaced PNG and single-scan baseline JPEG subset from data URLs or caller-supplied exact-match bundles. It validates bundle configuration, MIME, signatures, decoder progress, scan/table bounds, and unsupported pixel-affecting variants; bounds URI bytes, entry count, per-entry and cumulative bytes, dimensions, pixels, cumulative pixels, and PNG decompression output; and never reads a locator as a path. Serialized reports retain hashes and Source Spans rather than payloads or caller file paths.
- Fixed [comparison resource limits](resource-limits.md) bound UTF-8 input bytes, XML elements and nesting, path-data work, references, raster dimensions, Difference Regions, and built-in JSON output. An overrun returns a bounded failed report rather than a truncated inventory.
- The project-owned [local-reference guard](reference-safety.md) rejects cycles and saturates transitive `<use>` expansion before the pinned renderer can clone the graph.

### Rendering and HTML output

- Both SVG inputs use one explicit local viewport and a pinned renderer identity.
- Original SVG sources are placed in sandboxed iframe preview documents in the HTML report. The iframe has an empty `sandbox` token set, so embedded scripts cannot execute.
- Preview `srcdoc` content and report JSON are HTML-escaped before embedding.
- The preview document applies `default-src 'none'`; the top-level report allows only its own inline presentation script and styles.
- The pinned Chromium [HTML security gate](../evaluation/html-security/README.md) verifies that hostile scripts and event handlers do not execute, the parent report is not mutated, and hostile external resource URLs produce no requests.
- Semantic classification comes only from the Structured Report. Browser rendering in the report cannot promote unsupported input to complete analysis.
- The static GitHub Pages product performs comparison in a dedicated Worker through the no-I/O wasm entry. It has no upload, remote-URL acquisition, account, history, analytics, or telemetry path; only same-origin static application assets and the wasm binary are fetched.
- The page accepts local file bytes through an explicit browser file picker or drop action and keeps them in tab-local memory. Input and report previews retain empty iframe sandboxes and restrictive nested CSP documents. The top-level page permits same-origin scripts, styles, Worker, and wasm compilation plus the inline styles required by the shared Inspector; it does not authorize input scripts or remote resources.

### CLI and data access

- The CLI reads the two SVG paths plus only resource files named by repeatable `--before-resource RESOURCE_JSON` or `--after-resource RESOURCE_JSON` single-value options, and writes only explicitly requested JSON or HTML paths. Each JSON object contains string `locator`, `media_type`, and `path` fields. A resource path supplies bytes and never becomes locator identity or report evidence.
- Invalid arguments and file I/O errors exit with status `2`; malformed SVG analysis exits with status `1`.
- A partial report is returned successfully so Diagnostics remain machine-readable.

## Known security gaps

Schema `3.0` provides fixed resource admission but does not yet provide a complete hostile-input execution sandbox:

- the CLIs expose a deterministic checkpoint budget but no wall-clock deadline or external cancellation predicate; cooperative control cannot preempt one synchronous parser or renderer call;
- no streaming admission before the CLI allocates the complete input String, no in-process peak-memory enforcement for final serialization, and no configurable embedding policy;
- no coverage-guided or sanitizer-guided fuzzing; the fixed-seed generative [fuzz smoke](../evaluation/fuzz/README.md) covers parser, adapter, renderer, JSON, and HTML boundaries but does not measure code coverage;
- no automated dependency advisory or SBOM check, and no signing, notarization, or SLSA attestation of the CI-published license and provenance evidence;
- no persistent-cache poisoning or multi-tenant isolation surface, because no persistent or remote comparison cache is implemented;
- the release gate builds one tagged revision on three hosted environments and covers the versioned determinism corpus, but it does not establish cross-toolchain reproducibility or independently signed provenance.

These gaps do not permit false complete analysis, and fixed limits plus local-reference admission bound the major deterministic growth dimensions. Embedding callers can use [`compare_with_control`](library-api.md) to stop at cooperative engine checkpoints, but this is not process isolation or a hard deadline. The [performance budget suite](../evaluation/performance/README.md) measures complete-process peak RSS for named representative workloads, including final serialization, but does not enforce memory or time for arbitrary inputs. Crafted inputs can still consume excessive time or transient memory within fixed admission bounds. Do not expose either executable entry as an unauthenticated hostile-upload service until process-level hard time and memory enforcement are complete.

`Milky2018/svgdiff@0.3.3` is published on Mooncakes with its Apache-2.0 license, focused registry README, dependency versions, and package checksum. Its repository field is intentionally absent because this checkout has no configured canonical Git remote; do not replace that omission with an unverified URL. The publication archive excludes repository-only tests, evaluations, issues, scripts, prototypes, release automation, and security documentation, so consumers should use the registry checksum and packaged license as the available source-distribution evidence until a canonical repository is established.

## Current upstream follow-ups and blockers

| Item | Live upstream status on 2026-07-14 | Project impact | Current safe behavior |
| --- | --- | --- | --- |
| [`mizchi/svg#4`](https://github.com/mizchi/svg/pull/4): inline style precedence | Superseded for this project by `Milky2018/svg@0.3.1` | The current raw dependency passes the focused style-precedence fixtures, but that does not establish complete CSS conformance | Delegate the passing cascade path to the dependency; retain analyzer-side unsupported-syntax Diagnostics without a renderer precedence normalizer |
| [`mizchi/image-mbt#3`](https://github.com/mizchi/image-mbt/pull/3): derive `Debug` for assert-equality types | Open, ready for review | Direct `mizchi/image` dependencies fail while compiling packaged upstream tests, but the decoder implementation remains usable | Keep canvas and direct image dependencies out of production; maintain the narrow attributed workspace codec without patching the dependency cache |
| `moonbitlang/x@0.4.40` `Rational[Int64]` lacks `Debug` in dependency `assert_eq` tests | No matching open upstream PR found in the 2026-07-14 check | `moon doc` fails while checking transitive dependency tests | Use `moon ide doc` and `moon info`; project check, tests, and CLI remain green |

Deterministic font analysis is a deferred product capability, not an upstream blocker. The accepted [Font Bundle contract](font-resource-bundle.md) closes the future raw-byte, collection-face, fingerprint, legal-evidence, and no-ambient-I/O boundary. The accepted [Font Runtime dependency contract](font-runtime-dependencies.md) selects exact-source HarfBuzz 14.2.1 plus FreeType 2.14.3 behind a future separately versioned workspace module, with a static no-system-library build and a narrow initial OpenType/unhinted-grayscale slice.

Those libraries are selected future sources, not resolved dependencies in the table above. They are not vendored, linked, distributed, or consulted by current product code. Before that changes, the workspace module must carry the complete Old MIT and selected FreeType License texts/notices, exact source and build identities, sanitizer/fuzz evidence, hard parser/work limits, and target-specific shaping/outline/raster conformance. Current Mooncakes font implementations remain differential candidates rather than trusted canonical dependencies.

No color-management dependency is selected or resolved. The accepted [color-management profile boundary](color-management-profiles.md) makes CSS Color 4 predefined SDR mathematics the first future candidate and defers ICC conversion behind a separate transform-dependency evaluation. Any later ICC seam must pin exact sources and builds, isolate dependency types, accept bounded in-memory bytes only, validate hostile profile structures and transform work, preserve complete licenses, and prove numeric and cross-target conformance. Platform CMS APIs are external observations, not dependency candidates for canonical execution.

No JavaScript engine, DOM implementation, or browser runtime is selected or resolved for script execution. The accepted [script execution boundary](script-execution-boundary.md) makes such execution a permanent canonical non-goal. A future external observer may use a separately pinned browser harness only after process isolation, API/state closure, event and timeline contracts, hard limits, exact resource acquisition, and repeatability are independently reviewed; it must not enter the production dependency graph by implication.

No input-synthesis or interactive browser dependency is selected or resolved for product state evaluation. The accepted [interaction-state boundary](interaction-state-profiles.md) requires a future project-owned bounded state/hit-test evaluator for canonical checkpoints and keeps WebDriver-style action tooling external. A browser automation library cannot become selector applicability authority merely because it can replay a pointer or keyboard sequence.

No animation scheduler, interpolation engine, virtual-time browser harness, or transition-history implementation is selected or resolved. The accepted [animation-timeline boundary](animation-timeline-model.md) requires a future project-owned evaluator for any canonical declarative subset and exact scenario history for events or transitions. A browser virtual-time API may support an external observation but cannot become canonical timing authority by dependency selection alone.

No HTML/CSS layout engine or foreign-language handler is selected or resolved. General XHTML support requires one under the accepted [foreign-content boundary](foreign-object-layout-boundary.md), but a complete browser is neither implied nor selected. Any future dependency must accept only bounded in-memory trees and caller-supplied resources, disable ambient I/O and executable features, expose project-owned layout evidence, run under hard limits and isolation appropriate to its parser/decoder surface, retain licenses, and pass the renderer ownership and conformance gates.

No general URL resolver, snapshot-package reader, fetch client, archive format, or prefetch runtime is selected. The project must own request identity, manifest/digest validation, recursive closure, secret exclusion, and comparison-time no-I/O enforcement. A later acquisition dependency remains outside comparison and must pass SSRF, private-network, redirect, DNS-rebinding, credential, proxy, cache, decompression, path/member, limit, provenance, and license review independently from every resource-family parser.

## Refresh procedure

Refresh this ledger whenever a dependency version changes and at every release milestone:

1. inspect `modules/svgdiff/moon.mod` and resolved `.mooncakes/*/moon.mod*` versions;
2. verify each manifest license against the packaged LICENSE or upstream repository;
3. review new transitive dependencies and native code;
4. query every linked upstream PR and replace stale status text;
5. rerun security boundary tests, CLI integration, fuzz smoke, representative performance budgets, and the pinned Chromium HTML security gate;
6. update [`renderer-evaluation.md`](renderer-evaluation.md), [`feature-coverage.md`](feature-coverage.md), and the upgrade procedure when behavior changes;
7. leave resolved blocker history in issues or ADRs rather than deleting it from the record.

Dependency upgrades must follow [`upgrade-procedures.md`](upgrade-procedures.md).
