# Animation Timeline Model

Status: accepted future profile boundary; no dynamic comparison is implemented

Future profile identity: `svgdiff-animation-timeline-profile/1`

Future checkpoint-set identity: `svgdiff-animation-checkpoint-set/1`

Future observation identity: `svgdiff-animation-observation/1`

Last verified: 2026-07-17

Svgdiff may eventually compare SVG animation at explicitly declared logical checkpoints, but it will not infer a checkpoint from wall-clock delay, normalize two animations to matching progress, or claim interval equality from a finite frame sample. The current deterministic static Comparison Profile remains animation-free and continues to guard SMIL elements, CSS animation and transition semantics, scripts, and event-driven timing.

The future profile defines one common comparison vocabulary while retaining mechanism-specific timing state. It does not flatten SMIL timing, CSS Animations, CSS Transitions, Web Animations, interaction actions, and script scheduling into one approximate clock.

The governing decision is [ADR 0104](adr/0104-compare-animation-at-explicit-logical-checkpoints.md). Primary evidence is in the [research note](research/animation-timeline-model.md), and the boundary is machine-checkable under [`evaluation/animation-timeline-decision`](../evaluation/animation-timeline-decision/).

## Current behavior

The current profile has no timeline, animation start state, event trace, or sampling request. Animation and transition execution are disabled. Encountered dynamic constructs reduce coverage rather than being evaluated at time zero, frozen at a guessed value, or treated as equal because the renderer output happens to match.

This decision adds no parser, animation evaluator, browser mode, report field, Schema change, Diagnostic, public API, fixture, dependency, CLI flag, CI job, or release asset. It does not make animation comparison complete.

## Typed timeline profile

A future `svgdiff-animation-timeline-profile/1` must close and hash all of these groups:

1. **Logical timeline**: timeline kind, exact origin rule, signed rational time unit, initial current time, monotonicity, playback rate, seek policy, inactive/null behavior, and virtual-clock evaluator identity. Wall-clock epoch and elapsed process time are not timeline identity.
2. **Document activation**: document creation and activation steps, document timeline readiness, initial style and DOM state, declarative animation discovery, and exact resource-readiness manifest. “Page loaded” or “network idle” is not an activation rule.
3. **Mechanism semantics**: accepted SVG/SMIL, CSS Animation, CSS Transition, and Web Animations subsets plus their evaluator versions. Native begin/end lists, restart, fill, repeat, delay, direction, easing, composite, transition reversal, and generated-effect state remain typed mechanism data.
4. **Triggers and processing axes**: exact declared timing events, syncbase/repeat dependencies, interaction checkpoint or scenario references, script-observation reference, event-order and microstep policy, and explicit disabled values for unused axes. Referencing an axis does not enable it.
5. **Cross-side identity**: animation/effect locators, subject alignment evidence, event or boundary mapping, and the selected synchronization mode. Missing, additional, or ambiguous effects remain differences or unavailable mappings.
6. **Checkpoint request**: one typed point, finite point set, declared boundary/event set, or interval question; exact inclusivity and ordering; pre/post-event phase; requested values; and maximum checkpoints, events, dependency steps, iterations, and output.
7. **Execution identity**: style, geometry, resource, font, color, renderer, renderer-conformance, state, and script-observation identities plus the complete normalized manifest hash.

Logical times use a canonical signed rational representation, not binary floating-point or a locale-formatted decimal. Negative requested times are representable; whether a mechanism is active there is a separate result. A null or inactive timeline is not numeric zero.

## Checkpoint questions

Each comparison request has exactly one of these kinds:

| Kind | Meaning | Maximum claim |
| --- | --- | --- |
| `point` | Resolve both sides at one exact shared logical timeline time. | Equality or difference only at that checkpoint and under the exact profile. |
| `finite_point_set` | Resolve an explicit ordered set of independent point checkpoints. | Equality or difference only at the listed checkpoints; unsampled time is unknown. |
| `boundary_event_set` | Resolve the declared union of mapped timing boundaries or events, with exact before/after processing phases. | Equality or difference at those boundaries; it does not cover interpolation between them. |
| `continuous_interval` | Ask whether the complete rendered semantics agree throughout an exact open, closed, or half-open interval. | Permitted only when the admitted mechanisms have a complete analytic/event-partition proof; otherwise `interval_proof_unavailable`. |

A `boundary_event_set` is not secretly expanded into an interval claim. A finite sample may provide a counterexample to interval equality, but matching samples cannot prove equality between them. Adaptive or renderer-selected frames are observational unless their complete deterministic selection policy is separately versioned.

## Synchronization

The default and only general point synchronization mode is `document_time_locked`: both SVGs receive the same exact logical document-timeline value. Duration, delay, iteration, rate, and start-time edits therefore remain observable; svgdiff does not rescale either side to hide them.

`logical_event_locked` is available only for a boundary/event request with explicit cross-side mapping evidence. It compares named pre- or post-processing states around the mapped event while retaining each side's achieved logical time and mechanism state. A missing, duplicate, ambiguous, unresolved, differently ordered, or differently triggered boundary is a reportable inventory or mapping outcome, not an invitation to choose the nearest event.

