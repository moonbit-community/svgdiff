# Dependency and Contract Upgrade Procedures

Status: current maintenance procedure

Last verified: 2026-07-22

Renderer, parser, metric, schema, same-domain ordering-policy, and Impact Assessment policy versions influence the meaning of a report. They must not be upgraded as isolated dependency edits. This document defines the evidence and synchronized changes required before an upgrade may be merged.

## Current pinned identities

| Component | Current identity | Contract surface |
| --- | --- | --- |
| SVG scene and canonical renderer | `svgdiff/residual-paint-normalizer@1+opacity-used-value-normalizer@1+length-unit-normalizer@1+shape-css-points-normalizer@1+stroke-length-normalizer@1+mask-edge-semantics-normalizer@1+isolated-group-compositor@1+static-mask-compositor@1+empty-filter-outcome-adapter@1+static-blend-compositor@1+Milky2018/svg@0.3.1` | `profile.renderer_id`, rendered magnitudes, Difference Regions, coverage guards |
| Renderer conformance profile | `svgdiff-renderer-conformance-profile/27` | conformance fixtures, dispositions, guards, thresholds, and Rendered Evidence claims |
| Authored XML parser | `Milky2018/xml@0.4.0` | well-formedness, namespaces, entity behavior, UTF-16 Source Spans |
| Baseline pixel comparison | `mizchi/pixelmatch@0.6.1` | connected pixel-mask regions and renderer comparison support |
| Embedded raster codec | `Milky2018/svgdiff-raster-codec@0.1.1` plus `mizchi/zlib@0.4.6` | admitted PNG/JPEG bytes, format-level color metadata, dimensions, normalized RGBA8 pixels, and intrinsic magnitude inputs |
| Raster metric representation | `linear_srgb_premultiplied_rgba_f64` | `RenderedMagnitude` and `DifferenceMagnitude` numeric meaning |
| Perceptual color metric | `delta_e_ok_changed_pixels_after_linear_srgb_background/v1` | event-local changed-pixel sample count and arithmetic mean DeltaEOK |
| Perceptual spatial metric | `nvlabs_ldr_flip/v1.7-b475eb4b` | event-local LDR-FLIP maps, response bounds, quantization, and Viewing Conditions |
| JSON Schema | `2.0` | every serialized field, enum, omission rule, and top-level invariant |
| Nonvisual source-audit schema | `1.0` | source-only fact identity, paths, values, provenance, status, and parse failures |
| Same-domain ordering | `v2_domain_lexicographic` | `DomainOrdering.components` construction and comparison |
| Impact Assessment | `event_rendered_pareto/v1` | event eligibility, common rendered inputs, Pareto dominance, ties, incomparability, missing evidence, frontier groups, and domination witnesses |

The source of dependency versions is `modules/svgdiff/moon.mod`. The source of serialized constants is the public implementation plus [`schema/svgdiff-report.schema.json`](../schema/svgdiff-report.schema.json). The [compatibility and versioning contract](versioning.md) decides which identity each consumer-visible change must increment.

## General upgrade gate

Before changing any component:

1. Start from a clean worktree and record the old component identity.
2. State the reason for the upgrade and the concrete capability, bug, security fix, or conformance result it addresses.
3. Identify affected evidence layers and report fields.
4. Add or identify fixtures that fail or differ under the old version for the intended reason.
5. Run the existing baseline before the edit and preserve its output for comparison.
6. Change only the smallest required layer.
7. Review all changed report values; do not accept snapshot churn without explaining it.
8. Update current-contract documents, the feature coverage matrix, and profile or policy identity when semantics changed.
9. Run the common validation gate at the end of this document.

A successful build is necessary but never sufficient. An upgrade is accepted only when the report meaning and coverage claim remain explicit.

## SVG renderer upgrade

Use this procedure for `mizchi/svg`, a replacement renderer, or a project-owned rendering layer.

