# Dependency, Security, and Upstream Status

Status: current maintenance ledger

Last verified: 2026-07-14

This ledger records the licenses shipped with the currently resolved packages, the security boundary implemented by schema `1.2`, and external blockers that still affect development or coverage. It is not a release SBOM or legal opinion.

## Resolved dependencies and licenses

| Dependency | Relationship | Resolved version | Manifest license | License file in installed package |
| --- | --- | ---: | --- | --- |
| `Milky2018/xml` | Direct; authored XML and Source Spans | `0.4.0` | Apache-2.0 | Yes |
| `mizchi/svg` | Direct; scene and canonical v1 renderer | `0.2.1` | Apache-2.0 | No |
| `mizchi/pixelmatch` | Direct; baseline image difference support | `0.6.1` | Apache-2.0 | Yes |
| `moonbitlang/async` | Direct module dependency | `0.19.1` | Apache-2.0 | Yes |
| `moonbitlang/x` | Direct module dependency | `0.4.40` | Apache-2.0 | No |
| `moonbitlang/quickcheck` | Direct module dependency retained by `moon info` | `0.14.0` | Apache-2.0 | Yes |
| `mizchi/image` | Transitive through `pixelmatch` | `0.1.2` | Apache-2.0 | No |
| `mizchi/zlib` | Transitive through `image` | `0.4.0` | Apache-2.0 | Yes |

Evidence comes from the resolved `.mooncakes` manifests and packaged LICENSE files on 2026-07-14. The root project declares Apache-2.0 and includes its own [`LICENSE`](../LICENSE).

All resolved manifests declare Apache-2.0, but three installed package archives omit a LICENSE file. The current [release dependency manifest](../release/dependencies.v1.json) preserves that evidence distinction instead of pretending every archive carried its own text. The [native release bundle](../release/README.md) includes the complete Apache-2.0 text and generates versioned third-party notices for all eight resolved packages. This is transparent packaging evidence, not a legal opinion.

`mizchi/canvas@0.9.0` and its `mizchi/image@0.4.2` dependency were used only in an experiment. They are not part of the production dependency graph above.

## Current security boundary

### Input parsing

- `Milky2018/xml@0.4.0` enforces document well-formedness, rejects duplicate attributes and trailing content, bounds entity expansion, and does not implicitly resolve external entities.
- Namespace-aware UTF-16 Source Spans allow parse failures and authored facts to be localized without reparsing untrusted text through a second XML implementation.
- Unsupported SVG elements, attributes, CSS, resources, and dynamic behavior reduce analysis coverage through Diagnostics rather than being executed or treated as equality.
- The comparison engine performs no implicit network fetches.

### Rendering and HTML output

- Both SVG inputs use one explicit local viewport and a pinned renderer identity.
- Original SVG sources are placed in sandboxed iframe preview documents in the HTML report. The iframe has an empty `sandbox` token set, so embedded scripts cannot execute.
- Preview `srcdoc` content and report JSON are HTML-escaped before embedding.
- The preview document applies `default-src 'none'`; the top-level report allows only its own inline presentation script and styles.
- The pinned Chromium [HTML security gate](../evaluation/html-security/README.md) verifies that hostile scripts and event handlers do not execute, the parent report is not mutated, and hostile external resource URLs produce no requests.
- Semantic classification comes only from the Structured Report. Browser rendering in the report cannot promote unsupported input to complete analysis.

### CLI and data access

- The CLI reads only the two paths explicitly supplied by the caller and writes only explicitly requested JSON or HTML paths.
- Invalid arguments and file I/O errors exit with status `2`; malformed SVG analysis exits with status `1`.
- A partial report is returned successfully so Diagnostics remain machine-readable.

## Known security gaps

Schema `1.2` does not yet provide production-grade hostile-input resource control:

- no configurable limit for input bytes, element count, nesting depth, path complexity, references, raster dimensions, region count, or report size;
- no cancellation or comparison time budget;
- no coverage-guided or sanitizer-guided fuzzing; the fixed-seed generative [fuzz smoke](../evaluation/fuzz/README.md) covers parser, adapter, renderer, JSON, and HTML boundaries but does not measure code coverage;
- no automated dependency advisory or SBOM check, and no CI enforcement or signing of the locally generated license and provenance evidence;
- no cross-platform determinism gate for released binaries.

These gaps do not permit false complete analysis, but they can permit excessive CPU, memory, or output growth. Do not expose the CLI as an unauthenticated service for hostile SVG uploads until the Phase 11 resource-limit work is complete.

## Current upstream blockers

| Blocker | Live upstream status on 2026-07-14 | Project impact | Current safe behavior |
| --- | --- | --- | --- |
| [`mizchi/svg#4`](https://github.com/mizchi/svg/pull/4): inline style precedence | Open, ready for review; the pinned `0.2.1` package does not contain the change | The pinned renderer can resolve conflicting presentation and inline declarations in XML attribute order | Emit `renderer_style_precedence_unresolved`; keep Source Semantics; make computed/rendered coverage partial |
| [`mizchi/image-mbt#3`](https://github.com/mizchi/image-mbt/pull/3): derive `Debug` for assert-equality types | Open, ready for review | Blocks the evaluated `mizchi/canvas` path and contributes to `moon doc` dependency-test failure | Keep canvas out of production; do not patch the dependency cache |
| `moonbitlang/x@0.4.40` `Rational[Int64]` lacks `Debug` in dependency `assert_eq` tests | No matching open upstream PR found in the 2026-07-14 check | `moon doc` fails while checking transitive dependency tests | Use `moon ide doc` and `moon info`; project check, tests, and CLI remain green |

Deterministic font analysis is a deferred product capability, not an upstream blocker. It remains tracked separately because the font environment and shaping contract require a design decision before implementation.

## Refresh procedure

Refresh this ledger whenever a dependency version changes and at every release milestone:

1. inspect `moon.mod` and resolved `.mooncakes/*/moon.mod*` versions;
2. verify each manifest license against the packaged LICENSE or upstream repository;
3. review new transitive dependencies and native code;
4. query every linked upstream PR and replace stale status text;
5. rerun security boundary tests, CLI integration, fuzz smoke, and the pinned Chromium HTML security gate;
6. update [`renderer-evaluation.md`](renderer-evaluation.md), [`feature-coverage.md`](feature-coverage.md), and the upgrade procedure when behavior changes;
7. leave resolved blocker history in issues or ADRs rather than deleting it from the record.

Dependency upgrades must follow [`upgrade-procedures.md`](upgrade-procedures.md).
