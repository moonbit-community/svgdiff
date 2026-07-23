# Multi-Renderer and Browser Profile Semantics

Status: accepted experiment-container boundary; no multi-renderer product mode is implemented

Future container identity: `svgdiff-renderer-experiment-matrix/1`

Future cell identity: `svgdiff-renderer-experiment-cell/1`

Last verified: 2026-07-17

Svgdiff will support both same-engine profile-sensitivity experiments and same-profile cross-renderer experiments, but never as one untyped `renderer diff`. A future matrix is a container of independently identified cells and typed comparison edges. The current Structured Report remains one canonical before/after comparison under one exact Comparison Profile, renderer, and renderer-conformance identity.

The governing decision is [ADR 0101](adr/0101-model-multi-renderer-work-as-typed-experiments.md). Primary evidence is recorded in the [research note](research/multi-renderer-profiles.md), and the classification is machine-checkable under [`evaluation/multi-renderer-decision`](../evaluation/multi-renderer-decision/).

## Cell model

One `svgdiff-renderer-experiment-cell/1` represents the same before and after inputs executed once by one exact target under one declared semantic profile. It records:

- exact before/after SVG hashes and ordered resource-bundle identities;
- payload kind (`canonical_structured_report`, `external_render_observation`, or `unavailable`) and payload hash/reference;
- target role, modules/svgdiff/engine/browser source or binary identity, renderer adapters, OS/build, architecture, graphics/font/color backends, process flags, sandbox, and capture-tool identity;
- a renderer-neutral semantic-profile key covering viewport, DPR, color, background, fonts, resources, static/dynamic state, and every other declared input that the target claims to implement;
- the cell's native Comparison Profile, renderer, conformance, font, color, and platform-observation identities where applicable;
- output coordinate mapping, dimensions, pixel format, alpha, color space, normalization method, and hashes for before, after, and derived output evidence; and
- execution status, coverage/unsupported features, repeatability, Diagnostics or target errors, unavailable inputs, and unresolved ambient state.

The renderer-neutral key is an experiment compatibility declaration, not a replacement for each cell's native identity. Two targets may share it only when every field needed by the compared evidence is exactly equal or explicitly normalized by a versioned lossless method.

## Supported experiment types

| Question | Required constant axis | Varied axis | Typed result |
| --- | --- | --- | --- |
| Does one target react differently to two declared profiles? | Target identity, sources/resources, capture/normalization | Semantic profile | `profile_sensitivity` |
| Do two engines agree under one declared profile? | Semantic profile, sources/resources, comparable environment and output normalization | Target engine | `renderer_conformance` when the environment is equivalent; otherwise `renderer_target_observation` |
| How do several targets and profiles behave together? | Common source/resource set and compatible cell contract | Target and profile across separate edges | `typed_matrix`; retain every horizontal and vertical edge |
| What caused a diagonal difference where target and profile both changed? | Nothing sufficient | Target plus profile | `confounded_diagonal`; no direct attribution |
| Does profile sensitivity itself vary by target? | Four compatible rectangle cells | Interaction of target and profile effects | `target_profile_interaction`; evidence of interaction, not a unique cause |

“Both” therefore means one container can carry both edge families. It does not mean their claims are interchangeable.

## Edge rules

Every edge names its two cells, constant fields, changed fields, compatibility checks, comparison method, evidence domain, and result. It retains separate relations for the before outputs, after outputs, and before-to-after difference outcome so that a shared renderer bias is not mistaken for a changed SVG effect.

Report-local IDs are not cross-cell identities. A future edge must correlate facts, subjects, events, regions, or output observations through an explicit versioned mapping artifact based on stable source/resource locators, signatures, or another reviewed matching method. If the mapping is ambiguous, partial, or unavailable, the affected synthesis is `insufficient_evidence`; array position and coincident report IDs are never correspondence evidence. An external observation cell can map only the output evidence it actually contains.

- A `profile_sensitivity` edge may say that one target's observed outcome changes or remains stable across profiles. It cannot establish canonical equality between profiles or say which changed profile field is causal when several changed together.
- A `renderer_conformance` edge requires the same renderer-neutral semantic profile and equivalent non-engine environment. Pixel agreement proves only agreement for the exact fixtures and capture method; disagreement identifies a renderer divergence, not which renderer is correct.
- If OS, backend, font/color environment, capture path, or another material target input also differs, classify the edge `renderer_target_observation` and list the confounders. Do not call it engine-only conformance.
- An edge that changes both target and semantic profile is `confounded_diagonal`. It becomes interpretable only through compatible same-axis edges. Two alternative paths through a complete rectangle must remain visible even when they reach the same endpoint.
- Missing, failed, partial, ambient, or normalization-incompatible cells produce `insufficient_evidence` for claims that require them. Absence is never agreement.

External browser/platform cells expose rendered observation layers only. They cannot fabricate Source Semantics, Computed Appearance, Visual Events, Cause Envelopes, or complete-analysis coverage that the target did not produce.

## Agent-facing synthesis

A future text-only projection may classify a mapped outcome as:

- `invariant_across_required_cells`: every required compatible cell supports the outcome and every required edge agrees;
- `profile_sensitive`: at least one valid same-target profile edge disagrees;
- `renderer_sensitive`: at least one valid same-profile conformance edge disagrees;
- `renderer_target_sensitive`: disagreement is inseparable from declared target-environment differences;
- `target_profile_interaction`: a complete compatible rectangle shows different profile responses by target;
- `confounded`: only a diagonal or multi-axis comparison supports the observation; or
- `insufficient_evidence`: a required cell/edge is missing, partial, failed, ambient, or incomparable.

Every synthesis record must link all required cells and edges, the supporting agreements, the disagreeing evidence, and excluded/incomparable cells. `invariant` is universal over the declared required set, never a majority. The container preserves every cell result and does not replace each cell's full evidence.

There is no averaging, voting, “two browsers agree,” tolerance-based truth selection, or default preferred engine. A user-selected target priority may filter presentation, but it cannot rewrite evidence or canonical status.

## Authority boundaries

The project engine's one Structured Report remains the only canonical complete-analysis artifact for its exact profile. Renderer conformance remains a reviewed fixture/disposition process and does not become report equality. Browser, platform font, platform color, and future native renderer outputs remain external observations under their own identities.

The accepted font and color observation contracts constrain cell admission. An ambient font or display result stays `ambient_unreproducible`; putting it in a matrix does not improve its authority. Cross-browser and platform-specific implementation remains deferred until every target closes resources, environment, capture, and limits.

## Reconsideration

The container may be implemented only when a concrete Agent task requires cross-target stability evidence, at least two useful compatible cells exist, event/output mapping and normalization have versioned negative controls, and the result vocabulary can be scored without hiding missing or disagreeing evidence. Until then, run the decision gate with:

```sh
sh scripts/test-multi-renderer-decision.sh
```
