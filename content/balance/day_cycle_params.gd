class_name DayCycleParams
extends Resource
## Open / Close / night lengths and run deadline. Tunable without code changes.


@export var open_phase_sec: float = 180.0
@export var close_phase_sec: float = 15.0
@export var night_patrol_base_sec: float = 28.0
@export var night_patrol_per_alert_sec: float = 8.0
@export var night_quiet_sec: float = 32.0
## Day index that ends the run if still not escaped (1-based).
@export var deadline_day: int = 5
## Player shout uses per day (knife 4 wires this).
@export var shout_daily_limit: int = 4
