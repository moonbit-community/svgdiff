# SVG Diff Roadmap

Status: living post-v1 roadmap

Last reviewed: 2026-07-17

This roadmap records remaining work between the current deterministic static-SVG implementation and the terminal product goal:

> Enable an agent without multimodal perception to identify the important visual-semantic differences between two SVG artifacts, measure their magnitude, locate their effects, and inspect a causally sound set of possible reasons using only a machine-readable report.

The completed v1 foundation is tracked in [`issues/`](issues/). This file is the detailed post-v1 capability backlog, not the current support contract. An unchecked item may be planned, deferred, or awaiting a design decision; tags make that state explicit. See [`docs/v1-scope.md`](docs/v1-scope.md) for implemented behavior.

## Milestone view

| Milestone | Outcome | Main phases |
| --- | --- | --- |
| M1 | Installable, benchmarked, evidence-first CLI | 0-2, 7, 11 |
| M2 | Credible essential static-SVG coverage | 2-6 |
| M3 | Agent-grade main-difference reporting | 0, 4-7 |
| M4 | Deterministic text and packaged resources | 3, 8 |
| M5 | Optional advanced comparison profiles | 9-10 |

The phase checklists below are intentionally exhaustive. Use the milestone gates near the end for release decisions and the phase lists for issue creation. Items should move into the issue tracker when scheduled; completion evidence belongs in the issue rather than being duplicated here.

Milestone reviews follow [`docs/roadmap-governance.md`](docs/roadmap-governance.md). Planned, deferred, and undecided capabilities remain visible; any intentional rejection or supersession must be recorded in that document before an item is removed.

## Tags

- **P0**: required for the next credible product milestone.
- **P1**: required for broad deterministic static-SVG usefulness.
- **P2**: valuable after the core static pipeline is credible.
- **Deferred**: explicitly recorded but not currently scheduled.
- **Decision**: requires an ADR or accepted design before implementation.

## Non-negotiable correctness rules

- Keep Source Semantics, Computed Appearance, and Rendered Evidence independently reportable.
- Preserve continuous measurements; never replace them with only a visibility boolean, label, or universal score.
- Exclude pure XML formatting variation from Visual Differences while preserving supported authored representation changes, computed equivalence, rendered-zero outcomes, and raw magnitude evidence as distinct states.
- Enumerate every supported Atomic Difference, group by domain, and order only with an explicit versioned policy.
- Treat measured zero, not-computed, indeterminate, unsupported, and failed as different states.
- Never claim `complete` when an unsupported semantic, missing resource, renderer gap, or failed measurement could affect the result.
- Guarantee that every `complete` Cause Envelope contains every actual changed cause; allow false positives but not false negatives.
- Keep report-local identity separate from authored SVG IDs and source order.
- Record every comparison environment input that can affect results.
- Keep HTML and other presentation layers outside the core comparison contract.

## Phase 0: Evaluation foundation

- [x] **P0** Define an agent-facing acceptance specification for identifying difference kind, magnitude, location, and possible cause.
- [x] **P0** Build a curated corpus of real SVG pairs covering equivalent, subtle, salient, structural, resource-mediated, zero-contribution, and unsupported cases.
- [x] **P0** Add mutation-generated pairs with known changed facts and known affected subjects.
- [x] **P0** Record human labels for the main visual changes, their relative importance, and acceptable alternative descriptions.
- [x] **P0** Record region ground truth or conservative reference bounds for localizable cases.
- [x] **P0** Record actual-cause ground truth for cases used to test Cause Envelope recall.
- [x] **P0** Build a text-only agent evaluation harness that consumes only Structured Report JSON.
- [x] **P0** Measure Atomic Difference recall, main-difference ranking quality, region overlap, Cause Envelope recall, and false-positive volume.
- [x] **P0** Establish regression thresholds and publish a reproducible benchmark command.
- [x] **P0** Separate renderer-conformance failures from report-model and agent-interpretation failures in benchmark results.
- [x] **P1** Add adversarial pairs designed to trigger false `complete`, false equality, wrong alignment, attribution leakage, and magnitude-ordering failures.
- [x] **P1** Add a compatibility corpus for schema and policy-version migrations.

## Phase 1: Installable CLI and stable distribution