`effect_phase_locked` is a distinct diagnostic question that may be proposed later for shape-of-motion analysis. It is not whole-scene timeline synchronization, cannot establish temporal equality, and must not replace the document-time result. Two animations at 50% progress can occur at different document times and answer a different Agent question. `external_frame_locked` is observation-only and identifies an exact virtual-time step and capture phase while retaining achieved target time, task, microtask, event, and frame-callback evidence.

The boundary set is the deterministic union of requested before-side and after-side boundaries, preserving side and mechanism provenance. Additional animation effects, generated transitions, keyframes, repeat boundaries, or event dependencies therefore remain present. No intersection-only policy may discard one-sided timing structure.

## State and phase preservation

At every checkpoint, the evaluator records the requested timeline time, achieved timeline time, timeline activity, and each relevant mechanism's phase and state. At minimum it preserves:

- Web Animations `idle`, `running`, `paused`, and `finished` play states separately from pending play or pause tasks;
- before, active, and after effect phases, fill behavior, unresolved current/start time, hold time, playback rate, and cancellation/removal;
- SMIL unresolved, indefinite, event-based, syncbase-based, active, frozen, repeated, restarted, and ended timing with simple and active durations kept distinct;
- CSS Animation delay, iteration, direction, fill, easing, play state, and generated animation identity;
- CSS Transition generation state, delay, duration, start/end values, reversing behavior, cancellation, and no-transition outcomes; and
- script or interaction requested state separately from the state actually achieved by an external observation.

An unresolved begin is not idle at time zero. A paused effect is not finished. An infinite duration or iteration is not nontermination. A cancelled transition is not a completed transition. A timeline with null current time is not at zero.

## Trigger and processing rules

Declarative clock-based timing may be evaluated canonically only inside an accepted closed subset. Event-based SMIL timing requires a declared event trace and versioned dispatch/microstep rules. Interaction-triggered timing references an accepted `svgdiff-interaction-state-profile/1` checkpoint or a target-local scenario observation; it does not synthesize user actions implicitly.

Script-driven animation remains external under the permanent [script execution boundary](script-execution-boundary.md). A future `svgdiff-animation-observation/1` may reference one exact `svgdiff-script-observation/1`, but canonical analysis still executes no script. `requestAnimationFrame` timestamps, tasks, microtasks, timers, DOM mutations, and achieved captures belong to that observation's transcript and cannot be inferred from a sleep duration.

Resource readiness is an input or a typed unavailable outcome. A delayed font, image, stylesheet, or external document cannot be allowed to race a checkpoint. The current no-implicit-I/O policy remains unchanged.

## Outcomes and authority

Canonical profile resolution uses distinct outcomes including:

- `resolved`;
- `invalid_profile`;
- `timeline_inactive`;
- `time_unresolved`;
- `trigger_unresolved`;
- `effect_inventory_incomparable`;
- `checkpoint_mapping_unavailable`;
- `mechanism_unsupported`;
- `resource_unavailable`;
- `interval_proof_unavailable`;
- `nonterminating_processing`;
- `sampling_limit_exceeded`;
- `dependency_limit_exceeded`; and
- `insufficient_evidence`.

External observations additionally retain `requested_time_not_reached`, `state_not_reached`, `replay_diverged`, `ambient_unreproducible`, `failed`, and `unavailable`. A timeout, exhausted limit, unresolved trigger, missing effect, null time, failed replay, or unsupported mechanism is never serialized as a zero duration, empty animation, unchanged frame, or equality.

A future `svgdiff-animation-checkpoint-set/1` records the normalized profile hash, ordered requested checkpoints, derived per-side schedule and effect state, statuses, and links to independently produced comparison evidence. A resolved future canonical checkpoint could feed the existing semantic and rendered evidence layers only under its exact profile and checkpoint identity. An external browser observation can report target-local achieved state and pixels but cannot fabricate canonical Source Semantics, Computed Appearance, Visual Events, Impact, Difference Regions, Cause Envelopes, or coverage.

## Agent interpretation

A text-only Agent must distinguish authored timing differences, generated mechanism/effect inventory, requested checkpoints, achieved temporal state, current computed values, rendered frame evidence, and interval-proof status. It must state the checkpoint kind and synchronization mode when summarizing dynamic results.

The Agent must not call matching sampled frames “the animations are equal,” describe normalized-progress similarity as same-time equality, convert an unresolved event start into no animation, or treat a browser frame captured after a delay as a reproducible logical checkpoint.

## Implementation gate

Implementation may begin only when a concrete Agent task requires it and the project has:

- a versioned schema for the complete profile, rational time, checkpoint kinds, effect locators, mappings, outcomes, and compatibility;
- a deliberately small declarative first slice with project-owned timing, interpolation, easing, cascade, and composition semantics;
- exact fixtures for negative delay/time, zero and indefinite duration, fill, repeat, direction, pause, seek, restart, unresolved and event begins, cancellation, transition reversal, one-sided inventories, and boundary ordering;
- hard limits for checkpoints, effects, events, dependencies, fixed-point processing, analytic partitions, output, and external process execution;
- conformance evidence against pinned primary-source test cases and external browsers without granting those browsers canonical authority;
- proof that scripts, interaction actions, network/resource races, wall time, and ambient state remain disabled or independently referenced; and
- Agent evaluation showing that temporal evidence improves main-difference identification without encouraging interval or causality overclaiming.

Until then, run:

```sh
sh scripts/test-animation-timeline-decision.sh
```
