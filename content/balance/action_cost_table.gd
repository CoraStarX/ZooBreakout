class_name ActionCostTable
extends Resource
## Unified action cost lookup. Knife 2+ reads Soft/Hard/trace; gather keys reserved for phase B.


@export var soft_interact_sec: float = 0.45
@export var hard_interact_sec: float = 2.0
@export var gather_sec: float = 0.7
@export var gather_poor_sec: float = 2.0
## Gather B (`GatherPoint.risky` / POINTS "risky": true). Defaults = no extra risk; R6 sets real values.
@export var gather_risky_sec: float = 0.7
@export var gather_risky_noise: float = 0.0
@export var gather_risky_trace: float = 0.0
@export var shout_cooldown_sec: float = 6.0
@export var shout_loudness: float = 0.85
@export var throw_cooldown_sec: float = 8.0
## Landing noise (staff hear it at the landing spot, not at the thrower).
@export var throw_loudness: float = 0.7
## How far ahead the stone lands (walls stop it short).
@export var throw_range: float = 7.0
@export var throw_flight_sec: float = 0.45
## Carrying any heavy item: multiply planar move speed (0.6 = −40%).
@export var heavy_speed_mult: float = 0.6


func interact_seconds(soft: bool) -> float:
	return soft_interact_sec if soft else hard_interact_sec


func gather_seconds(has_verb: bool) -> float:
	return gather_sec if has_verb else gather_poor_sec
