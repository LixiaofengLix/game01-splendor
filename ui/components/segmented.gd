## 分段选择：SEGMENT_BG 底 + 2px 内距，选中项 HUD 底 + GOLD_TEXT 字 + 底部内阴影。
## 只负责显示与选中回调；具体选项由调用方设置。
class_name UiSegmented
extends PanelContainer

signal selected_changed(index: int)

var items: Array[String] = []:
	set(value):
		items = value.duplicate()
		_rebuild()

var selected_index: int = 0:
	set(value):
		selected_index = value
		_apply_selection()

var disabled_indices: Array[int] = []:
	set(value):
		disabled_indices = value.duplicate()
		_rebuild()

var _row: HBoxContainer
var _buttons: Array[Button] = []
var _normal_style: StyleBoxFlat
var _hover_style: StyleBoxFlat
var _pressed_style: StyleBoxFlat
var _selected_style: StyleBoxFlat


func _ready() -> void:
	add_theme_stylebox_override("panel", _make_root_style())
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 2)
	_row.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_row)

	_normal_style = _make_item_style(Color(0, 0, 0, 0))
	_hover_style = _make_item_style(UiPalette.CARD_SOFT)
	_pressed_style = _make_item_style(UiPalette.CARD)
	_selected_style = _make_item_style(UiPalette.HUD)
	_selected_style.border_width_bottom = 2
	_selected_style.border_color = Color(0, 0, 0, 0.4)
	_rebuild()


func _make_root_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UiPalette.SEGMENT_BG
	style.content_margin_left = 2
	style.content_margin_top = 2
	style.content_margin_right = 2
	style.content_margin_bottom = 2
	style.anti_aliasing = false
	return style


func _make_item_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.content_margin_left = 10
	style.content_margin_top = 4
	style.content_margin_right = 10
	style.content_margin_bottom = 4
	style.anti_aliasing = false
	return style


func _rebuild() -> void:
	if _row == null:
		return
	for button: Button in _buttons:
		button.queue_free()
	_buttons.clear()
	for index in items.size():
		var button := Button.new()
		button.text = items[index]
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.custom_minimum_size = Vector2(0, 24)
		button.add_theme_stylebox_override("normal", _normal_style)
		button.add_theme_stylebox_override("hover", _hover_style)
		button.add_theme_stylebox_override("pressed", _pressed_style)
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.add_theme_color_override("font_color", UiPalette.INK_2)
		button.add_theme_color_override("font_hover_color", UiPalette.INK)
		button.add_theme_color_override("font_pressed_color", UiPalette.INK)
		button.pressed.connect(_on_item_pressed.bind(index))
		button.modulate = Color(1, 1, 1, 0.35) if disabled_indices.has(index) else Color.WHITE
		_row.add_child(button)
		_buttons.append(button)
	_apply_selection()


func _apply_selection() -> void:
	for index in _buttons.size():
		var button := _buttons[index]
		var is_selected := index == selected_index
		button.add_theme_stylebox_override("normal", _selected_style if is_selected else _normal_style)
		button.add_theme_color_override(
				"font_color",
				UiPalette.GOLD_TEXT if is_selected else UiPalette.INK_2)
		button.add_theme_color_override(
				"font_pressed_color",
				UiPalette.GOLD_TEXT if is_selected else UiPalette.INK)
		button.disabled = disabled_indices.has(index)
		button.modulate = Color(1, 1, 1, 0.35) if disabled_indices.has(index) else Color.WHITE


func _on_item_pressed(index: int) -> void:
	if disabled_indices.has(index) or index == selected_index:
		return
	selected_index = index
	selected_changed.emit(index)
