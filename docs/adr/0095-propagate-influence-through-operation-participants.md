# ADR 0095: Propagate influence through operation participants

- Status: accepted
- Date: 2026-07-17
- Decision owners: svgdiff maintainers
- Refines: ADR 0094 source-influence indexing
- Supersedes: the temporary comparison-wide complete-operation fallback in ADRs 0070 and 0074

## Context

The private subject-influence index established the source-to-subject edge of the may-influence graph, but a complete render operation can read more subjects than its event alignment names. A group surface reads its descendants and overlapping backdrop; clip, mask, and filter operations read a host or content plus a resource; blending reads a foreground and an ordered backdrop prefix; stacking reads the inverted pair. Widening every such complete event to all Changed Facts preserves recall but also admits facts from disjoint later subjects that cannot participate in the operation.

The semantic analyzers already publish conservative participants through each direct Changed Fact's `affected_subject_ids`. Difference Region identity also supplies a conservative relation between simultaneous events over the same final pixel component. These two existing seams are sufficient for region-level transfer without introducing a serialized provenance graph or exact contribution index.

## Decision

Classify complete events privately as leaf input, group surface, clip, mask, filter, blend, isolation, or compositing order.

- Leaf entity events query the before/after identities of their entity-role Subject Alignment and retain direct event tokens.
- Supported operation events additionally union every direct fact's analyzer-owned `affected_subject_ids` before querying the subject-influence index.
- Every event sharing the exact Difference Region contributes its tokens to that region's envelope. This retains an independently changed overlapping backdrop or stacking participant.
- Partial reports and complete events with no candidate retain the comparison-wide fallback. Unsupported semantics continue to revoke causal completeness through Diagnostics.
- Candidate order remains report order, and the report schema remains unchanged.

Group opacity therefore carries the group and descendants; clip, mask, and filter carry hosts, resources, content, and consumers; blend and isolation carry the foreground, isolation boundary, and conservative ordered backdrop prefix; stacking carries its inverted pair and any exact shared-region event. A disjoint later subject does not enter an operation envelope merely because it changed elsewhere in the comparison.

## Consequences

Complete supported operations no longer receive an unconditional comparison-wide candidate set. The result is still a sound overapproximation: analyzer fan-out and exact region sharing can retain false positives, and no candidate is an exact contributor, unique cause, visibility judgment, severity, or weight.

This is region-level provenance, not tile-level propagation. If a future supported operation cannot express a conservative participant set or region relation, it must widen or revoke the guarantee rather than reuse this pruning rule speculatively.

## Rejected alternatives

- Keep every complete operation comparison-wide: sound but needlessly includes disjoint facts already proven independent by supported operation bounds.
- Use only the event alignment: incomplete for descendants, shared resources, backdrop prefixes, and stacking pairs.
- Infer participants from domain strings at report-consumption time: duplicates producer semantics and cannot restore tokens already pruned.
- Implement exact contribution weights now: unnecessary for the accepted conservative-completeness objective and explicitly deferred by ADR 0038.

## Evidence

- [`cause_envelopes_wbtest.mbt`](../../engine/cause_envelopes_wbtest.mbt)
- [`influence-provenance.md`](../influence-provenance.md)
- [`ISS-148`](../../issues/ISS-148.md)