Before replacing or owning a layer, apply the [Renderer Upstream and Ownership Gate](renderer-ownership-gate.md). An upgrade that preserves dependency ownership does not need to pass the project-ownership admission threshold.

### Required evidence

- Run all current complete-eligible fixtures before and after the upgrade.
- Compare geometry, paint, alpha, presence, connected regions, and linear-premultiplied raster metrics.
- Re-run micro-delta cases in both directions around raster boundaries.
- Reproduce `scripts/test-alternate-scale-qa.sh` and review every scale-curve or directional-classification change as QA evidence only.
- Exercise every known preflight guard, especially inline-style precedence, invalid or unresolved gradient/pattern semantics, unsupported attributes, and group opacity.
- Add a regression fixture for every upstream bug the new version claims to fix.
- Use an external renderer only as a conformance oracle; do not substitute its output into the production profile without a separate decision.
- Run `scripts/test-browser-oracle.sh`, `scripts/test-renderer-conformance.sh`, and `scripts/test-renderer-dispositions.sh`; every changed divergence must receive a reviewed disposition.

### Required synchronized changes

- Update the dependency version in `modules/svgdiff/moon.mod` through
  `moon -C modules/svgdiff add` or the supported package command.
- Update `ComparisonProfile::v1_default().renderer_id` when the production renderer identity changes.
- Review and normally increment `renderer_conformance_profile_id` when fixtures, dispositions, guards, tolerances, or accepted capability claims change, even if the renderer package does not.
- Keep the Schema structural constraints for `profile.renderer_id` and `profile.renderer_conformance_profile_id` independent from concrete accepted identities; update the versioned consumer compatibility policy whenever either production identity changes.
- Update the conformance baseline, CLI version output, compatibility cases, and disposition validator together.
- Reassess Diagnostics whose only purpose was to guard an old renderer defect. Remove a guard only after its negative test is replaced by a positive conformance test.
- Update the encountered renderer-capability mapping and its tests whenever a renderer Diagnostic is added, removed, or changes support status.
- Update [`renderer-evaluation.md`](renderer-evaluation.md), [`feature-coverage.md`](feature-coverage.md), and [`v1-scope.md`](v1-scope.md).
- Review Difference Region and magnitude output for intentional numeric drift.

Changing pixels without changing `renderer_id` is a contract bug.

## Renderer conformance profile upgrade

Use this procedure when the renderer fixture set, divergence dispositions, accepted tolerances, production guards, or Rendered Evidence capability claims change without necessarily changing the report shape or renderer package.

1. Compare the old and proposed browser-oracle and pinned-renderer baselines.
2. Explain every added, removed, or changed divergence and its production consequence.
3. Allocate a new `renderer_conformance_profile_id` when the accepted claim changes; comment-only, formatting-only, and evaluation-tool refactors that preserve all evidence do not require a new ID.
4. Update `ComparisonProfile::v1_default`, the compatibility policy, conformance baseline, dispositions, disposition validator, CLI version output, and current-contract documentation together.
5. Keep `schema_version` unchanged when serialized field meanings and compatibility are unchanged; review `renderer_id` independently when implementation identity or pixel behavior changes.
6. Run the browser oracle, conformance comparison, dispositions, CLI, and benchmark gates before accepting the new profile.

## XML parser upgrade

Use this procedure for `Milky2018/xml` or any replacement source parser.

### Required evidence

- Reject trailing content, mismatched tags, duplicate attributes, unclosed elements, and malformed namespaces.
- Verify namespace-qualified elements and attributes.
- Verify single- and double-quoted attributes, entity expansion limits, and disabled implicit external entities.
- Verify exact authored value recovery from parser spans.
- Verify half-open UTF-16 offsets for ASCII, non-BMP characters, attributes, direct text, and parse errors.
- Confirm that parser-specific types remain private to the Source Semantics adapter.

The regression sources are [`source_adapter_wbtest.mbt`](../modules/svgdiff/engine/internal/diff/source_adapter_wbtest.mbt) and the historical [`milky-xml-evaluation.md`](research/milky-xml-evaluation.md). A new version should receive a dated evaluation follow-up rather than rewriting the historical snapshot.

