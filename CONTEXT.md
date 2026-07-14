# SVG Diff Project Context

Status: current orientation

Last verified: 2026-07-14

## Terminal goal

`svgdiff` should let an agent without multimodal perception identify the important visual-semantic differences between two SVG artifacts, quantify those differences, locate their effects, and inspect a causally sound set of possible reasons from machine-readable evidence.

## Current state

The repository contains a production comparison engine for a narrow deterministic static-SVG subset, a stable JSON report schema at version `1.3`, a native CLI, and an optional self-contained HTML presentation. It is not a general SVG or browser-equivalence engine.

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
