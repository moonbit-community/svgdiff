# Architecture Decision Index

ADRs record why a decision was made at a point in time. They are historical records, not a complete description of the current implementation. Unless an ADR says otherwise, its status is accepted. For current behavior, start with the [documentation guide](../README.md).

## Report and evidence model

| ADR | Status | Decision |
| --- | --- | --- |
| [0001](0001-group-atomic-differences-into-visual-events.md) | Accepted | Group Atomic Differences into Visual Events. |
| [0002](0002-deliver-a-self-contained-html-report.md) | Accepted, implemented | Deliver a self-contained HTML report. |
| [0003](0003-base-diff-identity-on-visual-correspondence.md) | Superseded by 0005 | Base identity on visual correspondence. |
| [0004](0004-record-differences-at-three-evidence-layers.md) | Accepted | Preserve source, computed, and rendered evidence layers. |
| [0005](0005-use-set-to-set-entity-alignments.md) | Superseded by 0017 | Use set-to-set entity alignments. |
| [0006](0006-use-render-observations-as-visible-change-evidence.md) | Accepted | Use render observations as visible-change evidence. |
| [0007](0007-separate-magnitude-evidence-from-impact-policy.md) | Accepted | Separate magnitude evidence from impact policy. |
| [0008](0008-use-domain-specific-ordering-tuples.md) | Accepted | Use domain-specific ordering tuples. |
| [0013](0013-keep-diagnostic-rerendering-outside-the-report.md) | Accepted | Keep diagnostic rerendering outside the report. |
| [0014](0014-separate-difference-domain-from-computed-relation.md) | Accepted | Separate Difference Domain from Computed Relation. |
| [0015](0015-measure-presence-by-footprint-not-a-boolean.md) | Accepted | Measure presence by footprint rather than a boolean. |
| [0016](0016-visual-entities-may-have-zero-contribution.md) | Accepted | Permit visual subjects with zero rendered contribution. |
| [0017](0017-align-visual-subjects-set-to-set.md) | Accepted | Align Visual Subjects set-to-set. |
| [0018](0018-preserve-evidence-layers-in-visual-event-magnitude.md) | Accepted | Preserve evidence layers in event magnitude. |
| [0019](0019-form-visual-events-around-outcomes.md) | Accepted | Form Visual Events around outcomes. |
| [0020](0020-anchor-v1-visual-events-to-one-subject-alignment.md) | Accepted | Anchor each v1 event to one Subject Alignment. |

## Correctness boundary and provenance

| ADR | Status | Decision |
| --- | --- | --- |
| [0009](0009-scope-initial-correctness-to-deterministic-static-svg.md) | Accepted | Scope the initial correctness claim to deterministic static SVG. |
| [0010](0010-guarantee-causal-completeness-with-conservative-provenance.md) | Accepted, implemented for the supported slice | Guarantee causal completeness through conservative provenance. |
| [0021](0021-use-one-resolved-comparison-viewport.md) | Accepted target; only explicit viewport dimensions are implemented | Compare both inputs under one resolved viewport. |
| [0022](0022-separate-raw-raster-evidence-from-perceptual-background.md) | Accepted target; perceptual backgrounds are not implemented | Separate raw raster evidence from a perceptual background. |
| [0023](0023-default-the-comparison-dpr-to-one.md) | Accepted, implemented as a fixed v1 value | Default Comparison DPR to one. |
| [0024](0024-use-srgb-semantics-and-linear-srgb-raster-math.md) | Accepted, implemented for the v1 raster metrics | Use sRGB semantics and linear-sRGB premultiplied raster math. |
| [0027](0027-represent-authored-visual-declarations-as-facts.md) | Accepted, implemented for supported properties | Represent authored visual declarations as facts. |

## Dependency and ownership decisions

| ADR | Status | Decision |
| --- | --- | --- |
| [0011](0011-prefer-moonbit-rendering-dependencies-before-owning-a-renderer.md) | Accepted | Prefer MoonBit rendering dependencies before owning a renderer. |
| [0012](0012-own-only-the-smallest-failing-renderer-layer.md) | Accepted | Own only the smallest failing renderer layer. |
| [0025](0025-own-source-semantics-as-a-workspace-module.md) | Superseded by 0026 | Originally own Source Semantics as a workspace module. |
| [0026](0026-adopt-milky-xml-for-authored-parsing.md) | Accepted, implemented | Adopt `Milky2018/xml` for authored parsing. |

## CLI and distribution decisions

| ADR | Status | Decision |
| --- | --- | --- |
| [0028](0028-use-one-explicit-stdin-stream.md) | Accepted, implemented | Use `-` for exactly one explicit stdin SVG and keep errors off stdout. |
| [0029](0029-use-three-cli-exit-status-classes.md) | Accepted, implemented | Use three stable exit-status classes for reports, failed analysis, and invocation or I/O failures. |
| [0030](0030-compact-canonical-json-for-agent-mode.md) | Accepted, implemented | Compact the canonical report for agent transport without creating a lossy projection. |
| [0031](0031-report-feature-layer-coverage.md) | Accepted, implemented | Report coverage independently per encountered feature and evidence layer. |
| [0032](0032-gate-complete-on-coverage-proof.md) | Accepted, implemented | Require centralized coverage proof obligations before a report may remain complete. |

Some accepted ADRs intentionally describe a target that is not yet fully implemented. The implementation status above is a navigation aid; [`v1-scope.md`](../v1-scope.md) remains authoritative for current support.
