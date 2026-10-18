## 本地开局设置（02）：座位（名字 / 人类或电脑 / 难度）、加减座位、常用组合、
## 人数 / 种子 / 规则只读信息、同屏换人遮挡开关。
## 只把开局的 setup 字典发给应用入口；不直接创建会话。
class_name UiLocalSetup
extends Control

signal back_requested
signal start_requested(setup: Dictionary)

const DEFAULT_NAMES: Array[String] = ["小明", "薄荷", "紫晶", "橘子"]
const TYPE_LABELS: Array[String] = ["人类", "电脑", "大模型"]
const DIFFICULTY_LABELS: Array[String] = ["简单", "普通", "困难"]
const DIFFICULTY_TYPES: Array[String] = ["easy", "normal", "hard"]
const PRESETS: Array[Dictionary] = [
	{"key": "duel", "title": "单挑电脑", "detail": "你 vs 困难电脑"},
	{"key": "standard", "title": "标准 3 人", "detail": "你 + 2 个普通电脑"},
	{"key": "hotseat", "title": "4 人同屏", "detail": "4 位人类，打开换人遮挡"},
	{"key": "bots", "title": "电脑对战", "detail": "2 个电脑，你观战"},
]

var _rules: RulesConfig
var _counts: Array[int] = []
var _seats: Array[Dictionary] = []
var _hotseat_cover: bool = false
var _active_preset: String = ""

var _seat_list: VBoxContainer
var _count_segment: UiSegmented
var _seed_input: UiInput
var _hotseat_switch: UiSwitch
var _hotseat_hint: Label
var _start_button: UiButton
var _error_label: Label
var _rule_values: Dictionary[String, Label] = {}
var _preset_buttons: Dictionary[String, UiButton] = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rules = DataRegistry.rules()
	_counts = _rules.supported_player_counts()
	_apply_preset("standard")
	_build()


# ---------------------------------------------------------------- 布局

func _build() -> void:
	_build_topbar()

	var body := MarginContainer.new()
	body.name = "Body"
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_top = 44
	body.add_theme_constant_override("margin_left", 24)
	body.add_theme_constant_override("margin_top", 18)
	body.add_theme_constant_override("margin_right", 24)
	body.add_theme_constant_override("margin_bottom", 20)
	add_child(body)

	var columns := HBoxContainer.new()
	columns.name = "Columns"
	columns.add_theme_constant_override("separation", 20)
	body.add_child(columns)

	var left := VBoxContainer.new()
	left.name = "Left"
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 14)
	columns.add_child(left)

	_build_seats_panel(left)
	_build_presets_panel(left)

	var right := VBoxContainer.new()
	right.name = "Right"
	right.custom_minimum_size.x = 380
	right.add_theme_constant_override("separation", 12)
	columns.add_child(right)

	_build_court_panel(right)
	_build_hotseat_panel(right)

	_error_label = Label.new()
	_error_label.name = "SetupError"
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error_label.add_theme_color_override("font_color", UiPalette.DANGER)
	_error_label.visible = false
	right.add_child(_error_label)

	_start_button = UiButton.new()
	_start_button.name = "StartGameButton"
	_start_button.variant = &"accent"
	_start_button.size_key = &"lg"
	_start_button.text = "开始对局"
	_start_button.focus_mode = Control.FOCUS_ALL
	_start_button.pressed.connect(start_pressed)
	right.add_child(_start_button)

	_rebuild_seats()
	_refresh_summary()
	_refresh_presets()


func _build_topbar() -> void:
	var bar := Control.new()
	bar.name = "TopBar"
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 44
	bar.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(bar)

	var background := ColorRect.new()
	background.color = UiPalette.HUD
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(background)
	var highlight := ColorRect.new()
	highlight.color = UiPalette.HUD_HIGHLIGHT
	highlight.position = Vector2.ZERO
	highlight.size = Vector2(0, 2)
	highlight.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	highlight.offset_bottom = 2
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(highlight)
	var border := ColorRect.new()
	border.color = UiPalette.HUD_BORDER
	border.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	border.offset_top = -4
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(border)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14
	row.offset_right = -14
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_child(row)

	var back := UiButton.new()
	back.name = "BackButton"
	back.variant = &"hud"
	back.size_key = &"sm"
	back.text = "‹ 主菜单"
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func() -> void: back_requested.emit())
	row.add_child(back)

	var title := Label.new()
	title.text = "本地游戏"
	title.add_theme_color_override("font_color", UiPalette.CREAM)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)


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


