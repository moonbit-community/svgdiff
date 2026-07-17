# Animation Timeline Model Research

Status: research for ISS-157; no timeline execution or observation is implemented

Last verified: 2026-07-17

## Question

What timeline contract would let svgdiff compare SMIL, CSS, and script-driven SVG animation without turning a few screenshots, one browser run, or an unresolved event into a false equality claim?

This note uses only primary specifications for external technical claims. It recommends a project boundary; it does not claim that current svgdiff, its pinned renderer, or every browser implements the cited models.

## Findings from the platform timing models

### There is no single interchangeable clock

Web Animations defines a timeline as a source of time values. A time value can be unresolved, and a timeline is inactive while its current time is unresolved. A document timeline is inactive before its document time origin exists and while its document is not active. The default document timeline has origin time zero; its time roughly corresponds to `Performance.now()`, but it changes only when animations are updated, not continuously within a task. The API exposes timeline and animation `currentTime` as nullable values, so unresolved time must remain distinct from numeric zero. [Web Animations: time values and timelines](https://www.w3.org/TR/web-animations-1/#timelines), [document timelines](https://www.w3.org/TR/web-animations-1/#document-timelines), [timeline interface](https://www.w3.org/TR/web-animations-1/#the-animationtimeline-interface)

An animation derives its current time from a hold time or from `(timeline time - start time) * playback rate`; no timeline, an inactive timeline, or an unresolved start time produces unresolved animation time. Play state is also not a simple running boolean: the model distinguishes idle, running, paused, and finished, while pending play and pause tasks affect those classifications and execute asynchronously. [Web Animations: current time](https://www.w3.org/TR/web-animations-1/#the-current-time-of-an-animation), [play states](https://www.w3.org/TR/web-animations-1/#play-states), [playing an animation](https://www.w3.org/TR/web-animations-1/#playing-an-animation)

`requestAnimationFrame` does not supply wall-clock time. HTML stores callbacks in order and invokes a selected batch with the rendering opportunity's relative high-resolution timestamp. During rendering, HTML updates animations and sends their events before running animation-frame callbacks, then recalculates style and layout. User agents may skip or coalesce rendering opportunities. Therefore callback count, callback arrival time, host wall time, and document timeline time are not interchangeable checkpoint coordinates. [HTML: animation frames](https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html#animation-frames), [HTML: update the rendering](https://html.spec.whatwg.org/multipage/webappapis.html#update-the-rendering)

### SMIL admits scheduled, dependent, and externally triggered time

SVG animation `begin` and `end` values can be lists containing document offsets, syncbase references to another animation's begin or end, event bases, repeat events, access keys, wall-clock values, or `indefinite`. A document offset is relative to document begin, while event and syncbase instance times may not yet be resolved. DOM calls such as `beginElement()` also create instance times. [SVG 1.1: animation timing attributes](https://www.w3.org/TR/SVG11/animate.html#TimingAttributes), [SVG 1.1: animation DOM interfaces](https://www.w3.org/TR/SVG11/animate.html#InterfaceElementTimeControl)

SMIL treats an unresolved event- or syncbase-based end as indefinite until it resolves, and reevaluates begin/end lists when an unresolved value becomes resolved. An event that never occurs can mean that an element never has an active interval; it is not evidence that the authored trigger is equivalent to no animation. [SMIL timing: end values and begin/end lists](https://www.w3.org/TR/smil-boston/smil-timing.html#Timing-EndValueSyntax)

The sampled value also depends on active duration, repeat behavior, restart, fill, accumulation, and interpolation. SVG defines `freeze` and `remove` as different post-active behavior, permits indefinite repeat, and distinguishes discrete jumps from linear, paced, and spline interpolation. [SVG 1.1: timing attributes](https://www.w3.org/TR/SVG11/animate.html#TimingAttributes), [SVG 1.1: animation value attributes](https://www.w3.org/TR/SVG11/animate.html#ValueAttributes)

### CSS animations and transitions need more than a timestamp

CSS Animations derive start from the moment the applying style and keyframes resolve. Negative delay starts immediately at progressed local time, paused animations retain progress, fill mode controls values outside the active interval, and start, iteration, end, and cancel events carry timing-specific `elapsedTime`. [CSS Animations 1: applying animations](https://www.w3.org/TR/css-animations-1/#animations), [animation properties](https://www.w3.org/TR/css-animations-1/#animation-name), [animation events](https://www.w3.org/TR/css-animations-1/#events)

CSS Transitions are history-dependent. Their generation requires before-change and after-change styles at a style change event. A negative delay begins partway through the transition. Interrupting and reversing a running transition uses its prior current value, reversing-adjusted start value, and reversing shortening factor; it can shorten both duration and a negative delay. Consequently, loading a final DOM and seeking a clock cannot reconstruct a transition without the ordered style-change history. [CSS Transitions 1: starting transitions](https://www.w3.org/TR/css-transitions-1/#starting), [faster reversing](https://www.w3.org/TR/css-transitions-1/#reversing), [transition delay](https://www.w3.org/TR/css-transitions-1/#transition-delay-property)

Transition events are derived from changes between animation-frame phases, and CSS Transitions 2 explicitly accounts for seeking and reversal through Web Animations. Event dispatch time is therefore evidence about a frame transition, not a substitute for the ideal schedule or the sampled visual value. [CSS Transitions 2: transition events](https://www.w3.org/TR/css-transitions-2/#transition-events)

### Disabled animation is not a sample at zero

SVG Integration states that disabling declarative animation means SMIL, CSS Animations, and CSS Transitions are not applied or run, and explicitly distinguishes that processing mode from pausing the document at `0s`. Svgdiff's current secure-static result must therefore remain a different profile from any future `time = 0` animated result. [SVG Integration: processing modes](https://www.w3.org/TR/svg-integration/#processing-modes)

## Recommended artifact boundary

Reserve three separately versioned future artifacts:

- `svgdiff-animation-timeline-profile/1`: closed semantic inputs, supported declarative timing families, synchronization question, exact checkpoints, and evaluator identity;
- `svgdiff-animation-checkpoint-set/1`: the derived before/after schedule states and evidence captured at those checkpoints; and
- `svgdiff-animation-observation/1`: one exact browser/runtime replay, including script and event-loop behavior, with target-local authority only.

The current Structured Report remains one static comparison with animation disabled. A future timeline result must not silently replace its Comparison Profile or upgrade its `partial` status.

The recommended authority split is:

| Animation source | Future authority | Reason |
| --- | --- | --- |
| Closed SMIL offset/syncbase subset | Project-owned declarative evaluator may become canonical for an accepted subset | Its schedule and value model can be derived without executing author code when every dependency resolves. |
| Closed CSS Animation subset | Project-owned declarative evaluator may become canonical for an accepted subset | Initial style resolution, effect timing, composition, and value interpolation can be pinned. |
| CSS Transition | Canonical only with an explicit, closed style-change scenario | Timestamp alone cannot reconstruct before/after style history or reversal state. |
| Event-based SMIL or interaction-triggered CSS | Canonical only when every event is supplied by an accepted scenario and target mapping | An undeclared event leaves timing unresolved. |
| Script-created or script-mutated animation | External observation only | The accepted script boundary does not admit canonical script execution or scheduler semantics. |
| Browser-specific animation behavior | External observation or multi-renderer cell | It describes one named target, not semantic truth. |

## Timeline taxonomy

The profile must name which question each checkpoint answers. These modes cannot be merged after execution.

### `document_time_locked`

Apply the same exact document-time coordinate and the same declared scenario prefix to before and after. This is the default comparison question: “What differs at the same elapsed presentation time?” Each side derives its own animation start times, local times, iterations, and values from its source.

For a project-owned evaluator, `t = 0` is a synthetic presentation epoch established only after admitted sources, resources, initial style, and initial interaction state are ready. For a browser observation, do not pretend navigation or load completion is document time zero: record the browser time origin, the actual nullable `document.timeline.currentTime`, and the harness activation offset.

### `logical_event_locked`

Apply one versioned event/stimulus transcript to both sides, then capture at a named phase relative to one mapped logical event occurrence. This answers “What differs after the same declared occurrence?” The event has one logical identity, exact target locator/mapping evidence, ordered occurrence index, exact scheduled coordinate when available, payload, dispatch policy, and postcondition.

If the event exists or resolves on only one side, target mapping is ambiguous, or the achieved postcondition differs, the checkpoint is incomparable or unavailable. It must not fall back to no event or to wall time.

### `effect_phase_locked`

Compare explicitly mapped effects at the same iteration and exact local progress, even if their document times differ. This can diagnose changed duration, easing, or keyframe shape, but it is not a whole-scene temporal equality check. Non-target animations remain at separately declared document times or make the checkpoint invalid. Keep this mode diagnostic until an Agent task proves it is useful.

### `external_frame_locked`

For a browser/script observation, identify an exact virtual-time step and capture phase in the target's update pipeline. Record the document timeline value, animation current times and play/pending states, dispatched events, microtask and task transcript, rAF batch and timestamp, DOM/style snapshot, and raster hash. “After N rAF callbacks” is not a portable time coordinate and cannot be the sole identity.

## Exact profile and checkpoint identity

Every profile must contain or hash all of these fields:

1. profile version and normalized-manifest hash;
2. exact before/after source and ordered resource identities;
3. base Comparison Profile, renderer/conformance, font, color, and interaction-profile references;
4. execution authority: `project_declarative` or `external_target_observation`;
5. admitted timing families and exact evaluator/spec/build identities;
6. synthetic presentation-epoch rule or external document time-origin and activation rule;
7. exact rational time representation, accepted range, conversion precision, and rounding at renderer or browser boundaries;
8. start-time, active-duration, repeat, fill, restart, direction, easing, composition, cascade, and discrete-endpoint policies;
9. ordered scenario stimuli, style-change transactions, logical events, target locators, cross-side mappings, and postconditions;
10. script policy reference, scheduler/task/microtask/timer/rAF policy, and API closure for external observations;
11. checkpoint list, synchronization mode, capture phase, requested evidence, and ordering;
12. work limits, failure policy, output dimensions/normalization, and repetition requirement.

Use normalized exact rationals for declared time, not binary floating-point identity. When calling a browser API or renderer that accepts a finite floating value, record the exact conversion and resulting IEEE value separately.

Each checkpoint record needs at least:

- report-local checkpoint ID and profile hash;
- query kind: `instant` or `interval`;
- synchronization mode and logical locator;
- requested exact coordinate or interval with endpoint inclusion;
- resolved before and after document time, local effect time, iteration, phase, play state, pending state, and resolution provenance;
- transcript prefix hash and capture phase;
- status, coverage, Diagnostics, rendered artifact hashes, and links to any resulting comparison evidence.

Report-local animation/effect IDs are side-local. Cross-side effect mapping needs versioned evidence based on source locators, target-subject alignment, animated-property identity, and schedule structure. Authored IDs alone are not sufficient; ambiguous mapping means insufficient evidence.

## Instant and interval questions

An instant checkpoint establishes only the state at one exact coordinate and capture phase. Equality at listed samples never proves equality between samples, across an omitted discrete jump, or for another event history.

An interval query is a distinct proof obligation. Represent intervals with exact endpoints and explicit open/closed membership. A complete declarative interval analysis must partition at every potentially relevant discontinuity, including begin/end/restart, repeat boundaries, discrete key times, fill changes, event occurrences, style-change transactions, and transition reversals. Within each partition it must either:

- derive a sound continuous relation for every participating animated value and downstream visual effect; or
- mark the interval partial and retain only the sampled or bounded evidence actually established.

Rendered screenshots at endpoints or a fixed frame rate cannot prove interval equality. Threshold-crossing intervals for raster or perceptual metrics additionally require a sound continuous bound or adaptive procedure with a declared error bound; otherwise report sampled observations, not exact difference intervals.

Recommended first product question: explicit `document_time_locked` instant checkpoints. Keyframe inventories and schedule differences may be reported separately as source/computed timing facts. Exact temporal intervals should remain deferred until continuous geometry, paint, compositing, and metric bounds exist.

## Unresolved timing, failures, and limits

Use typed outcomes rather than coercing missing time to zero:

- `resolved`: both sides reached the exact checkpoint under the declared transcript;
- `timeline_inactive`: a required timeline has unresolved current time;
- `timing_unresolved`: an event, syncbase, start time, duration, or mapping remains unresolved;
- `checkpoint_incomparable`: the two sides cannot represent the same logical coordinate;
- `event_not_reached` or `postcondition_not_reached`: a required scenario occurrence failed;
- `schedule_cycle` or `schedule_unstable`: dependency resolution does not reach the required stable schedule;
- `interval_unbounded`: a requested complete interval has no finite admitted end or proof bound;
- `execution_limit_exceeded`: deterministic timeline/evaluator work was exhausted;
- `replay_diverged`, `ambient_unreproducible`, `failed`, or `unavailable`: external observation outcomes consistent with the script and interaction boundaries.

An indefinite or infinitely repeating animation is not itself a failure for a finite resolved instant. It prevents a “settled final frame” or complete unbounded-interval claim. No quiescence rule may silently stop an animation, discard pending work, or choose the last captured frame.

Independently cap schedule nodes and dependency edges, rational-number size, event occurrences, repeats expanded before a checkpoint, style-change transactions, transitions, mapped effects, checkpoints, interval partitions, derived visual states, renderer work, transcript bytes, and output bytes. External script observations also retain the separate instruction/fuel, tasks, microtasks, timers, rAF callbacks, DOM mutations, memory, wall-time, process, and descendant limits from the accepted script boundary. A wall-time kill is a failed observation, not a timeline coordinate.

## Script and interaction boundaries

Script-driven animation must reference `svgdiff-script-observation/1`. The timeline profile supplies requested coordinates and capture phases, but it does not make script execution canonical. Exact browser/runtime, virtual-clock controller, event-loop scheduling, allowed APIs, task/microtask/timer/rAF transcript, mutations, play/pause/seek operations, and replay agreement remain observation evidence.

Interaction-triggered animation must also reference either a resolved `svgdiff-interaction-state-profile/1` checkpoint or an external `svgdiff-interaction-scenario/1`. State inputs, achieved state, event dispatch, and animation time are separate axes. A hover state at `t = 500ms` does not say when hover began unless the scenario declares that transition.

CSS transitions caused by interaction require at least the pre-change resolved style, the exact logical state-change tick, the resulting after-change style, and any later reversal tick. CSS transitions caused by script remain external even if their interpolation is otherwise declarative.

## Rejected shortcuts

- Treating animation-disabled output as the frame at `0s`.
- Comparing only final frames or waiting for “settled” output.
- Treating unresolved or inactive timeline time as zero.
- Synchronizing by wall-clock launch time, load-event arrival, frame count, or rAF callback count alone.
- Seeking only the visible clock while omitting CSS transition style history, pending play/pause tasks, events, repeats, or fill state.
- Comparing before and after at independently chosen “interesting” times without a typed phase-locked question.
- Inferring interval equality from keyframes, endpoints, uniform samples, or one browser frame rate.
- Running script in the canonical comparator because a browser sandbox is present.
- Voting several browser observations into canonical animation semantics.

## Staged implementation gates

1. **Contract only**: accept the identities, instant/interval distinction, synchronization modes, failures, and Agent interpretation rules without product fields.
2. **Static inventory**: parse and compare authored SMIL/CSS timing declarations and schedules as source-only or computed timing evidence; keep rendered animation coverage partial.
3. **Closed declarative instants**: implement a deliberately small offset-only SMIL and CSS Animation subset at explicit document-time checkpoints, with exact boundary, negative-delay, repeat, fill, discrete, and unresolved controls.
4. **Declared events and transitions**: add accepted event transcripts and style-change transactions; test missing events, target ambiguity, negative delay, interruption, reversal, and one-side failure.
5. **Interval evidence**: admit only properties and downstream effects with proven partitioning and continuous bounds; preserve sampled-only evidence elsewhere.
6. **External script observation**: only after the script-observation admission gate, pin a target and virtual-time/event-loop harness, prove byte-identical replay, and retain target-local authority.
7. **Agent and multi-renderer evaluation**: show that timeline artifacts improve report-only answers about what changes when, without weakening static equality or turning target agreement into truth.

## Recommendation

Accept an explicit, question-typed timeline profile, beginning with same-document-time instant checkpoints for closed declarative animation. Require an ordered event/style-change scenario for event-driven SMIL and CSS transitions. Keep phase-locked effect comparisons diagnostic and interval claims deferred behind stronger proof obligations. Keep all script-driven animation in separately versioned external observations tied to exact virtual-time and event-loop evidence.

This model preserves the project's central distinction: a source schedule difference, a computed state at one checkpoint, a captured pixel difference, and a complete temporal interval claim are four different statements.
