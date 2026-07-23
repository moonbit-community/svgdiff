# Incremental and Cache Investigation

Status: accepted investigation; no persistent cache implemented

Investigation artifact: `svgdiff-cache-investigation/1`

Reserved future key identity: `svgdiff-exact-result-cache-key/1`

Last verified: 2026-07-17

## Outcome

Svgdiff will keep the current comparison API cache-free. Existing within-call memoization remains an implementation detail and may expand only around measured duplicate work with exact-output regression tests. No persistent exact-result, per-input, per-stage, graph-incremental, or remote cache is justified by current workload evidence.

If a concrete embedding workload later demonstrates repeated identical comparisons, the first candidate is an optional caller-owned local exact-result cache. It must cache only the complete canonical Structured Report bytes for one exact comparison request and must use a separately versioned key and artifact envelope. A cache hit is an optimization of a comparison that could be recomputed; it is never evidence authority, a completeness upgrade, or permission to skip compatibility and resource checks.

Parsed-tree, semantic-inventory, render, alignment, region, event, and Cause Envelope caches remain deferred. Their private values have no stable artifact schema, and several depend on both inputs or on downstream coverage and policy decisions. Graph-incremental recomputation remains deferred until the engine has an explicit dependency DAG with complete invalidation and an evaluation corpus containing local edits. Shared or remote caches remain rejected until a local design proves useful and adds a separate authenticated trust model.

## Current pipeline evidence

The public comparison seam receives two exact `String` values, one `ComparisonProfile`, optional separate `ResourceBundle` values, fixed `ResourceLimits`, and optional cooperative control. Admission validates the profile raster dimensions, resource-bundle configuration, source size and structure, then calls the comparison pipeline. The pipeline performs preflight parsing, subject extraction and alignment, renderer-input normalization, pinned SVG parsing and rendering, Difference Region extraction, magnitude calculation, provenance attachment, coverage proof, Impact Assessment, and output-size enforcement.

The current implementation reparses or re-extracts some source data across analyzer seams. That is an optimization opportunity, not proof that a persistent intermediate is safe. Private analyzer inputs often encode only the assumptions of one feature slice, and a new feature or coverage proof can change the final report without changing the renderer profile.

The only production cache is `IsolatedPaintMeasurementCache` in `modules/svgdiff/engine/internal/measurement/difference_magnitudes.mbt`. It lives for one report assembly, keys by a current alignment ID, caps comparisons and raster work, and shares one isolated render pair across multiple magnitude channels. It never crosses requests, versions, profiles, or processes. ISS-083 also removed a measured per-event full-canvas scan, while rejecting an unproductive alignment-distance cache after measurement. These precedents support measured local reuse, not speculative persistent state.

The performance suite separately measures parse/admission, alignment, rendering, region extraction, provenance, and serialization. Its representative end-to-end budgets are generous release regression ceilings; they report no repeated-request hit rate, edit locality, storage budget, or latency target that a persistent cache would solve. A future proposal must add those workload facts before implementation.

## Candidate shapes

| Shape | Reusable unit | Current disposition | Main correctness boundary |
| --- | --- | --- | --- |
| Within-call memoization | One private computation in one comparison | Accepted when measured | Key must cover every local input; output must be byte-identical with and without reuse |
| Exact-result cache | Canonical report bytes for one exact request | First future candidate, not implemented | Complete request, implementation, policy, limits, artifact integrity, and output compatibility |
| Per-input parsed or semantic artifact | One side's parsed tree or semantic inventory | Deferred | Stable intermediate schema, parser/adapter identity, Source Spans, resource closure, and feature invalidation |
| Render artifact | One side or isolated subject raster | Deferred | Exact renderer/profile/resource/subject closure and retained coverage; pixels cannot replace semantics |
| Pair-stage artifact | Alignment, regions, events, or provenance for both sides | Deferred | Pair-global dependencies and full downstream invalidation |
| Graph-incremental recomputation | Affected nodes after one edit | Deferred | Complete dependency DAG, stable node identities, deletion/split/merge handling, and equivalence against full recomputation |
| Shared or remote cache | Any artifact across trust boundaries | Rejected until local value is proven | Authentication, namespace isolation, poisoning resistance, confidentiality, quotas, and safe fallback |

## Exact-result key contract

`svgdiff-exact-result-cache-key/1` is reserved but not implemented. It must domain-separate a canonical manifest containing all of these groups:

