# Record an explicit opaque sRGB Perceptual Background

## Context

Raw renderer evidence is produced on a transparent canvas. Display-dependent color measurements require a background, but choosing white, black, or any SVG-derived paint implicitly would make the result environment-dependent and would violate ADR 0022. The event-local perceptual-color roadmap item therefore needs a recorded profile input first.

## Decision

Add nullable `ComparisonProfile.perceptual_background`. A present value is one normalized opaque sRGB8 color with integer red, green, and blue channels. The default remains absent. Public and CLI parsing reuse the deterministic solid-color grammar but accept only resolved alpha-one colors; contextual, system, invalid, and translucent values are rejected.

The root comparison seam preserves this field while continuing to canonicalize every other fixed v1 rendering condition. This item records policy input only: product rendering remains on transparent pixels, and no existing raw magnitude, region, equality, Diagnostic, ordering tuple, renderer identity, or conformance result may change because a background was supplied.

## Consequences

Future event-local color and FLIP measurements have one exact shared compositing input and can report `not_computed` when it is absent. Agents can distinguish the declared display background from authored SVG paint and transparent-canvas raw evidence.

The required nullable field advances Structured Report schema to `1.39` and module version to `0.5.19`. Perceptual measurement fields and background compositing remain separate roadmap work.
