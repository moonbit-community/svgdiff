# Use three CLI exit-status classes

`svgdiff` will use three stable process-status classes: `0` for a successfully produced complete or partial Structured Report, `1` for a produced report whose `analysis_status` is `failed`, and `2` for invocation or I/O errors that prevent the requested report from being produced or delivered.

A partial report exits zero because it contains usable, explicitly constrained evidence; its Diagnostics and `analysis_status` carry the coverage limitation. A failed analysis remains distinct from command and transport failures because it still produces a schema-valid report that callers should inspect. Invalid arguments and I/O failures share status `2` because neither yields the requested machine-readable report. Adding finer error identities in the future requires structured diagnostics or a separately versioned CLI contract rather than silently reassigning these statuses.