### Required synchronized changes

- Update `modules/svgdiff/moon.mod` with
  `moon -C modules/svgdiff add`.
- Update parser identity in ownership and evaluation documents.
- Review every Source Span assertion and serialized source-fact fixture.
- Reassess `svg_parse_failed` behavior and any new parser error categories.
- If offset units or source-recovery semantics change, treat that as a report-contract change and follow the Schema procedure.

Parser permissiveness must never silently widen. A newly accepted malformed input requires an explicit correctness decision or a project-side rejection guard.

## Embedded raster codec upgrade

Use this procedure for the project-owned raster codec, its zlib dependency, or a newly admitted embedded image format.

- Preserve the no-I/O policy: only caller-supplied bytes may reach the decoder, and MIME plus signature validation must precede decoding.
- Prove exact and one-past behavior for source bytes, decoded bytes, dimensions, per-image pixels, cumulative pixels, and format-specific decompression output before accepting wider inputs.
- Re-run PNG and JPEG identity, malformed-input, compact-hash, intrinsic-magnitude, insertion/deletion, and mixed-scene final-evidence tests.
- Treat changes to normalized RGBA8 pixels, accepted format variants, failure classification, or intrinsic metric inputs as report semantics requiring Schema and compatibility review.
- Re-run Chromium image fixtures and renderer dispositions. Decoding success cannot remove `renderer_embedded_raster_unavailable`; only a separately reviewed compositor and conformance claim can do that.
- Package and validate the codec archive independently, then compile the root archive against it. Publish the codec version before any root module that declares it.

The codec is a resource decoder, not the production SVG renderer. Its intrinsic pixels must never be substituted into `RenderedEvidence` without placement, clipping, interpolation, stacking, opacity, and compositing semantics.

## Color execution profile admission or upgrade

No beyond-sRGB profile currently exists. Before admitting or changing one under `svgdiff-color-execution-profile/1`:

1. select one complete source-admission, conversion, interpolation, working/compositing, reference-output, measurement, limit, and build identity rather than a generic gamut flag;
2. preserve the old profile as a separately accepted identity and require before and after to use the same profile;
3. add exact conversion and interpolation vectors, extended-range and alpha cases, malformed and adversarial resources, negative controls, browser observations, and supported-target byte/numeric determinism evidence;
4. prove that every current out-of-profile Diagnostic is either retained or retired by a positive supported-path test without silently clipping, retagging, ignoring ICC data, or tone mapping;
5. review Perceptual Background, DeltaEOK, FLIP, raw raster magnitude, Impact inputs, renderer identity, renderer conformance, Schema, Agent guidance, resource limits, dependency licenses, and release artifacts independently; and
6. run the full Schema, compatibility, renderer, resource, metric, Agent, fuzz, performance, and cross-platform gates before release.

ICC dependency selection and HDR reference/display semantics require their own accepted decisions before implementation. Platform or physical-display captures remain external `svgdiff-color-observation/1` artifacts and cannot substitute for this gate.

## Multi-renderer experiment admission or upgrade

No multi-renderer container currently exists. Before implementing or changing `svgdiff-renderer-experiment-matrix/1` or `svgdiff-renderer-experiment-cell/1`:

1. preserve each current Structured Report or external observation as an independently identified cell with its native authority, status, coverage, errors, resources, environment, and output contract;
2. version cell, edge, comparator, cross-cell mapping, and Agent-synthesis contracts without reusing Schema, renderer, or renderer-conformance identities;
3. prove same-target profile edges and same-profile target edges separately, reject direct diagonal attribution, and retain before, after, and before-to-after outcome relations;
4. add negative controls for missing, failed, partial, ambient, cross-OS, unmatched, dimension-, alpha-, color-, and normalization-incompatible cells, all of which must yield `insufficient_evidence` where required;
5. require universal evidence over the declared required set for invariance, with no voting, averaging, preferred-renderer truth, or discarded disagreement; and
6. validate at least one closed four-cell rectangle plus sparse and failed matrices before adding product, Agent, CI, or release integration.

