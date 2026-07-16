# Partition canonical reports into lossless Agent JSONL

Limited-context Agents should not need to ingest one complete Structured Report object before they can inspect its Impact header, one Atomic Difference, or one Visual Event. Whitespace compaction alone reduces transport bytes but does not reduce the maximum semantic unit that must be loaded. A lossy summary would create a second truth surface and could erase source-only differences, zero or unavailable measurements, Diagnostics, or conservative causes.

Add a separately versioned `svgdiff-agent-projection/1` JSONL transport. One header retains every non-array top-level field and exact section counts. Ordered item records retain every canonical array value with its section, section index, global sequence, and source Schema identity. The complete stream must reconstruct the canonical Structured Report exactly; missing, duplicated, reordered, miscounted, or mislabeled records are invalid.

This is a transport projection, not a report-schema change or importance policy. `--agent-json` remains whitespace-only canonical JSON, default JSON remains unchanged, and both remain authoritative. The projection may be larger in total because of record envelopes, but each accepted fixture has a largest record smaller than its complete compact report. Consumers gain line-addressable evidence without losing canonical traceability.
