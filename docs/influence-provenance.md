# Influence Provenance and Causal Completeness

Status: accepted design; v1 implementation validated

Last verified: 2026-07-14

This is the current causal-completeness contract for the supported v1 slice. Feature coverage remains defined by [`v1-scope.md`](v1-scope.md); historical prototype evidence is archived in [`research/influence-provenance-prototype.md`](research/influence-provenance-prototype.md).

## Objective

For every rendered Difference Region, report a Cause Envelope that is guaranteed to contain every actual changed cause within the supported Deterministic Static SVG scope. False-positive candidates are acceptable. Exact contribution weights, unique causes, and minimal causal subsets are not required.

[ADR 0038](adr/0038-defer-exact-contribution-index-until-task-failure.md) records why exact Contribution Index work is deferred and the concrete Agent-task, precision, product, or dependency evidence required to reopen it.

## Fact universe

Let `Delta` be the complete set of Changed Facts between the two comparison artifacts. A Changed Fact may describe:

- an element's presence, authored value, text, or structural relationship;
- a CSS rule, inherited value, reference, or paint resource;
- a referenced image, font, symbol, gradient, pattern, clip, mask, or filter input;
- document semantics such as `viewBox` or paint order;
- a declared environmental input when the two artifacts intentionally use different inputs.

Formatting Variations are excluded because normalization has already established that they cannot affect semantics. Undeclared environmental state is not a Changed Fact; it is a coverage failure.

## May-influence graph

The evaluator records a directed graph whose edges mean `may influence`, never `did contribute by a particular weight`:

```text
Changed Fact
    -> Computed Property
    -> Visual Subject or Render Operation
    -> Group Layer or Effect Operation
    -> Output Tile or Region
```

For every graph value `x`, `MayInfluence(x)` is a conservative set of Changed Fact tokens. The governing obligation is:

```text
if a Changed Fact can affect x under supported semantics,
then its token is in MayInfluence(x)
```

The reverse implication is not required.

## Cause Envelope

For a rendered Difference Region `R`, the Cause Envelope is:

```text
CauseEnvelope(R) = Delta intersect union(
  MayInfluence(before tiles overlapping R),
  MayInfluence(after tiles overlapping R)
)
```

Both inputs are required. A moved or deleted entity may influence only the vacated region in the before rendering, while an inserted or moved entity may influence only the occupied region in the after rendering.

If no safe influence information is available, the required fallback is:

```text
CauseEnvelope(R) = Delta
```

This fallback is maximally imprecise but causally complete.

## Conservative propagation rules

| Operation | Required token propagation |
|---|---|
| Computed property resolution | Union tokens from the authored value, inheritance chain, matching CSS rules, references, and relevant document semantics |
| Geometry and transform | Propagate geometry, transform, viewport, and ancestor transform tokens to every conservatively covered tile |
| Fill and stroke | Propagate geometry, paint, opacity, paint-server, and paint-order tokens to every conservatively painted tile |
| Group opacity and isolation | Union all child tokens with the group operation token across the entire group layer |
| Source-over compositing | Union source tokens, backdrop tokens, opacity tokens, and compositing-order tokens in every possibly affected output tile |
| Blend modes | Union foreground, backdrop, blend-mode, isolation, and ordering tokens across the conservative blend region |
| Clip paths and masks | Union content tokens with clip or mask geometry, paint, transform, and reference tokens across the enclosing effect region |
| Local filters | Dilate the input token region by a conservative kernel or effect bound and add all filter-parameter tokens |
| Global or unknown filters | Propagate all input and filter tokens to the entire filter layer, or the entire canvas if no smaller bound is proven safe |
| Reordering or structural change | Propagate the structural token across every region where the affected draw-order interval may overlap |
| Insertion or deletion | Attach the presence token to the existing side's conservative render region and include both inputs when building the envelope |
| Unknown supported-path operation | Widen to the enclosing subtree, layer, or complete `Delta`; never drop tokens |
| Unsupported operation | Revoke Causal Completeness, emit a Diagnostic, and reduce Analysis Coverage |

An implementation may use tile-level bitsets, region sets, or another representation. The representation is valid only if every transfer rule remains a conservative superset.

## Soundness argument

The guarantee follows by structural induction over the evaluated render graph:

1. Each leaf render operation begins with every Changed Fact token read by its geometry, paint, resource, transform, and structural inputs.
2. Each intermediate operation produces a token set that is a superset of the tokens for every input or parameter that can affect its result.
3. Therefore every output tile's token set is a superset of all Changed Facts that can affect that tile.
4. A Difference Region is composed of output tiles from both renderings, so the union of their token sets contains every Changed Fact that can cause the region.
5. Intersecting with `Delta` removes unchanged context without removing a changed cause.

