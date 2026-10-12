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
## Repeatable points (`GatherPoint.RefreshMode.REPEATABLE`, e.g. the trash bin): the fallback source.
## Each rummage takes this long and is loud (kind `gather`, never raises Alert by itself).
@export var gather_repeat_sec: float = 3.0
@export var gather_repeat_noise: float = 0.9
@export var gather_repeat_yield: int = 1
## Chance a rummage comes up empty.
@export_range(0.0, 1.0) var gather_repeat_empty_chance: float = 0.5
## After this many empty rummages in a row the next one is a guaranteed find (bounded bad luck).
@export var gather_repeat_pity: int = 2
## Finds per day (empty rummages don't count); resets at dawn.
@export var gather_repeat_daily_cap: int = 1
## Finds per run; 0 = no run cap (only the daily cap applies).
@export var gather_repeat_run_cap: int = 0
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
