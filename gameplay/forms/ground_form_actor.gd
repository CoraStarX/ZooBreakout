class_name GroundFormActor
extends TraversalActor
## 新本體適配器；沿用凍結接地／斜坡／邊緣保護，完全不把Space傳入跳躍緩衝。
@export var jump_hint: String = "此形態不能跳躍；需要攀爬才能"
func step(delta: float, axes: Vector2, space_pressed: bool = false) -> void:
	super.step(delta,axes,false)
	if space_pressed: feedback.emit(jump_hint)
func refresh_selection(_direction: Vector3 = Vector3.ZERO) -> void:
	has_jump_preview = false
	selected_link = null
	preview_is_drop = false
	jump_refusal = jump_hint