- [x] **P0** Provide an installation workflow that makes `svgdiff before.svg after.svg` available on `PATH`.
- [x] **P0** Publish release-mode native binaries for supported operating systems and architectures.
- [x] **P0** Add `--help` and `--version` output with schema, engine, renderer, and policy versions.
- [x] **P0** Document stdin/stdout behavior and decide whether `-` denotes an SVG stream.
- [x] **P0** Stabilize exit-code semantics for complete, partial, failed, invalid-argument, and I/O outcomes.
- [x] **P0** Add a compact agent-oriented JSON mode without removing canonical evidence.
- [x] **P1** Add shell completion and package-manager installation where maintainable.
- [x] **P1** Publish `Milky2018/svgdiff` as a consumable MoonBit library module.
- [x] **P1** Define semantic-versioning rules for the MoonBit interface, JSON Schema, diagnostics, and ranking policies.
- [x] **P1** Produce checksums, provenance metadata, licenses, and dependency notices for releases.

## Phase 2: Coverage contract and renderer conformance

- [x] **P0** Replace coarse `complete`/`partial` reasoning with an explicit per-feature and per-evidence-layer coverage matrix.
- [x] **P0** Define proof obligations that every analyzer must satisfy before it may contribute to a `complete` report.
- [x] **P0** Add property tests that unsupported inputs can never produce complete equality.
- [x] **P0** Add mutation tests for every currently supported property and subject kind.
- [x] **P0** Resolve [ISS-002](issues/ISS-002.md), upgrading the renderer or privately normalizing inline-style precedence.
- [x] **P0** Build a browser-based rendering oracle for supported deterministic fixtures.
- [x] **P0** Compare the pinned renderer against the oracle for geometry, paint, alpha, clipping, and compositing cases as coverage expands.
- [x] **P0** Convert every accepted renderer divergence into either an adapter fix, a narrower completeness claim, or a stable Diagnostic.
- [x] **P1** Version the renderer conformance profile separately from the JSON Schema.
- [x] **P1** Define the minimum conformance threshold that triggers a focused upstream patch versus a project-owned rendering module.
- [x] **P1** Add alternate-scale rerendering as renderer QA only, without allowing it to redefine canonical report evidence.
- [x] **P1** Make missing renderer capabilities observable through structured capability metadata.

## Phase 3: Source Semantics and Computed Appearance coverage

### Geometry and coordinate systems

- [x] **P0** Implement complete `path` parsing, normalization, and segment-level source evidence.
- [x] **P0** Compare path geometry with exact segment parameters and painted-boundary measurements.
- [x] **P0** Implement transform lists and cumulative transforms for entities, groups, resources, and nested viewports.
- [x] **P0** Decompose transform changes into translation, rotation, scale, skew, and residual matrix effects.
- [x] **P0** Implement `viewBox`, `preserveAspectRatio`, intrinsic sizing, and nested `<svg>` viewport semantics.
- [x] **P1** Complete geometry edge cases for rect, circle, ellipse, line, polyline, and polygon.
- [x] **P1** Implement stroke geometry including width, line caps, joins, miter limits, dash arrays, dash offsets, and `vector-effect`.
- [x] **P1** Implement marker placement and marker viewport/orientation semantics.
- [x] **P1** Preserve exact authored units while resolving device-space and viewport-relative values.

### CSS, inheritance, and paint

- [x] **P0** Implement the SVG/CSS cascade with presentation attributes, inline style, stylesheet rules, specificity, source order, and `!important`.
- [x] **P0** Implement selector matching for the supported static scope.
- [x] **P0** Implement ordinary inheritance for every supported visual property.
- [x] **P0** Implement `inherit`, `initial`, `unset`, `revert`, `currentColor`, and CSS custom properties where they affect supported SVG values.
- [x] **P0** Preserve declaration origin and Source Span provenance through cascade resolution.
- [x] **P1** Implement complete solid-color syntax and opacity semantics.
- [x] **P1** Implement full linear and radial gradient semantics, including all stops, offsets, opacity, units, spread methods, transforms, inheritance, and references.
- [x] **P1** Implement patterns and their coordinate, transform, viewport, and reference semantics.
- [x] **P1** Implement paint fallback lists and missing-paint-server behavior.
- [x] **P1** Implement `paint-order`, fill rules, clip rules, and inherited paint dependencies.

### Structure, reuse, and resources

