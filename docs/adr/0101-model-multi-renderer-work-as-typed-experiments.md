# ADR 0101: Model multi-renderer work as typed experiments

- Status: accepted, not implemented
- Date: 2026-07-17
- Decision owners: svgdiff maintainers
- Supersedes: none

## Context

The current Structured Report compares two SVGs under one pinned Comparison Profile and one renderer/conformance identity. The browser oracle and renderer-conformance baselines are independent development evidence. Future font, color, browser, and platform profiles create two different questions: how one engine changes across declared profiles, and how different engines behave under one shared profile.

Changing both axes at once cannot identify whether an outcome came from the engine, profile, environment, or their interaction. A browser screenshot also lacks the source, computed, alignment, and causal layers of a canonical report.

## Decision

Support both questions through a future `svgdiff-renderer-experiment-matrix/1` container of `svgdiff-renderer-experiment-cell/1` cells and typed edges. Preserve each cell's native artifact and authority.

Use `profile_sensitivity` only when target, sources/resources, and capture are fixed. Use `renderer_conformance` only when the semantic profile and material non-engine environment are fixed; otherwise use `renderer_target_observation` and list confounders. A target-plus-profile diagonal is `confounded_diagonal` unless compatible horizontal and vertical edges decompose it. A complete four-cell rectangle may expose `target_profile_interaction` without assigning a unique cause.

Keep one current Structured Report single-profile and canonical. External renderer cells remain observations. Agent synthesis may report universal invariance, profile sensitivity, renderer sensitivity, target/environment sensitivity, interaction, confounding, or insufficient evidence, always with links to all required cells and edges. Never vote, average, discard disagreement, or infer truth from prevalence.

## Consequences

The model can answer both roadmap questions while preserving attribution. A full matrix is optional; sparse graphs remain useful but make fewer claims. Environment closure and output normalization are first-class compatibility checks. Missing or partial cells weaken synthesis rather than disappearing.

No product mode, report field, Schema, dependency, browser fixture, current conformance result, or release asset changes through this decision.

## Rejected alternatives

- Choose only same-engine profiles: this cannot expose implementation divergence seen by users.
- Choose only cross-browser output: this cannot isolate profile sensitivity and lacks canonical source/computed/causal evidence.
- Put several renderers inside one Structured Report: it would make equality, coverage, renderer identity, and causal authority ambiguous.
- Compare every pair of cells with one generic relation: diagonal pairs conflate target and profile changes.
- Treat a browser majority or preferred browser as truth: prevalence is not SVG semantics or causal evidence.
- Drop missing, failed, partial, or disagreeing cells from the summary: that converts incomplete evidence into false stability.
- Call cross-OS browser differences engine conformance: the environment and platform backends are material confounders.
