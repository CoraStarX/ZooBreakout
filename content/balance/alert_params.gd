class_name AlertParams
extends Resource
## Global Alert tier caps and consequences (read through the Alert autoload).
## Tiers: 2 hearing · 3 construction noise + ground items confiscated · 4 awareness/quiet window + warning · 5 full search.


@export var max_alert_level: int = 5
@export var base_hearing_radius: float = 3.2
@export var hearing_per_alert: float = 1.2
## Staff hearing range scale (footsteps + noises) from Alert >= 2.
@export var hearing_mult_at_alert_2: float = 1.25
## How far staff hear construction noise, scale from Alert >= 3.
@export var construction_noise_mult_from_alert_3: float = 1.3
## From this Alert, staff confiscate dropped items they see (route-point stash is never taken).
@export var ground_confiscate_from_alert: int = 3
## Awareness gain scale when Alert >= 4.
@export var awareness_gain_mult_at_alert_4: float = 1.35
## Quiet window scale when Alert >= 4 (< 1 shortens).
@export var quiet_window_mult_at_alert_4: float = 0.75
## Full search (max Alert): staff keep patrolling through what would be the quiet window.
@export var full_search_cancels_quiet: bool = true
## Full search: patrol heat pinned on route points and the last known animal position (existing heat weight).
## Must outweigh staleness (seconds since visit; never-visited points ≈ 1e4) to keep the staff there.
@export var full_search_focus_heat: float = 10000.0
