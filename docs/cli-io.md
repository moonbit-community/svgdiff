# CLI Input and Output Contract

Status: current command contract

Last verified: 2026-07-23

## Inputs

Both `svgdiff` and `svgdiff_miniio` implement this contract and require two positional SVG operands. A path reads a UTF-8 file. `-` reads one complete UTF-8 SVG document from stdin. MiniIO paths must be visible through the WASI host's preopened directories.

| Invocation shape | Meaning |
| --- | --- |
| `svgdiff before.svg after.svg` | Read both inputs from files. |
| `cat before.svg \| svgdiff - after.svg` | Read the before SVG from stdin. |
| `cat after.svg \| svgdiff before.svg -` | Read the after SVG from stdin. |
| `svgdiff - -` | Invalid: one stdin stream cannot supply two independently bounded documents. |
| `svgdiff before.svg after.svg --before-resource '{"locator":"asset.png","media_type":"image/png","path":"before.png"}' --after-resource '{"locator":"asset.png","media_type":"image/png","path":"after.png"}'` | Supply exact-match bytes for `asset.png` independently on each side. |
| `svgdiff before.svg after.svg --perceptual-background white` | Record one normalized opaque sRGB8 Perceptual Background without changing current transparent-canvas raw evidence. |
| `svgdiff before.svg after.svg --perceptual-background white --flip-pixels-per-degree 67` | Compute optional event-local LDR-FLIP maps under explicitly recorded pixels-per-degree Viewing Conditions. |
| `svgdiff before.svg after.svg --max-checkpoints 1000000` | Stop with exit status `1` if deterministic engine work exceeds the explicit checkpoint budget. |

Missing positional operands never imply stdin. Resource options are repeatable single-value options; each value is a JSON object with string `locator`, `media_type`, and `path` fields, and `path` may not be `-`. The CLI reads only those explicitly named resource files, and the engine treats each locator as an opaque key rather than opening it as a path. `--perceptual-background COLOR` accepts only deterministic resolved opaque sRGB colors; contextual, system, invalid, and translucent values are rejected before comparison. `--flip-pixels-per-degree PPD` accepts only finite values in `[1, 4096]`, records the exact value, and does not imply a background; both options are required for computed FLIP maps. `--max-checkpoints N` accepts a positive integer; omission means unlimited deterministic work. The command reads the complete SVG stream and explicit resource files before comparison, then the engine applies the fixed source and bundle budgets before XML or image analysis. This bounds comparison work but not the CLI's initial file-read allocation; streaming admission remains future work.

## Outputs

| Condition | stdout | stderr |
| --- | --- | --- |
| Default comparison | One canonical Structured Report JSON document followed by a newline | Empty on success |
| `--agent-json` | One whitespace-free canonical Structured Report JSON document followed by a newline | Empty on success |
| `--agent-projection` | One lossless `svgdiff-agent-projection/1` JSONL stream followed by a newline | Empty on success |
| `--output report.json` | Empty | Empty on success; the selected canonical JSON or projection JSONL is written to the selected file |
| `--html report.html` | Unchanged from the JSON rule | Empty on success; HTML is written independently |
| `--summary summary.md` | Unchanged from the selected JSON or JSONL rule | Empty on success; derived non-authoritative Markdown is written independently |
| `--help` or `--version` | Requested informational text | Empty |
| Invalid argument or I/O failure | Empty | Human-readable error |
| Analysis status `failed` | A parseable failed Structured Report unless `--output` is used | Empty unless a separate I/O error occurs |

The stable exit statuses associated with these outcomes are defined in [`cli-exit-codes.md`](cli-exit-codes.md). They preserve the stdout/stderr separation above.

## Rationale

Machine callers can safely parse stdout as one JSON document in the default and `--agent-json` modes, or as versioned JSONL records under `--agent-projection`. The two Agent output modes are mutually exclusive. `--summary` never replaces stdout and the generated Markdown never replaces canonical evidence. Explicit stdin avoids accidental blocking when arguments are missing. Rejecting two stream operands keeps the interface simple and leaves any future framed multi-document input protocol as a separate decision.