1. **Key and artifact protocols**: key version, hash and canonical-encoding versions, exact-result artifact version, and canonical Structured Report encoding identity.
2. **Both source inputs**: side role, exact UTF-8 byte length, and lowercase SHA-256 of the exact bytes. XML equivalence, normalized renderer input, or source formatting equivalence cannot replace exact identity because Source Spans and authored facts are report evidence.
3. **Both current resource bundles**: ordered entry count and, for every index, exact locator and media-type UTF-8 bytes plus exact resource length and SHA-256. Raw invalid configurations remain distinguishable because their entry index and Diagnostic subject can affect output. Future Resource Snapshot Bundles contribute their complete rendering-relevant and manifest identities under their own versioned contract.
4. **Complete Comparison Profile**: every field, including viewport, DPR, color and raster identities, renderer and conformance identities, optional Perceptual Background, FLIP Viewing Conditions, and threshold. Floating-point inputs require a versioned canonical finite binary representation rather than host-formatted decimal text.
5. **Semantic implementation identity**: module/engine build identity plus the XML parser, semantic adapter, renderer normalizers/compositors and dependency builds. Structured Report Schema and renderer conformance alone do not version all source, computed, alignment, region, causal, and status behavior.
6. **Every independent policy identity**: Structured Report Schema, Diagnostics contract, same-domain ordering, Impact Assessment, coverage proof, alignment, region, magnitude, provenance, resource interpretation, and every adopted font, color, timeline, interaction, foreign-content, or other execution profile that can change output.
7. **Limits and control mode**: every effective deterministic resource limit. Cancelled or time-budget-interrupted calls produce no cache artifact. An implementation may choose not to store failed or partial reports initially; it must never alias different limits because a limit can change status and Diagnostics.
8. **Target identity where required**: target, architecture, toolchain, or build fingerprint whenever cross-target byte equality has not been established for every retained numeric and serialized value.

The cache key is lowercase SHA-256 over a canonical manifest after domain separation. Hash equality alone does not authorize use: the stored envelope must repeat its key, length and content digest; the reader must validate its format, compatibility and report-byte limit before parsing. Implementations with stronger collision requirements may retain or verify the canonical key manifest. A cache miss, corrupt entry, unknown identity, validation error, or policy mismatch falls back to ordinary recomputation and may evict the entry; it never returns a partial invented result.

Before/after order remains part of the key. Swapping the pair can change signed magnitudes, insertion/deletion roles, Source Spans, IDs, ordering witnesses, and report bytes even when some symmetric measurements are unchanged.

## Why intermediate reuse is not ready

Source parsing and semantic extraction could eventually be side-local, but current analyzer records are private and feature-specific. They do not form one closed, versioned semantic snapshot, and they can preserve different normalized forms and Source Span needs. Reusing one without its exact parser, adapter, resource, profile, limit, and feature identities risks omitting a newly supported fact while still returning `complete`.

Alignment is pair-global. Inserting one repeated subject can change an equivalence class, a deterministic tie, or every downstream report-local alignment ID. Split, merge, insertion, deletion, and resource/entity role changes can invalidate more than the syntactically edited node. Regions depend on the two rendered canvases; events depend on alignments and Atomic Differences; Cause Envelopes depend on the complete changed-fact and influence graph on both sides. None can be reused through a local edit without a sound dependency proof.

Partial and failed reports are valid deterministic outputs but are poor first cache targets: a different limit, newly supported feature, fixed dependency, or resource snapshot can change their Diagnostics and status. The future exact-result envelope may admit them only when its full identity and caller use case justify the added validation surface.

## Security and lifecycle

A cache directory is derived-data storage, not part of SVG authority. Writers use immutable content-addressed entries and atomic publication. Readers do not follow SVG-authored paths, symlinks, archives, network locators, or cache-provided external references. Implementations cap key-manifest, entry, total storage, parse, and eviction work; reject traversal and type confusion; and avoid storing secrets, caller file paths, credentials, or unsanitized acquisition transcripts.

Local cache namespaces must be scoped by user and product identity. Remote reuse adds authentication, authorization, tenant separation, transport integrity, poisoning defenses, quotas, retention, and confidentiality; it cannot be inferred from local content addressing. Cache deletion is always safe. Unknown versions are misses. Upgrades may garbage-collect unreachable namespaces but must not reinterpret old bytes under a new identity.

Reports returned from a future cache retain their original complete evidence and exact profile. Agent consumers need no cache field because cache provenance does not change visual semantics. Operational telemetry may record hit/miss, lookup time, bytes, and eviction outside the Structured Report; it must not change ordering, Impact, completeness, or equality.

## Reconsideration gates

Open an implementation issue only when all of the following are recorded:

- a representative embedding workload with repeated-pair or edit-locality distributions;
- a latency, CPU, memory, or energy target not met by measured local optimization;
- expected hit rate, artifact size, storage limit, and invalidation frequency;
- a versioned exact key/envelope proposal and negative tests for every omitted or changed identity;
- cold-versus-hit equivalence for complete, partial, failed, resource-mediated, and cross-target cases in scope;
- corruption, poisoning, traversal, quota, upgrade, cancellation, and fallback tests; and
- evidence that implementation and maintenance cost beats simpler caller-side memoization or further measured hot-path work.

Until then, full recomputation remains the correctness reference and the product behavior.
