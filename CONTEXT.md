# SVG Diff Project Context

Status: current orientation

Last verified: 2026-07-18

## Terminal goal

`svgdiff` should let an agent without multimodal perception identify the important visual-semantic differences between two SVG artifacts, quantify those differences, locate their effects, and inspect a causally sound set of possible reasons from machine-readable evidence.

## Current state

The repository contains a production comparison engine for a bounded deterministic static-SVG subset, Structured Report schema `1.45`, a native CLI, an optional self-contained HTML presentation, and a separate nonvisual source-audit API. It is not a general SVG or browser-equivalence engine. Current support includes authored and used geometry, exact local/CSS/viewport/entity scalar parameter scales, symmetric pinned-raster painted-boundary mean/p95/maximum distributions, alpha-only painted-coverage differences, optional explicit opaque sRGB8 background compositing with event-local changed-pixel mean DeltaEOK and opt-in event-local LDR-FLIP maps plus separate canvas, event, response, and explicit-threshold statistics kept separate from transparent-canvas evidence, a required uncalibrated Pareto frontier over common Visual Event rendered magnitudes, transforms and viewports, the static author cascade and inheritance, solid paint, gradients, patterns, paint fallbacks and rules, isolated static container opacity, deterministic local rectangular clips, static alpha/luminance masks, bounded local `feOffset` filter graphs, source-only opaque subtree differences for unsupported filter primitives with resolved filter-region localization, transform-event pixel selection through cumulative before/after painted bounds, opaque binary-alpha CSS blend modes and isolation with conservative stacking dependencies, transform- and conservative-painted-bounds-aware rendered shape/path/use-instance alignment, exact repeated rendered equivalence classes, role-typed source-structural entity and Visual Resource alignment with every resource Atomic Difference attached, structural/use-instance semantics, a typed resource graph, bounded PNG/JPEG image evidence from data URLs or exact caller-supplied bundles, precise source-located coverage Diagnostics for embedded raster color-profile and HDR metadata without implicit conversion, and explicit auditing of descriptive content plus accessibility/custom-data attributes without mixing them into visual Atomic Differences. General clip or mask content, clip/mask attachment on use instances, visual execution of filter primitives beyond the admitted `feOffset` slice, CSS filter functions, continuous vector boundary correspondence, continuous-alpha or effect-interacting blending, font-dependent text semantics, dynamic behavior, nested SVG images, final raster-image composition, wide-gamut conversion and HDR tone mapping, unequal-cardinality or mixed-change repeated clusters, calibrated Impact Assessment, and calibrated alignment confidence remain explicitly guarded or deferred.

Every call currently performs a full comparison. One bounded paint-measurement memoization exists only inside report assembly; no persistent, graph-incremental, shared, or remote cache is part of the product.

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

**Review Classification Axes**:
The orthogonal factual coordinates used to organize a report for review: Visual Event rendered-outcome state, Atomic Difference Computed Relation, and Atomic Difference Difference Domain. None is a magnitude or severity class.
_Avoid_: Difference type, severity class, single outcome category

**Rendered Outcome Group**:
A review grouping of Visual Events whose canonical rendered outcome is measured nonzero, not computed, or measured zero under the Comparison Profile. It is not a visibility, severity, importance, or equality class.
_Avoid_: Visible, invisible, minor, major, impact tier

**Event Relation Summary**:
The counts of an event's Atomic Differences by Computed Relation. It is a multi-valued child summary, not a Computed Relation assigned to the Visual Event.
_Avoid_: Event relation, dominant relation, mixed relation class

**Domain Family**:
A review-facing grouping of exact Difference Domains for scanning and filtering while every Atomic Difference retains its complete domain. Unknown domains remain explicit rather than entering a catch-all family.
_Avoid_: Other, visual outcome type, replacement domain

**Evidence Availability Summary**:
A review summary of declared Atomic Difference evidence-layer counts, exact rendered-outcome status, and linked Diagnostic count. It is not an event completeness ratio or confidence score.
_Avoid_: Event completeness, coverage percentage, confidence

**Magnitude Channel**:
One named, unit-preserving magnitude family: Parameter Change, Spatial Outcome, Canvas Response, Perceptual Observation, or Intrinsic Resource Response. Channels answer different measurement questions and never combine into a universal score or severity.
_Avoid_: Magnitude score, severity bar, overall percentage

