## 设置 · 通用（15）：对局偏好、声音与显示、存档。改动立即生效并写盘（UiSettings）。
## 电脑思考延迟要 IR-05，落地前不显示这一项。
class_name UiSettingsGeneralPage
extends Control

const SPEED_LABELS: Array[String] = ["慢", "标准", "快"]

var _nickname: UiInput
var _speed_segment: UiSegmented
var _animations_switch: UiSwitch
var _confirm_switch: UiSwitch
var _hotseat_switch: UiSwitch
var _sfx_switch: UiSwitch
var _fullscreen_switch: UiSwitch
var _show_ids_switch: UiSwitch
var _autosave_switch: UiSwitch
var _save_dir_note: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var columns := HBoxContainer.new()
	columns.name = "Columns"
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	columns.add_theme_constant_override("separation", 20)
	add_child(columns)

	var left := VBoxContainer.new()
	left.name = "Left"
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left)
	_build_game_panel(left)

	var right := VBoxContainer.new()
	right.name = "Right"
	right.custom_minimum_size.x = 440
	right.add_theme_constant_override("separation", 12)
	columns.add_child(right)
	_build_display_panel(right)
	_build_save_panel(right)


func _make_panel(panel_name: String) -> UiFrame:
	var panel := UiFrame.new()
	panel.name = panel_name
	panel.frame_texture = UiAssets.frame_l("ink")
	panel.frame_border = 4
	panel.background_color = UiPalette.CARD
	panel.content_padding = Vector4i(18, 14, 18, 16)
	panel.shadow_enabled = true
	panel.shadow_offset = Vector2i(0, 4)
	panel.top_highlight = true
	return panel


func _build_game_panel(parent: VBoxContainer) -> void:
	var panel := _make_panel("GamePanel")
	panel.feature_bar = true
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 12)
	panel.content.add_child(column)

	var title := Label.new()
	title.text = "对局"
	title.theme_type_variation = &"UiTitle"
	column.add_child(title)

	_nickname = UiInput.new()
	_nickname.name = "DefaultName"
	_nickname.max_length = 8
	_nickname.text = UiSettings.default_name()
	_nickname.text_changed.connect(func(text: String) -> void: UiSettings.set_default_name(text))
	_add_setting(column, "默认昵称", _nickname, "开局设置里第一个人类座位的名字；最多 8 个字。")

	_speed_segment = UiSegmented.new()
	_speed_segment.name = "AnimSpeed"
	_speed_segment.items = SPEED_LABELS
	_speed_segment.selected_index = maxi(UiSettings.SPEEDS.find(UiSettings.anim_speed()), 0)
	_speed_segment.selected_changed.connect(func(index: int) -> void:
		UiSettings.set_anim_speed(UiSettings.SPEEDS[clampi(index, 0, 2)]))
	_add_setting(column, "动画速度", _speed_segment, "慢会拖慢动效，快适合连续操作。")

	_animations_switch = _make_switch(UiSettings.animations_enabled(),
			func(on: bool) -> void: UiSettings.set_animations_enabled(on))
	_add_setting(column, "播放动效", _animations_switch, "关闭后事件与视图立即落地，不播飞行动效。")

	_confirm_switch = _make_switch(UiSettings.confirm_before_buy(),
			func(on: bool) -> void: UiSettings.set_confirm_before_buy(on))
	_add_setting(column, "购买前确认", _confirm_switch,
			"关掉后，点一张买得起的卡会直接购买；仍然可以预留。")

	_hotseat_switch = _make_switch(UiSettings.hotseat_cover_default(),
			func(on: bool) -> void: UiSettings.set_hotseat_cover_default(on))
	_add_setting(column, "同屏换人遮挡", _hotseat_switch,
			"开局设置里“换人时遮挡”的默认值；有 2 位以上人类时生效。")


