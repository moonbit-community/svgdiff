# Default the Comparison DPR to one

Core v1 will use one positive finite Comparison DPR for both inputs, default it to `1.0` when omitted, and record the effective value in the Structured Report. DPR controls only the canonical raster response: exact Computed Appearance measurements preserve subpixel distinctions, while higher-scale and supersampled rerendering remain renderer QA and never become report probes or additional evidence.
