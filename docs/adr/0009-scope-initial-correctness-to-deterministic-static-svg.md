# Scope initial correctness to deterministic static SVG

The initial comparison contract covers Deterministic Static SVG evaluated with declared rendering conditions and pinned resources. Scripts, event-driven state, animation timelines, implicit network resources, and unspecified platform state are outside that correctness claim; encountering them must reduce Analysis Coverage through Diagnostics rather than silently treating their effects as absent or equal.
