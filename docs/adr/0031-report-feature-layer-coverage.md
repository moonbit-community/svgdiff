# Report coverage per feature and evidence layer

The Structured Report will contain a deterministic `coverage_matrix`. Each row names an encountered feature and subject, records coverage independently for Source Semantics, Computed Appearance, and Rendered Evidence, and references Diagnostics that explain limitations. Cell status is one of `covered`, `limited`, `not_applicable`, or `failed`.

The engine derives top-level `analysis_status` from the strongest matrix cell instead of treating it as an independent analyzer label. Feature discovery and row construction remain behind the engine module interface; callers receive only stable feature IDs and evidence-layer claims. The field is additive and optional in the schema `1.0` validator so previously emitted reports remain valid, while current producers always emit it. A later schema policy may make the field required in a new compatibility version.
