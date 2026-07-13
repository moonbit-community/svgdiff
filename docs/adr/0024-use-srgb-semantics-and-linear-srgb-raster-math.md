# Use sRGB semantics and linear-sRGB raster math

Core v1 will default SVG and CSS color interpretation to sRGB and compute blending and numeric raster evidence in linear-sRGB premultiplied RGBA, recording both choices in the Structured Report. Embedded ICC profiles and wide-gamut content will produce Diagnostics and reduced Analysis Coverage rather than being silently converted, because gamma-encoded arithmetic or unreported gamut mapping would make color magnitudes misleading.
