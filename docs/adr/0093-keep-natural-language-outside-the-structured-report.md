# Keep natural language outside the Structured Report

Natural-language orientation is useful for quick inspection, but serialized prose inside the Structured Report would duplicate facts, create migration and localization pressure, and invite consumers to treat an incomplete narrative as authoritative evidence.

Provide deterministic Markdown only as an optional derived presentation over an existing report. The public renderer and CLI side artifact repeat report-local IDs and direct values, list every Atomic Difference and Diagnostic, and explicitly defer to canonical JSON. They do not recompute comparison or invent severity, visibility, equality, total-order, or unique-cause judgments. Structured Report Schema `1.43` and every evidence identity remain unchanged.
