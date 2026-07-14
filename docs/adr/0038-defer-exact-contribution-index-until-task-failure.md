# Defer exact Contribution Index until a concrete Agent task fails

Exact per-pixel contribution weights, minimal root-cause sets, and an instrumented Contribution Index will not be implemented in the current deterministic static-SVG roadmap sequence. The accepted Cause Envelope remains the causal contract: complete reports preserve every actual changed cause through `sound_overapproximation`, and incomplete propagation widens candidates or revokes the guarantee.

This decision distinguishes two questions. A Cause Envelope answers which Changed Facts may have caused a Difference Region while guaranteeing recall under complete coverage. A Contribution Index would additionally assign exact or quantitative responsibility through occlusion, alpha compositing, blending, filtering, masking, group surfaces, and overlapping draws. The latter is not required to make the former sound.

The current evidence does not justify owning that complexity:

- the bidirectional mutation property retains the independently declared actual fact across thirty-six complete directional comparisons and 130 regions;
- the labeled benchmark has complete Cause Envelope recall on every eligible case;
- the seven-case baseline records five unique-per-case candidates, six region candidate occurrences, five regions, and zero labeled false-positive fraction;
- the report-only evidence adapter passes the causal interpretation thresholds, although this is not evidence that an external language model has been evaluated;
- exact contribution would require deeper renderer instrumentation and maintained propagation semantics through mechanisms that the current renderer API does not expose.

This supersedes only the exact Contribution Index requirement in ADR 0006. Render Observations remain authoritative visible-outcome evidence, and ADR 0010's conservative provenance decision remains in force.

Reopen this decision when at least one of the following is demonstrated with a minimized, versioned case:

1. a text-only Agent task fails because a sound candidate set remains ambiguous after coverage, localization, ranking, and safe region- or tile-level pruning are applied;
2. a versioned candidate-volume or false-positive threshold fails on representative complete-coverage cases;
3. a product requirement needs quantitative contribution weights rather than possible-cause containment;
4. a renderer dependency exposes stable contribution instrumentation whose ownership and conformance cost is lower than the demonstrated task value.

The deferred roadmap implementation item remains visible. It may be activated only by one of these triggers and must define weight semantics, compositing behavior, schema versioning, and independent evaluation before implementation.
