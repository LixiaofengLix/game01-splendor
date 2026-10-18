## 像素开关：40×24，2px INK 描边；关是 BG_SOFT 底、滑块在左，开是 ORANGE 底、白滑块在右。
class_name UiSwitch
extends BaseButton

const SIZE := Vector2(40, 24)
const KNOB := 16
const BORDER := 2


func _ready() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = SIZE
	toggled.connect(func(_on: bool) -> void: queue_redraw())


## 代码里切换状态时用这个；BaseButton 的 button_pressed 不保证触发重绘。
func set_on(on: bool) -> void:
	button_pressed = on
	queue_redraw()


func _draw() -> void:
	var on: bool = button_pressed
	draw_rect(Rect2(Vector2.ZERO, size), UiPalette.INK)
	draw_rect(
			Rect2(BORDER, BORDER, size.x - BORDER * 2, size.y - BORDER * 2),
			UiPalette.ORANGE if on else UiPalette.BG_SOFT)
	var knob_y := float(BORDER + 2)
	var knob_x: float = size.x - BORDER - 2 - KNOB if on else float(BORDER + 2)
	var knob_color: Color = UiPalette.WHITE if on else UiPalette.INK
	draw_rect(Rect2(knob_x, knob_y, KNOB, KNOB), knob_color)
