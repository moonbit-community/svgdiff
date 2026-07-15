# ADR 0072: Own static alpha and luminance mask semantics

Status: accepted

Date: 2026-07-15

## Context

SVG masks combine a non-inherited host attachment, resource coordinate systems, a bounded mask region, painted mask content, alpha or luminance interpretation, and isolated compositing. Treating every mask as unsupported omitted useful source and numeric evidence. Delegating the complete claim to `mizchi/svg@0.2.1` was also insufficient: its broad mask API does not establish the project's cascade, provenance, effect-bound, missing-resource, fractional-alpha, or container-isolation contracts.

## Decision

Own one deterministic static slice: `none` or one same-document SVG mask reference; host `mask-mode`; resource `mask-type`, `maskUnits`, `maskContentUnits`, region defaults, sRGB color interpolation, and exactly zero or one direct non-rounded solid rectangle under a deterministic axis transform. Resolve declarations through the existing cascade and computed-value model without inheriting `mask`, `mask-mode`, or `mask-type`. Compute alpha from content alpha, or luminance from non-premultiplied sRGB coefficients `0.2126`, `0.7152`, and `0.0722` multiplied by content alpha.

Render container content and mask content on separate transparent surfaces, clip the mask surface to the resolved mask region, multiply target alpha by the selected mask value, then source-over composite the result. `static-mask-normalizer@1` materializes admitted computed values and exact 8-bit alpha for the pinned renderer; `static-mask-compositor@1` owns isolated container application. Missing, wrong-kind, empty, or non-positive-region single SVG mask layers have the specification-defined transparent-black outcome. External acquisition, CSS image or multi-layer masks, mask borders and layer subproperties, multiple or curved content, paint servers, nested effects, animation, use-host attachment, unsupported transforms, conflicting shared host modes, `linearRGB`, and unavailable bounds remain precise partial Diagnostics.

For every complete consumer, retain a separate before/after conservative effect bound equal to the target's painted bound intersected with the mask region and transformed mask-content rectangle. Resource events union every consumer bound; host events union the affected descendants on both sides so occupied and vacated pixels remain localizable. These bounds are localization supersets, not exact contribution maps.

## Consequences

Text-only Agents can distinguish source-only mask rewrites, attachment and mode changes, resource component changes, deterministic suppression, affected-consumer fan-out, continuous numeric deltas, final raster magnitude, and conservative location. Partial cases retain exact source locations but revoke complete rendered and causal claims.

Six Chromium fixtures cover alpha, luminance, object-bounding-box coordinates, host mode override, transforms, and isolated container application. Five are raw-renderer exact; the container case has a one-channel-level divergence handled by the reviewed product compositor. The raw baseline expands to 125 cases with 57 exact and 68 divergent observations, renderer conformance advances to `/23`, Structured Report schema to `1.28`, module and CLI to `0.5.8`, and the production renderer identity adds both mask components.