Follow the accepted [multi-renderer semantics](multi-renderer-profiles.md). External browser or platform cells cannot acquire Source Semantics, Computed Appearance, Visual Events, Cause Envelopes, or canonical completeness merely by entering the container.

## External script observation admission or upgrade

Canonical script execution is a permanent non-goal and no external observer currently exists. Before implementing or changing `svgdiff-script-observation/1`:

1. document the Agent task that static Structured Reports and existing observations cannot answer, then accept the prerequisite event-state, timeline, resource, API-closure, and capture-checkpoint contracts;
2. pin exact browser/runtime, DOM/SVG, harness, OS, sandbox, rendering, font, color, and output identities without adding them to the canonical comparison process;
3. close or reject every script-visible clock, entropy, locale, storage, permission, device, worker, network, service-worker, scheduling, and external-resource input, recording every attempted access;
4. add deterministic instruction/fuel and DOM/task/output limits plus independently enforced process, wall-time, memory, filesystem, credential, network, and descendant isolation;
5. preserve typed parse errors, exceptions, unsupported APIs, timeouts, kills, crashes, pending work, ambient state, and replay divergence as unavailable or failed evidence, never zero;
6. prove byte-identical repetition on adversarial fixtures and retain exact transcripts, mutation/final-state hashes, outputs, disagreement, and closure classification; and
7. validate mechanically that the observation cannot establish Structured Report equality, completeness, Computed Appearance, Visual Events, Impact, regions, or causal completeness.

Follow the accepted [script execution boundary](script-execution-boundary.md). Passing these gates admits only a target-local external observation, not a canonical Script Execution Profile.

## Interaction state profile or observation admission

No interaction profile, action scenario, or browser observation currently exists. Before implementing or changing `svgdiff-interaction-state-profile/1`, `svgdiff-interaction-scenario/1`, or `svgdiff-interaction-observation/1`:

1. state the Agent task and select one deliberately small pseudo-class slice, keeping static structural selectors, script execution, animation time, form controls, and browser UI states in their owning domains;
2. version exact checkpoint seeds, before/after target locators and mapping mode, state evaluator, selector grammar, focus policy, hit-test method, fixed-point algorithm, limits, and normalized manifest identity;
3. reject caller-supplied match booleans and add valid, empty, impossible, missing, ambiguous, wrong-instance, unstable-cycle, limit, and one-side-unavailable cases;
4. distinguish coordinate-locked from mapped-subject-locked checkpoints and prove geometry, clipping, stacking, transforms, `pointer-events`, focus ancestry, target fragments, and state-feedback behavior for the accepted slice;
5. for browser replay, version ordered action ticks separately and require achieved-state postconditions, transcripts, repeats, typed dispatch/default-action failures, and target-local authority;
6. preserve every invalid, unresolved, unsupported, unstable, divergent, or ambient state as unavailable or insufficient evidence, never selector non-match, zero, or equality; and
7. run selector, cascade, renderer-conformance, resource, determinism, Agent, adversarial, and cross-host gates before product or release integration.

Follow the accepted [interaction-state semantics](interaction-state-profiles.md). A browser action observation cannot define canonical selector applicability or upgrade a static report.

## Animation timeline profile or observation admission

No animation timeline profile, checkpoint set, or observation currently exists. Before implementing or changing `svgdiff-animation-timeline-profile/1`, `svgdiff-animation-checkpoint-set/1`, or `svgdiff-animation-observation/1`:

