# Classify resource outcomes on independent axes

Status: accepted and implemented across the current resource families

## Context

The engine already had precise family-specific behavior for paint fallbacks, structural reuse, gradients, patterns, markers, images, caller bundles, and reference safety. Those implementations could not be summarized by one `resolved` flag. For example, a missing paint server can deterministically select red, an invalid image payload is indeterminate, an unused resource can still contain a source-semantic change, and an unused cycle can violate the same safety invariant as an active cycle.

Without one cross-family policy, callers and text-only Agents would need to reverse-engineer status from Diagnostic names and could incorrectly treat missing as invalid, unused as irrelevant, or partial as equality.

## Decision

Classify each resource occurrence on five independent axes: locator state, expected target kind, family semantic validity, whole-graph safety, and current activity. Preserve precise family-specific Diagnostics and evidence instead of adding a generic resource result that would erase useful distinctions.

Apply whole-input failures first. Malformed XML, invalid caller-bundle configuration, fixed-budget violations, accepted local-reference cycles, and explosive expansion fail because the engine cannot promise a usable complete inventory. Cycle rejection covers the entire accepted local graph, including unused definitions.

Treat missing and wrong-kind local paint servers as complete when the implemented SVG rule selects an admitted fallback or deterministic no-paint result. Keep unresolved non-paint consumers, external references, and invalid or unsupported referenced semantics partial with exact Source Spans and independently supported evidence.

Preserve unused SVG visual definitions as resource-role source-semantic differences without fabricated consumer fan-out or nonzero final rendered outcomes. Do not compare or decode unused caller-bundle content, because bundles are acquisition context rather than SVG source; continue validating every bundle entry's global key, MIME, and byte-budget invariants before analysis.

## Consequences

Status and evidence interpretation are uniform without forcing gradients, patterns, markers, use instances, or images through a lossy common value type. The distinction between safety and activity is explicit: unused cycles fail, while valid unused definitions remain analyzable. The distinction between SVG source and acquisition context is also explicit: invalid unused SVG semantics remain partial, while unused bundle payload contents are ignored.

This decision does not add serialized fields, Diagnostic codes, or public APIs, so module `0.5.4`, Structured Report schema `1.24`, renderer conformance `/20`, metric semantics, and ordering policy remain unchanged.
