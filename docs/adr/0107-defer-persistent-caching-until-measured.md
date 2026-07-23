# Defer persistent caching until a measured workload justifies an exact-result contract

## Context

The deterministic static comparison profile and its compatibility domains are versioned, and the pipeline repeats some parsing and extraction. However, current performance gates contain no repeated-request workload or edit-locality evidence. Private intermediate values are not stable artifacts, while alignment, events, regions, and causal provenance depend on both sides and can change globally after a local edit.

## Decision

Keep the product cache-free. Continue to permit measured within-call memoization that preserves exact output. Do not add persistent per-input, per-stage, graph-incremental, or remote caching now.

Reserve `svgdiff-exact-result-cache-key/1` as the first future product candidate. It may be implemented only as an optional caller-owned local cache after a representative workload proves value. Its key must cover exact ordered before/after source and resource inputs, the complete Comparison Profile, semantic modules/svgdiff/engine/build and dependency identities, every report and policy identity, effective deterministic limits, and target identity where cross-target equality is unproven. Stored report bytes are untrusted derived data and must pass envelope, digest, compatibility, and size validation; every miss or error falls back to full recomputation.

Do not expose or persist private intermediate values until each reusable unit has a versioned schema and a complete dependency/invalidation proof. Do not implement shared or remote reuse until local value is established and a separate authenticated multi-tenant trust design is accepted.

## Consequences

Current APIs, CLI behavior, Structured Report, identities, dependencies, and performance gates do not change. Some repeated work remains, but full recomputation stays the correctness oracle and cache deletion is always safe.

Future work has a narrow first path and explicit measurement, key-completeness, corruption, security, cancellation, upgrade, and equivalence gates. Adding a cache cannot make a partial report complete, replace visual-semantic evidence, or conceal an unsupported feature.
