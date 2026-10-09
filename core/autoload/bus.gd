extends Node
## Global signal bus — keep thin; prefer local signals when possible.

signal animal_switched(animal: Node3D)
signal animal_rescued(animal_id: StringName)
signal interact_feedback(message: String)
signal captured(animal: Node3D)
signal alert_changed(level: int)
signal phase_changed(phase: int)
signal intel_gained(id: StringName)
signal material_gathered(id: StringName, amount: int)
signal day_changed(day: int)
signal day_summary(day: int, lines: PackedStringArray)
signal breach_changed(value: float)
signal office_items_changed(items: Array)
signal detention_changed(animal: Node3D)
signal run_outcome_changed(outcome: int)
