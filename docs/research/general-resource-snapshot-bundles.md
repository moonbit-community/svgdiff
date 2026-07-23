# Generalized External Resource Snapshot Bundles

Status: decision research for ISS-159; not a product contract

Evidence snapshot: 2026-07-17

## Question

How can svgdiff admit external SVG, CSS, font, image, nested-document, and future host-language resources without giving comparison ambient filesystem or network authority, while preserving browser-relevant URL, fetch, response, and content distinctions?

## Recommended decision

Keep the implemented `ResourceBundle` unchanged: it is a narrow PNG/JPEG `image` adapter whose keys are exact opaque strings, not URLs. Define a parallel future `svgdiff-resource-snapshot-bundle/1` as an immutable, side-qualified, root-bound, recursively closed snapshot. Comparison validates it and reads only in-memory members; it never opens a path, resolves a host, consults a cache, follows a redirect, or fetches.

The generalized bundle is not a URL-to-bytes map. It contains four linked but non-interchangeable layers:

1. source references: exact authored locator, owner content hash and byte span, effective base URL, resolved selection URL, and fragment;
2. logical requests: a canonical fragmentless request key plus policy that can affect availability or representation;
3. side-local response snapshots: redirect URL list, terminal outcome, response metadata, and exact representation bytes;
4. interpretations: consumer family, MIME/charset/sniff policy, parser/decoder identity, validation result, and later evidence.

Acquisition provenance and license evidence may accompany rendering input but have separate identities. A timestamp, cache source, legal notice, or operator name must not make equal representation bytes visually different; a CORS denial, different final response URL used as a nested base, or different representation bytes can.

## Current project boundary

The current public `ResourceBundleEntry` is exactly `{ locator, media_type, bytes }`. The engine trims and case-sensitively matches the locator, accepts only PNG/JPEG media types, keeps sides separate, validates fixed budgets, and performs no I/O ([implementation](../../modules/svgdiff/engine/internal/resource_model/resource_bundle.mbt), [implemented policy](local-resource-bundle-policy.md)). It does not resolve a base, normalize URLs, follow redirects, or model requests. Referenced content uses the bounded raster path; unused payload is not decoded or compared. Missing entries are partial, invalid global configuration and budget overflow fail admission, and unused valid entries make no report difference ([Resource Outcome Policy](../resource-outcome-policy.md)).

That admitted behavior must not be reinterpreted as web loading. The typed resource graph retains external locator edges and Source Spans but is not a complete external resolver ([Reference Safety](../reference-safety.md)).

## Primary-source findings

### URL, base, and fragment are separate facts