**Comparable Magnitude Set**:
A set whose members share an explicit comparison policy: Visual Events related by one Impact Assessment, or Atomic Differences sharing one exact domain and Domain Ordering policy. Ordering claims do not cross the set boundary.
_Avoid_: Global ranking, cross-domain order, overall leaderboard

**Magnitude Display Value**:
A scan-oriented unit-bearing rendering of one raw report number, paired with that raw value and its scope or denominator. Rounding is marked as approximate and may never turn a nonzero value into displayed zero.
_Avoid_: Rounded evidence, unlabeled percentage, threshold bucket

**Magnitude Availability State**:
The explicit disposition of one Magnitude Channel: measured, not computed, not requested, not applicable by a declared rule, or reported null without a known reason. Only measured may carry numeric zero.
_Avoid_: Empty value, implicit zero, generic unavailable

**Impact Map**:
A two-axis navigation view of the declared Impact Assessment measurements, preserving frontier membership, exact ties, incomparability, domination, null measurements, and calibration status. It is not a score chart or total ranking.
_Avoid_: Severity plot, leaderboard, overall impact score

**Magnitude Graphic**:
A visual encoding with an explicit absolute scale, unit, scope, and accompanying Magnitude Display Value. It may encode only a declared measurement, never a report-relative severity invented by presentation.
_Avoid_: Relative severity bar, unlabeled meter, color-only magnitude

**Side Footprint**:
The side-qualified spatial extent of one subject or effect in the before or after input. An absent side remains absent and is never filled from the opposite side.
_Avoid_: Difference Region, copied union bounds, ghost subject

**Difference Outcome Surface**:
The canvas-space localization of an observed or conservatively bounded result difference. It does not identify side occupancy, exact contribution, or a unique cause.
_Avoid_: Side Footprint, contribution mask, causal region

**Observed Difference Mask**:
The exact binary map of canonical rendered pixels that differ between the two inputs under one Comparison Profile. It is result evidence, not per-event contribution, visibility, or causal attribution.
_Avoid_: Contribution mask, perceptual mask, cause map

**Side Footprint State**:
The explicit per-side disposition of a Side Footprint: bounded, absent, proven empty, unavailable, or not applicable. Missing bounds never borrow evidence from the opposite side.
_Avoid_: Nullable side bounds, copied footprint, zero-area placeholder

**Shared Event Localization**:
The owning Visual Event's localization shown while inspecting one of its Atomic Differences. It never claims that the selected child independently contributed the highlighted outcome.
_Avoid_: Atomic contribution region, property mask, child-specific pixels

**Localization Visual Grammar**:
The fixed multimodal mapping from localization evidence kind to outline, fill, pattern, label, and region identity. Color supplements but never solely carries the evidence distinction.
_Avoid_: Generic red box, color-only region, decorative overlay

**Localization Fallback Ladder**:
The strict outcome-localization preference from exact observed mask to observed bounds-only, conservative outcome bounds, and finally no outcome surface. Side Footprints remain independent and never substitute for a missing outcome.
_Avoid_: Guessed region, whole-canvas fallback, footprint-as-outcome

**Review Information Layers**:
The five question-driven presentation depths: Report Overview, Event Scan Summary, Atomic Difference Inventory, Evidence Drill-down, and Raw Report. Schema object type alone never determines prominence.
_Avoid_: Schema-order UI, flat evidence list, JSON-shaped navigation

**Event Scan Summary**:
The always-visible three-row Event summary of subject and classification, Canvas Response and Impact relation, then localization, Diagnostic, and evidence-availability counts. Detailed evidence never enters this scan layer.
_Avoid_: Event evidence dump, severity card, schema record preview

**Atomic Difference Summary Row**:
The default-visible child row containing exact domain, source before and after, a human-readable Effective Value result derived losslessly from Computed Relation, declared evidence layers, one direct Magnitude Display Value or availability state, and Shared Event Localization status.
_Avoid_: Hidden child, full evidence card, event-outcome duplicate

**Evidence Ownership**:
The rule that Event measurements, localization, regions, causes, and Event Diagnostics render once at Event level, while child source, computed, magnitude, provenance, and ordering evidence render at Atomic Difference level and link upward.
_Avoid_: Repeated event tree, duplicated Diagnostic, child-owned outcome

