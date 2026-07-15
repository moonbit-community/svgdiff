# Separate nonvisual source audit from visual diff

Status: accepted and implemented for descriptive content and metadata attributes

## Context

The primary product answers a visual-semantic question for text-only Agents. Adding accessibility descriptions, RDF payloads, or custom data directly to `AtomicDifference` would mix nonvisual source auditing with visual outcomes, fabricate magnitudes and regions, and make an empty visual-difference list impossible to interpret. Dropping those changes entirely would also leave callers without an explicit way to inspect them.

There was a second correctness problem: general analyzers could see resource-looking or visual-looking foreign markup nested inside `metadata` and incorrectly create subjects, unsupported-feature Diagnostics, or reference cycles even though SVG descriptive content does not render.

## Decision

Keep Structured Report and every Visual Event free of pure nonvisual metadata differences. Before visual analysis, mask only the inner content of outermost SVG `title`, `desc`, and `metadata` elements with equal-length UTF-16 whitespace. Preserve the outer element and its DOM/CSS position so a real supported selector consequence is not erased.

Provide `audit_nonvisual_metadata` as an independent library operation. Audit exact authored descriptive content and unprefixed `aria-*`/`data-*` values, align them by namespace-expanded same-name-ordinal path, and retain before/after UTF-16 spans. Do not make this a comparison-profile switch or a new Structured Report field.

Treat `data-*` and `aria-*` as source-audit facts, not universally inert visual inputs. If a supported selector consumes one, report the resulting visual property consequence in the ordinary visual domains while keeping the metadata value itself out of Atomic Differences.

## Consequences

Visual Agents receive a cleaner and more truthful report, while callers that need source governance can opt into a deterministic audit without recomputing or reinterpreting visual evidence. Arbitrary metadata payloads no longer reduce visual coverage or poison reference safety. Exact authored metadata content intentionally remains representation-sensitive in the audit; this operation does not claim semantic RDF or accessibility equivalence.

Module `0.5.5` adds the source-audit API and records. Source-audit schema `1.0` is independent. Retiring visual Diagnostics previously fabricated by nested metadata advances Structured Report schema to `1.25`; report fields, renderer identity, conformance `/20`, metrics, and ordering remain unchanged.
