## 像素输入框：沿用 Theme 的 LineEdit 小框，顶部加 2px 内阴影；聚焦时边框不变。
class_name UiInput
extends LineEdit


func _ready() -> void:
	custom_minimum_size.y = 32
	mouse_default_cursor_shape = Control.CURSOR_IBEAM
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(2, 2, maxf(size.x - 4, 0), 2), Color(0, 0, 0, 0.12))
