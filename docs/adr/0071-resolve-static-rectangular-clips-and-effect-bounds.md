# ADR 0071: Resolve Static Rectangular Clips and Effect Bounds

Status: Accepted, implemented for the admitted static rectangle slice

Date: 2026-07-15

## Context

Treating every `clipPath` as unsupported preserved soundness but prevented the report from answering the central questions a text-only Agent needs: which host attachment changed, which shared resource fact changed, which consumers are affected, how large a numeric geometry change is, and where on the canvas clipping can matter. Raw XML comparison would also misclassify equivalent URL and number spellings, while a binary visible/invisible flag would erase small continuous changes such as `1.0` to `0.99999`.

The pinned `mizchi/svg@0.2.1` renderer already produces exact Chromium pixels for a narrow deterministic rectangle slice. It does not establish general curved clipping, nested clip resources, dynamic behavior, clipping on use hosts, or arbitrary object-bounding-box/container combinations. The report therefore needs a project-owned semantic boundary instead of inheriting the dependency's entire apparent feature surface.

## Decision

Resolve non-inherited `clip-path` through the existing author cascade, CSS-wide defaulting, bounded custom-property substitution, and local-reference grammar. Keep the winning host declaration and Source Span separate from the referenced resource. Admit `none` and one local `clipPath` whose effective content is exactly one direct non-rounded `rect`, whose units are `userSpaceOnUse` or unitless numeric `objectBoundingBox`, and whose clip and child transforms belong to the deterministic axis-transform slice. Ordinary leaves and containers are admitted; direct clip attachment to a `use` host remains guarded.

Report host attachment changes as `clipping.path`. Report resource presence, units, transforms, rectangle geometry, and simple-contour rule changes as `resource.clip.*`. Each resource Changed Fact lists every active consumer. Canonical numeric values distinguish equivalent spellings from actual changes, while geometry differences carry signed and absolute parameter deltas, symmetric-relative magnitude, and normal same-domain ordering. Resource insertion, deletion, and unused definitions follow the cross-family Resource Outcome Policy.

For every complete affected leaf, transform the rectangle into viewport CSS space and intersect it with the leaf's conservative unclipped painted bound. Preserve the before and after results separately inside analysis; an empty intersection is a proven empty effect, not unavailable evidence. Localize a clip-resource event with the union of every nonempty before/after consumer bound. The resulting rectangle is an effect-bound superset, not an exact clip mask or contributor map. If a required host bound is unavailable, retain the unclipped conservative fallback and emit `clip_path_effect_bounds_unavailable`, which revokes the causal-completeness guarantee.

Keep missing, external, invalid, wrong-kind, multi-child, rounded/curved, nested-reference, dynamic, unsupported-unit, unsupported-transform, object-bounding-box-container, use-instance, and unavailable-bound cases source-visible behind precise `clip_path_*` Diagnostics. Do not guess pixels for those cases. Keep the two polygon clip-rule fixtures guarded, and require the four admitted leaf, container, object-bounding-box, and transformed rectangle fixtures to remain exact and complete under renderer conformance profile `/22`.

## Consequences

Text-only Agents can distinguish source-only spelling changes, small continuous geometry changes, zero-contribution full/empty outcomes, active shared-resource fan-out, and salient raster changes without inspecting images. Difference Regions and Cause Envelopes are restricted to conservative clip effect locations on complete inputs, while partial cases remain complete inventories of known facts and possible causes rather than false equality claims.

The implementation deliberately does not provide an exact per-pixel contribution index, arbitrary path clipping, antialiased curved masks, percentages in object-bounding-box clip coordinates, nested clip resources, use-host clipping, animation, masking, filters, or blending. Those remain separate roadmap items or explicit guarded boundaries. The production renderer identity is unchanged because the accepted path uses the pinned renderer directly; the independently versioned conformance claim advances to `/22`, Structured Report schema advances to `1.27`, and module/CLI version advances to `0.5.7`.
