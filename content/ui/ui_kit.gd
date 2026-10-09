class_name UIKit
extends RefCounted
## Small shared UI builders so HUD / pause menu look consistent (no theme file yet).

const BG := Color(0.07, 0.09, 0.12, 0.78)
const BORDER := Color(1, 1, 1, 0.12)
const TEXT_DIM := Color(0.75, 0.8, 0.85)
const ACCENT := Color(1.0, 0.85, 0.35)


static func panel(min_size: Vector2 = Vector2.ZERO, margin: int = 10) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.border_color = BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(margin)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = min_size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func label(text: String, size: int = 16, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func swatch(color: Color, size: Vector2 = Vector2(12, 12)) -> ColorRect:
	var c := ColorRect.new()
	c.color = color
	c.custom_minimum_size = size
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
