# Embedded Raster Resource Policy Evidence

Status: implementation-grounded research note

Last verified: 2026-07-15

## Normative boundary

[SVG 2 embedded content](https://svgwg.org/svg2-draft/embedded.html#ImageElement) defines `image` as rendering a complete referenced file and requires conforming SVG viewers to support PNG, JPEG, and SVG image formats. It also makes intrinsic dimensions and `preserveAspectRatio` part of fitting the referenced image into its viewport. This implementation admits PNG and JPEG only; SVG image resources remain deferred because nested SVG introduces another document, resource graph, scripting, and renderer boundary.

[RFC 2397](https://www.rfc-editor.org/rfc/rfc2397) defines `data:[<mediatype>][;base64],<data>`. Without `;base64`, octets use URL-escaped encoding. The SVG diff policy is intentionally stricter: the media type may contain ordinary parameters but must explicitly identify `image/png` or `image/jpeg`; omitted media types and all other formats are unsupported. Base64 syntax is validated before decoding, percent escapes must be complete hexadecimal byte escapes, and non-ASCII literal payload characters are rejected.

[PNG Third Edition](https://www.w3.org/TR/png-3/) defines the signature, IHDR dimensions and color information, chunk CRCs, compressed image data, and scanline filters. The project validates the PNG structure and IHDR before normalized image allocation, calculates the exact admitted decompressed scanline length from validated dimensions and color type, and passes that length as the zlib output ceiling. A small IHDR cannot therefore authorize an arbitrarily large decompressed buffer. The current normalized-pixel claim is deliberately limited to 8-bit non-interlaced inputs whose transparency, color, physical-size, orientation, unknown-chunk, and animation semantics are all implemented or absent; other valid PNG variants are diagnosed rather than decoded approximately. JPEG admission is likewise limited to one baseline scan with grayscale, 4:4:4, or 4:2:0 sampling.

## MoonBit dependency evidence

The resolved `mizchi/svg@0.2.1` source handles `data:image/svg+xml` image content but has no PNG or JPEG image-compositing path. Browser fixtures confirm that Chromium paints the admitted PNG and JPEG while the pinned renderer leaves those pixels absent. Renderer conformance profile `20` therefore assigns both divergences to `renderer_embedded_raster_unavailable`.

Direct trials of `mizchi/image@0.1.2` and `mizchi/image@0.4.2` failed project checking in packaged upstream tests: `assert_eq` requires `Debug` for image types that do not derive it. The decoding implementation itself is usable, but changing those upstream tests or patching the cache would make the build non-reproducible. The workspace therefore owns the narrow bounded decoder module derived from `0.1.2`, retains Apache-2.0 attribution, and upgrades only its zlib dependency to `mizchi/zlib@0.4.6` for bounded decompression.

## Evidence layers

The source locator, decoded resource, placed image, and final canvas are distinct evidence layers:

1. the exact Source Span proves which locator was authored;
2. encoded-byte hash, MIME, encoding, and byte length identify the admitted resource representation;
3. intrinsic width, height, normalized RGBA8 hash, and pixel metrics identify decoded visual content;
4. x/y/width/height, preserveAspectRatio, opacity, and cumulative transform describe admitted placement;
5. final-canvas evidence additionally requires image sampling, clipping, stacking, and compositing.

Only layers one through four are currently computed. `IntrinsicRasterMagnitude` is therefore a separate nullable object inside the difference magnitude vector. It records both dimensions on every content change; when dimensions match, it also records compared pixels, changed pixels, changed-pixel fraction, RGBA8 RMSE, and linear-sRGB premultiplied-RGBA RMSE. Dimension-mismatched images retain dimensions but leave per-pixel metrics null rather than inventing a resampling policy.

## Security and deferred work

The comparison engine never follows external image locators and never reads a path named inside SVG. Data-URL source bytes, decoded bytes, dimensions, per-image pixels, cumulative pixels, and decompressed PNG output are bounded. Reports replace payloads with hashes and retain the exact value only indirectly through the caller-owned source plus Source Span.

Caller-supplied local raster bundles are implemented under the separate [local resource bundle policy](local-resource-bundle-policy.md), and missing, cyclic, invalid, and unused cross-resource outcomes follow the current [Resource Outcome Policy](../resource-outcome-policy.md). Network-backed acquisition, if ever supported, must be an explicit prefetch step outside comparison. Embedded SVG and final image compositing remain deferred until their complete deterministic execution and conformance profiles are accepted.
