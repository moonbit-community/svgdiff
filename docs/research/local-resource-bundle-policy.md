# Explicit Local Resource Bundle Policy

Status: implementation-grounded policy note

Last verified: 2026-07-15

## Question

How can a comparison resolve non-data-URL raster images reproducibly without granting an SVG document filesystem or network authority?

## Implemented answer

Resource acquisition belongs to the caller. The root API accepts separate before and after `ResourceBundle` values. Each ordered entry contains an opaque locator, an explicit media type, and bytes. Resolution trims the authored `image` locator and performs one case-sensitive exact match against the corresponding bundle. It does not resolve relative paths, apply a base URL, percent-decode or canonicalize the key, follow redirects, inspect the current directory, or fetch a network URL.

The CLI exposes the same boundary through repeatable `--before-resource LOCATOR MEDIA_TYPE FILE` and `--after-resource LOCATOR MEDIA_TYPE FILE` triplets. It reads exactly those named files before comparison. The file path is acquisition input only: it is not used as locator identity and is never serialized in the report.

## Admission and evidence

Bundle configuration is validated before SVG analysis. Empty, fragment-only, and `data:` keys are reserved; duplicate trimmed keys are invalid; media types must be `image/png` or `image/jpeg`; and entry count, per-entry bytes, and total bytes are fixed-budget inputs. Configuration failure produces a small failed report. Content signatures, decoder behavior, dimensions, and pixels are validated when a referenced entry reaches the existing bounded raster decoder. A referenced locator with no entry produces source-located partial coverage through `resource_bundle_entry_missing`.

Decoded bundle bytes use the same normalized RGBA8 representation, encoded and pixel hashes, intrinsic dimensions, image placement facts, magnitudes, conservative bounds, and final-compositing gap as data URLs. The report never contains resource bytes. The same locator may map to different bytes in before and after, which reports a resource content change without inventing an authored locator change.

## Unused entries and deferred boundary

An entry with valid global configuration is decoded only when an authored `image` locator selects it. Unused payload bytes are caller acquisition context, not SVG source: the engine neither validates their image signature nor compares them as visual differences. Entry keys, declared MIME types, duplicate detection, counts, per-entry bytes, and cumulative bytes remain global admission checks because the caller has already supplied that input. The cross-family rationale is defined by the [Resource Outcome Policy](../resource-outcome-policy.md).

This policy covers PNG/JPEG `image` consumers only. It does not resolve nested SVG documents, fonts, stylesheets, external gradients or patterns, or arbitrary graph edges. Network acquisition, if ever offered, must remain an explicit caller-side prefetch operation rather than comparison-time behavior.
