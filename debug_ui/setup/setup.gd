## 开局设置：人数、种子、每个座位的类型与配置。阶段 5 开放人类、三档电脑和大模型，
## 大模型座位可以选择配置档；「大模型设置…」打开配置面板（增删改 / 测试连接）。
## 开始按钮只发出 start_requested，由主界面负责创建对局。
class_name SetupScreen
extends Control

## seat_options 与座位一一对应；大模型座位形如 {"llm_profile": "deepseek"}。
signal start_requested(player_count: int, seed: int, seat_types: Array[String],
		seat_options: Array[Dictionary])

const MAX_SEATS: int = 4
const DEFAULT_HUMAN_SEAT_TYPE: String = "human"
const DEFAULT_BOT_SEAT_TYPE: String = "bot_normal"
const SEAT_TYPE_LLM: String = "llm"
## [显示名, 座位类型, 是否禁用]。阶段 6 再把"远程"的禁用去掉。
const SEAT_TYPE_ITEMS: Array = [
	["人类", "human", false],
	["电脑（简单）", "bot_easy", false],
	["电脑（普通）", "bot_normal", false],
	["电脑（困难）", "bot_hard", false],
	["大模型", "llm", false],
	["远程", "remote", true],
]

var _count_option: OptionButton
var _seed_edit: LineEdit
var _seat_rows: Array[HBoxContainer] = []
var _seat_options: Array[OptionButton] = []
var _seat_profile_options: Array[OptionButton] = []
var _start_button: Button
var _status_label: Label
var _llm_hint: Label
var _llm_settings: LlmSettings = null

func _ready() -> void:
	_build_ui()
	_refresh_llm_profiles()
	_refresh_seat_rows()
	if not DataRegistry.is_valid():
		var errors: Array[String] = DataRegistry.get_errors()
		_status_label.text = "✗ 数据校验失败（%d 个问题）：%s" % [
			errors.size(), errors[0] if not errors.is_empty() else ""]
		_start_button.disabled = true

# ---------------------------------------------------------------- 对外接口

## 主界面在开局失败时调用。
func show_error(message: String) -> void:
	_status_label.text = "✗ " + message

# ---------------------------------------------------------------- 界面

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.14, 0.18)
	style.border_color = Color(0.45, 0.4, 0.28)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var title := Label.new()
	title.text = "璀璨宝石 · 新对局"
	title.add_theme_font_size_override("font_size", 24)
	column.add_child(title)
	var hint := Label.new()
	hint.text = "阶段 5：人类、三档电脑和大模型可以混合；大模型失败时自动由程序 AI 兜底。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(0, 22)
	hint.modulate = Color(1, 1, 1, 0.7)
	column.add_child(hint)

	var count_row := HBoxContainer.new()
	column.add_child(count_row)
	count_row.add_child(_label("人数"))
	_count_option = OptionButton.new()
	for player_count: int in [2, 3, 4]:
		_count_option.add_item(str(player_count), player_count)
	_count_option.select(0)
	_count_option.item_selected.connect(_on_count_changed)
	count_row.add_child(_count_option)

	var seed_row := HBoxContainer.new()
	column.add_child(seed_row)
	seed_row.add_child(_label("种子"))
	_seed_edit = LineEdit.new()
	_seed_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed_edit.text = str(randi())
	seed_row.add_child(_seed_edit)
	var random_button := Button.new()
	random_button.text = "随机"
	random_button.pressed.connect(_on_random_seed)
	seed_row.add_child(random_button)

	var seats_grid := GridContainer.new()
	seats_grid.columns = 1
	seats_grid.add_theme_constant_override("h_separation", 8)
	seats_grid.add_theme_constant_override("v_separation", 6)
	column.add_child(seats_grid)
	for seat: int in MAX_SEATS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var seat_label := _label("座位 %d" % seat)
		seat_label.custom_minimum_size = Vector2(58, 0)
		row.add_child(seat_label)
		var option := OptionButton.new()
		option.custom_minimum_size = Vector2(150, 0)
		option.set_meta("role", "seat_type")
		option.set_meta("seat", seat)
		for item: Array in SEAT_TYPE_ITEMS:
			option.add_item(String(item[0]))
			var index: int = option.item_count - 1
			option.set_item_metadata(index, String(item[1]))
			option.set_item_disabled(index, bool(item[2]))
		option.item_selected.connect(_on_seat_type_changed.bind(seat))
		row.add_child(option)
		var profile_option := OptionButton.new()
		profile_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		profile_option.set_meta("role", "llm_profile")
		profile_option.set_meta("seat", seat)
		profile_option.visible = false
		row.add_child(profile_option)
		seats_grid.add_child(row)
		_seat_rows.append(row)
		_seat_options.append(option)
		_seat_profile_options.append(profile_option)
	# 默认人机对战：座位 0 是人类，其余座位是普通电脑。
	for seat: int in MAX_SEATS:
		var default_type: String = DEFAULT_HUMAN_SEAT_TYPE if seat == 0 else DEFAULT_BOT_SEAT_TYPE
		_select_seat_type(_seat_options[seat], default_type)

	var llm_row := HBoxContainer.new()
	column.add_child(llm_row)
	var llm_button := Button.new()
	llm_button.text = "大模型设置…"
	llm_button.pressed.connect(_on_llm_settings_pressed)
	llm_row.add_child(llm_button)
	_llm_hint = Label.new()
	_llm_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_llm_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_llm_hint.modulate = Color(1, 1, 1, 0.65)
	llm_row.add_child(_llm_hint)

	_start_button = Button.new()
	_start_button.text = "开始游戏"
	_start_button.add_theme_font_size_override("font_size", 18)
	_start_button.pressed.connect(_on_start_pressed)
	column.add_child(_start_button)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.modulate = Color(1, 0.6, 0.6)
	column.add_child(_status_label)

