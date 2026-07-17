# Incremental and Cached Deterministic Comparisons

Status: research for the roadmap P2 caching item; not a product contract

Evidence snapshot: 2026-07-17

## Question

What primary-source practices are relevant if svgdiff later reuses complete
comparisons or intermediate results, without allowing caching to weaken report
correctness, profile identity, determinism, or security?

## Evidence summary

The mature systems surveyed here consistently separate three concerns:

1. a semantic operation key identifies all inputs that can affect a result;
2. content-addressed storage identifies immutable blobs and dependency nodes;
3. an explicit dependency graph determines which derived nodes are invalidated.

These are related, but none substitutes for the others. A hash of an output does
not prove that it belongs to the requested operation. A complete operation key
does not reveal which smaller intermediate can be safely reused. A dependency
graph is not correct if a computation reads ambient data without declaring an
edge to it.

Bazel states the prerequisite directly: shared remote outputs are safe to reuse
when the build is reproducible, and each action declares its inputs, output
names, command line, and environment variables. Its remote cache then maps an
action hash to result metadata and stores output files in a separate CAS
([Remote Caching](https://bazel.build/remote/caching#overview)). Bazel's
hermeticity guidance defines the stronger foundation: the same source and
configuration produce the same output only when host software and external
services cannot silently affect execution, and exact tool and dependency
versions are inputs
([Hermeticity](https://bazel.build/basics/hermeticity#overview)).

The implication for svgdiff is conditional rather than a product decision:
cache work becomes a correctness-preserving optimization only after each cached
stage has a stable semantic identity and has closed every input on which it
depends. Until that has been demonstrated, re-execution is the evidence-bearing
behavior.

## Operation-key completeness

The Remote Execution API models a repeatable `Action` as the digest of its
canonical wire encoding. The action contains a command digest and a root digest
for the complete input directory tree. It also includes timeout and platform
requirements; the specification explains that a different timeout must produce
a different action, and provides an explicit salt for abandoning a namespace
after buggy software or tool failures poison results
([Action](https://github.com/bazelbuild/remote-apis/blob/main/build/bazel/remote/execution/v2/remote_execution.proto#L608-L681)).
The command separately carries arguments, environment variables, output paths,
working directory, and execution-platform requirements
([Command](https://github.com/bazelbuild/remote-apis/blob/main/build/bazel/remote/execution/v2/remote_execution.proto#L683-L866)).

Bazel documents two concrete incomplete-key failures. Environment variables can
prevent intended cross-machine sharing when they vary, while a compiler outside
the workspace can cause an incorrect hit because different compilers receive
the same action hash
([Remote Caching known issues](https://bazel.build/remote/caching#known-issues)).
Ccache exposes the same tradeoff more explicitly: ignoring headers or compiler
options, or using timestamps rather than file contents, can create stale hits;
its `sloppiness` settings deliberately trade correctness checks for hit rate
([ccache configuration](https://ccache.dev/manual/4.13.6.html#_configuration_options)).

For svgdiff, this evidence identifies categories that a future cache-key audit
would have to examine. The exact admitted fields remain a product decision, but
omitting a result-affecting member from any category would require proof of
semantic irrelevance:

- ordered before and after source identities, not an unordered pair;
- every reachable embedded or supplied resource outcome and the resolution
  policy that made it reachable;
- viewport, background, scale, renderer, analysis, magnitude, alignment,
  attribution, Impact, limit, and serialization profiles when they can alter
  the cached stage;
- algorithm, schema, dependency, tool-build, and execution-target identities
  until compatibility or cross-target equivalence is proved;
- feature flags, mode switches, environment values, and caller policy that are
  actually observed by the computation;
- terminal partial, unsupported, limit, and failure outcomes, since changing a
  limit or support profile can change whether evidence exists at all.

This list does not imply that all metadata belongs in every key. The Nix manual
distinguishes input addressing, where identity describes how an object was
made, from content addressing, where identity describes the object itself. It
also documents quotient hashing to avoid rebuilding merely because fetching
details changed when the fixed content input provably did not
([Input-addressing derivation outputs](https://nix.dev/manual/nix/2.34/store/derivation/outputs/input-address.html)).
That distinction is relevant to svgdiff: acquisition provenance, timing, local
file names, cache location, and logs need not alter visual evidence when they
are proved not to affect the normalized comparison input. Such facts may still
need separate audit or security records.

## Content-addressed nodes and Merkle closure

The Remote Execution API's CAS addresses every binary blob by digest. An input
root is a `Directory` node whose file entries contain content digests and whose
directory entries contain child-directory digests; the action therefore reaches
the complete input tree through a Merkle-shaped graph
([CAS](https://github.com/bazelbuild/remote-apis/blob/main/build/bazel/remote/execution/v2/remote_execution.proto#L350-L567),
[Directory](https://github.com/bazelbuild/remote-apis/blob/main/build/bazel/remote/execution/v2/remote_execution.proto#L982-L1000)).
The protocol makes byte size an integral part of a digest and requires a
canonical protobuf encoding when a digest names a message
([Digest](https://github.com/bazelbuild/remote-apis/blob/main/build/bazel/remote/execution/v2/remote_execution.proto#L1085-L1119)).

Nix's content-addressed store similarly includes the file-system object graph,
references, store directory, and name in store-object identity. Its
documentation emphasizes that referenced objects are part of the identity,
rather than treating the root object's bytes as the entire graph
([Content-Addressing Store Objects](https://nix.dev/manual/nix/2.26/store/store-object/content-address)).

Applied as evidence rather than a prescribed format, these designs suggest two
different svgdiff identities:

- immutable node content can be addressed by canonical bytes plus an explicit
  digest algorithm and size;
- a reusable semantic result must also be bound to the identities of every
  dependency node and the profile that interprets them.

Fine-grained reuse is possible only at a stable semantic seam. Potential nodes
might correspond to parsing, resource closure, canonical facts, rendered
evidence, magnitude maps, alignments, events, or report serialization, but a
Merkle DAG does not prove that any such split is sound. Each node would need a
documented pure function from named input identities to canonical output bytes.
Coarse whole-stage reuse is less incremental but has a smaller dependency
surface to prove.

## Dependency tracking and invalidation

Bazel's Skyframe requires computations to obtain input data through declared
dependency nodes. Reading the filesystem directly would omit an edge and cause
incorrect incremental builds. With complete edges, a changed input invalidates
its reverse transitive closure. Skyframe can then prune propagation when a
rebuilt node has the same value as before
([Skyframe data model and incrementality](https://bazel.build/reference/skyframe#data-model)).
The same documentation says Bazel avoids in-place incremental mutation where it
cannot guarantee equality with a clean rebuild, favoring decomposition into
smaller independently recomputable nodes instead
([Incremental linking and compilation](https://bazel.build/reference/skyframe#incremental-linking-compilation)).

Ccache documents a race with the same shape: if the source changes after ccache
hashes it but before the compiler reads it, the output can be stored under the
old key. It disables caching for files that appear newly modified to avoid that
time-of-check/time-of-use mismatch
([Handling newly created source files](https://ccache.dev/manual/4.13.6.html#_handling_of_newly_created_source_files)).

The svgdiff implications are:

- dependency discovery and use must observe one immutable snapshot; a source or
  resource must not change between key computation and analysis;
- dynamic discovery, such as references found while parsing SVG or CSS, must
  become explicit dependency edges before a result is admitted to the cache;
- changing a node invalidates every consumer unless recomputation proves the
  consumer's canonical value unchanged;
- deletion, newly resolvable references, cycle outcomes, duplicate identifiers,
  and changes from unused to reachable resources are dependency changes, not
  merely byte changes to already known leaves;
- clean uncached execution is the reference oracle for any incremental path.

Eviction and semantic invalidation should also remain conceptually separate.
Deleting a cache entry only sacrifices performance. A profile or algorithm
change makes an old result inapplicable even if its bytes remain stored. The
Remote Execution API's action salt demonstrates an emergency namespace escape
for poisoned software results, while normal field changes alter action identity
directly. Neither mechanism requires treating wall-clock age as evidence that a
semantic result changed.

## Reproducibility gates before reuse

The Reproducible Builds project defines reproducibility as bit-for-bit identical
specified artifacts from the same source, environment, and instructions. It
calls out dependencies, versions, configuration flags, environment variables,
and locale as relevant environment attributes, and verifies artifacts by exact
comparison, usually using cryptographic hashes
([Definitions](https://reproducible-builds.org/docs/definition/)).

Bazel's cache-debugging workflow first requires repeated same-machine runs to
hit, then repeats across machines and compares execution logs. Those logs expose
file inputs, arguments, environment variables, and outputs, allowing leaked host
state and key differences to be located
([Debugging Remote Cache Hits](https://bazel.build/remote/cache-remote)).

Corresponding evidence gates for a future svgdiff experiment would include:

1. compare clean uncached and cached executions byte-for-byte for each cached
   artifact, terminal status, and final report;
2. repeat in fresh processes and on every claimed execution target;
3. mutate every declared semantic input one at a time and verify either a miss
   or a proved same-value result;
4. mutate excluded provenance and ambient state and verify that the canonical
   result does not change;
5. test deletion, insertion, newly reachable dependencies, resource cycles,
   malformed cached records, interrupted writes, concurrent writers, and
   dependency changes during analysis;
6. compare incremental results with a clean rebuild after randomized sequences
   of edits, rather than testing only isolated hits;
7. keep a supported way to bypass and purge reuse so correctness failures can be
   reproduced without cached state.

A high hit rate is not a correctness gate. Neither is equality on a few fixtures.
The required claim is that every admitted cached result is exactly the result the
same versioned deterministic computation would have produced from the current
closed inputs.

## Local and shared cache boundaries

Bazel distinguishes a local disk cache from a remote cache shared by developers
or CI. It warns that the remote cache contains binaries, recommends controlling
who may write, and specifically suggests that only CI may receive write access
([Remote-cache security and permissions](https://bazel.build/remote/caching#authentication)).
Ccache checks local storage before remote storage by default and documents the
promotion of a remote hit into the local cache. Its shared-directory guidance
requires trusting every user with write permission
([Storage interaction](https://ccache.dev/manual/4.13.6.html#_storage_interaction),
[Sharing a local cache](https://ccache.dev/manual/4.13.6.html#_sharing_a_local_cache)).
Nix pairs substituter configuration with trusted public keys for binary-cache
objects
([Custom binary cache](https://nix.dev/guides/recipes/add-binary-cache.html)).

These sources support the following risk distinction for svgdiff:

| Cache scope | Correctness and security exposure | Evidence needed before use |
| --- | --- | --- |
| Process-local memory | Stale mutable state, object aliasing, incomplete invalidation | Immutable values, explicit lifetime, clean-run equivalence |
| User-local disk | Corruption, concurrent writes, version/profile drift, hostile pre-existing files | Atomic publication, digest and size verification, bounded decoding, namespace/version checks |
| Shared or remote | All local risks plus untrusted writers, cross-target incompatibility, credential/transport compromise, cache poisoning, tenant data leakage | Authentication, transport protection, writer policy, integrity/authenticity verification, isolation, audit and purge controls |

The lookup tier must not change semantics. A hit from memory, local disk, shared
storage, or no cache should yield the same canonical artifact. Remote
availability failures should therefore be distinguishable from comparison
failures; cache absence is ordinarily a miss followed by local computation, not
missing visual evidence.

## Integrity, authenticity, and hostile cache records

Content addressing detects accidental or malicious byte substitution only when
the consumer recomputes the declared digest and size. It does not by itself
establish who was authorized to publish the mapping from an operation key to a
result. Bazel treats writer access as security-sensitive and documents cache
poisoning as a reason to clear cached outputs. Nix's use of trusted public keys
for substituters provides primary-source evidence that shared artifact
authenticity is a separate layer from content identity.

For svgdiff, a future cache reader would remain an untrusted-input parser. The
same hard limits and reference-closure checks required for reports and resource
bundles would apply before a cached artifact gains authority. Relevant negative
controls include:

- a correct key pointing to bytes with the wrong digest or length;
- valid blob digests linked by a forged or unauthorized result record;
- unknown schema, algorithm, profile, or digest identifiers;
- missing child nodes, graph cycles where forbidden, duplicate canonical keys,
  and inconsistent aggregate digests;
- oversized, deeply nested, decompression-amplified, or path-bearing payloads;
- partial and non-atomic writes that look like complete entries;
- a valid artifact from another tenant, side ordering, target, or privacy
  boundary.

Secrets, local paths, source contents, fonts, images, and complete reports may
all be sensitive. A shared-cache proposal would therefore need an explicit data
classification, retention, access-control, and redaction analysis in addition
to cache-key correctness.

## What the evidence does not establish

The surveyed sources do not establish that caching will materially improve
svgdiff's workload, which stage is expensive enough to cache, or what granularity
has a favorable storage and complexity tradeoff. They also do not prove that
two svgdiff execution targets are interchangeable, that semantic profile
compatibility can be inferred from version numbers, or that a cached report can
be reused after any source edit without recomputing attribution and completeness.

Before a product decision, measurements would need to separate hashing,
dependency discovery, serialization, storage, and transfer cost from saved
computation. The correctness proof and miss-path behavior remain necessary even
when measured hit rates are low. Conversely, performance benefit cannot justify
an intentionally incomplete key: ccache's documented `sloppiness` tradeoffs are
a warning, not evidence that false hits are acceptable for an Agent-facing
visual-difference report.
