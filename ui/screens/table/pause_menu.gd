## 暂停菜单（13）：左栏操作，右栏规则速查；退出先展开二次确认。
## 只发信号，存档、读档和退出由 UiTableFlow / 应用入口处理。
class_name UiPauseMenu
extends Control

signal continue_pressed
signal save_pressed
signal load_pressed
signal exit_pressed
signal closed

var can_save: bool = true
var save_note: String = ""
var exit_note: String = ""

var _frame: UiModalFrame
var _save_button: UiButton
var _exit_row: HBoxContainer
var _confirm_row: HBoxContainer
var _rules: UiRulesPanel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var scrim := ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = UiPalette.SCRIM
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect(_on_scrim_input)
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_frame = UiModalFrame.new()
	_frame.name = "PauseFrame"
	_frame.preferred_width = 720
	_frame.title = "暂停"
	center.add_child(_frame)

	var row := HBoxContainer.new()
	row.name = "Columns"
	row.add_theme_constant_override("separation", 22)
	_frame.body().add_child(row)

	var left := VBoxContainer.new()
	left.name = "Left"
	left.custom_minimum_size.x = 230
	left.add_theme_constant_override("separation", 8)
	row.add_child(left)

	var resume_button := _make_button("继续游戏", &"accent")
	resume_button.name = "PauseResume"
	resume_button.pressed.connect(func() -> void: continue_pressed.emit())
	left.add_child(resume_button)

	_save_button = _make_button("保存", &"ghost")
	_save_button.name = "PauseSave"
	_save_button.pressed.connect(func() -> void: save_pressed.emit())
	left.add_child(_save_button)

	var load_button := _make_button("读取存档", &"ghost")
	load_button.name = "PauseLoad"
	load_button.pressed.connect(func() -> void: load_pressed.emit())
	left.add_child(load_button)

	var settings_button := _make_button("设置", &"ghost")
	settings_button.name = "PauseSettings"
	settings_button.disabled = true
	settings_button.tooltip_text = "设置页将在后续版本开放"
	left.add_child(settings_button)

	var line := ColorRect.new()
	line.custom_minimum_size.y = 2
	line.color = UiPalette.LINE
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(line)

	var note := Label.new()
	note.name = "SaveNote"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", UiPalette.INK_3)
	left.add_child(note)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)

	var exit_label := Label.new()
	exit_label.name = "ExitNote"
	exit_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	exit_label.add_theme_color_override("font_color", UiPalette.INK_2)
	left.add_child(exit_label)

	_exit_row = HBoxContainer.new()
	_exit_row.name = "ExitRow"
	left.add_child(_exit_row)
	var exit_button := _make_button("退出", &"danger", &"sm")
	exit_button.name = "PauseExit"
	exit_button.pressed.connect(_show_exit_confirm)
	_exit_row.add_child(exit_button)

	_confirm_row = HBoxContainer.new()
	_confirm_row.name = "ExitConfirmRow"
	_confirm_row.visible = false
	left.add_child(_confirm_row)
	var confirm := _make_button("确认退出", &"danger", &"sm")
	confirm.name = "PauseExitConfirm"
	confirm.pressed.connect(func() -> void: exit_pressed.emit())
	_confirm_row.add_child(confirm)
	var cancel := _make_button("取消", &"quiet", &"sm")
	cancel.name = "PauseExitCancel"
	cancel.pressed.connect(_hide_exit_confirm)
	_confirm_row.add_child(cancel)

	var divider := ColorRect.new()
	divider.custom_minimum_size.x = 2
	divider.color = UiPalette.LINE
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(divider)

	var right := VBoxContainer.new()
	right.name = "Right"
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	_rules = UiRulesPanel.new()
	_rules.name = "Rules"
	right.add_child(_rules)

	_apply_config(note, exit_label)


func configure(p_can_save: bool, p_save_note: String, p_exit_note: String) -> void:
	can_save = p_can_save
	save_note = p_save_note
	exit_note = p_exit_note
	if is_node_ready():
		_apply_config(_frame.find_child("SaveNote", true, false) as Label,
				_frame.find_child("ExitNote", true, false) as Label)


func setup_rules(rules: RulesConfig) -> void:
	_rules.setup(rules)


func _apply_config(note: Label, exit_label: Label) -> void:
	if note != null:
		note.text = save_note
		note.visible = not save_note.is_empty()
	if exit_label != null:
		exit_label.text = exit_note
	if _save_button != null:
		_save_button.disabled = not can_save


func _make_button(text: String, variant: StringName, size_key: StringName = &"default") -> UiButton:
	var button := UiButton.new()
	button.text = text
	button.variant = variant
	button.size_key = size_key
	button.focus_mode = Control.FOCUS_ALL
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button


func _show_exit_confirm() -> void:
	_exit_row.visible = false
	_confirm_row.visible = true


func _hide_exit_confirm() -> void:
	_exit_row.visible = true
	_confirm_row.visible = false


func _on_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			closed.emit()


# ---------------------------------------------------------------- 测试用

func save_button() -> UiButton:
	return _save_button


func rules_panel() -> UiRulesPanel:
	return _rules


func request_exit_confirm() -> void:
	_show_exit_confirm()


func confirm_exit() -> void:
	exit_pressed.emit()


func cancel_exit_confirm() -> void:
	_hide_exit_confirm()
