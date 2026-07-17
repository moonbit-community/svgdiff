# Incremental and Cache Investigation Artifact

`candidates.v1.json` is the machine-checkable summary of the accepted `svgdiff-cache-investigation/1` outcome. It inventories every investigated cache shape, the complete future exact-result key groups, non-negotiable invariants, and reconsideration evidence.

Run:

```sh
python3 evaluation/cache-investigation/validate.py
```

The validator also runs negative controls that remove one key group and attempt to accept graph-incremental or remote reuse prematurely.