- [x] **P0** Model `<g>`, `<defs>`, `<symbol>`, and `<use>` without losing instance-versus-definition identity.
- [x] **P0** Report structural changes that alter computed appearance, stacking, inheritance, or resource resolution.
- [x] **P0** Build a resource dependency graph for gradients, patterns, markers, clips, masks, filters, symbols, and images.
- [x] **P1** Implement embedded raster-image and data-URI resources under a declared resource policy.
- [x] **P1** Implement explicitly supplied local resource bundles without implicit network fetching.
- [x] **P1** Define missing, cyclic, invalid, and unused resource behavior.
- [x] **P1** Keep nonvisual metadata outside visual Atomic Differences while preserving an optional source-only audit path.

### Compositing and effects

- [x] **P0** Implement group opacity as an isolated compositing operation rather than inherited leaf opacity.
- [x] **P0** Implement clipping with exact or conservative effect bounds.
- [x] **P0** Implement masking, including luminance/alpha mask semantics and resource units.
- [x] **P1** Implement filter primitive graphs, filter regions, intermediate surfaces, and conservative expansion bounds.
- [x] **P1** Implement blending modes, isolation, and stacking/compositing dependencies.
- [x] **P1** Define deterministic handling for unsupported filter primitives without losing source differences.

## Phase 4: Subject Alignment and Visual Event construction

- [x] **P0** Extend Subject Alignment to paths, groups, text, resource definitions, and `<use>` instances.
- [x] **P0** Add transform-aware and rendered-geometry-aware correspondence features.
- [x] **P0** Improve repeated-subject matching without relying on authored IDs or source order.
- [x] **P0** Record alignment evidence, ambiguity, and confidence without converting uncertainty into equality.
- [x] **P1** Validate one-to-one, insertion, deletion, split, merge, and many-to-many reorganizations on the benchmark corpus.
- [x] **P1** Define stable deterministic tie-breaking for equally plausible alignments.
- [x] **P1** Align Visual Resources separately from Visual Entities while preserving mediated outcomes.
- [x] **P1** Define when one source change creates multiple visual outcomes and when several changes form one Visual Event.
- [x] **Decision** Decide whether and how to aggregate Visual Events across Primary Subject Alignments by space, hierarchy, shared resources, or outcome coherence.
- [ ] **Deferred** Implement cross-subject event aggregation only after its exact invariants and evaluation criteria are accepted.

## Phase 5: Difference Magnitudes and importance

- [x] **P0** Complete exact parameter magnitudes in authored units, CSS pixels, viewport fractions, and entity-relative scales.
- [x] **P0** Add painted-boundary displacement distributions with mean, p95, and maximum values.
- [x] **P0** Add symmetric coverage-difference measurements independent of color.
- [x] **P0** Add event-local perceptual color measurements after explicit background compositing.
- [x] **P0** Implement FLIP as an optional event-local perceptual map with all viewing parameters recorded.
- [x] **P0** Preserve canvas, event-region, p95, maximum, and area-above-threshold perceptual statistics separately.
- [x] **P0** Define a versioned Impact Assessment policy for identifying the main visual differences across domains.
- [x] **P0** Run a reproducible Impact threshold and ordering calibration study on the human-labeled corpus before assigning labels such as subtle or major; the v1 study rejected every production candidate.
- [ ] **Deferred** Re-run Impact calibration and publish a new calibrated policy only after independent reviewer agreement, ranked multi-event cases, broader tier coverage, complete policy inputs, and profile sensitivity evidence exist.
- [x] **P0** Keep the raw score vector authoritative beneath every policy-dependent Impact Assessment and across legacy reports where one is unavailable.
- [x] **P1** Add DeltaEOK or CIEDE2000 under an explicitly declared perceptual background.
- [x] **P1** Evaluate SSIM/MS-SSIM only as secondary structural diagnostics; retain them as QA-only observations and reject canonical report or Impact semantics.
- [x] **P2** Evaluate LPIPS as an optional experiment, never as an equality oracle.
- [x] **P1** Define policy behavior for spatially small but semantically important changes; preserve query-matching dominated events from the complete inventory without inferring semantic priority from visual magnitude or SVG source.
- [x] **P1** Version and test domain-specific lexicographic ordering tuples.
- [x] **Decision** Decide whether a cross-domain scalar is needed at all; if adopted, record policy ID, weights, thresholds, corpus, and metric versions.

## Phase 6: Difference Regions and causal completeness

