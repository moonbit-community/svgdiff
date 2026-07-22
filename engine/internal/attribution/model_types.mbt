///|
using @model {
  type AtomicDifference,
  type ChangedFact,
  type Diagnostic,
  type DiagnosticSourceLocation,
  type DifferenceRegion,
  type ImpactAssessment,
  type ImpactDominationWitness,
  type ImpactFrontierGroup,
  type ImpactMeasurement,
  type StructuredReport,
  type SubjectAlignment,
  type SubjectReference,
  type VisualEvent,
}

///|
using @source_semantics {
  type ParsedResourceLocator,
  generated_subject_id,
  parse_resource_locator,
  resource_url_locators,
  source_slice,
}

///|
using @report_support {diagnostic_location_from_xml, same_diagnostic_location}

///|
using @resource_model {type ResourceLimits, resource_limit_diagnostic}
