---
status: superseded by ADR-0005
---

# Base diff identity on visual correspondence

Diff identity will be established by Correspondence between Visual Entities rather than identity between Source Elements. SVG element types, identifiers, hierarchy, and source locations remain provenance and matching evidence, but treating them as authoritative would misclassify visually equivalent rewrites, such as a circle replaced by an equivalent path, as unrelated deletion and insertion.