The WHATWG URL Standard defines parsing, serialization, origin, and equality; equality compares serialized URLs and can exclude fragments ([URL parsing and serialization](https://url.spec.whatwg.org/#urls), [URL equivalence](https://url.spec.whatwg.org/#url-equivalence)). Pin that algorithm/version and retain the serialization; do not invent lowercasing, path cleanup, percent-decoding, Unicode normalization, or query sorting.

XML Base makes `xml:base` inherit through ancestry, resolves ordinary attributes against their element base, and derives the document entity base from retrieval unless overridden ([XML Base 4.1-4.4](https://www.w3.org/TR/xmlbase/#resolution)). SVG 2 tests same-document references by comparing every component except the fragment with the document base ([SVG 2 linking](https://www.w3.org/TR/SVG2/linking.html#URLReference)).

External CSS resolves URLs against the stylesheet, while embedded CSS uses its container's base; fragment-only CSS URLs have tree-scoped behavior ([CSS Values 4](https://www.w3.org/TR/css-values-4/#relative-urls)). Every edge therefore needs its own base and fragment. The fragment selects within acquired content and is excluded from the request key; query remains. Fragment variants may share a body without becoming the same source fact.

Each root declares an absolute `document_url`; no current-directory or input-path inference is allowed. A stable synthetic HTTPS URL is valid, but changes relative resolution and origin and is therefore an input.

### Fetch outcome is not content identity

Fetch requests carry method, URL list, destination, mode, credentials/cache/redirect modes, origin, referrer policy, integrity, and headers; responses carry URL list, type, status, headers, and body ([requests](https://fetch.spec.whatwg.org/#requests), [responses](https://fetch.spec.whatwg.org/#responses)). CORS depends on origin and credentials, and opaque responses hide body and headers ([CORS](https://fetch.spec.whatwg.org/#http-cors-protocol), [opaque response](https://fetch.spec.whatwg.org/#concept-filtered-response-opaque)). Resolved URL alone cannot key a response.

Redirects append to the URL list and can cross origins ([Fetch redirects](https://fetch.spec.whatwg.org/#http-redirect-fetch)). Preserve the list and final URL because nested relatives use the effective response location. The transcript also records each hop's status, `Location`, decision, and failure; timing is provenance only.

HTTP caching selects how a response is obtained, not the resulting representation's identity ([RFC 9111](https://www.rfc-editor.org/rfc/rfc9111)). Record cache mode and source in provenance; comparison consumes captured bytes and never replays caching.

An HTTP error status remains a response, distinct from a network error and content validity. Preserve status and let the consumer policy decide usability ([RFC 9110](https://www.rfc-editor.org/rfc/rfc9110.html#name-status-codes)).

### Representation bytes precede semantic interpretation

The rendering blob is the exact representation bytes presented to the consumer after transfer and content-coding processing; byte length and SHA-256 are authoritative. Wire chunks, TLS, `Content-Encoding`, and transfer hash are acquisition provenance. A prefetcher unable to name its byte boundary cannot emit a canonical snapshot.

MIME Sniffing separates supplied and computed types, ignores HTTP filename extensions, and uses context-specific image/style/font algorithms ([supplied type](https://mimesniff.spec.whatwg.org/#supplied-mime-type-detection-algorithm), [context sniffing](https://mimesniff.spec.whatwg.org/#context-specific-sniffing)). Preserve exact `Content-Type` values and parsed parameters. Interpretation separately states context, sniff policy/result, charset source, decoded-text hash, and parser/decoder identity; suffixes and caller intuition are not authority.

CSS has ordered byte-decoding rules ([CSS Syntax 3](https://www.w3.org/TR/css-syntax-3/#input-byte-stream)); SVG/XML decoding is likewise family semantics. Bytes, code points, parsed objects, normalized pixels, and rendered output stay distinct even if later declared equivalent.

## Exact future artifact identities

The first version should reserve these exact strings:

| Identity | Authority |
| --- | --- |
| `svgdiff-resource-snapshot-bundle/1` | Immutable package manifest, root binding, request/response graph, blobs, terminal outcomes, and member hashes. |
| `svgdiff-resource-resolution-policy/1` | WHATWG URL serialization, XML/SVG/CSS base rules, fragment handling, request-key construction, closure, duplicate, and limit rules. |
| `svgdiff-resource-prefetch-profile/1` | Future acquisition policy: allowed schemes/hosts, request defaults, CORS, redirects, credentials, cache, service workers, timeouts, and byte limits. |
| `svgdiff-resource-prefetch-transcript/1` | Sanitized ordered acquisition attempts, redirects, policy decisions, response metadata, failures, and tool/runtime identity. |

Use RFC 8785 JCS for canonical manifest bytes and SHA-256 for member and
aggregate digests ([RFC 8785](https://www.rfc-editor.org/rfc/rfc8785),
[FIPS 180-4](https://csrc.nist.gov/pubs/fips/180-4/upd1/final)). Digest fields
are omitted from their own digest input.

Required identities are:

- `blob_sha256`: exact representation bytes only;
- `resolution_snapshot_digest`: root hash/URL, side, resolution policy, all
  declared reference/request edges, terminal outcomes, response URL/status and
  interpretation-relevant headers, and representation hashes;
- `reachable_render_inputs_digest`: produced by comparison from only reachable
  consumed outcomes plus exact interpretation/render policy IDs; unused package
  members are excluded;
- `acquisition_transcript_digest`: retrieval history and sanitized environment;
- `compliance_evidence_digest`: license expressions, notices, source claims,
  and security attestations, without authority to change content semantics;
- `package_digest`: all canonical manifest fields and every member hash.

Changing acquisition or legal evidence can change `package_digest` without
changing `reachable_render_inputs_digest`. A policy result that blocks a
resource, a final URL that changes a nested base, or different representation
bytes changes the resolution input even when acquisition metadata is otherwise
identical.

## Request key and response records

A `fetch_key` is the JCS/SHA-256 identity of this typed descriptor:

```text
{
  url_without_fragment,
  method: "GET",
  destination,
  mode,
  credentials_mode,
  origin,
  redirect_mode,
  cache_mode,
  referrer_policy,
  integrity_metadata,
  representation_affecting_request_headers
}
```

`destination` keeps stylesheet, image, font, SVG document, and future foreign
content requests distinct. Request headers must be a policy-defined canonical
list; `Accept` can select a different representation. Secret authorization and
cookie values must never appear or be hashed into a distributable artifact. The
canonical prefetch profile therefore uses `credentials_mode: omit`, no cookies,
no client certificates, and no ambient authentication. A noncanonical external
capture may instead record an opaque secret-context label and `credentials_used`
without claiming reproducible reacquisition.

Within one side, one `fetch_key` has exactly one terminal record. Multiple
source references may point to it. Duplicate identical records are rejected as
noncanonical; conflicting records are invalid. The same serialized URL with a
different request descriptor is allowed. Before and after are independent, so
the same `fetch_key` may intentionally resolve to different bytes or outcomes.

One terminal record is exactly one of:

- `response`: ordered URL list, final URL, response type, status, selected
  semantic header fields, representation blob, and acquisition reference;
- `network_error`: DNS, connection, TLS, transport, or abort class;
- `policy_blocked`: scheme, origin/CORS, mixed-content, CSP, credential, private
  network, or sandbox policy plus stable rule ID;
- `redirect_error`: invalid location, policy crossing, loop, or hop limit;
- `resource_limit`: header, transfer, representation, time, or work dimension;
- `not_acquired`: an explicit handcrafted-snapshot absence, distinct from an
  undiscovered edge.

These outcomes close acquisition, not interpretation. A `response` may later be
`supported`, `representation_equivalent`, `invalid_content`,
`unsupported_family`, or `consumer_unusable`. A missing terminal record for a
reachable edge means the snapshot is not closed and cannot support a complete
comparison.

## Recursive closure

Bind the manifest to `(side, root_source_sha256, document_url)`. Starting from
that root, parse only admitted static syntax and materialize every reachable
external reference edge from SVG, external CSS including `@import`, font
sources, raster images, external SVG documents, and later admitted foreign
content. Each edge records its owner blob/root hash, Source Span, raw locator,
effective base, resolved selection URL, fragment, consumer family, and
`fetch_key` or same-document target.

Closure rules:

1. every reachable admitted external edge has one terminal request outcome;
2. every response selected for a recursively parsed family has an interpretation
   record and contributes its newly discovered edges;
3. a graph edge back to an existing request records a cycle and reuses that
   record; family semantics decide whether the cycle is ignored, invalid, or
   partial rather than the loader recursively fetching again;
4. maximum roots, references, requests, redirect hops, nesting depth, bytes,
   decoded text, parsed nodes, and total work are versioned hard limits;
5. hitting a closure/depth/work limit leaves the artifact non-closed and fails
   canonical admission, matching the project's no-truncated-inventory rule;
6. unreferenced extra responses/blobs are allowed only as `unused_members`, are
   globally hash/size validated, and do not enter reachable rendering identity;
7. byte-identical aliases may share one blob but retain distinct reference,
   request, URL, origin, and response evidence;
8. same bytes with different MIME/charset/base or policy outcomes are not one
   interpretation; different bytes that decode/render equivalently remain
   different content identities with a later typed equivalence result.

Unused members, an explicitly recorded failed acquisition, a missing request
record, invalid content, and an unsupported family are five different states.
Only the first is irrelevant to the current comparison. An explicit failure
closes the snapshot graph but leaves the affected evidence unavailable; an
undeclared reachable request invalidates the closure claim.

## Future prefetch boundary

`svgdiff-resource-prefetch-profile/1` is a separate tool/profile, never a library
callback executed by comparison. Its smallest canonical mode should:

- allow only explicitly configured HTTP(S) origins and reject `file:`, ambient
  paths, URL credentials, local/private/link-local addresses, DNS rebinding,
  and redirects outside the allowlist;
- use GET, credentials omitted, cookies/storage/client certificates absent,
  service workers disabled, cache bypassed, redirect following bounded, and
  browser/script execution absent;
- enforce CORS and every destination-specific fetch policy instead of granting
  use merely because bytes were downloaded;
- bound DNS/connect/read time, header bytes, redirect hops, transfer bytes,
  decoded representation bytes, nested depth, resource count, and total work;
- store exact representation members atomically, then emit a sanitized,
  content-addressed transcript with tool/build, URL-policy, and environment
  identities; timestamps and network addresses remain provenance only;
- never serialize cookies, authorization, proxy credentials, TLS private data,
  or unredacted sensitive headers.

A caller may also construct a snapshot from already owned bytes. Such a bundle
uses `not_network_acquired` provenance and must still satisfy URL, graph,
response-metadata, MIME, closure, digest, and limit rules. Supplying bytes is not
evidence that browser security policy would have allowed the resource.

Comparison rejects malformed or non-closed artifacts before semantic analysis,
copies no payload into the report, and reports only stable hashes, policy IDs,
selected response/interpretation identities, outcomes, and Source Spans.

## Practical smallest implementation slice

The first implementation after this decision should be intentionally narrow:

1. implement only a parser/validator for
   `svgdiff-resource-snapshot-bundle/1`, JCS digests, safe in-package members,
   side/root binding, WHATWG URL resolution, request-key uniqueness, and closure
   checks; do not add a fetcher;
2. admit only root-document external PNG/JPEG `image` references, with explicit
   absolute `document_url`, one-hop `response` records, and the existing bounded
   PNG/JPEG decoder; fragments are retained but invalid for these raster
   consumers;
3. run it in parallel with, not as a migration of, current opaque
   `ResourceBundle`; no current API or report meaning changes until the new path
   has conformance evidence;
4. prove relative/base resolution, query identity, fragment/body sharing,
   same-URL different-side bytes, aliases, duplicates/conflicts, missing
   outcomes, MIME/signature mismatch, unused members, and exact/one-past limits;
5. add external CSS recursion next, then font mapping, then nested external SVG;
   foreign content remains gated by its own host-layout decision;
6. build the prefetch tool only after the offline artifact and resolver are
   stable, with network tests outside default hermetic comparison CI.

This slice creates the deep seam first while reusing the only external payload
family already understood by the engine. It does not pretend that a manifest
validator is a CSS, font, nested-SVG, or HTML execution engine.

## Security and ownership

Treat every URL, header, manifest field, archive member, compressed body, XML,
CSS, font, and image as hostile. Reject absolute/member traversal paths,
backslash aliases, `.`/`..`, NUL, duplicate member names, symlinks, hash/length
mismatch, decompression overrun, integer overflow, graph explosion, and parser
budget overflow. The artifact reader has no sockets and no filesystem authority
beyond bytes explicitly opened by its caller.

The project owns URL resolution, artifact validation, graph closure, request and
outcome taxonomy, fingerprints, limits, and report projection. Family-specific
parsers/decoders own content validity. A browser or fetch library may acquire an
external observation, but its output is not canonical until converted to and
validated against the project artifact. Renderer/browser identity, color
profile, fonts, script, interaction, animation, and foreign-content profiles
remain independent axes; the resource bundle supplies closed inputs but cannot
make those engines deterministic by itself.

## Text-only Agent rule

An Agent must distinguish source locator change, resolved request change,
response availability/policy change, exact content change, interpretation
change, and rendered consequence. Equal URLs do not imply equal bytes; equal
bytes do not imply equal interpretation; different bytes can be
representation-equivalent; an unused member is not an SVG difference. If any
reachable request is absent, blocked, over limit, invalid, or unsupported, the
Agent must preserve independently supported findings but must not claim visual
equality for the affected evidence.

## Rejected shortcuts

- **Generalize the current opaque locator map.** It cannot express base URLs,
  fragments, redirects, origins, request variants, nested closure, or failures.
- **Use one `URL -> bytes` dictionary.** Destination, mode, credentials, origin,
  headers, redirects, and side can select different outcomes.
- **Normalize authored locators in place.** This destroys Source Semantics and
  provenance; resolution is a derived record.
- **Share one snapshot across before and after.** This erases the important
  same-URL/different-response case.
- **Hash decoded objects or pixels instead of exact bytes.** That loses content,
  decoder, MIME, charset, metadata, and invalid-input distinctions.
- **Treat successful download or HTTP 2xx as semantic validity.** Fetch,
  security acceptance, MIME interpretation, parse validity, and rendering are
  different stages.
- **Let comparison fetch missing entries.** It makes equality depend on mutable
  networks, credentials, caches, time, and security state.
- **Record only a browser cache/export directory.** Without root binding,
  request policy, redirect chain, response metadata, exact representation bytes,
  graph closure, and limits, it is not a reproducible comparison input.

## Staged acceptance gates

1. Decision gate: ADR fixes the four artifact IDs, digest boundaries, URL/fetch
   model, closure/outcome taxonomy, security ownership, and current compatibility.
2. Format gate: adversarial manifest/member validator with canonical digest,
   duplicate, traversal, hash, byte, depth, and closure tests.
3. Resolver gate: URL/XML Base/SVG/CSS cases are checked against pinned Web
   Platform Tests or equivalent primary conformance vectors.
4. Raster tracer gate: the smallest PNG/JPEG slice produces the same intrinsic
   evidence as current bundles while adding URL/request/response distinctions.
5. Recursive-family gates: CSS, fonts, nested SVG, and foreign content enter only
   with their own parser/execution/conformance decisions and exact budgets.
6. Prefetch gate: sandbox, SSRF/private-network/redirect/CORS/credential tests,
   transcript reproducibility, secret-redaction review, and no-network
   comparison tests pass before any acquisition tool is described as supported.
7. Agent gate: corpus cases prove that missing, blocked, invalid, unsupported,
   unused, exact-content, and representation-equivalent outcomes cannot be
   collapsed into equality or a generic `resource changed` statement.