1. state the Agent task and choose one deliberately small declarative mechanism slice, leaving script execution external and unsupported timing guarded;
2. version exact rational time, origin and activation, mechanism evaluator, initial state and resources, triggers, effect locators and mappings, synchronization mode, capture phase, limits, and normalized manifest identity;
3. distinguish point, finite-point-set, boundary/event-set, and continuous-interval questions, and prohibit sample agreement from establishing interval equality;
4. use `document_time_locked` as the default before/after question, retain one-sided effects and boundaries, and keep `effect_phase_locked` diagnostic rather than substituting it for same-time evidence;
5. add exact controls for inactive and unresolved time, negative time and delay, pending tasks, pause, seek, fill, repeat, restart, indefinite duration, cancellation, event starts, transition generation and reversal, mapping failure, schedule cycles, and every limit;
6. for external replay, require requested and achieved timeline/effect state, event/task/microtask/frame transcripts, output hashes, repeats, typed divergence, isolation, and target-local authority; and
7. run source, cascade, state, script, resource, renderer-conformance, determinism, Agent, adversarial, and cross-host gates before product or release integration.

Follow the accepted [animation timeline semantics](animation-timeline-model.md). Animation-disabled output is not `t = 0`, a browser virtual-time harness is not canonical authority, and a finite checkpoint set cannot upgrade a static report or prove an interval.

## Foreign content profile or observation admission

No foreign-content profile, host-language engine, or observation currently exists. Before implementing or changing `svgdiff-foreign-object-layout-profile/1`, `svgdiff-foreign-object-xhtml-rect-slice/1`, or `svgdiff-foreign-object-observation/1`:

1. state the Agent task, select one namespace and deliberately closed markup/CSS/layout slice, and reject every unlisted host language or feature without treating it as empty;
2. version source MIME and tree construction, namespace handling, host semantics, UA style, CSS modules, SVG integration, fonts, resources, processing axes, color/rendering, limits, evaluator/build, and normalized manifest identity;
3. preserve authored markup, computed style, box/line/glyph/replaced-content layout, isolated surfaces, final SVG compositing, coverage, alignment, and conservative provenance separately;
4. add exact positive, equivalent, malformed, wrong-namespace, unsupported, missing font/resource, overflow, transform/effect, stacking, platform-widget, limit, and hostile-input controls;
5. prove the applicable deterministic font, resource, cascade, selector, layout, paint, compositing, renderer-conformance, no-I/O, no-script, no-ambient-state, and process-isolation obligations;
6. for browser observations, record parsing mode and achieved namespace tree, exact target/OS/UA style/fonts/resources/state/layout/output, repeats, divergences, failures, and target-local authority; and
7. run compatibility, determinism, security, resource, renderer, Agent, adversarial, performance, and cross-host gates before product or release integration.

Follow the accepted [foreign-content semantics](foreign-object-layout-boundary.md). A DOM or CSS parser is not layout support, a bounded evaluator is not general XHTML support, and browser pixels cannot upgrade current report coverage.

## General resource snapshot or prefetch admission

No generalized snapshot bundle, URL resolver, or prefetcher currently exists. Before implementing or changing `svgdiff-resource-snapshot-bundle/1`, `svgdiff-resource-resolution-policy/1`, `svgdiff-resource-prefetch-profile/1`, `svgdiff-resource-prefetch-transcript/1`, or `svgdiff-resource-snapshot-http-image-slice/1`:

1. state the Agent task and keep the released exact opaque PNG/JPEG `ResourceBundle` behavior unchanged;
2. version root/side binding, URL and base algorithms, fragment handling, complete logical request keys, response/failure records, representation-byte boundary, canonical encoding, closure, digest, duplicate, and compatibility rules;
3. preserve authored locator, request, response, exact bytes, interpretation, graph activity, consumers, downstream evidence, acquisition transcript, and compliance evidence separately;
4. add exact side-difference, base, query, fragment, alias, variant, redirect, status, header, MIME/charset, integrity, missing, blocked, failed, invalid, unused, nested, cycle, conflict, and limit controls;
5. prove every family parser consumes only verified representation bytes, recursive closure cannot truncate, unused members create no SVG difference, and report authority still follows family semantics and coverage;
6. prove zero comparison-time filesystem/network authority and reject implicit paths, `file:`, URL credentials, private/localhost destinations, ambient cache/proxy/storage, and missing-entry fallback fetch; and
7. before prefetch ships, independently pass allowlist, SSRF, DNS-rebinding, redirect, CORS, credential, secret-redaction, decompression, atomic-output, transcript, process-isolation, determinism, license, and Agent gates.

