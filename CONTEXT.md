# SVG Diff Project Context

Status: current orientation

Last verified: 2026-07-17

## Terminal goal

`svgdiff` should let an agent without multimodal perception identify the important visual-semantic differences between two SVG artifacts, quantify those differences, locate their effects, and inspect a causally sound set of possible reasons from machine-readable evidence.

## Current state

The repository contains a production comparison engine for a bounded deterministic static-SVG subset, Structured Report schema `1.44`, a native CLI, an optional self-contained HTML presentation, and a separate nonvisual source-audit API. It is not a general SVG or browser-equivalence engine. Current support includes authored and used geometry, exact local/CSS/viewport/entity scalar parameter scales, symmetric pinned-raster painted-boundary mean/p95/maximum distributions, alpha-only painted-coverage differences, optional explicit opaque sRGB8 background compositing with event-local changed-pixel mean DeltaEOK and opt-in event-local LDR-FLIP maps plus separate canvas, event, response, and explicit-threshold statistics kept separate from transparent-canvas evidence, a required uncalibrated Pareto frontier over common Visual Event rendered magnitudes, transforms and viewports, the static author cascade and inheritance, solid paint, gradients, patterns, paint fallbacks and rules, isolated static container opacity, deterministic local rectangular clips, static alpha/luminance masks, bounded local `feOffset` filter graphs, source-only opaque subtree differences for unsupported filter primitives with resolved filter-region localization, transform-event pixel selection through cumulative before/after painted bounds, opaque binary-alpha CSS blend modes and isolation with conservative stacking dependencies, transform- and conservative-painted-bounds-aware rendered shape/path/use-instance alignment, exact repeated rendered equivalence classes, role-typed source-structural entity and Visual Resource alignment with every resource Atomic Difference attached, structural/use-instance semantics, a typed resource graph, bounded PNG/JPEG image evidence from data URLs or exact caller-supplied bundles, precise source-located coverage Diagnostics for embedded raster color-profile and HDR metadata without implicit conversion, and explicit auditing of descriptive content plus accessibility/custom-data attributes without mixing them into visual Atomic Differences. General clip or mask content, clip/mask attachment on use instances, visual execution of filter primitives beyond the admitted `feOffset` slice, CSS filter functions, continuous vector boundary correspondence, continuous-alpha or effect-interacting blending, font-dependent text semantics, dynamic behavior, nested SVG images, final raster-image composition, wide-gamut conversion and HDR tone mapping, unequal-cardinality or mixed-change repeated clusters, calibrated Impact Assessment, and calibrated alignment confidence remain explicitly guarded or deferred.

The engine deliberately reports three evidence layers separately:

1. Source Semantics: supported authored visual facts and provenance;
2. Computed Appearance: normalized or resolved visual facts;
3. Rendered Evidence: measurements and Difference Regions under one pinned v1 profile.

Unsupported semantics produce Diagnostics and reduce `analysis_status`; they are never silently interpreted as equality.

## Reading order

1. [`README.mbt.md`](README.mbt.md) for CLI and library usage.
2. [`docs/README.md`](docs/README.md) for document authority and navigation.
3. [`docs/v1-scope.md`](docs/v1-scope.md) for the current support boundary.
4. [`docs/core-model.md`](docs/core-model.md) for report concepts and invariants.
5. [`docs/agent-report-guide.md`](docs/agent-report-guide.md) for text-only interpretation examples.
6. [`roadmap.md`](roadmap.md) for unfinished work.

ADRs, research notes, issues, and prototypes are historical evidence. They explain why the project reached its current design but do not override the current contract or JSON Schema.

## Non-negotiable principles

- Report every supported semantic difference, including computed-equivalent and zero-raster-impact differences.
- Preserve continuous, domain-appropriate measurements instead of reducing difference to a boolean or universal scalar.
- Keep measured zero, not computed, indeterminate, unsupported, and failed distinct.
- Permit conservative causal false positives, but never omit a real cause from a Cause Envelope that claims completeness.
- Keep dependency-specific parser and renderer types behind the public comparison seam.
- Treat presentation, including HTML, as a projection of the Structured Report rather than a second comparison engine.

Normative terminology lives in [`docs/core-model.md`](docs/core-model.md). This file intentionally stays short so that it remains useful as agent orientation rather than becoming a second glossary.

## Language

**Changed Fact**:
One supported authored visual change and the subjects it may affect; it is a possible cause, not a rendered outcome.
_Avoid_: Diff, event

**Atomic Difference**:
The smallest independently reportable visual-semantic distinction for one aligned subject or resource; it may reference one or more Changed Facts.
_Avoid_: Cause, event

**Visual Event**:
The agent-facing grouping of Atomic Differences that describe one primary aligned-subject outcome, including its rendered outcome and regions.
_Avoid_: Source change, Changed Fact

