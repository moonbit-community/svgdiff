# Query-Conditioned Semantic Concern Evaluation

Status: accepted policy evaluation

Last verified: 2026-07-16

This evaluation proves the boundary between context-free visual Impact and caller-supplied semantic concern. It does not teach svgdiff what an indicator, logo, warning icon, or other business concept means.

The fixture contains two independent fill changes in one `16 x 16` viewport. One changes `64` pixels; the caller-designated target changes one pixel. Under `event_rendered_pareto/v1`, the larger event dominates the target in both `changed_pixel_fraction` and `linear_premultiplied_rgba_rmse`, so only the larger event enters the main frontier.

The target selector is stored in the evaluation manifest, outside both SVG inputs and the production report. It identifies the target by an expected region and difference domain rather than treating an authored ID as an intrinsic importance label. The evaluator then proves that:

- the target remains in the full Visual Event and Atomic Difference inventories;
- its Difference Region, Changed Facts, and sound Cause Envelope references resolve;
- its exclusion from the frontier has an explicit domination witness;
- `--agent-json` preserves the same event, differences, attribution evidence, and Impact Assessment;
- no semantic-concern or business-importance field is inferred into the report.

Run:

```sh
scripts/test-semantic-concern-policy.sh
```

The committed [`results.v1.json`](results.v1.json) is regenerated only with:

```sh
moon build --target native --release modules/svgdiff/cmd/svgdiff
python3 evaluation/semantic-concern/evaluate.py \
  --cli _build/native/release/build/Milky2018/svgdiff/cmd/svgdiff/svgdiff.exe \
  --update
```

The accepted consumer rule is query-conditioned: if external task context identifies a concern that resolves to a reported subject, event, difference, source fact, or region, the consumer must report every matching item even when it is dominated. If the context cannot be resolved to report evidence, semantic importance is unknown. In either case, the complete difference inventory remains mandatory.

The accepted policy was established under Schema `1.43` and module version `0.5.23`. This active regression now replays it under current Schema `4.0`; the Impact policy, complete inventories, query-conditioned interpretation, and rejection of production concern fields remain unchanged.
