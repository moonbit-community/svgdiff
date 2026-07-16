# Separate exact parameter scales from rendered outcomes

## Context

The report retained exact local scalar deltas and some geometry or raster outcomes, but it did not state how a local geometry edit maps into CSS pixels, the Comparison Viewport, or the size of its entity. A text-only Agent could distinguish `1.0` from `0.99999`, yet could not tell whether a transform amplified that edit or whether it was small relative to the affected entity. Reusing sampled boundary or raster evidence would make the result resolution-dependent and would erase continuous changes that quantize to the same pixels.

## Decision

Retain four independent parameter scales for admitted scalar spatial changes. `parameter_abs_user_units` and `parameter_signed_user_units` hold the canonical local numeric delta; exact authored spelling and units remain in the source facts. `parameter_abs_css_px` applies one complete cumulative directional mapping only when both sides have the same mapping: compare the relevant basis vector for a directed coordinate and the full linear part for an undirected radial parameter. Taking the larger norm of two conflicting mappings would be a conservative estimate, not an exact parameter magnitude. Non-scaling stroke scalars map one-to-one to CSS pixels. Ordinary stroke width and dash offset require the same isotropic linear scale because an anisotropic transform does not define one direction-independent scalar conversion. `parameter_viewport_fraction` divides that CSS displacement by the Comparison Viewport diagonal. `parameter_entity_fraction` divides it by the maximum nonzero diagonal of the before and after conservative painted bounds, considered separately so movement does not enlarge its own denominator.

Emit JSON null when a scalar mapping or denominator is not honest: incomplete transforms, zero-size or unavailable entity bounds, non-spatial numbers, angles, scales, lists, categorical values, residual matrices, and context-shared resource parameters do not receive fabricated spatial scales. Decomposed transform translation already has one exact CSS-pixel norm and may use the same viewport and entity denominators. Basic-shape coordinates and dimensions, image placement and size, scalar stroke lengths, and normalized path coordinates or radii use the scalar mapping where their transforms are complete.

Keep parameter displacement independent from `geometry_displacement_css_px`, future painted-boundary distributions, renderer pixels, and any future Impact Assessment. Stroke boundary movement, path boundary observations, and image placement effects under `preserveAspectRatio` are outcome evidence rather than aliases for exact parameter displacement. The new fields are authoritative raw measurements but do not change `v2_domain_lexicographic` ordering.

## Consequences

Agents can report a continuous exact change even when canonical pixels are unchanged, and can compare the same parameter through local, device, viewport, and entity-relative frames without inventing visibility or severity. Null continues to mean unavailable, while numeric zero means measured equality.

The three new required nullable fields advance Structured Report schema to `1.36` and module version to `0.5.16`. Renderer identity, conformance profile `/25`, ordering policy, Diagnostics, and event ownership remain unchanged. Painted-boundary mean, p95, and maximum measurements remain a separate roadmap item.