- [x] **P0** Localize transformed geometry, strokes, markers, clips, masks, filters, bounded SVG shadow regions, and composited groups without fabricating unsupported pixels or exact causes.
- [x] **P0** Preserve separate before/after effect bounds for insertions, deletions, and movement.
- [x] **P0** Attach source subjects and rendered regions without allowing scene-wide pixels to contaminate subject-specific evidence.
- [x] **P0** Propagate may-influence tokens through every supported geometry, paint, resource, transform, and structural input.
- [x] **P0** Propagate provenance through group surfaces, clips, masks, filters, blending, and compositing.
- [x] **P0** Union before and after provenance for every Difference Region.
- [x] **P0** Fall back to all Changed Facts or revoke the guarantee whenever a propagation rule is unavailable.
- [x] **P0** Add property tests asserting that actual causes are always contained in every complete Cause Envelope.
- [x] **P0** Measure false-positive candidate volume so conservative completeness remains useful to agents.
- [x] **P1** Use tile- or region-level provenance to remove irrelevant facts without weakening soundness.
- [x] **Decision** Decide whether exact Contribution Index propagation is worth its complexity beyond the accepted sound over-approximation guarantee.
- [ ] **Deferred** Implement exact contribution weights only if a concrete agent task cannot be solved with conservative candidate sets and ranking.

## Phase 7: Agent-oriented Structured Report

- [x] **P0** Add a machine-readable summary of the highest-impact Visual Events while retaining the full difference inventory through required `ImpactAssessment` and complete event/difference arrays.
- [x] **P0** Make supported source-only, computed-equivalent, computed-different/rendered-zero, rendered-nonzero, partial, and failed outcomes distinguishable through explicit report fields; pure XML formatting remains intentionally outside Visual Differences.
- [ ] **Deferred** Add calibrated subtle/salient or other severity outcome classes only after the Impact recalibration prerequisites are satisfied under a new policy identity.
- [x] **P0** Add explicit coverage summaries by subject, feature, and evidence layer.
- [x] **P0** Expose explicit alignment ambiguity and uncalibrated confidence availability; represent interpretation uncertainty separately through `indeterminate`, Diagnostics, and coverage.
- [ ] **Deferred** Calibrate alignment confidence only after independent correspondence ground truth, representative ambiguous cases, profile sensitivity, calibration error, and abstention behavior are versioned.
- [x] **P0** Provide stable transitive links from Impact summary groups through Visual Events and Atomic Differences to Changed Facts, regions, Cause Envelopes, and Diagnostics.
- [x] **P0** Guarantee deterministic ordering and report-local identifiers for identical inputs and profiles.
- [x] **P0** Validate through the report-only protocol and independent machine metrics that an Agent answer can retain what changed, exact multidimensional magnitude, where, and possible causes from JSON alone; external language-model acceptance remains in M3.
- [x] **P1** Add versioned lossless line-addressable report projection JSONL for limited-context Agents, with exact canonical reconstruction rather than deleted evidence.
- [x] **P1** Add schema examples for equivalent spelling, tiny numeric deltas, salient changes, insertion/deletion, resources, and partial coverage.
- [x] **P1** Define JSON Schema compatibility and migration tests for every released schema version.
- [x] **P1** Add optional deterministic Markdown summaries only as derived presentation, never as source-of-truth evidence.
- [x] **P2** Improve the HTML report after core agent evaluation identifies concrete inspection needs, exposing what/how much/where/why evidence without changing the Structured Report.

## Phase 8: Deterministic text and fonts

This phase is explicitly recorded but not currently scheduled. It expands [ISS-013](issues/ISS-013.md).

- [x] **Decision** Define the font-resource bundle, fingerprint, versioning, licensing, and reproducibility contract.
- [x] **Decision** Select or build deterministic shaping and glyph-rasterization dependencies.
- [ ] **Deferred** Implement explicit font loading with no unspecified system-font dependency.
- [ ] **Deferred** Implement deterministic family matching, fallback selection, style, weight, stretch, and variable-font axes.
- [ ] **Deferred** Implement Unicode shaping, script runs, bidirectional text, ligatures, kerning, language, and feature selection.
- [ ] **Deferred** Implement SVG text layout including `x`, `y`, `dx`, `dy`, `rotate`, anchors, baselines, `tspan`, `textLength`, and `textPath`.
- [ ] **Deferred** Preserve source facts separately from shaped runs, positioned glyphs, and rendered glyph evidence.
- [ ] **Deferred** Align text subjects, runs, and glyph outcomes across edits.
- [ ] **Deferred** Compute deterministic glyph bounds, Difference Regions, magnitudes, and Cause Envelopes.
- [ ] **Deferred** Add multilingual, fallback, emoji, ligature, vertical-text, and variable-font fixtures.
- [x] **Decision** Decide whether platform-native font rendering modes are supported profiles or permanent non-goals.

