# Dependency, Security, and Upstream Status

Status: current maintenance ledger

Last verified: 2026-07-15

This ledger records the licenses shipped with the currently resolved packages, the security boundary implemented by schema `1.27`, and external blockers that still affect development or coverage. It is not a release SBOM or legal opinion.

## Resolved dependencies and licenses

| Dependency | Relationship | Resolved version | Manifest license | License file in installed package |
| --- | --- | ---: | --- | --- |
| `Milky2018/xml` | Direct; authored XML and Source Spans | `0.4.0` | Apache-2.0 | Yes |
| `mizchi/svg` | Direct; scene and canonical v1 renderer | `0.2.1` | Apache-2.0 | No |
| `mizchi/pixelmatch` | Direct; baseline image difference support | `0.6.1` | Apache-2.0 | Yes |
| `moonbitlang/async` | Direct module dependency | `0.19.1` | Apache-2.0 | Yes |
| `moonbitlang/x` | Direct module dependency | `0.4.40` | Apache-2.0 | No |
| `moonbitlang/quickcheck` | Direct module dependency retained by `moon info` | `0.14.0` | Apache-2.0 | Yes |
| `Milky2018/svgdiff-raster-codec` | Direct local workspace module; bounded admitted PNG/JPEG subset decoding | `0.1.0` | Apache-2.0 | Project-owned source and LICENSE |
| `mizchi/image` | Transitive through `pixelmatch` | `0.1.2` | Apache-2.0 | No |
| `mizchi/zlib` | Transitive through `image` and the raster-codec module | `0.4.6` | Apache-2.0 | Yes |

Evidence comes from `moon tree`, the resolved `.mooncakes` manifests, the local workspace module, and packaged LICENSE files on 2026-07-15. The root project declares Apache-2.0 and includes its own [`LICENSE`](../LICENSE).

All resolved manifests declare Apache-2.0, but three installed package archives omit a LICENSE file. The current [release dependency manifest](../release/dependencies.v1.json) preserves that evidence distinction instead of pretending every archive carried its own text. The [native release bundle](../release/README.md) includes the complete Apache-2.0 text and generates versioned third-party notices for all nine resolved packages. This is transparent packaging evidence, not a legal opinion.

`mizchi/canvas@0.9.0` and its `mizchi/image@0.4.2` dependency were used only in an experiment. They are not part of the production dependency graph above. The project-owned raster-codec module is derived from the Apache-2.0 production decoder sources in `mizchi/image@0.1.2`; its narrow bounded API and attribution are documented in [`modules/raster_codec/README.mbt.md`](../modules/raster_codec/README.mbt.md).

## Current security boundary

### Input parsing

- `Milky2018/xml@0.4.0` enforces document well-formedness, rejects duplicate attributes and trailing content, bounds entity expansion, and does not implicitly resolve external entities.
- Namespace-aware UTF-16 Source Spans allow parse failures and authored facts to be localized without reparsing untrusted text through a second XML implementation.
- Unsupported SVG elements, attributes, CSS, resources, and dynamic behavior reduce analysis coverage through Diagnostics rather than being executed or treated as equality.
- The comparison engine performs no implicit network fetches.
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

### CLI and data access

- The CLI reads the two SVG paths plus only resource files named by repeatable `--before-resource LOCATOR MEDIA_TYPE FILE` or `--after-resource LOCATOR MEDIA_TYPE FILE` triplets, and writes only explicitly requested JSON or HTML paths. A resource path supplies bytes and never becomes locator identity or report evidence.
- Invalid arguments and file I/O errors exit with status `2`; malformed SVG analysis exits with status `1`.
- A partial report is returned successfully so Diagnostics remain machine-readable.

## Known security gaps

Schema `1.27` provides fixed resource admission but does not yet provide a complete hostile-input execution sandbox:

