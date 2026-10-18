## 银行列：宽 100 的大框面板，从上到下是“银行”、6 枚 lg 筹码（白蓝绿红黑金）、
## 底部提示与确认 / 取消按钮。能点哪些颜色由牌桌从合法动作推出后传进来。
class_name UiBankColumn
extends UiFrame

signal chip_clicked(color: int)
signal confirm_pressed
signal cancel_pressed

const WIDTH := 100

var _box: VBoxContainer
var _chips: Array[UiGemChip] = []
var _hint: Label
var _confirm: UiButton
var _cancel: UiButton
var _counts: Dictionary[int, int] = {}
var _selection: Dictionary[int, int] = {}
var _clickable: Array[int] = []
var _input_enabled: bool = false
var _confirm_enabled: bool = false


func _ready() -> void:
	frame_texture = UiAssets.frame_l("ink")
	frame_border = 4
	background_color = UiPalette.CARD
	content_padding = Vector4i(6, 10, 6, 10)
	top_highlight = true
	shadow_enabled = true
	shadow_offset = Vector2i(0, 4)
	super._ready()
	custom_minimum_size.x = WIDTH

	_box = VBoxContainer.new()
	_box.name = "Box"
	_box.add_theme_constant_override("separation", 4)
	_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	content.add_child(_box)

	var title := Label.new()
	title.name = "Title"
	title.text = "银行"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UiPalette.INK_3)
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(title)

	for color: Enums.GemColor in Enums.ALL_COLORS:
		var chip := UiGemChip.new()
		chip.name = "Chip_%s" % Enums.color_to_letter(color)
		chip.gem_color = color
		chip.size_key = &"lg"
		chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		chip.gui_input.connect(_on_chip_input.bind(chip))
		_box.add_child(chip)
		_chips.append(chip)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_box.add_child(spacer)

	_hint = Label.new()
	_hint.name = "Hint"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_color_override("font_color", UiPalette.INK_3)
	_box.add_child(_hint)

	var buttons := VBoxContainer.new()
	buttons.name = "Buttons"
	buttons.add_theme_constant_override("separation", 4)
	_box.add_child(buttons)

	_confirm = UiButton.new()
	_confirm.name = "ConfirmButton"
	_confirm.variant = &"accent"
	_confirm.size_key = &"sm"
	_confirm.text = "确认"
	_confirm.focus_mode = Control.FOCUS_NONE
	_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm.pressed.connect(func() -> void: confirm_pressed.emit())
	buttons.add_child(_confirm)

	_cancel = UiButton.new()
	_cancel.name = "CancelButton"
	_cancel.variant = &"ghost"
	_cancel.size_key = &"sm"
	_cancel.text = "取消"
	_cancel.focus_mode = Control.FOCUS_NONE
	_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cancel.pressed.connect(func() -> void: cancel_pressed.emit())
	buttons.add_child(_cancel)

	_apply_state()


## counts 以 Enums.GemColor 为键；缺少的颜色按 0 枚（空心）显示。
func set_counts(counts: Dictionary) -> void:
	_counts.clear()
	for color: Enums.GemColor in Enums.ALL_COLORS:
		var value: int = int(counts.get(color, 0))
		_counts[color] = value
		if color < _chips.size():
			_chips[color].count = value


func set_hint(text: String) -> void:
	_hint.text = text
	_hint.visible = not text.is_empty()


## 只有 playing 阶段、轮到我时才能点银行。
func set_interactive(enabled: bool) -> void:
	_input_enabled = enabled
	_apply_state()


## 本回合能拿的颜色（由合法动作推出）；金币不在其中。
func set_clickable_colors(colors: Array) -> void:
	_clickable.clear()
	for item: Variant in colors:
		_clickable.append(int(item))
	_apply_state()


func set_selection(selection: Dictionary) -> void:
	_selection.clear()
	for key: Variant in selection:
		_selection[int(key)] = int(selection[key])
	_apply_state()


func set_confirm_enabled(enabled: bool) -> void:
	_confirm_enabled = enabled
	_apply_state()


func set_cancel_enabled(enabled: bool) -> void:
	_cancel.disabled = not (_input_enabled and enabled)


func get_counts() -> Dictionary[int, int]:
	return _counts.duplicate()


func is_button_visible() -> bool:
	return _confirm.visible and _cancel.visible


func confirm_button() -> UiButton:
	return _confirm


func cancel_button() -> UiButton:
	return _cancel


func chip(color: Enums.GemColor) -> UiGemChip:
	return _chips[color] if color >= 0 and color < _chips.size() else null


## 动效起点 / 终点：筹码在屏幕上的位置。
func chip_rect(color: Enums.GemColor) -> Rect2:
	var node: UiGemChip = chip(color)
	return node.get_global_rect() if node != null else Rect2()


func _apply_state() -> void:
	for color: Enums.GemColor in Enums.ALL_COLORS:
		var chip: UiGemChip = _chips[color]
		chip.selected_amount = int(_selection.get(color, 0))
		var can_click: bool = _input_enabled and _clickable.has(color)
		chip.mouse_filter = Control.MOUSE_FILTER_STOP if can_click \
				else Control.MOUSE_FILTER_IGNORE
		chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_click \
				else Control.CURSOR_ARROW
	var total_selected: int = 0
	for value: Variant in _selection.values():
		total_selected += int(value)
	_confirm.disabled = not (_input_enabled and _confirm_enabled)
	_cancel.disabled = not (_input_enabled and total_selected > 0)


func _on_chip_input(event: InputEvent, chip: UiGemChip) -> void:
	if not _input_enabled:
		return
	if not event is InputEventMouseButton:
		return
	var mouse := event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed:
		return
	if not _clickable.has(chip.gem_color):
		return
	chip.accept_event()
	chip_clicked.emit(chip.gem_color)
