# Own only the smallest failing renderer layer

SVG Diff will adopt rendering dependencies capability by capability rather than treating a renderer as an indivisible choice. A passing parser, scene graph, resolver, rasterizer, or image-difference component may remain in use even when another component fails its acceptance cases.

When a required capability cannot be obtained from a community dependency or a focused upstream extension, the project will create a separate MoonBit module for the smallest failing layer and manage it through the repository workspace. Dependency-specific types remain behind the internal renderer seam. A failure in raster fidelity does not by itself justify rewriting SVG parsing or scene construction.

For the current candidates, `mizchi/svg` remains accepted provisionally for parsing, public scene inspection, and baseline localization. The next experiment evaluates `mizchi/canvas` as a higher-fidelity raster path. A project-owned workspace module will be proposed only if that experiment identifies a concrete unmet requirement.

The first `mizchi/canvas` experiment passed its directional-symmetry and scaled-response criteria when measured in premultiplied RGBA. Its current blocker is instead a one-line test-compatibility defect in transitive `mizchi/image@0.4.2`. This remains below the threshold for owning a renderer module: pursue a focused upstream fix or version update first.
