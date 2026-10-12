class_name RouteWorkParams
extends Resource
## Night route construction tiers and Soft/Hard multipliers.


@export var route_tiers: int = 3
@export var kit_tiers: int = 2
## Per-tier base seconds: specialist = has the point's verb (Soft); non-specialist = forcing it (Hard).
@export var tier_soft_sec: float = 15.0
@export var tier_hard_sec: float = 35.0
## Hard multipliers; time stacks on tier_hard_sec (effective Hard tier = tier_hard_sec × hard_time_mult).
@export var hard_time_mult: float = 3.0
@export var hard_noise_mult: float = 2.0
@export var hard_trace_mult: float = 2.0
## Dawn: remaining traces keep this fraction of intensity (knife 2).
@export_range(0.0, 1.0) var trace_dawn_retain: float = 0.5
