# Resolve only explicit caller-supplied raster bundles

Status: accepted and implemented for PNG/JPEG `image` consumers

## Context

An SVG locator such as `assets/photo.png` does not provide reproducible bytes by itself. Treating it as a filesystem path depends on the current directory and grants document-controlled file access; fetching it as a URL introduces network, redirect, cache, authentication, and timing state. Before and after may also intentionally require different bytes behind the same authored locator.

## Decision

Make resource acquisition an explicit caller responsibility. Accept separate ordered before and after bundles whose entries contain an opaque locator, explicit MIME type, and bytes. Match a trimmed SVG `image` locator case-sensitively and exactly. Do not interpret bundle keys as paths or URLs, normalize them, resolve a base, percent-decode them, or perform engine I/O.

Reserve empty, fragment-only, and `data:` keys; reject duplicate trimmed locators and unsupported MIME types before source analysis. Bound entry count, each entry, and cumulative bytes. Pass only referenced `image/png` and `image/jpeg` entries through the existing bounded decoder, intrinsic evidence, alignment, magnitude, and placement pipeline. Treat a missing entry as source-located partial coverage. Keep invalid bundle configuration as failed admission, but defer unused-content validation and general cross-resource missing, cycle, invalid, and unused rules to the following roadmap item.

Expose `compare_with_resources` and `compare_with_control_and_resources` from the root package. Let the CLI construct the same bundles only from explicit repeated before/after locator, MIME, and file triplets. Never serialize payload bytes or acquisition file paths. Keep final image composition unavailable under the existing renderer capability gap.

## Consequences

Comparisons are reproducible from closed caller-owned inputs and can distinguish different resources behind one locator without ambient state. Exact matching can reject keys that a browser URL resolver would consider equivalent; that is intentional because no base-URL contract exists. Bundle limits include unused entries because callers already supplied and allocated them, while content validity of unused entries remains deferred until unused-resource semantics are defined.

Module `0.5.4` adds the public bundle operations and CLI syntax. New missing, invalid-configuration, and resource-limit Diagnostic conditions advance Structured Report schema to `1.24`. Renderer identity, conformance profile `/20`, intrinsic metric meaning, and ordering policy remain unchanged.
