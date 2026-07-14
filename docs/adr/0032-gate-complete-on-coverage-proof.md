# Gate complete reports on coverage proof obligations

Every analyzer result will pass through one engine-owned coverage proof gate before it can be returned as `complete`. The gate validates feature inventory, evidence-layer status, Diagnostic closure, Subject Alignment coverage, Atomic Difference domain coverage, and the matrix-to-status summary.

An incomplete proof does not crash or silently trust the analyzer. It emits `coverage_proof_incomplete`, limits all evidence layers, and downgrades the result. Keeping the gate behind one module interface gives every analyzer the same obligations without duplicating caller-visible policy or requiring callers to validate internal analyzer paths themselves.
