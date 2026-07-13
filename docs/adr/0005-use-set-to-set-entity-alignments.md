---
status: superseded by ADR-0017
---

# Use set-to-set entity alignments

Every Visual Entity will participate in one accepted Entity Alignment whose two sides may contain any number of entities, provided the union is non-empty. This single abstraction represents insertion, deletion, one-to-one correspondence, splitting, merging, and many-to-many reorganization; ambiguous alternatives remain candidates rather than masquerading as accepted alignments. It replaces the one-to-one Correspondence model from ADR-0003, which would turn equivalent restructuring into noisy additions and deletions.
