class_name ActionCostTable
extends Resource
## Unified action cost lookup. Knife 2+ reads Soft/Hard/trace; gather keys reserved for phase B.


@export var soft_interact_sec: float = 0.45
@export var hard_interact_sec: float = 2.0
@export var gather_sec: float = 0.7
@export var gather_poor_sec: float = 2.0
## Reserved for R6 / phase B (defaults match current gather; no extra risk yet).
@export var gather_risky_sec: float = 0.7
@export var gather_risky_noise: float = 0.0
@export var gather_risky_trace: float = 0.0
@export var shout_cooldown_sec: float = 6.0
@export var shout_loudness: float = 0.85
@export var throw_cooldown_sec: float = 8.0
@export var throw_loudness: float = 0.7
## Carrying any heavy item: multiply planar move speed (0.6 = −40%).
@export var heavy_speed_mult: float = 0.6


func interact_seconds(soft: bool) -> float:
	return soft_interact_sec if soft else hard_interact_sec


func gather_seconds(has_verb: bool) -> float:
	return gather_sec if has_verb else gather_poor_sec
