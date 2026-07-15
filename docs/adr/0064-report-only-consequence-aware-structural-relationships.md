# ADR 0064: Report Only Consequence-Aware Structural Relationships

Status: accepted and implemented for the admitted aligned-subject slice

## Context

An XML tree edit is not necessarily a visual-semantic difference. Reordering disjoint subjects, renaming a container ID, or moving a subject between equivalent parents can leave computed and rendered results unchanged. Conversely, moving a leaf between inherited or transformed parents, changing its `use` target, or reversing two overlapping draw operations can change the image without changing a leaf-local declaration. Reporting every parent or sibling edit would mix source auditing with visual comparison; ignoring all of them leaves real causes out of Changed Facts and can produce false complete equality for stacking changes.

## Decision

Derive one private effective-parent signature for each rendered subject from element kinds and same-kind sibling ordinals in its rendered ancestry. Exclude the leaf itself, and do not use authored IDs as cross-document identity. Keep use-instance resolution as a separate signature over direct-versus-instanced placement, definition identity, and use depth.

Emit `document.structure.ancestry` or `document.structure.resource_resolution` only when the corresponding signature changes and the aligned subject already has a supported computed difference. Add the structural relationship fact to every affected consequence difference. Equivalent inheritance rewrites, declaration-only changes, ID renames, formatting, and parent changes with no supported computed consequence remain outside visual Atomic Differences.

Detect stacking changes as pairwise source-order inversions across one-to-one Subject Alignments. Retain every inverted pair whose conservative painted bounds overlap on either side, widening unknown bounds to possible overlap. Emit the pair only when the final rendered comparison has changed pixels. The relationship fact is a conservative candidate, not an exact contribution claim: another simultaneous change may be responsible for some or all observed pixels.

Give each ancestry or resource relationship the existing subject event that owns its consequence. A stacking relationship receives one document-level relationship event whose affected subjects remain explicit in its Changed Fact. This is not cross-subject outcome aggregation: independently aligned leaf outcomes are not merged, ranked, or assigned a synthetic shared visual subject.

## Consequences

The report can now name structural causes for inherited, transformed, instanced, and stacking outcomes while pure XML restructuring remains excluded. Difference Regions and Cause Envelopes reuse the existing conservative machinery; stacking events deliberately receive the complete final pixel mask because the public report has no pair-alignment reference.

False-positive stacking candidates are allowed by the causal-completeness contract, but disjoint inversions and zero-raster inversions are proven irrelevant and pruned. Exact contribution weights, minimal causes, arbitrary unsupported rendering-tree behavior, blending, isolation, filters, masks, clipping, images, external resources, dynamic instance trees, and the unified cross-resource dependency graph remain separate work.
