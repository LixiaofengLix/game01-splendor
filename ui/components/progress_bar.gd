## 像素进度条：高 6，底 PROGRESS_BG，填充上叠 8px 周期的 2px 竖纹。
class_name UiProgressBar
extends Control

var ratio: float = 0.0:
	set(value):
		ratio = clampf(value, 0.0, 1.0)
		if is_inside_tree():
			queue_redraw()

var fill_color: Color = UiPalette.ORANGE:
	set(value):
		fill_color = value
		if is_inside_tree():
			queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(100, 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiPalette.PROGRESS_BG)
	var filled := roundf(size.x * ratio)
	if filled <= 0:
		return
	draw_rect(Rect2(0, 0, filled, size.y), fill_color)
	var stripe := Color(0, 0, 0, 0.28)
	var x := 6.0
	while x < filled:
		draw_rect(Rect2(x, 0, minf(2, filled - x), size.y), stripe)
		x += 8.0
