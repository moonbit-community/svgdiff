# Local Reference Safety

Status: current module `0.3.5` and schema `1.4` admission contract

Last verified: 2026-07-14

SVG references can consume far more work than their source size suggests. A definition DAG is acyclic, yet each definition can contain several `<use>` instances of the next definition. If every level repeats the previous level twice, the authored graph grows linearly while renderer instance count grows exponentially. The ordinary element and reference limits bound the source graph, not that transitive cloning cost.

The engine therefore builds a conservative local-reference graph from the same namespace-aware, already bounded XML event stream before invoking `mizchi/svg`. This is an admission guard, not a complete SVG resource resolver.

## Accepted edge grammar

The graph records every nonempty authored `id` and every local fragment recognized by the following fixed grammar:

- `<use href="#id">` and namespace-qualified attributes whose local name is `href` create an expanding edge to any existing ID;
- local `href="#id"` on `linearGradient`, `radialGradient`, `pattern`, `marker`, `clipPath`, `mask`, `filter`, or `symbol` creates a resource-dependency edge;
- every case-insensitive `url(#id)` token in an attribute value creates a resource-dependency edge when the target ID denotes one of those resource kinds;
- ASCII whitespace and matching single or double quotes inside `url(...)` are accepted;
- percent escapes in local fragment IDs are decoded with the pinned renderer's byte-oriented fragment rule;
- missing IDs and nonlocal values such as `other.svg#id` create no graph edge.

References found under an ID-bearing element are attached to every containing ID scope. Duplicate IDs are merged and resource-kind identity is widened. These two rules can add edges that a stricter SVG resolver would discard, but they prevent nesting or duplicate lookup behavior from hiding a possible dependency. A `url(#id)` target that is only an ordinary visual element does not create a resource edge.

Ancestor propagation could otherwise multiply the 100,000 source-reference budget by the maximum nesting depth. The graph therefore admits at most 1,000,000 materialized owner-edge instances. It checks the boundary before appending an edge and returns source-located `resource_limit_exceeded` with subject `reference_graph_edges.before` or `.after` at the first excess. This fail-closed bound keeps the conservative completeness rule from becoming its own memory-exhaustion path.

This completeness claim is relative to the accepted grammar above and the current static-input boundary. Stylesheet text, dynamic script or animation references, external resources, and unsupported reference syntaxes are not silently executed by the analyzer or renderer and remain outside this guard's claim.

## Cycle rejection

An iterative depth-first traversal checks the combined expanding and resource-dependency graph. It uses explicit arrays rather than the process call stack, so graph depth cannot create recursive traversal failure within the element and reference budgets.

The first discovered gray-edge cycle returns a failed report with `reference_cycle_detected`. Its `Diagnostic.subject_id` is `reference_cycle.before` or `reference_cycle.after`, and `source_locations` identify the reference attributes that establish the discovered cycle. Both inputs are checked independently. The renderer is not invoked when either side fails.

## Expansion upper bound

After the combined graph is proven acyclic, the engine topologically evaluates the `<use>` subgraph. For each ID definition, its cost is its authored descendant-element count plus the cost of every referenced target, retaining repeated edges because repeated `<use>` instances repeat renderer work. The document bound is its authored element count plus the target cost of every authored local `<use>`.

All additions are saturating comparisons against the inclusive production maximum of 1,000,000 expanded elements. The exact boundary is accepted; the first one-past case returns `reference_expansion_limit_exceeded` with the offending `href` span. The calculation is an upper bound: duplicate-ID merging, ancestor propagation, and counting definitions conservatively can reject a document whose actual renderer allocation would be smaller. That false-positive tradeoff is intentional. The guard must not undercount an accepted local expansion path.

## Failure report and ownership

Cycle and expansion rejection produces `analysis_status = "failed"`, failed coverage rows, stable Diagnostics, and empty alignments, facts, differences, and events. Empty inventories are not partial evidence and cannot establish equality. The CLI exits with status `1`.

`Milky2018/xml` separately owns XML entity recursion and expansion limits. Fixed source, structure, raster, region, and serialization budgets remain defined in the [resource-limit contract](resource-limits.md). Embedding callers may cooperatively cancel or set an elapsed-time budget through the [controlled library API](library-api.md); dependency calls remain non-preemptible, and streaming file admission plus hard peak-memory enforcement remain future security work.

Executable boundaries live in [`resource_limits_wbtest.mbt`](../engine/resource_limits_wbtest.mbt), while the production-CLI counterexample lives in the [adversarial corpus](../evaluation/adversarial/README.md).
