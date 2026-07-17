# Interaction State Profiles

Status: accepted future profile boundary; no interaction support is implemented

Future profile identity: `svgdiff-interaction-state-profile/1`

Future observation identity: `svgdiff-interaction-observation/1`

Future scenario identity: `svgdiff-interaction-scenario/1`

Last verified: 2026-07-17

Svgdiff may eventually compare a synthetic, explicitly declared interaction checkpoint, but it will not accept arbitrary pseudo-class match booleans or treat a replayed browser action trace as canonical state. The current deterministic static profile remains interaction-free and continues to guard every unsupported pseudo-class.

The future profile separates two artifacts:

- `svgdiff-interaction-state-profile/1` declares closed semantic inputs and uses a pinned project-owned state, selector, and hit-test evaluator to derive pseudo-class matches for both SVGs.
- `svgdiff-interaction-observation/1` records one exact browser/target action replay plus its achieved state and output. It is external evidence and cannot define canonical selector matches.

The governing decision is [ADR 0103](adr/0103-separate-declared-interaction-state-from-action-observations.md). Primary evidence is in the [research note](research/interaction-state-profiles.md), and the boundary is machine-checkable under [`evaluation/interaction-state-decision`](../evaluation/interaction-state-decision/).

## Current behavior

The current profile declares no navigation target, focus, pointing device, activation, or user-input state. Pseudo-class syntax such as `rect:hover` remains outside the static selector grammar, emits `css_cascade_unsupported`, and prevents false complete equality. The engine neither assumes every dynamic pseudo-class is false nor delegates matching to the pinned raster renderer.

This decision does not add selector grammar, state fields, events, scripts, animation time, browser capture, or report evidence. The current Comparison Profile, Schema, renderer, conformance identity, Diagnostics, tests, and outputs are unchanged.

## Declared checkpoint inputs

A future canonical checkpoint must identify all of the following or explicitly select their empty state:

1. **Document target state**: exact document URL identity and decoded fragment, with deterministic same-document target resolution.
2. **Focus state**: zero or one required focus target locator per side, locator-mapping evidence, focus origin/input modality, and one versioned focus-visible policy. Focusability and instance/shadow-tree behavior belong to that policy; they are not inferred from an authored ID alone.
3. **Pointing state**: an ordered set of device IDs and types, primary-device designation, hover capability, viewport-coordinate position in CSS pixels, buttons, activation state, and an explicit no-pointer option.
4. **Geometry context**: exact common viewport, DPR, coordinate mapping, renderer/hit-test identity, clipping and stacking semantics, and the resource/font/color profiles needed to compute the painted hit target.
5. **Processing axes**: script execution remains disabled, animation and transitions remain disabled unless a later timeline profile is referenced, no event dispatch occurs, and pointer capture or browser default actions are unavailable.
6. **Checkpoint identity**: profile version, state-evaluator build, selector grammar, hit-test method, target-locator method, closure policy, limits, and complete normalized input hash.

The same logical checkpoint applies to before and after. `coordinate_locked` checkpoints use the same viewport coordinates on both sides and may legitimately hit different subjects after an edit. `mapped_subject_locked` checkpoints use separate target locators connected by explicit cross-side mapping evidence. These answer different questions and cannot be substituted. Required locators resolve independently; a missing, duplicate, ambiguous, wrong-instance, or unsupported target does not silently become “no target” and makes the affected state unavailable.

## Derived state

Callers declare input state, not selector answers. The evaluator derives and records:

- `:target` from the declared URL fragment and deterministic target resolution;
- `:focus` from the resolved focus target;
- `:focus-within` from the focus target's inclusive derived ancestry under the accepted instance/tree model;
- `:focus-visible` only from `:focus` plus the named focus-visible policy and declared modality inputs;
- `:hover` from every hover-capable pointer's deterministic hit target plus the normative derived chain; and
- `:active` from the declared primary activation state, hit target, and named activation-chain policy.

The profile records both normalized seeds and the complete derived match sets with reasons. It rejects impossible combinations such as several focus targets, active buttons without an applicable primary device, undeclared coordinate spaces, or a derived ancestor chain that does not belong to the indexed visual tree.

State resolution may require iteration because `:hover` or `:active` styles can change geometry, clipping, stacking, visibility, or `pointer-events`, which can change the next hit target. The evaluator recomputes style, geometry, hit testing, and derived matches until the complete state manifest reaches a fixed point. A repeating cycle is `state_unstable`; exhausting the fixed iteration budget is `state_resolution_limit_exceeded`. Neither may select an arbitrary first, last, or visually smallest state.

Directly supplied sets such as `hover_ids: ["box"]`, `focus_within: true`, or `active: true` are not accepted canonical inputs. They bypass hit testing, ancestry, focusability, exclusivity, and mapping invariants and can describe states no conforming user interaction reaches.

## Pseudo-class boundary

