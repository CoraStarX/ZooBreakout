extends SceneTree
func _initialize():
	var c = load("res://content/game_const.gd")
	print("GameConst script:", c)
	var z = load("res://scenes/world/zoo_p0.tscn")
	print("zoo_p0:", z)
	var s = load("res://scenes/boot/start_select.tscn")
	print("start_select:", s)
	quit(0)
