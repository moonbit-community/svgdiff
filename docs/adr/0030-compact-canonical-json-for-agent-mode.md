# Compact canonical JSON for agent mode

The `--agent-json` mode will serialize the full schema `1.0` Structured Report without formatting whitespace. It will not introduce a second projected schema or omit evidence.

The canonical report already contains the coverage, difference, magnitude, localization, and possible-cause evidence required by the text-only agent acceptance contract. A smaller lossy projection would need a new compatibility surface and could silently erase source-only differences, zero measurements, Diagnostics, or causal candidates. Whitespace compaction reduces transport and token overhead while allowing the existing JSON Schema, interpretation rules, and benchmark adapters to remain authoritative. The later `svgdiff-agent-projection/1` transport partitions complete evidence into reconstructable JSONL rather than changing this decision; any semantic summary must still be separately versioned and retain traceability to the complete report.
