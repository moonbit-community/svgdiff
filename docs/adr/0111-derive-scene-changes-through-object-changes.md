# Derive Scene Changes through Object Changes

Status: accepted and implemented

The banking cross-generator comparison showed that a flat scene projection
cannot distinguish one cause from its many subject effects. Four root viewport
Changed Facts produced 128 Atomic Differences across 32 primitive subjects and
nine Visual Objects. Counting those effects as independent scene facts made a
document-level change look like dozens of unrelated changes.

The report therefore uses a typed causal DAG:

```text
Changed Fact -> Atomic Difference -> Visual Object Change -> Visual Scene Change
```

A Visual Object Change owns one accepted Visual Object Alignment. It references
every supporting Atomic Difference and primitive Event, plus the unique Changed
Facts that caused those effects. It never copies evidence payloads. Direct
entity evidence must have one proven object owner. If direct ownership is absent,
a shared container or resource cause may fan out only through the explicit
`ChangedFact.affected_subject_ids` provenance. Ambiguous ownership remains
unresolved.

A Visual Scene Change is constructed exclusively from Visual Object Change IDs.
It cannot inspect or reference Atomic Differences or primitive Events directly.
Object Changes of the same semantic kind belong to one Scene Change only when
they form a connected component through shared Changed Fact IDs. Thus one
viewport fact may produce one systemic change spanning many objects, while
independent local layout facts remain separate Scene Changes even when their
kind is identical. Empty-cause Object Changes remain separate rather than being
merged by resemblance alone.
Its counts remain dimensionally distinct:

- cause count is the number of unique Changed Fact IDs;
- effect count is the number of unique Atomic Difference IDs reachable through
  the referenced Object Changes;
- affected-subject count is the number of unique primitive Event subjects;
- object count is the number of referenced Object Changes.

Object presence, relation, and layout changes require object-layer comparison
evidence. Primitive presence or structural differences cannot create those
higher-level conclusions by domain name alone. Content, effective style, and
representation evidence may create an Object Change only when it has proven
object ownership; this admits inherited and shared-container fan-out without
turning object-internal implementation changes into object-set or relation
changes.

Coverage is explicit at both transitions:

```text
assigned_difference_count + unresolved_difference_count
  == effective_difference_count

assigned_object_change_count + residual_object_change_count
  == object_change_count
```

Here effective means every non-`equivalent` Atomic Difference. Indeterminate,
ownerless, ambiguous, and unsupported-domain evidence remains unresolved. The
system accepts conservative unresolved evidence; it does not invent an owner or
silently discard it.

This design guarantees the expected improvement because aggregation identities
are references, not value-based guesses: a Changed Fact is counted once by its
stable ID regardless of fan-out; one Object Change exists per semantic kind and
object alignment; and a Scene Change can only group a cause-connected component
of those Object Changes. It
does not guarantee that object extraction matches every human interpretation.
Errors in object extraction remain visible through alignment and transition
coverage rather than being hidden by scene-level deduplication.
