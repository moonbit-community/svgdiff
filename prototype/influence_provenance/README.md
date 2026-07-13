# Influence Provenance Prototype

**PROTOTYPE — throw this code away after the design question is answered.**

Run it with:

```sh
moon run --target native prototype/influence_provenance
```

## Question

Can conservative Changed Fact token propagation produce a Cause Envelope that always contains the injected actual causes across direct paint, before/after movement, filter expansion, compositing, and unknown-operation fallback, while explicitly refusing to claim completeness when coverage is incomplete?

The prototype contains a six-tile deterministic toy renderer. Its paint, blur, and composite operations calculate both output values and conservative provenance; Difference Regions are derived by comparing the two outputs rather than prefilled. It does not parse or render SVG and therefore validates the state model and soundness discipline, not renderer integration.

Select scenarios by entering the displayed key followed by Return. Use `a` to run the complete scenario suite and `q` to quit.

Scenario 7 is a real integration spike. It parses and renders SVG with `mizchi/svg`, compares the resulting images with `mizchi/pixelmatch`, maps the resulting Difference Regions back to a conservative Cause Envelope, and measures the raster effect of `1.0 -> 0.99999` and `1.0 -> 1.00001` geometry changes.