Any transfer rule that cannot satisfy step 2 must widen its result or revoke the guarantee. Spatial overlap without a proven conservative influence bound is not a sound pruning rule.

## Guarantee boundary

Causal Completeness is conditional, not a proof that the renderer implementation has no bugs. It may be declared only when:

- the comparison artifacts and resource bundles are closed and deterministic;
- Changed Fact enumeration is complete;
- every executed semantic and render operation has a conservative transfer rule;
- all spatial effect bounds are conservative supersets;
- tokens from both before and after renderings are included;
- no unsupported feature can affect the region;
- pruning uses only established independence rules.

If any condition fails, the report uses `not_established` rather than claiming completeness. The current implementation also widens every available partial-report region to the complete Changed Fact universe, sets `fallback_scope` to `comparison`, and retains the establishing Diagnostics.

## Structured Report shape

```json
{
  "cause_envelope": {
    "guarantee": "sound_overapproximation",
    "coverage": "complete",
    "fallback_scope": "event_region",
    "candidate_changed_fact_ids": ["fact:12", "fact:19"],
    "diagnostic_ids": []
  }
}
```

A partial result uses:

```json
{
  "cause_envelope": {
    "guarantee": "not_established",
    "coverage": "partial",
    "fallback_scope": "comparison",
    "candidate_changed_fact_ids": ["fact:12", "fact:19"],
    "diagnostic_ids": ["diagnostic:unsupported-operation"]
  }
}
```

Candidate ranking may reorder or annotate the Cause Envelope but cannot remove candidates from a causally complete envelope.

## Validation obligations

The original prototype gate required the following demonstrations, all of which informed the implemented conservative engine:

1. token propagation through direct paint, grouped operations, local filter expansion, compositing dependencies, and unknown-operation fallback;
2. union of before and after provenance for insertion, deletion, and movement;
3. `actual causes` is a subset of the resulting Cause Envelope in every scenario;
4. unsupported operations revoke the guarantee rather than returning an incomplete envelope as complete;
5. conservative rules remove at least some irrelevant Changed Facts compared with the `Delta` fallback.

Ongoing production validation should add mutation/property tests as supported semantics and render operations expand. The safe default for a missing rule remains a larger Cause Envelope.

The text-only benchmark measures conservative imprecision separately from recall. Every case records unique candidate count, candidate occurrences across all regions, region count, and candidates per region. Cases with eligible actual-cause labels additionally record false-positive count and fraction. Partial comparison-wide fallbacks still contribute to raw volume because they affect Agent context size, but they do not receive a precision score when unsupported semantics make an actual-cause reference unsound.

The deterministic mutation suite adds a complementary containment property across all six supported basic subject kinds and forty-three authored properties. Each of the fifty-eight generated pairs changes exactly one independently declared fact and is evaluated in both comparison directions. Every one of the forty regions in thirty-eight complete directional comparisons must contain the direction-correct fact under `sound_overapproximation`; computed-equivalent color syntax and inactive clip-rule changes produce no changed region, and guarded active-stroke, curved/point geometry, fractional-opacity, gradient-raster, pattern-raster, active paint-order, and active winding-rule cases must not claim that guarantee. The complete inherited-rectangle, CSS-wide fill, CSS Color 3 spelling, `currentColor`, custom-property, missing-server fallback, and inactive clip-rule mutations prove ancestor ownership, computed dependency, selected-branch causality, and leaf consequence containment, while the gradient and pattern unit, transform, stop, and child cases prove resource ownership plus affected-consumer fan-out behind only their renderer guards. This exercises occupied and vacated outcomes plus paint alpha, gradients, stroke, transform, viewport, cascade, inheritance, computed CSS changes, paint order, and winding rules without pretending that future exact transformed outlines, clip-path evaluation, filters, masks, or compositing provenance are already implemented. A negative control removes the fact from one envelope and must fail.

Current production pruning is event-region level. A complete envelope with `fallback_scope: event_region` contains exactly the Changed Facts referenced by its Visual Event's Atomic Differences; a complete `comparison` fallback contains the full fact universe. The disjoint two-event adversarial case proves that each region removes the other event's fact, and a cross-event contamination negative control is rejected. This is coarser than future tile-level provenance: facts that share one event remain conservative candidates even when a finer propagation model might separate them.

The same disjoint fixture independently fixes the two subject bounds at `(1, 4, 5, 5)` and `(10, 4, 5, 5)` CSS pixels. Each Visual Event resolves through its Subject Alignment to one authored subject, contains one 25-pixel region and a 25-pixel rendered outcome, and never receives the 50-pixel scene total. This is the current supported-slice protection against scene-wide pixel contamination; future transformed and composited subject localization remains separate roadmap work.
