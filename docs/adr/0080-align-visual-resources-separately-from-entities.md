# Align Visual Resources separately from Visual Entities

## Context

Schema `1.34` aligned visual definitions through the source-structural inventory but did not distinguish those definitions from entities and left resource Atomic Differences unattached. An Agent could locate a definition candidate yet could not follow a resource difference to a typed alignment. Embedded images made the ambiguity concrete: decoded content and placed geometry share one source element but are different visual subjects.

## Decision

Give every Subject Alignment a closed `entity` or `resource` role. Rendered shapes, groups, text, use hosts, and image placement are entities. Symbols, gradients, patterns, markers, clip paths, masks, filters, and intrinsic image content are resources. Resource definitions use their own semantic-signature, authored-ID, structural-path, stable-order, insertion, and deletion basis vocabulary. Embedded image content uses a separate resource alignment even when its references are identical to the placement alignment.

Require every resource Atomic Difference to reference exactly one resource-role alignment. Resolve resource children to their containing definition using Changed Fact ownership, source spans, and family-kind fallback. Keep resource-mediated entity differences, consumer fan-out, Visual Events, Difference Regions, and Cause Envelopes unchanged. A resource and its sole mediated entity outcome may still share one event under ADR 0017 and ADR 0040; their alignment identities remain separate.

Resource alignment is correspondence evidence. It does not prove computed consumer equality, rendered equality, causation strength, or pairwise identity inside a repeated class.

## Consequences

Agents can traverse every resource difference to its before/after definition candidates without conflating the definition with a placement. The same image source reference may appear in two alignments with different roles, which is intentional. Resource insertion and deletion may accompany entity presence differences without duplicating either subject's Atomic Difference.

The required alignment role and resource-specific score kinds advance Structured Report schema to `1.35` and module version to `0.5.15`. Renderer identity, conformance profile `/25`, ordering policy, and event ownership remain unchanged.