func _build_display_panel(parent: VBoxContainer) -> void:
	var panel := _make_panel("DisplayPanel")
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.content.add_child(column)

	var title := Label.new()
	title.text = "声音与显示"
	title.theme_type_variation = &"UiTitle"
	column.add_child(title)

	_sfx_switch = _make_switch(UiSettings.sfx_enabled(),
			func(on: bool) -> void: UiSettings.set_sfx_enabled(on))
	_add_setting(column, "音效", _sfx_switch, "音效素材为空时静默跳过。")

	_fullscreen_switch = _make_switch(UiSettings.fullscreen(),
			func(on: bool) -> void: UiSettings.set_fullscreen(on))
	_add_setting(column, "全屏", _fullscreen_switch, "立即切换窗口模式。")

	_show_ids_switch = _make_switch(UiSettings.show_card_ids(),
			func(on: bool) -> void: UiSettings.set_show_card_ids(on))
	_add_setting(column, "显示卡牌 id", _show_ids_switch,
			"调试用：在场上的卡和你的预留卡上显示 L2-U-03 这类 id。")


func _build_save_panel(parent: VBoxContainer) -> void:
	var panel := _make_panel("SavePanel")
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.content.add_child(column)

	var title := Label.new()
	title.text = "存档"
	title.theme_type_variation = &"UiTitle"
	column.add_child(title)

	_autosave_switch = _make_switch(UiSettings.autosave(),
			func(on: bool) -> void: UiSettings.set_autosave(on))
	_add_setting(column, "每回合自动存档", _autosave_switch,
			"关掉后仍可在暂停菜单里手动保存；对局结束的回放照常保存。")

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	var label := Label.new()
	label.text = "存档目录"
	label.custom_minimum_size.x = 150
	label.add_theme_color_override("font_color", UiPalette.INK_2)
	row.add_child(label)
	var open_button := UiButton.new()
	open_button.name = "OpenSavesButton"
	open_button.variant = &"ghost"
	open_button.size_key = &"sm"
	open_button.text = "打开存档目录"
	open_button.focus_mode = Control.FOCUS_NONE
	open_button.pressed.connect(_open_save_dir)
	row.add_child(open_button)
	_save_dir_note = Label.new()
	_save_dir_note.name = "SaveDirNote"
	_save_dir_note.add_theme_color_override("font_color", UiPalette.INK_3)
	_save_dir_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_save_dir_note.text = "user://saves/"
	column.add_child(_save_dir_note)


func _open_save_dir() -> void:
	var error: Error = OS.shell_open(ProjectSettings.globalize_path("user://saves"))
	if error != OK:
		_save_dir_note.text = "打不开目录（%s）；路径仍是 user://saves/" % error_string(error)


# ---------------------------------------------------------------- 通用控件

func _make_switch(on: bool, callback: Callable) -> UiSwitch:
	var control := UiSwitch.new()
	control.set_on(on)
	control.toggled.connect(callback)
	return control


func _add_setting(parent: VBoxContainer, title: String, control: Control,
		hint: String = "") -> void:
	var box := VBoxContainer.new()
	box.name = "Setting_%s" % title
	box.add_theme_constant_override("separation", 4)
	parent.add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var label := Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", UiPalette.INK)
	row.add_child(label)
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	if not hint.is_empty():
		var note := Label.new()
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.add_theme_color_override("font_color", UiPalette.INK_3)
		note.text = hint
		box.add_child(note)


# ---------------------------------------------------------------- 测试用

func nickname_input() -> UiInput:
	return _nickname


func speed_segment() -> UiSegmented:
	return _speed_segment


func animations_switch() -> UiSwitch:
	return _animations_switch


func confirm_switch() -> UiSwitch:
	return _confirm_switch


func hotseat_switch() -> UiSwitch:
	return _hotseat_switch


func sfx_switch() -> UiSwitch:
	return _sfx_switch


func fullscreen_switch() -> UiSwitch:
	return _fullscreen_switch


func show_ids_switch() -> UiSwitch:
	return _show_ids_switch


func autosave_switch() -> UiSwitch:
	return _autosave_switch


func save_dir_note() -> String:
	return _save_dir_note.text if _save_dir_note != null else ""