**Primary Subject Alignment**:
The one before/after subject relationship that owns a current Visual Event and fixes its outcome boundary.
_Avoid_: Authored ID, global identity

**Font Resource**:
One exact encoded font byte sequence supplied inside a closed Font Bundle.
_Avoid_: System font, family name, font path

**Font Face Locator**:
The bundle-local pair of a Font Resource identifier and its zero-based face index.
_Avoid_: PostScript name, named instance, family name

**Font Bundle**:
An immutable closed set of caller-supplied Font Resources plus separately verifiable licensing and provenance evidence.
_Avoid_: Font directory, installed fonts, system environment

**Font Bundle Fingerprint**:
The content identity of the bundle fields that can select different encoded font resources or faces.
_Avoid_: Manifest digest, family name, glyph hash

**Font Bundle Manifest Digest**:
The integrity identity of the complete Font Bundle manifest, including legal and provenance evidence.
_Avoid_: Rendering fingerprint

**Font Execution Profile**:
The future versioned identity that combines a Font Bundle with selection, shaping, layout, rasterization, and runtime policies.
_Avoid_: Font Bundle, system renderer

**Font Runtime Module**:
The future separately versioned workspace boundary that owns pinned shaping and glyph-rasterization dependencies behind project-owned records and errors.
_Avoid_: System font stack, text layout engine, upstream API

**Font Runtime Build Identity**:
The exact identity of font-runtime sources, patches, configuration, toolchain, target, static artifacts, shim, and linked binary.
_Avoid_: Library name, Font Bundle Fingerprint, execution result

**Platform Font Observation**:
An external target-specific capture from CoreText, DirectWrite, a browser, or another platform stack; it is never canonical Structured Report evidence.
_Avoid_: Font Execution Profile, renderer truth, complete analysis

**Color Execution Profile**:
A future executable identity for source color admission, conversion, interpolation, compositing, reference output, measurement, limits, and implementation.
_Avoid_: Gamut name, display profile, renderer identity

**Color Observation**:
An external capture of browser, platform, or physical-display color behavior under one completely named environment.
_Avoid_: Color Execution Profile, canonical output, active display default

**Renderer Experiment Cell**:
One exact before/after execution by one target under one semantic profile, retaining its native report or observation authority.
_Avoid_: Renderer vote, canonical aggregate, screenshot alone

**Renderer Experiment Edge**:
A typed relation between compatible cells that states which target/profile axes are fixed or varied and what claims follow.
_Avoid_: Generic renderer diff, diagonal attribution, majority result

**Script Observation**:
An external target-specific artifact for one exact script-enabled runtime, scenario, state closure, and capture checkpoint; it is never canonical Structured Report evidence.
_Avoid_: Script Execution Profile, sandboxed truth, complete analysis

**Interaction State Profile**:
A future canonical checkpoint that declares URL, focus, modality, pointer, button, geometry, and processing inputs, then derives pseudo-class matches through versioned state and hit-test rules.
_Avoid_: Pseudo-class boolean bag, browser action trace, ambient UI state

**Interaction Observation**:
An external target-specific action replay with achieved-state postconditions, transcript, and output evidence.
_Avoid_: Interaction State Profile, canonical selector state, replay intent alone

**Animation Timeline Profile**:
A future closed logical-time contract that names one checkpoint question, exact rational coordinates, mechanism semantics, triggers, mappings, resources, limits, and evaluator identity.
_Avoid_: Wall-clock delay, frame count, normalized-progress equality, browser clock

**Animation Checkpoint Set**:
The ordered requested and achieved before/after temporal states for one Animation Timeline Profile, retaining per-checkpoint status and links to comparison evidence.
_Avoid_: Video, sampled interval proof, settled final frame

**Animation Observation**:
An external target-specific virtual-time and capture replay for script-driven or browser-specific animation, retaining requested and achieved time and state.
_Avoid_: Canonical timeline result, screenshot after sleep, browser truth

**Foreign Object Layout Profile**:
A future closed host-language execution contract for one namespace and admitted markup, UA style, CSS layout, font, resource, paint, and SVG-integration subset.
_Avoid_: Browser name, outer foreignObject rectangle, generic HTML support

**Foreign Object Observation**:
An external target-specific parse, layout, and render capture for foreign content with exact environment, achieved tree/state, and output evidence.
_Avoid_: Canonical layout, screenshot truth, unknown-namespace fallback

**Resource Snapshot Bundle**:
A future immutable side-qualified package of root-bound logical requests, response or failure snapshots, exact representation bytes, recursive closure, and digests, consumed with zero comparison-time I/O.
_Avoid_: URL-to-bytes map, current ResourceBundle, browser cache, fetch permission

**Resource Prefetch Transcript**:
A future sanitized record of one explicit acquisition run under a named Prefetch Profile, separate from rendering identity and comparison execution.
_Avoid_: Resource Snapshot Bundle, network replay inside comparison, ambient HAR
