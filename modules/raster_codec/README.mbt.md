# svgdiff-raster-codec

Project-owned bounded 8-bit non-interlaced PNG and single-scan baseline JPEG decoding for embedded SVG raster resources.

The decoder is derived from `mizchi/image@0.1.2` under Apache-2.0. The public surface is intentionally narrow: RGBA8 output plus caller-provided dimension and pixel bounds. PNG decompression is capped at the exact validated scanline size. PNG variants with unimplemented transparency, color, physical-size, orientation, unknown-chunk, or animation semantics are rejected; JPEG is limited to grayscale, 4:4:4, and 4:2:0 baseline sampling.
