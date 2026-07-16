# Preserve separate event-local FLIP statistics

## Context

An event-local FLIP map preserves spatial evidence, but a text-only consumer should not need to decode its quantized payload and choose an unstated denominator. A whole-canvas mean can hide a small intense change, while pooling only changed pixels can hide spatial response outside those pixels. Thresholded area is useful only when the threshold and denominator are explicit.

The NVIDIA FLIP reference computes the ordinary mean over the complete input image and also exposes weighted pooled summaries. Its CLI has a configurable default `0.05` threshold for pass/fail testing of a selected aggregate. That value does not define a pixel visibility boundary or area statistic.

## Decision

For every computed event-local LDR-FLIP map, report `event_local_ldr_flip_pooling/v1` statistics directly from the unquantized internal values. Keep these sampling domains separate:

- `canvas_mean` divides the complete-response sum by the whole comparison canvas pixel count; pixels outside the complete response are exact zero by construction;
- `event_region_mean` samples only raw-different pixels selected by the event's Difference Regions;
- `response_p95` is nearest-rank p95 over every pixel inside the serialized complete response bounds;
- `response_maximum` is the maximum over those response pixels.

Record all three sample counts so zero and unavailable evidence cannot be confused. Empty computed maps use zero event and response counts and zero statistics while retaining the canvas count.

Add an optional invariant-checked FLIP error threshold to the Comparison Profile and CLI. With no threshold, `area_above_threshold` is null. With one, record the exact threshold, the count of response pixels strictly greater than it, and that count divided by the whole canvas pixel count. Do not supply a default and do not describe this reporting threshold as a just-noticeable difference, visibility, severity, equality, or Impact Assessment boundary.

## Consequences

Agents can distinguish diffuse, concentrated, typical-tail, worst-case, and spatial-extent evidence without decoding base64 or conflating sampling domains. The map remains the spatial source of truth, while statistics remain deterministic derived evidence unaffected by uint16 transport quantization.

The additional profile and computed-evidence fields advance Structured Report schema to `1.42` and module version to `0.5.22`; renderer identity, conformance profile, raw transparent-canvas evidence, DeltaEOK, equality, Diagnostics, coverage, causes, and ordering remain unchanged.
