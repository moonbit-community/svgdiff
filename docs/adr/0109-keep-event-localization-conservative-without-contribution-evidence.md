# Keep Event localization conservative without contribution evidence

Every current Event-level Difference Region is conservative. Final canvas
pixels are observed globally, but assigning any subset of those pixels to one
Event requires stronger evidence than spatial overlap.

For an entity Event containing only admitted geometry, paint, or presence
differences, the engine renders the aligned before and after subjects in
isolation under the Comparison Profile. It intersects three sets: the final
canvas difference, the isolated-subject difference, and the union of the
Event's before/after geometry bounds. This produces a tighter conservative
candidate. A non-painting subject such as a shape with no active fill, stroke,
or marker has equal isolated renderings, so it receives no region and has a
measured zero rendered outcome even when its geometry bounds overlap another
change.

This intersection is not contribution evidence. A changed subject hidden
behind an opaque sibling can have the same isolated support as unrelated final
changes in front of it. Occlusion, alpha compositing, blending, filters, masks,
and cancellation require a scene-level counterfactual or renderer
instrumentation before an Event region may be called observed.

Isolation is deliberately refused when the Event mixes other semantic domains
or the subject has incomplete geometry, stroke, transform, resource, clip,
mask, filter, marker, or paint-server behavior. Per-channel fixed comparison
and raster-work limits also apply, and attempts consume budget even if
rendering fails. In those cases the engine retains the whole-canvas-mask
intersection with the Event's conservative bounds. Both isolated and
bounds-only pixel candidates serialize as `conservative`; computed-bounds
fallbacks remain conservative as well. Schema `2.0` reserves `observed` for a
future event-local method that actually establishes the required scene
relation.

Cause Envelopes are unchanged. Partial reports still widen to the full Changed
Fact universe so that localization precision cannot trade away causal recall.
Schema `2.0` serializes this as `scope = "comparison"` rather than repeating
every Atomic Difference ID in every region.
ADR 0038 remains deferred: isolated rendering is useful safe pruning and zero
evidence, but exact contribution weights still require the documented reopen
trigger and a separately evaluated implementation.

Regression coverage includes an overlapping computed-equivalent paint rewrite,
an overlapping `fill="none"` path change beside a moved shape, a stacking Event
that remains bounds-only, and browser assertions over all seven pinned Pages
examples. The Material placeholder has zero pixels and no region; the other
examples expose only conservative Event localization.