func _on_count_changed(_index: int) -> void:
	_refresh_seat_rows()
	_status_label.text = ""

func _on_random_seed() -> void:
	_seed_edit.text = str(randi())
	_status_label.text = ""

func _on_seat_type_changed(_index: int, seat: int) -> void:
	_refresh_profile_visibility(seat)
	_status_label.text = ""

func _refresh_seat_rows() -> void:
	var player_count: int = _selected_player_count()
	for seat: int in _seat_rows.size():
		_seat_rows[seat].visible = seat < player_count
		_refresh_profile_visibility(seat)
	_refresh_llm_availability()

## 把配置档列表同步到每个座位的下拉框；当前没有可用配置档时禁用"大模型"选项。
func _refresh_llm_profiles() -> void:
	var ids: Array[String] = AppConfig.llm_profile_ids()
	for seat: int in _seat_profile_options.size():
		var option: OptionButton = _seat_profile_options[seat]
		var previous: String = _selected_profile_id(option)
		option.clear()
		if ids.is_empty():
			option.add_item("（无配置档）")
			option.set_item_metadata(0, "")
			option.disabled = true
			continue
		option.disabled = false
		for profile_id: String in ids:
			var profile: LlmProfile = AppConfig.llm_profile(profile_id)
			var display_name: String = profile.display_name if profile != null else profile_id
			option.add_item(display_name)
			var index: int = option.item_count - 1
			option.set_item_metadata(index, profile_id)
			if profile_id == previous:
				option.select(index)
		if previous.is_empty() or not ids.has(previous):
			if not _select_profile_by_id(option, AppConfig.active_llm_profile_id()):
				option.select(0)
	_refresh_llm_availability()

func _refresh_llm_availability() -> void:
	var has_profiles: bool = AppConfig.has_llm_profiles()
	for option: OptionButton in _seat_options:
		for index: int in option.item_count:
			if String(option.get_item_metadata(index)) == SEAT_TYPE_LLM:
				option.set_item_disabled(index, not has_profiles)
				break
	if has_profiles:
		_llm_hint.text = "大模型座位失败时自动由困难电脑兜底；Key 只存在本机 user://config.json。"
	else:
		_llm_hint.text = "没有可用的大模型配置档，点「大模型设置…」新建或填写 Key。"

func _refresh_profile_visibility(seat: int) -> void:
	if seat < 0 or seat >= _seat_options.size():
		return
	var seat_type: String = String(
			_seat_options[seat].get_item_metadata(_seat_options[seat].selected))
	_seat_profile_options[seat].visible = seat_type == SEAT_TYPE_LLM

func _on_start_pressed() -> void:
	var seed_text: String = _seed_edit.text.strip_edges()
	if not seed_text.is_valid_int():
		_status_label.text = "✗ 种子必须是整数（可以点「随机」）"
		return
	var player_count: int = _selected_player_count()
	var seat_types: Array[String] = []
	var seat_options: Array[Dictionary] = []
	for seat: int in player_count:
		var option: OptionButton = _seat_options[seat]
		var seat_type: String = String(option.get_item_metadata(option.selected))
		seat_types.append(seat_type)
		if seat_type == SEAT_TYPE_LLM:
			var profile_id: String = _selected_profile_id(_seat_profile_options[seat])
			if profile_id.is_empty():
				_status_label.text = "✗ 座位 %d 选择了大模型，但没有可用的配置档" % seat
				return
			seat_options.append({"llm_profile": profile_id})
		else:
			seat_options.append({})
	_status_label.text = ""
	start_requested.emit(player_count, int(seed_text), seat_types, seat_options)

func _selected_player_count() -> int:
	return _count_option.get_item_id(_count_option.selected)

func _selected_profile_id(option: OptionButton) -> String:
	if option == null or option.selected < 0 or option.item_count == 0:
		return ""
	var metadata: Variant = option.get_item_metadata(option.selected)
	return "" if metadata == null else String(metadata)

func _select_profile_by_id(option: OptionButton, profile_id: String) -> bool:
	for index: int in option.item_count:
		if String(option.get_item_metadata(index)) == profile_id:
			option.select(index)
			return true
	return false

func _select_seat_type(option: OptionButton, seat_type: String) -> void:
	for index: int in option.item_count:
		if String(option.get_item_metadata(index)) == seat_type:
			option.select(index)
			return

func _on_llm_settings_pressed() -> void:
	if _llm_settings == null:
		_llm_settings = preload("res://debug_ui/llm_settings/llm_settings.tscn").instantiate() as LlmSettings
		_llm_settings.closed.connect(_on_llm_settings_closed)
		add_child(_llm_settings)
	_llm_settings.show()
	_llm_settings.refresh_from_config()

func _on_llm_settings_closed() -> void:
	_refresh_llm_profiles()
	_status_label.text = ""

func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label
