class_name RunLifecycle
extends RefCounted
## Cross-scene run state reset (new run / back to title). Lives in GamePlay: Core must not know Alert/Clock.


static func reset() -> void:
	Game.work_time_scale = 1.0
	Alert.level = 0
	OfficeStorage.take_all()
	Clock.reset_for_new_run()
