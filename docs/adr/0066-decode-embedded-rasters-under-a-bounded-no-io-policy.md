# Decode embedded rasters under a bounded no-I/O policy

Status: accepted and implemented for an explicit PNG/baseline-JPEG data-URL subset

## Context

An `image` locator is not itself visual evidence. Two different data-URL spellings may decode to identical pixels, while a one-byte source edit may replace every pixel. Conversely, decoding a resource does not prove its final SVG contribution: placement, fitting, transforms, opacity, clipping, interpolation, stacking, and compositing still mediate the final canvas. The pinned `mizchi/svg@0.2.1` renderer decodes nested SVG data URLs but does not composite PNG or JPEG image resources.

The current `mizchi/image` releases could not be used directly because their packaged dependency tests require `Debug` implementations that their public image types do not provide. This upstream test-only failure does not justify patching the dependency cache or changing upstream assertions.

## Decision

Admit only explicit case-insensitive `image/png` and `image/jpeg` data URLs on `image` elements. Accept RFC 2397 base64 and percent-encoded byte payloads. The implemented decoder slice is 8-bit non-interlaced PNG without unimplemented transparency, color-management, physical-size, metadata-orientation, unknown-chunk, or animation semantics, plus single-scan baseline JPEG in grayscale, 4:4:4, or 4:2:0 sampling. Other valid variants remain partial through `embedded_raster_variant_unsupported`. Require the declared MIME type, byte signature, and decoder to agree. Do not sniff another format, fetch a URL, read a path, resolve nested SVG, or perform any comparison-time I/O beyond the two caller-supplied SVG inputs.

Bound data-URL source bytes, decoded bytes, per-image dimensions, per-image pixels, cumulative pixels, and PNG decompressed scanline output. Validate dimensions before allocating normalized RGBA8 storage. A resource-limit crossing fails admission; malformed, unsupported, external, or undecodable content remains source-located partial analysis.

Maintain a small separately publishable workspace module, `Milky2018/svgdiff-raster-codec`, derived from the Apache-2.0 production decoder code in `mizchi/image@0.1.2`. Its public API exposes only bounded PNG and JPEG decode operations and uses `mizchi/zlib@0.4.6` with an exact PNG scanline-output ceiling. Keep attribution in the module and do not expand it into a general image library.

Retain exact locator provenance through its Source Span, but serialize only compact encoded-byte and normalized-RGBA8 hashes, MIME, encoding, byte count, and dimensions. Align image subjects by unique authored ID and then stable image source order. Report source encoding, intrinsic dimensions, normalized content, placement, fitting, opacity, transform, insertion, and deletion as separate distinctions.

Serialize intrinsic decoded-raster measurements in `DifferenceMagnitude.intrinsic_raster`. Never copy them into final-canvas `RenderedEvidence`. Every admitted image records `renderer_embedded_raster_unavailable`; mixed scenes also downgrade final raster outcomes because an omitted image can alter overlap and compositing anywhere in its bounds.

## Consequences

Text-only Agents can distinguish representation-only image changes from decoded visual changes and can rank same-size content changes by exact changed-pixel fraction and RGBA error. Image bounds remain hoverable even when final pixels are unavailable. Payloads do not inflate the report or become an accidental data-exfiltration surface.

Schema `1.23` adds the intrinsic raster magnitude, and renderer conformance profile `20` records PNG and JPEG divergence against Chromium. The current report remains partial for every encountered embedded raster because final compositing is unavailable.

Embedded SVG, external and caller-bundled resources, image interpolation, complete preserveAspectRatio compositing, referenced images inside deferred resources, and a renderer implementation remain later roadmap items. The codec module must be published before a registry release of the root module can depend on it.
