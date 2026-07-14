# Version renderer conformance separately

The canonical Comparison Profile will record `renderer_conformance_profile_id` independently from `schema_version` and `renderer_id`. Schema version identifies the serialized report contract, renderer ID identifies the concrete implementation, and conformance profile ID identifies the accepted fixture, disposition, guard, and future tolerance policy used to bound Rendered Evidence claims.

The first identity is `svgdiff-renderer-conformance-profile/1`. Current producers always emit it. JSON Schema `1.0` keeps the additive property optional so previously valid `1.0` reports remain valid. A change to conformance fixtures, accepted divergences, dispositions, tolerances, or capability claims requires reviewing and normally incrementing this profile even when the renderer package and report shape do not change.
