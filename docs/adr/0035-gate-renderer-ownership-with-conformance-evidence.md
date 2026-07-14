# Gate renderer ownership with conformance evidence

SVG Diff will not use a renderer-wide pass percentage or pixel-error magnitude to decide whether to own rendering code. Complete-eligible cases require zero unexplained divergences, but ownership is a separate maintenance decision.

One minimized dependency-owned failure is enough to pursue a focused upstream patch. A project-owned MoonBit layer becomes eligible only when an accepted active milestone is blocked, the smallest failing seam is named, no released dependency satisfies it, upstream is demonstrably non-viable, maintenance responsibility is explicit, and at least three independent cases satisfy either the breadth or project-specific-control trigger defined in the [Renderer Upstream and Ownership Gate](../renderer-ownership-gate.md).

Passing this gate authorizes a separate ownership ADR and bounded module issue. It never authorizes replacing passing parser, scene, image, or comparison layers.
