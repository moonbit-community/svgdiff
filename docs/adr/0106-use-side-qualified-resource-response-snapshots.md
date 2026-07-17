# ADR 0106: Use side-qualified resource response snapshots

- Status: accepted, not implemented
- Date: 2026-07-17
- Decision owners: svgdiff maintainers
- Supersedes: none

## Context

The current `ResourceBundle` matches one trimmed opaque locator to caller-supplied PNG/JPEG bytes and intentionally has no URL or base semantics. General external SVG, CSS, font, image, and foreign-content resources require URL resolution, request variants, response metadata, redirects, nested bases, recursive closure, and precise failures. Allowing the comparison engine to fetch would add ambient network, filesystem, credentials, cache, timing, and security state.

## Decision

Keep current opaque raster bundles unchanged. Reserve `svgdiff-resource-snapshot-bundle/1` for future immutable side-qualified logical request and response/failure snapshots, `svgdiff-resource-resolution-policy/1` for URL/request/closure/digest semantics, `svgdiff-resource-prefetch-profile/1` for future acquisition authority, and `svgdiff-resource-prefetch-transcript/1` for separate acquisition provenance.

Require an explicit absolute root document URL per side and a pinned URL/base evaluator. Key entries by complete logical request context, not URL text. Preserve original request, redirect chain, final response URL, access-relevant metadata, exact post-transfer-decoding representation bytes, and typed failure. Bind before and after to separate snapshots.

Reconstruct recursive resource closure offline from supplied bytes. Keep global bundle validity, family-specific interpretation, graph safety, activity, and downstream evidence independent. Never perform comparison-time I/O.

Select `svgdiff-resource-snapshot-http-image-slice/1` as the first unimplemented tracer: same-origin credential-free redirect-free HTTP(S) image requests resolved against an explicit root URL and backed by successful exact PNG/JPEG response snapshots using current decoders.

## Consequences

The model can reproduce response-dependent semantics without pretending URL identity is content identity or transport provenance is rendering. Nested resources remain bounded and explainable. Future network acquisition is possible only as an isolated explicit prefetch artifact, not as a comparison feature.

No generalized bundle, URL resolver, prefetcher, resource family, dependency, report field, Schema, public API, Diagnostic, fixture, CLI option, CI job, or release asset changes through this decision.

## Rejected alternatives

- Extend current opaque keys by silently applying URL normalization: this would change released exact-match behavior and lacks a root base.
- Key only by URL: response selection can depend on destination, origin, mode, credentials, referrer, integrity, and representation variants.
- Store only body bytes: response URL, status, headers, access result, MIME/charset, and typed failure affect interpretation.
- Put network fetching inside comparison: ambient network and credential state would enter canonical execution and hostile SVG could initiate I/O.
- Treat a browser cache or HAR as the canonical bundle: it can contain secrets, incomplete variants, decoded/raw ambiguity, target-private fields, and unrelated traffic.
- Compare every unused entry as an SVG difference: bundle contents are acquisition inputs, not authored visual facts.