func _build_seats_panel(parent: VBoxContainer) -> void:
	var panel := _make_panel("SeatsPanel")
	panel.feature_bar = true
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.content.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	column.add_child(header)
	var title := Label.new()
	title.name = "SeatsTitle"
	title.text = "座位"
	title.theme_type_variation = &"UiTitle"
	header.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var add_button := UiButton.new()
	add_button.name = "AddSeatButton"
	add_button.variant = &"quiet"
	add_button.size_key = &"sm"
	add_button.text = "＋ 加一位玩家"
	add_button.focus_mode = Control.FOCUS_NONE
	add_button.pressed.connect(_on_add_seat)
	header.add_child(add_button)

	_seat_list = VBoxContainer.new()
	_seat_list.name = "SeatList"
	_seat_list.add_theme_constant_override("separation", 6)
	_seat_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_seat_list)

	var hint := Label.new()
	hint.name = "SeatsHint"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", UiPalette.INK_3)
	hint.text = "人类座位由你操作；同屏时轮到谁才显示谁的盲抽牌。"
	column.add_child(hint)


func _build_presets_panel(parent: VBoxContainer) -> void:
	var panel := _make_panel("PresetsPanel")
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.content.add_child(column)

	var title := Label.new()
	title.text = "常用组合"
	title.add_theme_color_override("font_color", UiPalette.INK_2)
	column.add_child(title)

	var grid := GridContainer.new()
	grid.name = "PresetGrid"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	column.add_child(grid)
	for preset: Dictionary in PRESETS:
		var key: String = String(preset["key"])
		var button := UiButton.new()
		button.name = "Preset_%s" % key
		button.variant = &"ghost"
		button.size_key = &"sm"
		button.text = String(preset["title"])
		button.tooltip_text = String(preset["detail"])
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void: _apply_preset(key))
		grid.add_child(button)
		_preset_buttons[key] = button


