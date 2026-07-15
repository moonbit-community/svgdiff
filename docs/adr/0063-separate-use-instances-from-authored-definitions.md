# ADR 0063: Separate Use Instances from Authored Definitions

Status: accepted and implemented for the admitted static same-document slice

## Context

`defs` and source `symbol` content can exist without rendering directly, while one authored subtree can render several times through `use`. Treating the source element as one visual subject loses placement identity; copying it into synthetic source nodes loses the declaration owner, Source Span, stylesheet applicability, and definition-level fan-out. Raw XML expansion also makes nested reuse and cycles difficult to bound.

## Decision

Build one authored structural index over admitted containers, resources, and graphics elements. Keep each node's authored identity, source offset, parentage, definition status, and preferred local `href`. Derive a rendered-subject plan separately. A direct subject has no instance context; a reused subject receives a deterministic outer-to-inner use path, an instance ID derived from that path and the definition subject ID, and the unchanged authored definition identity.

Resolve an admitted `use` only when its preferred reference is an acyclic same-document fragment targeting a supported shape, `g`, `svg`, `symbol`, or another admitted `use`. Source `defs` and `symbol` descendants never enter direct rendered alignment. A use host becomes an ancestor of the cloned source subtree for cascade and ordinary inheritance, while stylesheet matching remains attached to corresponding authored nodes. Definition-owned Changed Facts fan out to all instance IDs they may affect.

Compose use-host transforms, supplemental `x` and `y` translation, nested paths, group transforms, and target viewports through the existing transform and viewport seams. Apply use `width` and `height` only to `svg` and `symbol` targets. Preserve existing pre-render reference-cycle and expansion admission.

Expose optional `SubjectInstanceContext` in Schema `1.21` rather than overloading `authored_id`. Current producers always emit the field, including null for direct subjects; omission remains a compatible legacy-shaped representation. Keep the existing `structural_rule` evidence kind and expose the specific match as alignment basis `use_instance_path` rather than expanding a closed enum. Treat transformed use hosts that combine authored transforms with nonzero supplemental translation as renderer-guarded because the pinned renderer differs from Chromium. Missing, external, wrong-kind, invalid-length, and invalid-viewport cases receive located Diagnostics.

## Consequences

One definition edit can now produce one owner-level Changed Fact and several independently localized instance outcomes. Direct definitions and unused definitions remain source-visible without becoming rendered subjects. Nested reuse, use-host inheritance, and symbol viewport placement have deterministic report identities.

This decision does not classify arbitrary structural reorderings, prove symbol overflow clipping, support external documents or dynamic shadow-tree behavior, or replace the later unified resource-dependency graph. Those boundaries remain explicit follow-up work.