- the CLI has no cancellation or comparison-time option; the library's controlled comparison is cooperative and cannot preempt one synchronous parser or renderer call;
- no streaming admission before the CLI allocates the complete input String, no in-process peak-memory enforcement for final serialization, and no configurable embedding policy;
- no coverage-guided or sanitizer-guided fuzzing; the fixed-seed generative [fuzz smoke](../evaluation/fuzz/README.md) covers parser, adapter, renderer, JSON, and HTML boundaries but does not measure code coverage;
- no automated dependency advisory or SBOM check, and no signing, notarization, or SLSA attestation of the CI-published license and provenance evidence;
- the release gate builds one tagged revision on three hosted environments and covers the versioned determinism corpus, but it does not establish cross-toolchain reproducibility or independently signed provenance.

These gaps do not permit false complete analysis, and fixed limits plus local-reference admission bound the major deterministic growth dimensions. Embedding callers can use [`compare_with_control`](library-api.md) to stop at cooperative engine checkpoints, but this is not process isolation or a hard deadline. The [performance budget suite](../evaluation/performance/README.md) measures complete-process peak RSS for named representative workloads, including final serialization, but does not enforce memory or time for arbitrary inputs. Crafted inputs can still consume excessive time or transient memory within fixed admission bounds. Do not expose the CLI as an unauthenticated hostile-upload service until process-level hard time and memory enforcement are complete.

`Milky2018/svgdiff@0.3.3` is published on Mooncakes with its Apache-2.0 license, focused registry README, dependency versions, and package checksum. Its repository field is intentionally absent because this checkout has no configured canonical Git remote; do not replace that omission with an unverified URL. The publication archive excludes repository-only tests, evaluations, issues, scripts, prototypes, release automation, and security documentation, so consumers should use the registry checksum and packaged license as the available source-distribution evidence until a canonical repository is established.

## Current upstream follow-ups and blockers

| Item | Live upstream status on 2026-07-14 | Project impact | Current safe behavior |
| --- | --- | --- | --- |
| [`mizchi/svg#4`](https://github.com/mizchi/svg/pull/4): inline style precedence | Open, ready for review; the pinned `0.2.1` package does not contain the change | The raw dependency can resolve conflicting presentation and inline declarations in XML attribute order | Normalize complete supported overlaps in a private renderer-input copy; retain `renderer_style_precedence_unresolved` only when a safe rewrite is unproven |
| [`mizchi/image-mbt#3`](https://github.com/mizchi/image-mbt/pull/3): derive `Debug` for assert-equality types | Open, ready for review | Direct `mizchi/image` dependencies fail while compiling packaged upstream tests, but the decoder implementation remains usable | Keep canvas and direct image dependencies out of production; maintain the narrow attributed workspace codec without patching the dependency cache |
| `moonbitlang/x@0.4.40` `Rational[Int64]` lacks `Debug` in dependency `assert_eq` tests | No matching open upstream PR found in the 2026-07-14 check | `moon doc` fails while checking transitive dependency tests | Use `moon ide doc` and `moon info`; project check, tests, and CLI remain green |

Deterministic font analysis is a deferred product capability, not an upstream blocker. It remains tracked separately because the font environment and shaping contract require a design decision before implementation.

## Refresh procedure

Refresh this ledger whenever a dependency version changes and at every release milestone:

1. inspect `moon.mod` and resolved `.mooncakes/*/moon.mod*` versions;
2. verify each manifest license against the packaged LICENSE or upstream repository;
3. review new transitive dependencies and native code;
4. query every linked upstream PR and replace stale status text;
5. rerun security boundary tests, CLI integration, fuzz smoke, representative performance budgets, and the pinned Chromium HTML security gate;
6. update [`renderer-evaluation.md`](renderer-evaluation.md), [`feature-coverage.md`](feature-coverage.md), and the upgrade procedure when behavior changes;
7. leave resolved blocker history in issues or ADRs rather than deleting it from the record.

Dependency upgrades must follow [`upgrade-procedures.md`](upgrade-procedures.md).