**Compact Report Overview**:
The global status and navigation layer containing report counts, Schema and Profile identity, a compact Impact Map, and Rendered Outcome Group links without duplicating Event or evidence detail.
_Avoid_: Impact evidence wall, report dump, duplicate inventory

**Default Disclosure State**:
The deterministic initial review depth where overview, outcome groups, Event summaries, and complete Atomic Difference inventories are visible while owned evidence details, Diagnostics, and Raw Report remain collapsed with every limitation summarized outside.
_Avoid_: Adaptive auto-collapse, hidden warning, evidence-first default

**HTML Projection Seam**:
The interface where canonical report facts become deterministic lossless presentation while review state stays local and missing semantic evidence remains upstream. Original SVG source crosses only for sandboxed preview and never supplies diff evidence.
_Avoid_: HTML semantic model, browser recomparison, UI-derived evidence

**HTML Projection Policy**:
The versioned mapping from known Structured Report schemas, domains, methods, and policy identities to lossless review grouping, labels, counts, formatting, and navigation. Unknown input remains explicit and is never guessed.
_Avoid_: Hidden UI heuristic, schema extension, Agent protocol

**Canonical Localization Evidence**:
Report-owned typed Side Footprints and optional encoded Observed Difference Masks consumed identically by JSON, Agent, Markdown, and HTML projections. Original SVG previews and presentation-private blobs cannot supply it.
_Avoid_: HTML overlay data, recomputed mask, loose evidence asset

**Measurement Availability**:
The report-owned status, reason, Diagnostic references, and optional raw-value reference for one canonical measurement family. Human Magnitude Channels remain projection and never replace these family facts.
_Avoid_: Null interpretation, channel availability, completeness percentage

**Event Diagnostic Closure**:
The deduplicated set of Diagnostics reached only through explicit references from an Event's owned child, measurement, localization, region, cause, and rendered evidence. It is projection, not a duplicate Event field or inferred subject match.
_Avoid_: Event diagnostic array, heuristic linkage, global-warning count

**Projection Compatibility Mode**:
The explicit degraded presentation for a known legacy report schema, preserving all available facts while naming localization and availability evidence that the schema cannot represent. It never reconstructs missing facts from SVG source or legacy nulls.
_Avoid_: Silent backfill, browser upgrade, legacy reinterpretation

**Minimal Report Increment**:
The only report-interface growth authorized by the HTML redesign: Canonical Localization Evidence, Measurement Availability, and missing Diagnostic references on their actual evidence owners. Review summaries, formatting, graphics, labels, and state remain projection.
_Avoid_: UI-ready report, duplicate summary field, presentation schema

**Review Mark**:
The local human assertion that one Atomic Difference has been reviewed. Event and Rendered Outcome Group checkboxes are derived three-state controls over descendant Review Marks and never mean accepted, ignored, equal, resolved, or unimportant.
_Avoid_: Acceptance state, ignore flag, diff result

**Localization Selection**:
The one persistent Visual Event whose localization surfaces are displayed, optionally carrying an Atomic Difference inspection context. Hover or focus may temporarily preview another Event and then restores this selection.
_Avoid_: Multi-event overlay, checked selection, Atomic contribution selection

**Review Filter**:
A local predicate over Event or Atomic Difference projection that changes visibility only while preserving complete-inventory counts, ordering, Review Marks, evidence, and hidden Localization Selection context.
_Avoid_: Evidence suppression, filtered report, importance policy

**Evidence Disclosure State**:
The independent local expansion state of one owned evidence section. It never selects localization, changes Review Marks or filters, or closes unrelated evidence automatically.
_Avoid_: Accordion mode, card selection, evidence mutation

**Review Session**:
The in-memory lifetime of Review Marks, Localization Selection, Review Filters, Evidence Disclosure State, search, and preview view state for one open HTML report. Reload deterministically resets it and no state enters report evidence or ambient storage.
_Avoid_: Persistent review record, report mutation, localStorage state

**Synchronized Preview View**:
The shared zoom and pan transform applied to both SVG previews in Comparison Viewport coordinates. Localization overlays never move it automatically; explicit fit commands change view state without changing evidence or selection.
_Avoid_: Auto-zoom hover, mismatched scales, localization mutation

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
