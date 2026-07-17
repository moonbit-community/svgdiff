# ADR 0104: Compare animation at explicit logical checkpoints

- Status: accepted, not implemented
- Date: 2026-07-17
- Decision owners: svgdiff maintainers
- Supersedes: none

## Context

SVG/SMIL, CSS Animations, CSS Transitions, Web Animations, script, and browser frame callbacks expose related but non-identical time and state. A wall-clock wait does not identify document time, a normalized progress value can conceal duration changes, and matching a finite set of frames cannot prove equality over a continuous interval. Event starts and generated transitions also depend on explicit prior state and processing order.

The current Comparison Profile disables all animation. Script execution is a permanent canonical non-goal, and interaction state has a separate accepted checkpoint model.

## Decision

Preserve the animation-free static profile. Define a future `svgdiff-animation-timeline-profile/1` with a project-owned logical document timeline, exact rational time, closed activation and mechanism inputs, explicit triggers, independently referenced script/interaction/resource axes, cross-side effect mapping, hard limits, and one typed checkpoint question.

Use shared exact timeline time as the general before/after synchronization rule. Preserve duration and inventory differences rather than normalizing progress. Permit mapped event/boundary checkpoints only with explicit mapping and pre/post phase. Treat normalized-effect-progress comparison as a separate possible diagnostic question without temporal-equality authority.

Keep point, finite-set, boundary/event, and continuous-interval questions distinct. Only a complete analytic/event-partition proof over an admitted mechanism may establish interval equality; finite matching samples cannot.

Script-driven animation and browser frame capture remain target-local `svgdiff-animation-observation/1` evidence referencing the accepted Script Observation contract. Requested and achieved time/state are both required.

## Consequences

The model can localize a dynamic result to a reproducible logical checkpoint without erasing timing edits. Mechanism-specific unresolved, pending, paused, finished, cancelled, infinite, event-based, and transition states remain explainable. Implementing even a small dynamic slice requires a project-owned timing evaluator and new versioned product contracts.

No dynamic evaluator, browser runtime, dependency, report field, Schema, public API, Diagnostic, fixture, CLI option, CI job, or release asset changes through this decision.

## Rejected alternatives

- Capture after a fixed wall-clock delay: process time, document time, resource readiness, task scheduling, and frame presentation are not the same clock.
- Normalize both animations to the same progress: this hides duration, delay, rate, repeat, and start-time changes and answers a different question.
- Compare only the intersection of keyframes or events: one-sided timing structure would disappear.
- Treat matching keyframes or sampled frames as interval equality: interpolation, easing, composition, transitions, and intervening events can differ.
- Let a pinned browser define canonical time: it supplies target-local behavior, not project-owned temporal semantics or complete causal evidence.
