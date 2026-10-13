class_name RouteWorkParams
extends Resource
## Night route construction tiers and Soft/Hard multipliers.


@export var route_tiers: int = 3
@export var kit_tiers: int = 2
## Seconds of work for one tier by a specialist (has the point's verb = Soft).
## Hard (forcing it) = tier_soft_sec × hard_time_mult. Progress carries over between nights.
@export var tier_soft_sec: float = 15.0
## Hard multipliers. Non-final Hard tiers cost no materials: the price is time, noise and a trace.
@export var hard_time_mult: float = 3.0
@export var hard_noise_mult: float = 2.0
@export var hard_trace_mult: float = 2.0
## Dawn: remaining traces keep this fraction of intensity (knife 2).
@export_range(0.0, 1.0) var trace_dawn_retain: float = 0.5
## A tier left half-done at dawn marks the site once with a trace of this intensity.
@export var overnight_trace_intensity: float = 1.0
## Night-patrol share of time a work spot sits in some staff member's vision (tuning target, F3 shows live).
@export_range(0.0, 1.0) var exposure_target_min: float = 0.4
@export_range(0.0, 1.0) var exposure_target_max: float = 0.6
