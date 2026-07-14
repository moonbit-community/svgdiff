# Report encountered renderer capability gaps

Schema `1.0` producers will emit an additive `renderer_capability_gaps` array. Each record identifies one stable renderer capability, classifies it as `guarded` or `unavailable`, and references every Diagnostic that establishes the gap for the current comparison.

The array is encountered-input metadata, not a global capability manifest. An empty array means that no known renderer-specific gap was encountered by these inputs; it does not mean that the renderer implements all SVG features. `analysis_status`, `coverage_matrix`, and Diagnostics remain the correctness authority.

The JSON Schema keeps this additive field optional so older valid schema `1.0` reports remain compatible. Current canonical and compact producers always emit it.
