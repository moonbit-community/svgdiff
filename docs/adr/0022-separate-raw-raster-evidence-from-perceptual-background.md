# Separate raw raster evidence from the Perceptual Background

Core v1 will always retain linear premultiplied-RGBA evidence rendered on a transparent canvas, while display-dependent perceptual metrics will be computed only after both inputs are composited over the same explicitly declared Perceptual Background. No background is guessed: when it is absent, perceptual metrics are marked `not_computed`, but geometry, coverage, alpha, raw raster evidence, and Analysis Coverage remain available.
