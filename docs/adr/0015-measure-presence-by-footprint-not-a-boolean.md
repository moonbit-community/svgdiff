# Measure presence by footprint rather than a boolean

Insertion and deletion are categorical Difference Domains, but their magnitude is a vector measured from the side on which the content exists: entity count, geometric extent, painted coverage, viewport fraction, and continuous Rendered Evidence. SVG Diff will not assign presence a boolean magnitude or fixed score because a large transparent insertion, a tiny opaque deletion, and a full-canvas replacement have materially different numeric footprints.
