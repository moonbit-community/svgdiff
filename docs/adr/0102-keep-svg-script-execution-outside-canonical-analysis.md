# ADR 0102: Keep SVG script execution outside canonical analysis

- Status: accepted
- Date: 2026-07-17
- Decision owners: svgdiff maintainers
- Supersedes: none

## Context

The current deterministic static profile does not execute scripts, events, animation, interaction, or implicit external resources. SVG secure-static processing provides a coherent basis for that boundary. Enabling scripts instead exposes DOM and event processing plus browser APIs whose scheduling, clocks, entropy, storage, resources, locale, platform state, and settled-output point are not closed merely by running inside a sandbox.

Svgdiff's canonical report must enumerate supported visual-semantic differences, distinguish missing evidence from zero, and provide causally sound over-approximations. A browser screenshot after arbitrary script execution cannot by itself supply those layers or prove reproducibility.

## Decision

Permanently exclude SVG script execution from the canonical Structured Report engine and its deterministic static Comparison Profile. Continue to detect unsupported dynamic content, retain source-located Diagnostics, and revoke complete equality rather than treating disabled effects as absent.

Permit only a future separately versioned `svgdiff-script-observation/1` outside the comparison process. It must record the exact target, source/resources, scenario, environment, API and state closure, scheduling/quiescence, limits, failures, transcript, outputs, and replay evidence. Even a closed repeatable observation remains target-local rendered evidence and cannot fabricate canonical source, computed, event, causal, or completeness claims.

Treat security isolation and reproducibility as independent obligations. Do not add a JavaScript engine, browser dependency, script profile, report field, CLI mode, or current fixture through this decision.

## Consequences

Static reports keep their existing meaning and attack surface. Scripted SVGs remain partial rather than falsely equal. Users who eventually need target behavior may retain exact external artifacts without making one browser authoritative.

The project gives up canonical analysis of arbitrary script-created states unless the reconsideration gate establishes a closed execution semantics and full provenance. Later event-state and timeline decisions remain independent prerequisites rather than hidden runtime defaults.

## Rejected alternatives

- Execute scripts in the current HTML preview: presentation is hostile-source isolation, not analysis, and cannot feed evidence back into the report.
- Pin Chromium plus iframe sandbox/CSP and call the output deterministic: those controls do not close scheduling, Web APIs, storage, service workers, time, entropy, platform state, or quiescence.
- Add an in-process JavaScript engine with a DOM shim: it expands the trusted attack surface and creates a project-specific SVG scripting semantics without browser conformance or complete provenance.
- Compare only final scripted screenshots: pixels cannot enumerate source/computed distinctions or establish causal completeness.
- Treat identical script bytes or disabled execution as equality: the same program may depend on undeclared state, and unsupported effects remain unanalyzed.
