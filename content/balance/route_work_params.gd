class_name RouteWorkParams
extends Resource
## Night route construction tiers and Soft/Hard multipliers.


@export var route_tiers: int = 3
@export var kit_tiers: int = 2
@export var tier_soft_sec: float = 6.0
@export var tier_hard_sec: float = 14.0
## Applied when Hard is allowed (knife 2 wires these into Interactable).
@export var hard_time_mult: float = 3.0
@export var hard_noise_mult: float = 2.0
@export var hard_trace_mult: float = 2.0
## Dawn: remaining traces keep this fraction of intensity (knife 2).
@export_range(0.0, 1.0) var trace_dawn_retain: float = 0.5
