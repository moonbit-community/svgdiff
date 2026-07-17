# General Resource Snapshot Bundle Boundary

Status: accepted future input boundary; no generalized bundle or prefetcher is implemented

Future bundle identity: `svgdiff-resource-snapshot-bundle/1`

Future resolution policy identity: `svgdiff-resource-resolution-policy/1`

Future prefetch profile identity: `svgdiff-resource-prefetch-profile/1`

Future prefetch transcript identity: `svgdiff-resource-prefetch-transcript/1`

Initial closed slice identity: `svgdiff-resource-snapshot-http-image-slice/1`

Last verified: 2026-07-17

Svgdiff will represent external resources as immutable, side-qualified response snapshots supplied before comparison. The comparison engine will never turn an SVG or CSS locator into filesystem or network authority. A future network-enabled prefetcher may produce a snapshot and a separate acquisition transcript, but it runs outside comparison and its success does not expand resource-family semantics.

The future abstraction is not `URL -> bytes`. It keeps authored locator, base resolution, logical request, response snapshot, representation bytes, interpretation, graph reachability, and acquisition provenance distinct. The current exact opaque-locator PNG/JPEG `ResourceBundle` and data-URL behavior remain unchanged.

The governing decision is [ADR 0106](adr/0106-use-side-qualified-resource-response-snapshots.md). Primary evidence is in the [research note](research/general-resource-snapshot-bundles.md), and the boundary is machine-checkable under [`evaluation/resource-snapshot-decision`](../evaluation/resource-snapshot-decision/).

## Artifact split

`svgdiff-resource-snapshot-bundle/1` is a strict offline manifest plus exact representation bytes. It contains no secrets and performs no acquisition. Before and after bind separate bundle instances and root document URLs, so the same resolved request may intentionally produce different bytes or failures on the two sides.

`svgdiff-resource-resolution-policy/1` fixes URL serialization, XML/SVG/CSS base rules, fragment handling, logical request construction, closure, duplicates, canonical JSON, digest, and limit rules. A `resolution_snapshot_digest` covers root/side binding, declared edges and outcomes, response semantics, and representation hashes. A `package_digest` additionally covers labels, unused entries, legal/security records, and supplied metadata. After graph traversal, `reachable_render_inputs_digest` identifies only exact reached outcomes plus interpretation/render policy IDs, without making unused entries visual differences.

`svgdiff-resource-prefetch-profile/1` declares how a future network tool is allowed to acquire: schemes/origins, request defaults, CORS, redirects, credentials, cache, service-worker, timeout, byte, and security policies. `svgdiff-resource-prefetch-transcript/1` separately records what happened: tool/build/profile, user authorization, request/response and redirect decisions, DNS/TLS/network facts where retained, raw transfer hashes and content decoding, timestamps, cache disposition, errors, limits, and the produced bundle digest. Acquisition timing, cache hit, transport encoding, TLS peer, and provenance do not change rendering when the normalized response snapshot is identical, but they remain integrity and audit evidence.

V1 canonical manifest bytes use RFC 8785 JCS and SHA-256, omitting each digest field from its own input. The six non-interchangeable digest boundaries are `blob_sha256` for exact representation bytes, `resolution_snapshot_digest`, `reachable_render_inputs_digest`, `acquisition_transcript_digest`, `compliance_evidence_digest` for licenses/notices/security attestations, and `package_digest` for the complete manifest and members. Legal or acquisition corrections can change package evidence without changing the reachable render inputs.

## Locator and request resolution

Every side declares one absolute root document URL even when its source bytes came from a local file. It is semantic base identity, not permission to fetch or a claim about the file path. A versioned project-owned URL evaluator resolves authored references under exact document, `xml:base`, stylesheet response-URL, nested document, and host-language base rules.

Each occurrence retains:

1. exact authored locator text and Source Span;
2. source document/resource ID and effective base URL provenance;
3. resolved URL serialized by the pinned URL policy;
4. fragment separately from the fragment-free fetch URL;
5. destination/resource family and expected target kind; and
6. logical request context: method, origin, destination, mode, credentials, redirect and cache modes, referrer policy/value, integrity, and every accepted representation-selecting header or environment input.

The lookup key is the complete logical request identity, not URL text alone. Distinct destination, origin, credentials, or variant inputs may legitimately select different entries for one URL. URL aliases remain distinct requests even when their bodies match. Duplicate complete keys or conflicting response records make the bundle invalid.

Current opaque raster keys are not silently migrated through URL normalization. A future caller chooses the new profile and supplies its explicit root URL and snapshot artifacts.

## Response snapshot

Each logical request maps to exactly one of:

- a response snapshot with redirect chain, final response URL, status, response type, normalized access-relevant header multimap, declared media type and charset, exact representation bytes after transfer and content-coding processing, length, and SHA-256; or
- a typed unavailable snapshot such as `not_acquired`, `unsupported_scheme`, `redirect_failed`, `network_failed`, `access_blocked`, `integrity_failed`, or `prefetch_limit_exceeded`.

An HTTP error response is a response, not the absence of an entry. A missing bundle entry differs from a recorded failed acquisition. Redirects do not become locator aliases: the original request, every hop, final response URL, and base-URL effect remain explicit. Transfer-compressed and uncompressed acquisitions can yield the same representation bytes and reachable-render-input digest while retaining different prefetch transcripts.

Media type, charset, signature, resource-family grammar, decoder, and color interpretation remain consumer-owned validation. The bundle does not make bytes valid SVG, CSS, font, image, or HTML by assertion, does not sniff a different family silently, and does not equate byte identity with representation or rendered equality.

## Recursive closure and graph integration

