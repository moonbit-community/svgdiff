# Interaction-State Profiles for Dynamic SVG Selectors

Status: research input for ISS-156; no product support is implemented

Date: 2026-07-17

## Question

How should svgdiff declare and reproduce event-driven pseudo-classes and user-interaction state without weakening the deterministic static report, conflating interaction with scripts or animation, or turning one browser observation into semantic truth?

## Recommendation

Use two separately versioned artifacts:

- `svgdiff-interaction-state-profile/1` declares one closed state checkpoint for a future deterministic evaluator. It declares inputs such as the document address, focus target and policy, and pointer devices, positions, and button state. The evaluator derives pseudo-class membership; callers never set arbitrary `:hover = true` or `:focus-within = true` flags.
- `svgdiff-interaction-observation/1` records one named browser target replaying a versioned action scenario and proving which state it actually reached. It is target-local rendered evidence, not a canonical Structured Report and not proof that another browser reaches the same state.

The current secure static Comparison Profile remains unchanged: interaction, author scripts, and animation are disabled, and unsupported state selectors continue to reduce coverage. A future interactive report still compares only one exact checkpoint. A suite of baseline, hover, focus, and pressed checkpoints is a container of separate reports or observations, never one merged equality claim.

This follows SVG 2's own separation of processing-mode switches: interactivity, script execution, declarative animation, and external resources are distinct capabilities. Static and secure-static SVG modes disable interaction, scripts, and animation; an interactive document is a different processing context, not merely the same image with extra CSS enabled ([SVG 2 processing modes](https://svgwg.org/svg2-draft/conform.html#processing-modes)).

## Why state is not a bag of pseudo-class booleans

