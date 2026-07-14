# Anchor v1 Visual Events to one Subject Alignment

Status: refined by ADR-0041

Every core v1 Visual Event will have exactly one Primary Subject Alignment and group the Atomic Differences attached to that alignment; related resource Differences may be referenced as context, and the resulting rendered regions need not be spatially connected. Cross-subject event aggregation is deferred because it affects report readability rather than the completeness of Atomic Differences or Cause Envelopes, and outcome-coherence heuristics would add substantial complexity before the core comparison model has been validated.