## Phase 9: Color, backgrounds, and renderer profiles

- [x] **P1** Add an explicit Perceptual Background to the Comparison Profile.
- [x] **P1** Composite both inputs over exactly the same declared background before display-dependent metrics.
- [x] **P1** Keep transparent-canvas raw evidence independent from perceptual-background evidence.
- [x] **P1** Detect embedded ICC, Display-P3, wide-gamut, and HDR content and emit precise coverage diagnostics without out-of-profile color conversion.
- [x] **Decision** Define color-management profiles beyond v1 sRGB.
- [x] **Decision** Define whether multiple renderer or browser profiles compare one engine against itself, browsers against each other, or both.
- [ ] **Deferred** Implement cross-browser comparison profiles without weakening single-profile equality claims.
- [ ] **Deferred** Add platform-specific rendering profiles only when their environment and resource inputs are fully declared.

## Phase 10: Dynamic and externally hosted content

These capabilities remain outside deterministic static v1 and require explicit product decisions.

- [x] **Decision** Decide whether scripts remain a permanent non-goal or are evaluated in a sandboxed deterministic runtime.
- [x] **Decision** Decide how event-driven pseudo-classes and user-interaction state are declared and reproduced.
- [x] **Decision** Define a timeline model for SMIL, CSS, and script-driven animation comparisons.
- [ ] **Deferred** Compare animation keyframes, sampled times, or temporal difference intervals only after the timeline model is accepted.
- [x] **Decision** Decide whether static `foreignObject` requires an embedded deterministic HTML/CSS layout engine.
- [ ] **Deferred** Render `foreignObject` only under a pinned layout, font, resource, and scripting profile.
- [ ] **Decision** Define explicit resource bundles for assets beyond embedded and caller-supplied resources.
- [ ] **Deferred** Add network-backed acquisition only as a separate prefetch step; never perform implicit comparison-time fetching.

## Phase 11: Robustness, security, and performance

- [x] **P0** Fuzz XML parsing, SVG semantic adaptation, renderer inputs, JSON serialization, and HTML escaping.
- [x] **P0** Add resource limits for input bytes, element count, path complexity, recursion, references, raster dimensions, regions, and report size.
- [x] **P0** Detect reference cycles and adversarial expansion without hanging or exhausting memory.
- [x] **P0** Preserve actionable Diagnostics and Source Spans for malformed or limited inputs.
- [x] **P0** Keep generated HTML sandboxed and safe for hostile SVG source.
- [x] **P1** Benchmark parse, alignment, rendering, region extraction, provenance, and serialization separately.
- [x] **P1** Establish performance and memory budgets for representative small, medium, and large SVGs.
- [x] **P1** Optimize only measured hot paths while preserving deterministic output.
- [x] **P1** Add cancellation and time-budget handling for embedding agents.
- [x] **P1** Test deterministic output across supported operating systems and architectures.
- [x] **P1** Add CI for formatting, warning checks, interfaces, tests, CLI integration, schema validation, fuzz smoke tests, and benchmark sanity.
- [ ] **P2** Investigate incremental or cached comparisons only after correctness and profile identity are stable.

## Phase 12: Documentation and maintenance

- [x] **P0** Replace stale design open decisions with accepted ADRs or explicit unresolved entries.
- [x] **P0** Maintain a feature-to-coverage matrix linked to Diagnostics and tests.
- [x] **P0** Document exactly what `complete`, `partial`, and `failed` guarantee to callers.
- [x] **P0** Document report interpretation for text-only agents with worked examples.
- [x] **P1** Generate public MoonBit interface documentation and library examples.
- [x] **P1** Document renderer, XML parser, metric, schema, and policy upgrade procedures.
- [x] **P1** Keep dependency licenses, security posture, and upstream blockers current.
- [x] **P1** Convert roadmap items into `ISS-###` issues only when they are accepted for implementation; do not duplicate unscheduled work prematurely.
- [x] **P1** Remove or archive `prototype/influence_provenance` after all validated logic is absorbed and no experiment still depends on it.
- [x] **P1** Review this roadmap at every milestone and record intentionally rejected capabilities rather than silently deleting them.

## Review log