Follow the accepted [resource snapshot semantics](general-resource-snapshot-bundles.md). A URL is not content identity, successful acquisition is not valid interpretation, and a prefetch transcript is not a rendering result.

## Metric upgrade

Use this procedure when changing raster arithmetic, adding a metric, changing a formula, or altering not-computed behavior.

### Required evidence

- State the physical or perceptual question answered by the metric and its units.
- Preserve exact parameter, geometry, coverage, raster, and perceptual channels separately.
- Test identity, symmetry where mathematically expected, monotonic controlled changes, transparent colors, premultiplied alpha, and legitimate zero results.
- Test that unavailable inputs produce absence or `not_computed`, never numeric zero.
- Record algorithm parameters, color interpretation, numeric representation, and external metric version.
- Evaluate same-domain ordering impact without introducing an implicit cross-domain scalar.

Historical metric choices and candidates are described in [`visual-difference-metrics.md`](research/visual-difference-metrics.md). Current implemented fields are defined in [`core-model.md`](core-model.md).

### Required synchronized changes

- Add or change project-owned report fields only with a Schema decision.
- Update `raster_representation` or another explicit metric identity when numeric meaning changes.
- Add assertion tests with hand-explainable controlled cases before adding broad snapshots.
- Update magnitude construction, Domain Ordering components, JSON Schema, agent examples, and feature coverage together.
- Retain the previous metric when consumers need migration comparison; do not silently reuse an old field name for new arithmetic.

## JSON Schema upgrade

Schema `2.0` is the only retained Structured Report consumer contract. A change to required fields, field meaning, enum values, omission behavior, identifier references, or numeric units requires an explicit compatibility review and direct migration of current consumers; obsolete schema artifacts are deleted rather than maintained indefinitely.

The independent source-audit schema follows the same discipline but is not entered in the Structured Report registry. Validate [`svgdiff-source-audit.schema.json`](../schema/svgdiff-source-audit.schema.json), its canonical example, and the public `SourceAudit*` interface whenever audit identity, paths, values, spans, status, or failures change.

### Procedure

1. Describe the old and new JSON shapes with concrete examples.
2. Classify whether old consumers can safely interpret new output without code changes.
3. If interpretation can change or parsing can fail, allocate a new `schema_version`; do not mutate the meaning of an existing identity.
4. Update public MoonBit types and serialization first, then regenerate `.mbti` with `moon info`.
5. Update `schema/svgdiff-report.schema.json` and its `$id`, title, constants, required fields, definitions, and enums.
6. Add the new version to the [released Schema registry](../schema/registry.v1.json) with its Schema file, ordering policies, canonical examples, and compatibility cases.
7. Add validation fixtures for every supported schema version and an explicit migration or rejection test.
8. Update the [compatibility corpus](../evaluation/compatibility/README.md) with current, legacy, additive, and unknown-version consumer and Schema-validation decisions.
9. Update README examples, the core model, status contract, agent guide, and CLI version output when available.
10. Verify that the HTML report consumes the new shape without becoming a second semantic implementation.

Use the allocation rules in the [compatibility and versioning contract](versioning.md). Any ambiguous consumer-visible correction receives a new schema version rather than silently changing an existing identity.

## Domain Ordering policy upgrade

`DomainOrdering` is versioned separately from the JSON Schema because ranking semantics can change without changing field shape.

The current tuple layouts and exact-domain consumer procedure are defined in the [Domain Ordering Policy](domain-ordering.md).

### Procedure

