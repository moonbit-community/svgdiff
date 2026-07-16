# Separate query-conditioned concern from context-free visual Impact

## Context

The current Impact Assessment summarizes context-free visual magnitude. A spatially small event can be dominated in both current rendered dimensions and therefore remain outside the Pareto frontier. External task context may still make that event important to a caller: examples include a status indicator, branding mark, or safety symbol.

SVG source alone does not establish those business meanings. Authored IDs, element names, text, source order, colors, and difference counts can be useful identifiers, but none is a trustworthy universal importance signal. Promoting every small event would make the main-change summary equivalent to the full inventory, while suppressing dominated events would make caller-specific recovery impossible.

## Decision

Keep `event_rendered_pareto/v1` as the context-free main-change policy. Keep every supported Visual Event and Atomic Difference in the complete report regardless of frontier membership, pixel count, spatial extent, or rendered score. Retain one domination witness for every excluded measured event.

Treat semantic concern as query-conditioned context supplied outside Structured Report. A consumer must first enumerate the full difference inventory. When caller context resolves to a reported subject, event, Atomic Difference, Changed Fact, source location, or Difference Region, the consumer must report every matching item even if its event is dominated. Impact membership may explain context-free magnitude, but it cannot veto the query match.

The query supplies the importance judgment; a source identifier may only help resolve that query. Without resolvable caller context, semantic importance is unknown rather than low. The consumer must not guess a match or infer business priority from source wording or magnitude.

Do not add a concern field, semantic label, source-derived priority, small-event threshold, or concern-aware ranking to Schema `1.43`. A future Concern Profile or query API requires its own task, deterministic matching contract, version identity, and evaluation evidence.

## Consequences

The report remains lossless for query-conditioned retrieval without claiming knowledge that the analyzer does not possess. A text-only Agent can use the frontier for an initial context-free summary, then recover a dominated concern through the full events, differences, regions, and cause links.

The main frontier may omit an externally important event by design; that is not data loss because the frontier is derived and the full inventory remains authoritative. A caller asking only for “the main changes” receives the context-free frontier. A caller naming a concern receives the matching evidence plus its dominated status. An unresolvable phrase such as “the safety icon” must produce an uncertainty statement while every difference is still enumerated.

The focused [semantic-concern evaluation](../../evaluation/semantic-concern/README.md) proves this behavior with a one-pixel dominated event. Schema `1.43`, module version `0.5.23`, canonical report bytes, and `event_rendered_pareto/v1` remain unchanged.