| Date | Review point | Result |
| --- | --- | --- |
| 2026-07-14 | Pre-M1 baseline | Retained every unchecked capability; established the rejection ledger from accepted ADRs. |
| 2026-07-16 | Impact calibration v1 | Completed the reproducible calibration study, rejected production labels and total ordering from insufficient evidence, and retained an explicit prerequisite-bound recalibration item plus the M3 calibrated-Impact gate. |
| 2026-07-16 | SSIM/MS-SSIM diagnostic evaluation | Accepted versioned QA-only structural observations; rejected report, equality, localization, severity, and Impact meanings after scale, coverage, availability, and human-order failures. |
| 2026-07-16 | Query-conditioned semantic concerns | Retained context-free Impact, required dominated concern matches to remain recoverable from the complete inventory, and rejected source- or magnitude-derived semantic priority. |
| 2026-07-16 | Phase 7 main-event summary reconciliation | Confirmed required `ImpactAssessment` already satisfies the machine-readable summary item and added direct full-inventory and reference-closure regression checks. |
| 2026-07-16 | Phase 7 outcome-state reconciliation | Codified explicit evidence-state distinctions, retained pure formatting exclusion, and kept subtle/salient severity labels deferred behind Impact calibration prerequisites. |
| 2026-07-16 | Phase 7 uncertainty reconciliation | Confirmed alignment ambiguity and confidence availability are explicit, kept interpretation indeterminacy Diagnostic-based, and retained calibrated alignment confidence as deferred work. |
| 2026-07-16 | Phase 7 summary traceability | Enforced exact frontier event-to-difference projection and retained downstream regions, causes, facts, and Diagnostics through the existing closed evidence graph. |
| 2026-07-17 | Script execution boundary | Permanently excluded SVG script execution from canonical analysis, retained secure-static coverage guards, and allowed only future separately versioned external observations after state, security, replay, and authority gates. |
| 2026-07-17 | Interaction state boundary | Accepted typed checkpoint seeds plus derived pseudo-class state for future canonical work, while keeping WebDriver-style action scenarios and achieved-state evidence as target-local observations. |
| 2026-07-17 | Animation timeline boundary | Accepted exact logical checkpoint questions with document-time locking by default, retained native mechanism and trigger state, and prohibited finite sampling or browser delay from proving temporal intervals. |
| 2026-07-17 | Static foreignObject layout boundary | Required a deterministic host-language engine for general canonical XHTML, allowed smaller closed evaluators without wider claims, and kept browser layout as target-local observation evidence. |

## Milestone gates

### M1: Installable evidence-first CLI

- [x] `svgdiff before.svg after.svg` works after a documented installation step.
- [x] The schema, exit codes, profile identity, and compact agent projection are versioned.
- [x] CI publishes tested native binaries and checksums.

### M2: Credible essential static SVG coverage

- [ ] Paths, transforms, viewports, CSS cascade, reuse, gradients, clipping, masking, and group compositing have explicit complete or partial behavior.
- [ ] Renderer conformance and coverage gates prevent false complete equality.
- [ ] Subject alignment, regions, and Cause Envelopes remain sound across the supported set.

### M3: Agent-grade main-difference reporting

- [ ] A text-only agent benchmark demonstrates acceptable difference recall, localization, causal recall, and main-event ranking.
- [ ] Event-local perceptual evidence and calibrated Impact Assessment are available without replacing raw measurements.
- [ ] Compact summaries link losslessly to the complete evidence graph.

### M4: Deterministic text and packaged resources

- [ ] Fonts, shaping, text layout, glyph rendering, images, and explicit resource bundles are deterministic and fingerprinted.
- [ ] Multilingual and resource-mediated benchmark cases meet the agent-evaluation thresholds.

### M5: Optional advanced profiles

- [ ] Every adopted dynamic, `foreignObject`, wide-gamut, platform, or cross-renderer capability has a pinned environment and separate profile identity.
- [ ] Capabilities that remain non-goals are explicitly documented and continue to reduce coverage rather than imply equality.

## Terminal acceptance

- [ ] For the declared supported profile, every real visual-semantic difference is either reported with evidence or covered by an explicit Diagnostic that prevents a false completeness claim.
- [ ] Reported magnitudes preserve exact, geometric, raster, coverage, color, and perceptual evidence where applicable.
- [ ] A text-only agent reliably identifies the important changes, their locations, and a causally sound set of possible reasons on the accepted benchmark corpus.
- [ ] The tool remains deterministic, installable, secure on hostile input, versioned, and reproducible across supported environments.
