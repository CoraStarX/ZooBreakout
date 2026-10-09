class_name RouteHelper
extends RefCounted
## Test helper: complete every construction tier of a route point (night work), fast.


## auto_supply = true tops up parts so only the mechanics are under test; false = play with what is carried.
static func finish(tree: SceneTree, it: Interactable, actor: AnimalActor, auto_supply: bool = true) -> void:
	Game.work_time_scale = 0.03
	var guard := 0
	while not it._done and guard < it.tiers + 2:
		guard += 1
		if auto_supply:
			for m in it.tier_cost:
				actor.give_items([m])
		it.try_use(actor)
		await tree.process_frame
		var t := 0.0
		while it._busy and t < 8.0:
			await tree.process_frame
			t += tree.root.get_process_delta_time()
