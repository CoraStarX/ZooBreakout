class_name HintDirector
extends Node
## Onboarding: contextual one-time hints. "Seen" state persists in UserPrefs; can be switched off / reset
## from the pause menu. Never blocks input.

const HINTS := {
	&"start": "WASD 移动；走近黄柱/蓝点/紫点按 E 交互；Tab 换控，F/H 让队友跟随/待命。\\n白天先出去搜集原料，夜里再去外墙施工。",
	&"gather": "原料夜里施工用：挖洞每档 木料+金属，攀爬每档 绳索+金属。\\n金属稀缺——冒险去职员工具间，或趁职员停步从背后偷他的工具车。",
	&"close": "闭园了，很快入夜。白天的搜集到此为止，准备去外墙。",
	&"night": "夜间：去西/南外墙按 E 施工（分 3 档）。红色扇形是职员视线；他歇岗时最安全，吵的 Hard 施工也不会引来人。",
	&"captured": "被抓：物品进办公室，你在笼内短押一小会儿（笼里还能搜集）。同伴可以撬门救你，但笼门当天会加固，开锁更费劲。",
	&"intel": "情报会跨天保留。知道职员歇岗时间，就能挑最安全的窗口施工。",
	&"rescued": "同伴入队！Tab 换控——不同动物的能力能让同一件事更稳更快，也能分头行动。",
}
const SEEN := "hints_seen"

var hud: GameHUD
var enabled: bool = true


func _ready() -> void:
	enabled = bool(UserPrefs.get_value("prefs", "hints_enabled", true))
	Bus.material_gathered.connect(func(_id: StringName, _n: int) -> void: trigger(&"gather"))
	Bus.captured.connect(func(_a: Node3D) -> void: trigger(&"captured"))
	Bus.intel_gained.connect(func(_id: StringName) -> void: trigger(&"intel"))
	Bus.animal_rescued.connect(func(_id: StringName) -> void: trigger(&"rescued"))
	Bus.phase_changed.connect(func(p: int) -> void:
		if p == Clock.Phase.CLOSE:
			trigger(&"close")
		elif p == Clock.Phase.NIGHT_PATROL:
			trigger(&"night")
	)
	get_tree().create_timer(1.5).timeout.connect(func() -> void: trigger(&"start"))


func trigger(id: StringName) -> void:
	if not enabled or hud == null or not HINTS.has(id):
		return
	if bool(UserPrefs.get_value(SEEN, String(id), false)):
		return
	UserPrefs.set_value(SEEN, String(id), true)
	hud.show_hint(String(HINTS[id]).replace("\\n", "\n"))


static func set_enabled(on: bool) -> void:
	UserPrefs.set_value("prefs", "hints_enabled", on)


static func reset_seen() -> void:
	UserPrefs.clear_section(SEEN)
