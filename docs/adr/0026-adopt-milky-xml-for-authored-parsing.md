# Adopt Milky XML for authored parsing

`Milky2018/xml@0.4.0` will own XML well-formedness, namespace resolution, entity handling, and source locations. SVG Diff will consume its `NamespaceReader` events through private Source Semantics helpers, recover raw authored spelling from the original input through the supplied spans, and keep dependency types out of the Structured Report. The project-owned `source_semantics` workspace module is removed because the dependency now satisfies the strict parsing and provenance requirements that originally justified owning that module.