1. State the affected domain and why the old component tuple is inadequate.
2. Define every component, direction, units, null handling, and deterministic tie-breaker.
3. Add controlled same-domain cases whose intended order is explainable without the implementation.
4. Compare old and new ordering across the evaluation corpus.
5. Allocate a new `policy_id` whenever components, order, direction, or tie-breaking changes.
6. Add the new ID and its old-to-new acceptance or rejection cases to the [compatibility corpus](../evaluation/compatibility/README.md).
7. Update report construction, HTML grouping/order behavior, agent interpretation guidance, tests, and the feature coverage matrix.
8. Never compare tuples from different policy IDs as if they shared semantics.

Cross-domain ranking requires its own accepted policy and must not be smuggled into a same-domain upgrade.

The complete compatibility boundary, including the rule that every tuple-semantic change allocates a new opaque policy ID, is defined in the [compatibility and versioning contract](versioning.md#ranking-policy-compatibility).

## Impact Assessment policy upgrade

`ImpactAssessment` is versioned separately from both the JSON Schema and same-domain ordering because main-event selection semantics can change while their serialized container remains stable.

The current uncalibrated rule and Agent interpretation boundary are defined in [Raw Magnitudes and Impact Assessment](impact-assessment.md).

### Procedure

1. State the Agent task and why the current policy cannot answer it.
2. Define candidate events, every input field and unit, availability behavior, comparison relation, ties, incomparability, and deterministic representation.
3. Preserve links from every result to its Visual Events and Atomic Differences.
4. Add controlled identity, dominance, tie, tradeoff, missing-evidence, and deterministic-witness cases before changing production output.
5. Evaluate the proposal against the versioned hidden-label corpus without feeding labels into production reports.
6. Allocate a new `policy_id` whenever eligibility, inputs, normalization, dominance, thresholds, labels, weights, tie behavior, or witness selection changes.
7. Update report construction, JSON Schema, compatibility policy, Agent guidance, benchmark harness, and current-contract documents together.
8. Never let an assessment create or erase an Atomic Difference, establish equality, override Diagnostics, or fabricate missing measurements as zero.

Calibration must introduce a new policy identity. It must record its corpus, label version, thresholds or learned parameters, required Comparison Profile inputs, and evaluation results rather than changing `event_rendered_pareto/v1` in place.

## Future exact-result cache upgrades

No cache artifact is currently implemented. If `svgdiff-exact-result-cache-key/1` is activated later:

1. treat every module, Schema, Diagnostic, parser, semantic adapter, renderer, conformance, coverage, alignment, region, magnitude, provenance, ordering, Impact, resource, and adopted execution-profile change as a cache-key compatibility review;
2. include exact ordered before/after source and resource inputs, the complete Comparison Profile, effective deterministic limits, modules/svgdiff/engine/build dependencies, and required target/toolchain identity;
3. allocate a new key or envelope version whenever canonical encoding, digest input, validation, stored report encoding, or reuse meaning changes;
4. test that changing each identity produces a miss and that cold and hit paths return byte-identical valid reports for every admitted status;
5. reject unknown, corrupt, oversized, cross-user, traversal, poisoned, cancelled, or time-budget-interrupted entries and fall back to full recomputation; and
6. keep cache migration and operational hit/miss telemetry outside Structured Report semantics.

Per-input, per-stage, graph-incremental, and remote artifacts require their own stable schemas and invalidation or trust proofs; an exact-result envelope does not authorize them.

## Common validation gate

Run from the repository root:

```sh
moon check --target native --warn-list +73
moon test --target native
sh scripts/test-cli.sh
sh scripts/test-agent-projection.sh
sh scripts/test-versioning.sh
moon fmt
moon info
jq empty schema/svgdiff-report.schema.json
jq empty schema/svgdiff-agent-projection.schema.json
git diff --check
```

Then review:

- dependency and lock/resolution diffs;
- generated `.mbti` changes;
- profile and policy identities;
- JSON Schema changes;
- changed Diagnostics and analysis statuses;
- numeric and region drift in controlled fixtures;
- current documentation and dated research follow-ups.

Do not publish or merge an upgrade with unexplained report churn, reduced coverage, or an unchanged identity for changed semantics.