Selectors can depend on information outside the document tree and can change without changing the document. The specification also imposes relationships between states: `:hover` and `:active` propagate through flat-tree ancestors, `:focus-within` is derived from focused descendants, and several input-state pseudo-classes are mutually constrained ([Selectors Level 4 pseudo-classes](https://www.w3.org/TR/selectors-4/#pseudo-classes), [user-action pseudo-classes](https://www.w3.org/TR/selectors-4/#useraction-pseudos)).

Direct flags could therefore manufacture impossible states, omit required ancestors, or hide a changed hit-test result. Svgdiff should record primitive inputs and a versioned derivation method, then serialize the complete achieved-state manifest as evidence.

## State taxonomy

| Family | Examples | Governing input | Recommended disposition |
| --- | --- | --- | --- |
| Tree and language selectors | `:root`, `:empty`, `:nth-child()`, `:has()`, `:lang()`, `:dir()` | Static document and selector semantics | Ordinary static selector coverage, not interaction state. |
| Address and target | `:target`, `:any-link` | Exact document/base URL, fragment, URL resolution | First deterministic candidate. `:target` is derived from the declared document URL, never an element flag ([Selectors target pseudo-class](https://www.w3.org/TR/selectors-4/#the-target-pseudo)). |
| Link history | `:link`, `:visited` | Browser history, partitioning, privacy policy | `:visited` is not canonical. Allow only an isolated target-local observation with exact fresh-profile and navigation identity. HTML explicitly allows privacy-specific matching rules ([HTML link pseudo-classes](https://html.spec.whatwg.org/multipage/semantics-other.html#selector-link)). |
| Pointer designation | `:hover` and propagated ancestor matches | Pointer subtype/capability, CSS-pixel position, current rendering, SVG hit testing, `pointer-events` | Deterministic only after a pinned hit-test evaluator exists; otherwise external observation. SVG hit testing depends on geometry, paint-related state, clipping, and `pointer-events` ([SVG 2 hit testing](https://svgwg.org/svg2-draft/interact.html#hit-testing)). |
| Activation | `:active` and propagated ancestor matches | Pointer/key down state, host activation semantics, exact checkpoint before release | Deterministic only as an explicitly held checkpoint. Never approximate a click as `:active`; the state normally exists between down and release ([Selectors `:active`](https://www.w3.org/TR/selectors-4/#the-active-pseudo)). |
| Focus | `:focus`, `:focus-within` | Focused area, focus chain, embedding context | Declare one focus target or none; derive `:focus-within`. Browser focusability and click/sequential focus can depend on UA and platform policy ([HTML focus model](https://html.spec.whatwg.org/multipage/interaction.html#focus)). |
| Focus indication | `:focus-visible` | Focus plus input modality, user preference, UA heuristic | Exclude from portable canonical state until svgdiff owns a named algorithm. A browser observation records the target's result; Selectors intentionally lets UAs choose heuristics ([Selectors `:focus-visible`](https://www.w3.org/TR/selectors-4/#the-focus-visible-pseudo)). |
| Host control state | `:enabled`, `:disabled`, `:read-write`, `:checked`, `:indeterminate`, `:valid`, `:user-invalid`, and related states | Host-language current values, dirty flags, group/form relations, validation and interaction history | Deferred with `foreignObject` and a deterministic HTML/forms engine. These are derived host states, not copies of SVG attributes ([Selectors input pseudo-classes](https://www.w3.org/TR/selectors-4/#input-pseudos)). |
| Browser or resource state | `:open`, `:popover-open`, `:modal`, `:fullscreen`, media playback/loading states | Top-layer/browser UI, resource loader, media clock | External target observation until the corresponding host, resource, and timeline contracts exist. |
| Selection and generated UI | `::selection`, caret, native focus ring, controls | Selection ranges and UA rendering | Separate future profile; do not smuggle them into element pseudo-class state. |

Plain SVG has no HTML checkbox or form-validation model. Encountering `:checked` in an SVG stylesheet does not justify setting it false and claiming completeness; it remains unsupported until a supported host-language element can actually participate.

## Canonical state-checkpoint identity

A proposed `svgdiff-interaction-state-profile/1` must identify all of the following:

1. exact before/after source and ordered resource-bundle hashes plus the parent Comparison Profile;
2. SVG processing context (`standalone_document`, a precisely named embedding mode, or another reviewed mode), with interaction enabled, author scripts disabled, external acquisition policy closed, and declarative animation disabled or referenced through a separate accepted timeline profile;
3. exact document URL, base URL resolution rule, origin model, fragment, and history policy;
4. one focus locator or explicit `none`, focus acquisition class, input-modality state, and either a pinned focus-visible policy ID or `focus_visible = unavailable`;
5. every input source by stable ID: `mouse`, `pen`, `touch`, or keyboard; hover capability; viewport CSS-pixel coordinates; pressed buttons/keys and modifiers; primary-pointer status; and any state explicitly unsupported by the evaluator;
6. the cross-side intent: `coordinate_locked` uses the same viewport coordinate on both SVGs, while `mapped_subject_locked` uses two targets connected by explicit Subject Alignment evidence. These answer different questions and cannot be silently substituted;
7. stable per-side target locators using source role, namespace-aware structural/source locator, optional authored ID, and `<use>` instance path where applicable; report-local IDs and array positions are not source identities;
8. the selector/state evaluator, hit-test, flat-tree/instance-tree, focus, URL, and state-transition policy IDs;
9. exact limits for state iterations, input sources, action ticks, locators, achieved-state records, and output bytes; and
10. one checkpoint ID and a complete derived manifest: focused area/chain, designated and active targets, propagated matches, target/link classifications, input state, resolved coordinates, unsupported states, and a manifest hash.

The same profile inputs are applied independently to before and after. A moved shape may therefore stop matching `:hover` in a coordinate-locked comparison; that is real interaction-sensitive evidence. A mapped-subject comparison instead asks how corresponding subjects respond and must fail closed when correspondence is ambiguous.

## State resolution

The future deterministic evaluator should use this order:

1. load the exact static source, resources, viewport, URL, and non-interaction profile inputs;
2. establish address-derived and explicitly declared primitive input state;
3. compute cascade, geometry, and hit testing;
4. derive designated, active, and focus-related pseudo-class sets, including required ancestor propagation;
5. recompute any style, geometry, or hit-test result changed by those selectors; and
6. repeat until the complete state manifest is stable or a fixed transition limit is reached.

This loop is necessary because a hover rule can change geometry, visibility, clipping, stacking, or `pointer-events`, thereby changing the next hit test. Selectors notes that the general specifics of hit testing are not fully defined, while SVG defines its own graphics hit-testing inputs; a versioned project-owned evaluator is therefore required for canonical results ([Selectors `:hover`](https://www.w3.org/TR/selectors-4/#the-hover-pseudo), [SVG 2 pointer-events](https://svgwg.org/svg2-draft/interact.html#PointerEventsProperty)).

A repeated manifest is a fixed point. A repeated cycle with no fixed point is `state_unstable`, not equality. The engine must not select the first, last, or visually smallest state arbitrarily.

## Browser action scenario and observation identity

Browser replay should use a separate `svgdiff-interaction-scenario/1` referenced by `svgdiff-interaction-observation/1`. The scenario records:

- initial state-profile hash, exact source role, browsing/embedding context, clean storage/history policy, viewport, scroll offsets, window-focus state, and target locator mapping;
- ordered input sources and action ticks using WebDriver-compatible `pointerMove`, `pointerDown`, `pointerUp`, `pointerCancel`, `keyDown`, `keyUp`, `scroll`, and zero-time ordering pauses;
- for every action, its source ID, subtype, viewport/pointer/element origin, CSS-pixel offsets, duration, button/key, pointer properties, modifiers, and per-side resolved target and coordinate;
- whether targeting is coordinate-locked or mapped-subject-locked, with all mapping evidence;
- the exact checkpoint between ticks, held input state at capture, release policy, and a capture barrier that does not imply animation time or general event-loop quiescence;
- required postconditions: current URL/fragment, focused area, matched state sets, pointer/button/key state, scroll position, and any navigation or default action that must not occur; and
- limits, errors, transcript hash, achieved-state manifest/hash, screenshot or raster hashes, repeat count, and byte-agreement result.

WebDriver is useful because it defines persistent input-source state, simultaneous action ticks, and key/pointer down and up operations. It also says dispatch is ultimately implementation-specific and default actions may generate additional events; an action transcript therefore proves intent, not achieved state ([WebDriver actions and input state](https://w3c.github.io/webdriver/#actions)). The observation must record and validate postconditions after the exact checkpoint.

Element-origin actions are not automatically comparable: WebDriver resolves them through the element's in-view center, which can differ after an SVG edit. Svgdiff must retain the resolved coordinate and subject on each side. Pointer capture also changes event targeting from ordinary hit testing, so any captured-pointer state must be explicit or unsupported ([Pointer Events pointer capture](https://www.w3.org/TR/pointerevents/#pointer-capture)).

Developer-tools “force pseudo state” commands may produce useful QA screenshots but are non-standard target controls and can create states normal input cannot reach. Record them only as `forced_target_state` observations; never use them for canonical equality or renderer conformance.

## Failure and authority semantics

| Condition | Result |
| --- | --- |
| Malformed or internally contradictory profile/scenario | Reject before comparison as invalid configuration. |
| Target locator or mapped correspondence is missing or ambiguous | `state_target_unresolved`; dynamic computed/rendered evidence is unavailable and the report/edge is insufficient, never retargeted by ID or order. |
| Unsupported pseudo-class, host state, hit-test feature, focus policy, pointer capture, or embedding behavior can affect output | Preserve supported source facts; mark interaction coverage partial and the affected computed/rendered relation indeterminate. |
| State iteration reaches a cycle or limit | `state_unstable` or `state_resolution_limit_exceeded`; no chosen-state pixels or equality. |
| Browser action is rejected, intercepted, navigates unexpectedly, times out, crashes, or misses its postcondition | Observation `failed` or `unavailable`; no fallback screenshot of a different state. |
| Repeated replays produce different manifests or bytes | `ambient_unreproducible`; preserve every disagreement. |
| Browser reaches a stable state different from the canonical evaluator | Retain both as a conformance divergence under their own identities; neither overwrites the other. |
| One side reaches the checkpoint and the other does not | Insufficient interaction evidence, not insertion, measured zero, or equality. |

An external observation may report the action transcript, achieved pseudo-class manifest, target-local DOM facts obtained by the harness, and captured raster difference. It cannot fabricate Source Semantics, canonical Computed Appearance, Visual Events, Impact, Difference Regions, or Cause Envelope completeness.

## Relationship to scripts and animation

Interaction state is an independent axis:

- The canonical evaluator never dispatches DOM events or runs author handlers. It computes one declared state checkpoint directly.
- A script-disabled browser replay may dispatch trusted input and allow only explicitly admitted host default actions. Exact author script bytes still reduce canonical coverage and belong to `svgdiff-script-observation/1` if executed.
- A script observation may reference the same interaction scenario, but its mutations and authority remain governed by the script observation contract.
- An action tick orders inputs; it is not a visual time sample. WebDriver durations, wall-clock waits, animation frames, CSS transitions, SMIL event-begins, and script timers require the future timeline contract.
- If an interaction starts or cancels declarative animation and no accepted timeline/checkpoint is present, the animated consequence is unavailable. Do not capture an arbitrary “settled” frame.

SVG 2 itself processes dynamic pseudo-class styles, event-triggered animation, hyperlink behavior, and other UI actions as distinct steps, supporting this separation ([SVG 2 event processing](https://svgwg.org/svg2-draft/interact.html#event-processing)).

## Rejected alternatives

- **Arbitrary per-element pseudo-class booleans:** can violate derivation, propagation, hit testing, host-language, and mutual-exclusion rules.
- **An action transcript without achieved-state evidence:** target dispatch and default actions are implementation-dependent.
- **One browser screenshot as canonical dynamic truth:** identifies only one target, environment, state path, and checkpoint.
- **A fixed sleep or “network idle” rule:** mixes interaction with animation, scripts, scheduling, and resources without proving state closure.
- **DevTools forced states as standards replay:** non-standard and potentially unreachable.
- **One report aggregating every interaction state:** hides which checkpoint supports each difference and permits missing states to look like agreement.
- **Treating every dynamic pseudo-class as permanently false:** correct only for the declared non-interactive static mode, not for a future interactive profile.

## Staged implementation and reconsideration gates

1. First admit address-only `:target` under an exact URL/fragment profile; it needs no input dispatch or hit testing.
2. Admit explicitly focused SVG elements and derived `:focus-within` only after stable locators, SVG focusability, `<use>` instance focus, and negative target tests exist. Keep `:focus-visible` unavailable until a named algorithm is owned.
3. Admit `:hover` only after complete hit testing for the supported painted geometry, clipping, stacking, `pointer-events`, coordinate mapping, feedback convergence, and coordinate- versus subject-locked fixtures.
4. Admit held `:active` only after down-state checkpoints, ancestor propagation, cancellation/release, keyboard activation, and no-implicit-click tests exist.
5. Keep form/control pseudo-classes behind the accepted deterministic `foreignObject` HTML/forms engine; keep browser top-layer, resource, selection, and media states behind their owning contracts.
6. Keep `:visited` non-canonical unless an isolated synthetic-history design can prove specification-compatible privacy behavior, zero ambient history, exact partition identity, cross-host replay, and Agent value.
7. Version the state profile, scenario, evaluator, locator mapping, limits, and observation independently from the Structured Report Schema, renderer, conformance profile, script observation, and animation timeline.
8. Add adversarial fixtures for impossible declarations, overlay retargeting, hover feedback cycles, moved subjects, duplicate IDs, ambiguous mappings, nested `<use>`, focus-policy variation, action interception, held buttons, target navigation, replay divergence, and one-side failure.
9. Require repeated byte-identical canonical outputs on supported hosts, target-local repeat evidence for browser observations, renderer-disposition review, and text-only Agent evaluation showing that interaction checkpoints improve main-difference identification without weakening static equality.

Until these gates pass, interaction remains outside the current complete-analysis slice and a browser replay remains an external observation.

## Primary sources

- [Selectors Level 4](https://www.w3.org/TR/selectors-4/)
- [CSS Basic User Interface Level 4](https://www.w3.org/TR/css-ui-4/)
- [SVG 2: Conformance Criteria and Processing Modes](https://svgwg.org/svg2-draft/conform.html)
- [SVG 2: Scripting and Interactivity](https://svgwg.org/svg2-draft/interact.html)
- [HTML Standard: User Interaction](https://html.spec.whatwg.org/multipage/interaction.html)
- [HTML Standard: Matching HTML Elements Using Selectors](https://html.spec.whatwg.org/multipage/semantics-other.html#selectors)
- [WebDriver](https://w3c.github.io/webdriver/)
- [Pointer Events](https://www.w3.org/TR/pointerevents/)