| Family | Future canonical role |
| --- | --- |
| `:target` | Derived from explicit URL/fragment state. |
| `:focus`, `:focus-within` | Derived from one resolved focus target and accepted tree policy. |
| `:focus-visible` | Derived only under a separately versioned, explicit policy; never guessed from focus alone. |
| `:hover`, `:active` | Derived from declared devices/coordinates/buttons through pinned hit testing and chain rules. |
| Structural pseudo-classes such as `:root`, `:empty`, and `:nth-child()` | Separate static selector-grammar work; they need no interaction profile. |
| Link history and `:visited` | Permanent canonical non-goal; no ambient history or privacy-sensitive state. |
| HTML form, validation, autofill, media, fullscreen, modal, popover, and platform-widget states | Deferred or target-observation-only; current SVG and `foreignObject` boundaries do not supply their semantics. |
| Unknown or future dynamic pseudo-classes | Unsupported until independently classified and versioned. |

CSS transitions or animations caused by a state change are not evaluated at an implicit instant. Without an accepted timeline profile, the canonical checkpoint applies the final non-animated computed style with transition/animation execution disabled, or remains unsupported where the specification does not permit that separation.

## External action observation

A future browser observation records one target's attempt to reach a checkpoint through a versioned `svgdiff-interaction-scenario/1`. It must include:

- exact source/resources and browser/runtime/OS/rendering/capture identity;
- initial URL, focus, viewport, DPR, device, storage, permission, script, timeline, network, font, and color state;
- ordered WebDriver-style action ticks with device state, origins, coordinates, buttons/keys, durations, and target-resolution inputs;
- every dispatch/default-action/script/timer/resource policy and typed failure;
- the achieved URL fragment, focus, focus-visible result, pointer hit targets, hover/active chains, DOM state, computed match postconditions, and capture checkpoint;
- output and transcript hashes, repeat count, byte agreement, and replay divergence; and
- hard limits and process isolation under the same external-execution rules as Script Observations.

An action trace is not sufficient by itself. Default actions, hit testing, focus-visible heuristics, event ordering, and target behavior can vary. The observation must record achieved-state postconditions, and any mismatch from the requested state is `state_not_reached`, not successful reproduction.

## Failure and authority

Canonical checkpoint resolution uses these deterministic outcome classes:

- `resolved`: every required input and derived match is available;
- `invalid_profile`: the normalized inputs violate profile invariants;
- `target_unavailable`: a required target is missing, ambiguous, or unsupported on either side;
- `hit_test_unavailable`: geometry, stacking, clipping, or renderer conformance cannot establish a pointer target;
- `pseudo_class_unsupported`: the selector family lacks an accepted state rule;
- `state_incomparable`: the two sides cannot represent the same logical checkpoint;
- `state_unstable`: state and hit testing repeat without a fixed point;
- `state_resolution_limit_exceeded`: the fixed derivation budget is exhausted; and
- `insufficient_evidence`: another coverage or environment limit blocks the requested conclusion.

External observations additionally retain `state_not_reached`, `replay_diverged`, `ambient_unreproducible`, `failed`, and `unavailable`. None is serialized as the empty state, selector non-match, measured zero, or equality.

A resolved future canonical checkpoint could supply selector applicability and downstream current evidence layers only under its exact profile. An external observation may report target-local achieved matches, DOM, and pixels, but cannot fabricate canonical Source Semantics, Computed Appearance, Atomic Differences, Visual Events, Impact, regions, causes, or complete coverage.

## Agent interpretation

A text-only Agent must distinguish:

- requested checkpoint inputs;
- project-derived canonical match state;
- an action trace intended to reach state;
- target-local achieved state;
- visual-semantic differences under the resolved checkpoint; and
- Diagnostics or failures that prevent the state from being compared.

The Agent must not describe a browser replay as proof that the checkpoint is universally reachable, a raw pseudo-class list as a valid state, a missing target as “not hovered,” or matching pixels as selector equality.

## Implementation gate

Implementation may begin only when a concrete Agent task requires it and the project has:

- a versioned checkpoint schema, target-locator and cross-side mapping contract, normalized-state identity, and compatibility policy;
- accepted SVG focusability, instance-tree, hit-test, hover/active chain, target-fragment, and focus-visible rules for a deliberately small first slice;
- exact fixtures for valid, empty, missing, ambiguous, impossible, multi-pointer, overlap, clipping, stacking, transform, and before/after mapping cases;
- renderer/browser conformance dispositions for hit testing and resulting styles;
- hard work limits for devices, locators, hit-test candidates, derived matches, action ticks, and observation output;
- proof that scripts, event dispatch, transitions, and animation time remain disabled or independently profiled; and
- Agent evaluation showing that explicit interaction state improves explanations without weakening static-profile equality.

Until then, run:

```sh
sh scripts/test-interaction-state-decision.sh
```
