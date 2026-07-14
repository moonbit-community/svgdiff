# Version product contracts independently

The MoonBit module, Structured Report schema, Diagnostic vocabulary, Domain Ordering policy, and renderer conformance profile have different compatibility boundaries and will not share one lockstep version.

The module uses SemVer, with `0.MINOR` reserved for breaking pre-1.0 changes and `0.MINOR.PATCH` kept backward-compatible. The report uses a `MAJOR.MINOR` schema identity: compatible serialized additions increment MINOR, while changes that can make an old consumer reject or misinterpret a report increment MAJOR. Diagnostic codes are stable open-string discriminators governed by report-schema semantics. Every ordering-tuple semantic change allocates a new opaque policy ID, and tuples from different IDs are incomparable.

This separation lets consumers dispatch on the contract they actually interpret. Release review must still consider all domains together and update every affected identity. Historical optional schema `1.0` additions are not rewritten; the allocation rules apply after this decision.