The root SVG plus each admitted nested stylesheet, SVG document, font stylesheet, or future foreign-content resource may discover more logical requests. The comparison engine reconstructs this typed graph only from source and supplied representation bytes, resolves each edge with the owning base rule, and requires the declared closure policy to account for every reachable admitted request.

Graph records retain source occurrence, logical request, response entry, interpretation result, consumers, and activity independently. Family semantics decide whether a missing target, cycle, import loop, redirect, or invalid payload is ignored, falls back, remains partial, or fails admission; the bundle does not collapse them to one `resolved` flag. Whole-graph safety limits apply before expensive interpretation.

Duplicate logical keys and contradictory entries are invalid globally. Entry envelope, hash, and byte-budget invariants apply to every supplied entry. Content parsing and decoder validity remain lazy for unused entries. A valid unused entry changes the package digest but produces no SVG Atomic Difference; the reachable-render-input digest excludes it. Missing reachable entries, unscannable nested references, or unsupported URL syntax make closure partial or unavailable rather than silently complete.

Same request and same exact bytes across sides can still produce different computed results under different consumer profiles. Different bytes may be representation-equivalent after valid parsing, and equal pixels do not erase source or resource differences. These are separate evidence relations.

## Initial closed slice

`svgdiff-resource-snapshot-http-image-slice/1` is the first implementation candidate. It reuses only the existing admitted PNG/JPEG `image` semantics and decoders while exercising the new request/snapshot seam:

- XML SVG with one explicit absolute HTTP(S) root URL per side;
- relative or absolute external `image` references resolved by the pinned URL evaluator;
- fragment-free same-origin anonymous GET, no credentials, no referrer, no redirect, no request variants, and one successful response;
- exact `image/png` or `image/jpeg`, no content encoding, exact representation bytes, and the current decoder/color guards and limits; and
- no nested resources, scripts, interaction, animation, network access, file URLs, cache, fallback fetch, or final raster-image compositing expansion.

This tracer does not replace the current opaque bundle and does not add a resource family. It validates root/base URL, side separation, request identity, response snapshot, missing/failure outcomes, and provenance linkage before nested CSS, fonts, SVG documents, redirects, CORS variants, or foreign content are attempted.

## Outcomes

Keep at least these bundle and resolution outcomes distinct:

- `resolved`;
- `invalid_bundle`;
- `base_url_unavailable`;
- `url_invalid`;
- `request_variant_ambiguous`;
- `snapshot_entry_missing`;
- `acquisition_failure_recorded`;
- `redirect_unavailable`;
- `access_blocked`;
- `integrity_failed`;
- `media_type_mismatch`;
- `content_invalid`;
- `resource_family_unsupported`;
- `nested_closure_incomplete`;
- `resource_cycle_or_family_loop`;
- `resource_limit_exceeded`; and
- `insufficient_evidence`.

Missing, failed, blocked, invalid, unsupported, conflicting, cyclic, or exhausted resources are not empty bytes, transparent content, a zero magnitude, or equality. A 404 response is not a network error; a CORS-blocked response is not a missing URL; an unused entry is not an authored resource difference.

## Prefetch and security boundary

Comparison-time filesystem and network I/O are permanent non-goals. The future prefetcher is an explicit user-invoked acquisition tool that emits files; it is not a comparison mode. It requires URL/scheme and destination allowlists, credential-free defaults, private-network and local-file protections, redirect/DNS rebinding checks, response and decompression limits, TLS and proxy policy, bounded concurrency/time/bytes, secret-free logs, atomic output, and complete typed failures.

The bundle contains no cookies, authorization headers, client certificates, proxy credentials, cache database, or ambient browser storage. A workflow needing authenticated resources must acquire and sanitize exact representation bytes outside svgdiff, with provenance indicating that the canonical prefetch contract was not used.

Snapshot bytes remain hostile. Admission validates manifest structure and hashes before invoking family parsers, then applies independent XML/CSS/font/image/HTML limits. Nested SVG and font-SVG content inherit secure-static script, animation, interaction, and external-resource policies.

## Agent interpretation

A text-only Agent must distinguish locator spelling, resolved logical request, response/failure snapshot, exact resource bytes, parsed representation, consumer result, rendered effect, reachability, and acquisition provenance. It must qualify findings by source role and resource profile.

The Agent must not call a missing snapshot a missing server resource, treat the same URL as the same content across sides, merge aliases because hashes match, call byte changes visually different without downstream evidence, describe unused bundle entries as SVG changes, or infer network behavior from an offline bundle.

## Implementation gate

Implementation may begin only when a concrete Agent task requires it and the project has:

- versioned schemas and canonical encodings for the bundle, resolution policy, six digest boundaries, prefetch profile/transcript, request keys, response/failure entries, and compatibility;
- a pinned URL/base evaluator with conformance vectors for Unicode, percent encoding, dot segments, queries, fragments, ports, origins, `xml:base`, redirects, and nested bases;
- exact controls for side separation, variants, aliases, redirects, status, headers, MIME/charset, integrity, missing/failed/blocked entries, unused content, nested closure, cycles, and limits;
- family parsers and decoders that consume only verified representation bytes and preserve independent resource outcomes;
- hard manifest, entry, total byte, URL, redirect, graph, depth, parser, decompression, surface, work, time, memory, output, and process limits;
- proof of zero comparison-time I/O and negative controls for paths, file URLs, localhost/private network, credentials, cache, proxy, environment, and ambient browser state;
- deterministic digest/replay behavior, security review, license/provenance handling, renderer conformance, and Agent evaluation; and
- a separately accepted and isolated implementation plan before any network-enabled prefetcher ships.

Until then, run:

```sh
sh scripts/test-resource-snapshot-decision.sh
```
