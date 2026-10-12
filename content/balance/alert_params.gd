class_name AlertParams
extends Resource
## Global Alert tier caps and consequences. Knife 3 wires most multipliers into gameplay.


@export var max_alert_level: int = 5
@export var base_hearing_radius: float = 3.2
@export var hearing_per_alert: float = 1.2
## Extra hearing scale from Alert >= 2 (on top of per-level add). Knife 3.
@export var hearing_mult_at_alert_2: float = 1.25
## Construction Hard/Soft noise multiplier when Alert >= 3. Knife 3.
@export var construction_noise_mult_from_alert_3: float = 1.3
## Awareness gain scale when Alert >= 4. Knife 3.
@export var awareness_gain_mult_at_alert_4: float = 1.35
## Quiet window scale when Alert >= 4 (< 1 shortens). Knife 3.
@export var quiet_window_mult_at_alert_4: float = 0.75