func _build_court_panel(parent: VBoxContainer) -> void:
	var panel := _make_panel("CourtPanel")
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	panel.content.add_child(column)

	var title := Label.new()
	title.text = "对局"
	title.theme_type_variation = &"UiTitle"
	column.add_child(title)

	var count_row := HBoxContainer.new()
	count_row.add_theme_constant_override("separation", 10)
	column.add_child(count_row)
	var count_label := Label.new()
	count_label.text = "人数"
	count_label.custom_minimum_size.x = 72
	count_label.add_theme_color_override("font_color", UiPalette.INK_3)
	count_row.add_child(count_label)
	_count_segment = UiSegmented.new()
	_count_segment.name = "CountSegment"
	var items: Array[String] = []
	for count: int in _counts:
		items.append("%d 人" % count)
	_count_segment.items = items
	_count_segment.selected_index = 1
	_count_segment.selected_changed.connect(_on_count_changed)
	count_row.add_child(_count_segment)

	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 8)
	column.add_child(seed_row)
	var seed_label := Label.new()
	seed_label.text = "种子"
	seed_label.custom_minimum_size.x = 72
	seed_label.add_theme_color_override("font_color", UiPalette.INK_3)
	seed_row.add_child(seed_label)
	_seed_input = UiInput.new()
	_seed_input.name = "SeedInput"
	_seed_input.placeholder_text = "留空 = 随机"
	_seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed_input.max_length = 12
	seed_row.add_child(_seed_input)
	var random_button := UiButton.new()
	random_button.name = "SeedRandomButton"
	random_button.variant = &"quiet"
	random_button.size_key = &"sm"
	random_button.text = "随机"
	random_button.focus_mode = Control.FOCUS_NONE
	random_button.pressed.connect(func() -> void: _seed_input.text = "")
	seed_row.add_child(random_button)

	var seed_hint := Label.new()
	seed_hint.text = "同一个种子开局完全一致。"
	seed_hint.add_theme_color_override("font_color", UiPalette.INK_3)
	column.add_child(seed_hint)

	var line := ColorRect.new()
	line.custom_minimum_size.y = 2
	line.color = UiPalette.LINE
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(line)

	var rules_title := Label.new()
	rules_title.text = "本局规则"
	rules_title.add_theme_color_override("font_color", UiPalette.INK_2)
	column.add_child(rules_title)
	for key: String in ["胜利分", "持币上限", "预留上限", "宝石", "贵族"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		column.add_child(row)
		var label := Label.new()
		label.text = key
		label.custom_minimum_size.x = 72
		label.add_theme_color_override("font_color", UiPalette.INK_3)
		row.add_child(label)
		var value := Label.new()
		value.name = "Rule_%s" % key
		value.add_theme_color_override("font_color", UiPalette.INK)
		row.add_child(value)
		_rule_values[key] = value


func _build_hotseat_panel(parent: VBoxContainer) -> void:
	var panel := _make_panel("HotseatPanel")
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	panel.content.add_child(column)

	var title := Label.new()
	title.text = "同屏"
	title.add_theme_color_override("font_color", UiPalette.INK_2)
	column.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	var label := Label.new()
	label.text = "换人时遮挡"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", UiPalette.INK)
	row.add_child(label)
	_hotseat_switch = UiSwitch.new()
	_hotseat_switch.name = "HotseatSwitch"
	_hotseat_switch.toggled.connect(func(on: bool) -> void: _hotseat_cover = on)
	row.add_child(_hotseat_switch)

	_hotseat_hint = Label.new()
	_hotseat_hint.name = "HotseatHint"
	_hotseat_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hotseat_hint.add_theme_color_override("font_color", UiPalette.INK_3)
	column.add_child(_hotseat_hint)


# ---------------------------------------------------------------- 座位

func _default_seat(index: int, seat_type: String = "bot") -> Dictionary:
	var seat_name: String = DEFAULT_NAMES[index] if index < DEFAULT_NAMES.size() \
			else "座位 %d" % (index + 1)
	# 设置页的默认昵称只用于第一个人类座位。
	if index == 0 and seat_type == "human":
		seat_name = UiSettings.default_name()
	var entry: Dictionary = {
		"name": seat_name,
		"type": seat_type,
		"difficulty": "normal",
	}
	if seat_type == "llm":
		entry["llm_profile"] = UiLlmBridge.active_profile_id()
	return entry


func apply_preset(preset_key: String) -> void:
	_apply_preset(preset_key)


func _apply_preset(preset_key: String) -> void:
	_seats.clear()
	_hotseat_cover = UiSettings.hotseat_cover_default()
	_active_preset = preset_key
	match preset_key:
		"duel":
			_seats.append(_default_seat(0, "human"))
			_seats.append(_default_seat(1, "bot"))
			_seats[1]["difficulty"] = "hard"
		"hotseat":
			for index: int in 4:
				_seats.append(_default_seat(index, "human"))
			_hotseat_cover = true
			# 4 人同屏默认打开遮挡；用户可在同屏面板里关掉。
		"bots":
			_seats.append(_default_seat(0, "bot"))
			_seats.append(_default_seat(1, "bot"))
		_:
			_seats.append(_default_seat(0, "human"))
			_seats.append(_default_seat(1, "bot"))
			_seats.append(_default_seat(2, "bot"))
	if _seat_list != null:
		_rebuild_seats()
		_refresh_summary()
		_refresh_presets()


func _refresh_presets() -> void:
	for key: String in _preset_buttons:
		var button: UiButton = _preset_buttons[key]
		button.variant = &"dark" if key == _active_preset else &"ghost"


func _rebuild_seats() -> void:
	for child in _seat_list.get_children():
		_seat_list.remove_child(child)
		child.queue_free()
	for index: int in _seats.size():
		_seat_list.add_child(_make_seat_row(index))
	var add_button := find_child("AddSeatButton", true, false) as UiButton
	if add_button != null:
		add_button.disabled = _seats.size() >= _counts[_counts.size() - 1]
	_refresh_summary()
	_refresh_presets()


func _make_seat_row(index: int) -> Control:
	var entry: Dictionary = _seats[index]
	var row := HBoxContainer.new()
	row.name = "SeatRow%d" % index
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size.y = 40
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var number := Label.new()
	number.theme_type_variation = &"UiNumMid"
	number.text = str(index + 1)
	number.custom_minimum_size.x = 24
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.add_theme_color_override("font_color", UiPalette.INK_3)
	row.add_child(number)

	row.add_child(UiAssets.mascot_icon(index, 40))

	var name_input := UiInput.new()
	name_input.name = "SeatName%d" % index
	name_input.text = String(entry.get("name", ""))
	name_input.max_length = 8
	name_input.custom_minimum_size.x = 150
	name_input.text_changed.connect(func(text: String) -> void:
		if index < _seats.size():
			_seats[index]["name"] = text)
	row.add_child(name_input)

	var type_segment := UiSegmented.new()
	type_segment.name = "SeatType%d" % index
	type_segment.items = TYPE_LABELS
	# 阶段 5 已落地：有配置档时“大模型”可选；没有配置档时保持禁用。
	if not UiLlmBridge.has_profiles():
		type_segment.disabled_indices = [2]
	type_segment.selected_index = _type_index(String(entry.get("type", "human")))
	type_segment.selected_changed.connect(func(selected: int) -> void: _on_type_changed(index, selected))
	row.add_child(type_segment)

	if String(entry.get("type", "human")) == "llm":
		row.add_child(_make_llm_profile_option(index, entry))

	if String(entry.get("type", "human")) == "bot":
		var difficulty := UiSegmented.new()
		difficulty.name = "SeatDifficulty%d" % index
		difficulty.items = DIFFICULTY_LABELS
		difficulty.selected_index = DIFFICULTY_TYPES.find(
				String(entry.get("difficulty", "normal")))
		if difficulty.selected_index < 0:
			difficulty.selected_index = 1
		difficulty.selected_changed.connect(func(selected: int) -> void:
			if index < _seats.size():
				_seats[index]["difficulty"] = DIFFICULTY_TYPES[selected])
		row.add_child(difficulty)

	if _is_first_human(index):
		var you := UiTag.new()
		you.name = "YouTag%d" % index
		you.text = "你"
		you.variant = &"dark"
		you.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(you)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var remove := UiButton.new()
	remove.name = "RemoveSeat%d" % index
	remove.variant = &"quiet"
	remove.size_key = &"sm"
	remove.text = "移除"
	remove.focus_mode = Control.FOCUS_NONE
	remove.disabled = _seats.size() <= _counts[0]
	remove.pressed.connect(func() -> void: _on_remove_seat(index))
	row.add_child(remove)
	return row


## 大模型座位的配置档下拉；显示名来自 AppConfig 的大模型配置档（桥接层）。
func _make_llm_profile_option(index: int, entry: Dictionary) -> Control:
	var option := OptionButton.new()
	option.name = "SeatLlmProfile%d" % index
	option.focus_mode = Control.FOCUS_NONE
	option.tooltip_text = "失败时由配置档指定的电脑兜底；配置档在 设置 → 大模型 里管理。"
	option.add_theme_color_override("font_color", UiPalette.INK)
	option.custom_minimum_size.x = 132
	var ids: Array[String] = UiLlmBridge.profile_ids()
	var selected: String = String(entry.get("llm_profile", ""))
	if selected.is_empty() or not ids.has(selected):
		selected = UiLlmBridge.active_profile_id()
	for id: String in ids:
		var profile: LlmProfile = UiLlmBridge.profile(id)
		var label: String = profile.display_name if profile != null else id
		option.add_item(label)
		option.set_item_metadata(option.item_count - 1, id)
		if id == selected:
			option.select(option.item_count - 1)
	option.item_selected.connect(func(selected_index: int) -> void:
		if index >= _seats.size():
			return
		var profile_id: String = String(option.get_item_metadata(selected_index))
		_seats[index]["llm_profile"] = profile_id)
	return option


func _type_index(seat_type: String) -> int:
	match seat_type:
		"bot":
			return 1
		"llm":
			return 2
		_:
			return 0


func _on_type_changed(index: int, selected: int) -> void:
	if index < 0 or index >= _seats.size():
		return
	var seat_type: String = ["human", "bot", "llm"][selected]
	_seats[index]["type"] = seat_type
	if seat_type == "llm":
		var current_profile: String = String(_seats[index].get("llm_profile", ""))
		if current_profile.is_empty() or UiLlmBridge.profile(current_profile) == null:
			_seats[index]["llm_profile"] = UiLlmBridge.active_profile_id()
	_active_preset = ""
	_rebuild_seats()


func _is_first_human(index: int) -> bool:
	for seat: int in _seats.size():
		if String(_seats[seat].get("type", "")) == "human":
			return seat == index
	return false


func _on_add_seat() -> void:
	if _seats.size() >= _counts[_counts.size() - 1]:
		return
	_seats.append(_default_seat(_seats.size(), "bot"))
	_active_preset = ""
	_rebuild_seats()


func _on_remove_seat(index: int) -> void:
	if _seats.size() <= _counts[0] or index < 0 or index >= _seats.size():
		return
	_seats.remove_at(index)
	_active_preset = ""
	_rebuild_seats()


func _on_count_changed(selected: int) -> void:
	var count: int = _counts[clampi(selected, 0, _counts.size() - 1)]
	while _seats.size() < count:
		_seats.append(_default_seat(_seats.size(), "bot"))
	while _seats.size() > count:
		_seats.pop_back()
	_active_preset = ""
	_rebuild_seats()


# ---------------------------------------------------------------- 汇总 / 开局

func _refresh_summary() -> void:
	if _count_segment == null:
		return
	var index: int = _counts.find(_seats.size())
	if index >= 0:
		_count_segment.selected_index = index
	var count: int = _seats.size()
	var humans: int = 0
	for entry: Dictionary in _seats:
		if String(entry.get("type", "")) == "human":
			humans += 1
	if _hotseat_switch != null:
		_hotseat_switch.set_pressed_no_signal(_hotseat_cover and humans >= 2)
		_hotseat_switch.queue_redraw()
		_hotseat_switch.disabled = humans < 2
		_hotseat_switch.modulate = Color(1, 1, 1, 0.5) if humans < 2 else Color.WHITE
	if _hotseat_hint != null:
		_hotseat_hint.text = "有 2 位以上人类时，换人前会先盖住屏幕。" if humans >= 2 \
				else "只有 1 位人类，不需要换人遮挡。"
	if _rule_values.size() > 0:
		_rule_values["胜利分"].text = "%d 分" % int(_rules.win_points)
		_rule_values["持币上限"].text = "%d 枚" % int(_rules.max_tokens)
		_rule_values["预留上限"].text = "%d 张" % int(_rules.max_reserved)
		_rule_values["宝石"].text = "每色 %d 枚 · 金 %d 枚" % [
			_rules.gems_per_color_for(count), int(_rules.gold_count),
		]
		_rule_values["贵族"].text = "%d 位" % _rules.nobles_for(count)
	if _start_button != null:
		_start_button.text = "开始观战" if humans == 0 else "开始对局"
		_start_button.disabled = count <= 0


## 校验并发出开局设置；种子不合法时只显示错误。
func start_pressed() -> void:
	if _error_label == null:
		return
	var setup: Dictionary = start_data()
	if setup.is_empty():
		_error_label.text = "种子必须是整数（留空则随机）"
		_error_label.visible = true
		return
	var llm_error: String = _llm_seat_error()
	if not llm_error.is_empty():
		_error_label.text = llm_error
		_error_label.visible = true
		return
	_error_label.visible = false
	start_requested.emit(setup)


func _llm_seat_error() -> String:
	var ids: Array[String] = UiLlmBridge.profile_ids()
	for index: int in _seats.size():
		if String(_seats[index].get("type", "human")) != "llm":
			continue
		if ids.is_empty():
			return "还没有大模型配置档：请到 设置 → 大模型 新建一个。"
		var profile_id: String = String(_seats[index].get("llm_profile", ""))
		if profile_id.is_empty():
			profile_id = UiLlmBridge.active_profile_id()
		if profile_id.is_empty() or not ids.has(profile_id):
			return "座位 %d 的大模型配置档不可用，请重新选择。" % (index + 1)
	return ""


## {count, seed, seats: [{name, type, llm_profile?}], seat_options, hotseat_cover}；
## 种子不合法时返回 {}。
func start_data() -> Dictionary:
	var seed_value: int = -1
	var seed_text: String = _seed_input.text.strip_edges() if _seed_input != null else ""
	if not seed_text.is_empty():
		if not seed_text.is_valid_int():
			return {}
		seed_value = int(seed_text)
	var seats: Array[Dictionary] = []
	var options: Array[Dictionary] = []
	var humans: int = 0
	for index: int in _seats.size():
		var entry: Dictionary = _seats[index]
		var name: String = String(entry.get("name", "")).strip_edges()
		if name.is_empty():
			name = DEFAULT_NAMES[index] if index < DEFAULT_NAMES.size() else "座位 %d" % (index + 1)
		var seat_type: String = "human"
		var option: Dictionary = {}
		if String(entry.get("type", "human")) == "bot":
			seat_type = "bot_" + String(entry.get("difficulty", "normal"))
		elif String(entry.get("type", "human")) == "llm":
			seat_type = "llm"
			var profile_id: String = String(entry.get("llm_profile", "")).strip_edges()
			if profile_id.is_empty():
				profile_id = UiLlmBridge.active_profile_id()
			option["llm_profile"] = profile_id
		if seat_type == "human":
			humans += 1
		var seat_entry: Dictionary = {"name": name, "type": seat_type}
		if seat_type == "llm":
			seat_entry["llm_profile"] = String(option.get("llm_profile", ""))
		seats.append(seat_entry)
		options.append(option)
	return {
		"count": _seats.size(),
		"seed": seed_value,
		"seats": seats,
		"seat_options": options,
		"hotseat_cover": _hotseat_cover and humans >= 2,
	}


func report_start_failed(message: String) -> void:
	if _error_label == null:
		return
	_error_label.text = message
	_error_label.visible = true


# ---------------------------------------------------------------- 测试用

func seat_count() -> int:
	return _seats.size()


func seat_data() -> Array[Dictionary]:
	return _seats.duplicate(true)


func set_seat_type(index: int, seat_type: String) -> void:
	if index < 0 or index >= _seats.size():
		return
	_seats[index]["type"] = seat_type
	if seat_type == "llm" and String(_seats[index].get("llm_profile", "")).is_empty():
		_seats[index]["llm_profile"] = UiLlmBridge.active_profile_id()
	_rebuild_seats()


func set_seat_profile(index: int, profile_id: String) -> void:
	if index < 0 or index >= _seats.size():
		return
	_seats[index]["llm_profile"] = profile_id
	_rebuild_seats()


func seat_llm_profile(index: int) -> String:
	if index < 0 or index >= _seats.size():
		return ""
	return String(_seats[index].get("llm_profile", ""))


func set_seed_text(text: String) -> void:
	if _seed_input != null:
		_seed_input.text = text


func set_hotseat_cover(on: bool) -> void:
	_hotseat_cover = on
	_refresh_summary()


func start_button() -> UiButton:
	return _start_button


func count_segment() -> UiSegmented:
	return _count_segment


func hotseat_switch() -> UiSwitch:
	return _hotseat_switch


func preset_button(key: String) -> UiButton:
	return _preset_buttons.get(key)


func error_text() -> String:
	return _error_label.text if _error_label != null else ""


func rule_value(key: String) -> String:
	var label: Label = _rule_values.get(key)
	return label.text if label != null else ""
