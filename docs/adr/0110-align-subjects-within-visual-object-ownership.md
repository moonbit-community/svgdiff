# Align rendered subjects within Visual Object ownership

Status: accepted and implemented

The banking cross-generator report demonstrated the failure required by ADR
0041: hundreds of locally plausible primitive pairings obscured nine stable
user-perceived objects and produced an unusable agent-facing inventory. A
globally minimal primitive assignment was deterministic but did not establish
cross-document identity.

The engine now extracts each side's Visual Object Graph before rendered-subject
alignment. Accepted entity Object Alignments constrain their owned rendered
subjects to the same object correspondence. A graphic object applies the same
constraint only for exact authored identity; anonymous graphics retain the
existing exact-equivalence and split/merge rules. This boundary prevents one
object's parts from being paired with another object's parts without making SVG
grouping universally authoritative.

Object alignment uses exact authored identity, exact complete object signature,
semantic-text evidence, and bounded compatible geometry in descending strength.
If remaining objects on both sides have no acceptable unambiguous candidate,
the report emits one `unresolved` alignment. Affected scene axes become
`indeterminate`; the engine does not manufacture insertions, deletions, or
pairwise identity. At the rendered-subject layer, a selected minimum-cost edge
is rejected when an equally good local competitor shares either endpoint, even
if deterministic optimization can choose one global assignment.

Visual Change Events are a non-owning derived view over the authoritative
Atomic Difference and primitive Event inventories. Events spanning multiple
Object Alignments use `scope: systemic`; single-object and comparison-wide
events use `object` and `comparison`. They retain one representative Atomic
Difference per domain, domain cardinalities, and every supporting primitive
Event ID. Atomic Differences still have exactly one primitive Event owner, so
ADR 0040 remains in force.

Scene evidence compression is lossless by construction. The unique union of
non-equivalent Atomic Differences supporting emitted scene events is counted as
classified evidence. Every other non-equivalent Atomic Difference, including
an indeterminate relation, is counted as a residual and summarized by domain.
The required invariant is:

```text
classified_difference_count + residual_difference_count
  == effective_difference_count
```

This decision improves reports only when the proposed object ownership and
pattern memberships survive these checks. It does not prove that object
extraction matches every human grouping, calibrate identity confidence, infer
semantic importance, or replace the complete primitive evidence inventory.
