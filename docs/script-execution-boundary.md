# SVG Script Execution Boundary

Status: accepted canonical non-goal; external observation not implemented

Future observation identity: `svgdiff-script-observation/1`

Last verified: 2026-07-17

Svgdiff will not execute SVG scripts while producing a canonical Structured Report. The deterministic static profile permanently uses secure static processing semantics: scripting, event dispatch, animation, interaction, and implicit external acquisition are disabled. Encountered script content continues to reduce coverage instead of being interpreted as inactive or equal.

The project may later capture explicitly requested script-enabled browser or runtime output as an external `svgdiff-script-observation/1`. Such a capture is evidence about one named target and scenario, not a second canonical engine, a complete report, or proof that the script is reproducible. The governing decision is [ADR 0102](adr/0102-keep-svg-script-execution-outside-canonical-analysis.md), with primary evidence in the [research note](research/script-runtime-boundary.md) and a machine-checkable boundary under [`evaluation/script-runtime-decision`](../evaluation/script-runtime-decision/).

## Why a sandbox is insufficient

A sandbox limits which capabilities untrusted code may reach. It does not by itself fix the order of event-loop tasks, clocks, random and cryptographic entropy, timers, animation frames, network/service-worker state, storage, locale, timezone, platform APIs, browser implementation, or the point at which output is considered settled. CSP and an iframe sandbox similarly constrain authority without defining one deterministic SVG result.

Executing arbitrary browser script would therefore add both a security boundary and a new semantic engine. The project would have to own DOM/SVG APIs, processing order, scheduling, state closure, quiescence, resource acquisition, termination, and causal provenance before it could make the same completeness guarantee as the static analyzer. Merely pinning a browser build does not close those inputs.

## Current canonical behavior

- The current Comparison Profile never executes inline scripts, event-handler attributes, script-created references, timers, or dynamic DOM mutations.
- `<script>` and other unsupported dynamic constructs retain source locations through Diagnostics and prevent a false `complete` equality conclusion.
- Script text is executable source, not a supported Declared Visual Fact. The current report does not infer mutations, computed values, pixels, locations, magnitudes, Impact, or causes from it.
- A browser preview or oracle capture cannot upgrade the report. Current hostile-source HTML previews keep an empty iframe sandbox and a no-network content policy.
- The comparison, renderer, Schema, Diagnostic, and conformance identities remain unchanged by this decision.

Two identical scripted inputs may still be `partial`: disabling execution is a coverage limit, not evidence that their realized visual states agree.

## External observation contract

A future `svgdiff-script-observation/1` may be admitted only as a separate artifact. Every observation must identify or explicitly mark unavailable:

1. exact before/after SVG and script bytes, MIME/language declarations, integrity hashes, and ordered resource bundles;
2. browser or runtime source/binary/build identity, DOM/SVG implementation, process flags, OS/architecture, graphics/font/color backends, sandbox mechanism, and capture tool;
3. the declared processing mode, initial DOM state, scenario/event transcript, virtual or ambient clock, random/entropy policy, locale/timezone, viewport, DPR, media preferences, storage, permissions, and network/service-worker policy;
4. script discovery and execution order, task and microtask policy, timer/animation-frame policy, quiescence rule, and capture checkpoint;
5. allowed, denied, and unavailable host APIs plus every external read or attempted capability access;
6. hard process isolation and limits for source, resources, runtime memory, stack, instructions/fuel, tasks, microtasks, timers, DOM nodes/mutations, logs, output pixels, wall time, and process descendants;
7. script parse/runtime exceptions, rejected capabilities, timeouts, kills, crashes, incomplete jobs, coverage gaps, and unresolved ambient inputs; and
8. mutation/transcript hashes, final DOM or artifact hashes, rendered outputs, repeat count, byte agreement, logs, and replay evidence.

The valid observation classes are `closed_replayable_observation`, `ambient_unreproducible`, `failed`, and `unavailable`. “Closed” requires repeated byte-identical artifacts under the exact recorded target and scenario; it does not make the result canonical or cross-target deterministic. A missing or failed side cannot be treated as zero or equality.

## Evidence and Agent limits

An external observation may report exact executed artifacts, target-local DOM snapshots, mutation logs, and raster differences that it actually captured. It may not fabricate the current report's Source Semantics, Computed Appearance, Visual Events, Atomic Differences, Difference Magnitudes, Difference Regions, Impact Assessment, or Cause Envelopes.

A text-only Agent must keep these statements distinct:

- the source contains or changes executable script;
- one named runtime executed or rejected it;
- one named scenario produced a recorded DOM or raster result; and
- the canonical static report is partial because script effects were not analyzed.

Agreement across repeated observations is scoped to the recorded target and scenario. Cross-target observations follow the [multi-renderer experiment boundary](multi-renderer-profiles.md); they never vote a script result into semantic truth.

## Relationship to later dynamic decisions

The accepted [Interaction State boundary](interaction-state-profiles.md) now owns event-driven pseudo-class checkpoints and target-local action scenarios; animation timelines remain a separate open decision. This script decision does not choose state, event sequences, sampled times, or a settled-state rule indirectly. A script observation must reference the applicable accepted interaction/timeline contracts or remain explicitly target-local and observational.

General browser script execution, implicit comparison-time network access, ambient storage, service workers, user input, physical devices, and host credentials are permanent product non-goals. A future external harness must acquire all inputs explicitly before execution and run outside the comparison process.

## Reconsideration gate

Canonical script execution may be reconsidered only when a concrete Agent task cannot be served by static evidence plus external observations and an accepted proposal supplies all of the following:

- a separately versioned execution profile with a closed language, DOM/SVG API, event, timeline, resource, scheduler, quiescence, and state model;
- a process-isolated runtime with deterministic instruction-based limits in addition to hard host limits;
- complete script-to-mutation-to-computed-to-rendered provenance sufficient for sound Cause Envelopes;
- negative controls for clocks, randomness, entropy, timers, tasks, workers, storage, locale, network, service workers, unsupported APIs, infinite loops, crashes, and replay divergence;
- cross-host byte-identical execution and report evidence for adversarial as well as ordinary fixtures; and
- a versioned Agent evaluation showing that the new evidence improves scripted-SVG comparison without weakening static equality.

Until every gate is satisfied, run the decision check with:

```sh
sh scripts/test-script-runtime-decision.sh
```
