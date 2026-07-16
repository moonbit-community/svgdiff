# ADR 0076: Separate structural and rendered subject alignment

Status: accepted

Date: 2026-07-15

## Context

The existing Subject Alignment pipeline models rendered basic shapes deeply: it resolves normalized paths, geometry properties, hierarchy, and `use` instance placement before correspondence. Forcing groups, text, use hosts, and resource definitions into that shape record would fabricate geometry fields and make later algorithms treat source containers as painted leaves. Omitting them prevents text-only Agents from following text changes, structural hosts, and resource definitions across the report.

Text and visual resources also have important capability boundaries. No deterministic font environment exists, so text source identity must not imply shaped or rendered equality. Resource differences are mediated and require a later resource-specific alignment contract; attaching them to entity alignments now would collapse Visual Entities and Visual Resources.

## Decision

Keep the normalized rendered-subject inventory unchanged for basic shapes, paths, and rendered leaf instances reached through `use`. Build a second private source-structural inventory for `g`, `text`, `use`, `symbol`, `linearGradient`, `radialGradient`, `pattern`, `marker`, `clipPath`, `mask`, and `filter`, then append its alignments after rendered-subject alignments.

Structural subjects pair only within the same SVG kind. Selection uses an authored-ID hint first, exact structural path second, and stable kind-local source order last. Every rule records candidate counts, tie status, and null uncalibrated confidence. Unmatched endpoints remain explicit insertions or deletions. IDs and source order are deterministic evidence, not authoritative identity; transform-aware, rendered-geometry-aware, and robust repeated-subject matching remain separate roadmap work.

Text content differences may reference the resulting text alignment, but font-dependent Computed Appearance and Rendered Evidence remain partial. Visual resource definitions receive source-structure alignments, but resource Atomic Differences retain null `subject_alignment_id` until Visual Resource alignment is specified separately. Structural endpoints receive source-semantic feature coverage without invented computed or rendered coverage.

## Consequences

Paths and rendered use-instance alignment retain their existing algorithms and report IDs. Shape geometry consumers do not receive container or resource records. Agents can follow group, text, use-host, and resource-definition presence and correspondence while seeing uncertainty explicitly.

The last-resort stable-order rule can pair the wrong repeated subjects after a reorganization. This is observable as tied, uncalibrated evidence and is addressed by the next transform/geometry and repeated-subject roadmap items rather than hidden as certainty. Schema `1.32` versions the expanded meaning of `subject_alignments`; renderer identity and conformance profile `/25` do not change because no pixel behavior changes.
