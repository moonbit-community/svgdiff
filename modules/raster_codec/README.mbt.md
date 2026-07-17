# svgdiff-raster-codec

Project-owned bounded 8-bit non-interlaced PNG and single-scan baseline JPEG decoding plus format-level color-metadata inspection for embedded SVG raster resources.

The decoder is derived from `mizchi/image@0.1.2` under Apache-2.0. The public surface is intentionally narrow: RGBA8 output plus caller-provided dimension and pixel bounds, and read-only PNG/JPEG color metadata classified as sRGB-compatible, embedded-profile, or HDR/high-bit-depth. Inspection validates container structure and reports intrinsic dimensions without converting pixels. PNG decompression is capped at the exact validated scanline size. PNG variants with unimplemented transparency, physical-size, orientation, unknown-chunk, or animation semantics are rejected; JPEG is limited to grayscale, 4:4:4, and 4:2:0 baseline sampling.
