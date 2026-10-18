## 大模型配置面板（调试界面）：配置档增删改、连接参数、思考预算、重试、兜底难度、性格，
## 以及「测试连接」。保存后写入 user://config.json；API Key 只显示密码框，不写日志。
## 正式 UI 会用自己的设置页替换这个面板（见 docs/ui/SCREENS.md 第 16 屏）。
class_name LlmSettings
extends Control

signal closed

var _profile_option: OptionButton
var _id_label: Label
var _display_name_edit: LineEdit
var _base_url_edit: LineEdit
var _api_key_edit: LineEdit
var _model_edit: LineEdit
var _temperature_spin: SpinBox
var _max_tokens_spin: SpinBox
var _request_timeout_spin: SpinBox
var _think_budget_spin: SpinBox
var _max_retries_spin: SpinBox
var _structured_option: OptionButton
var _thinking_option: OptionButton
var _fallback_option: OptionButton
var _personality_option: OptionButton
var _status_label: Label
var _test_button: Button
var _test_client: LlmClient = null
var _test_started_ms: int = 0
var _test_timer: Timer = null
var _current_id: String = ""

func _ready() -> void:
	_build_ui()
	refresh_from_config()

# ---------------------------------------------------------------- 对外接口

## 重新读取 AppConfig，刷新配置档下拉框与表单。
func refresh_from_config() -> void:
	var ids: Array[String] = AppConfig.llm_profile_ids()
	var previous: String = _current_id
	_profile_option.clear()
	if ids.is_empty():
		_current_id = ""
		_clear_fields()
		_set_buttons_enabled(false)
		var empty_errors: String = _config_errors_text()
		_status_label.text = empty_errors if not empty_errors.is_empty() \
				else "没有配置档，点「新建」创建第一个。"
		return
	for profile_id: String in ids:
		var profile: LlmProfile = AppConfig.llm_profile(profile_id)
		_profile_option.add_item(profile.display_name if profile != null else profile_id)
		_profile_option.set_item_metadata(_profile_option.item_count - 1, profile_id)
	var target_index: int = 0
	if not previous.is_empty() and ids.has(previous):
		for index: int in _profile_option.item_count:
			if String(_profile_option.get_item_metadata(index)) == previous:
				target_index = index
				break
	_profile_option.select(target_index)
	_load_profile(String(_profile_option.get_item_metadata(target_index)))
	var errors: String = _config_errors_text()
	if not errors.is_empty():
		_status_label.text = errors

# ---------------------------------------------------------------- 界面

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.14, 0.18)
	style.border_color = Color(0.85, 0.7, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 4)
	panel.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	margin.add_child(outer)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 520)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	scroll.add_child(column)

	var title := Label.new()
	title.text = "大模型设置"
	title.add_theme_font_size_override("font_size", 22)
	column.add_child(title)
	var hint := Label.new()
	hint.text = "兼容 OpenAI 的 /chat/completions。API Key 只保存在本机 user://config.json，不进存档、不发给对手。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(1, 1, 1, 0.65)
	column.add_child(hint)

	var profile_row := HBoxContainer.new()
	profile_row.add_theme_constant_override("separation", 6)
	column.add_child(profile_row)
	profile_row.add_child(_label("配置档"))
	_profile_option = OptionButton.new()
	_profile_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_profile_option.item_selected.connect(_on_profile_selected)
	profile_row.add_child(_profile_option)
	var new_button := Button.new()
	new_button.text = "新建"
	new_button.pressed.connect(_on_new_pressed)
	profile_row.add_child(new_button)
	var delete_button := Button.new()
	delete_button.text = "删除"
	delete_button.pressed.connect(_on_delete_pressed)
	profile_row.add_child(delete_button)
	_id_label = _label("")
	_id_label.modulate = Color(1, 1, 1, 0.5)
	column.add_child(_id_label)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	column.add_child(grid)
	_display_name_edit = _add_line_edit(grid, "显示名")
	_base_url_edit = _add_line_edit(grid, "BASE URL")
	_api_key_edit = _add_line_edit(grid, "API KEY")
	_api_key_edit.secret = true
	_model_edit = _add_line_edit(grid, "模型名")
	_temperature_spin = _add_spin(grid, "温度", 0.0, 2.0, 0.1)
	_max_tokens_spin = _add_spin(grid, "最大回复 token（推理模型建议 ≥4096 或关闭思考）", 1, 8192, 1)
	_request_timeout_spin = _add_spin(grid, "单次请求超时（ms）", 500, 600000, 1000)
	_think_budget_spin = _add_spin(grid, "每步思考预算（ms，0=不限）", 0, 600000, 1000)
	_max_retries_spin = _add_spin(grid, "解析失败重试次数", 0, 5, 1)
	_structured_option = _add_option(grid, "结构化输出", [
		["auto（先试 response_format）", LlmProfile.STRUCTURED_AUTO],
		["json_object（OpenAI）", LlmProfile.STRUCTURED_JSON_OBJECT],
		["format（Ollama）", LlmProfile.STRUCTURED_OLLAMA_FORMAT],
		["none（纯文本解析）", LlmProfile.STRUCTURED_NONE],
	])
	_thinking_option = _add_option(grid, "思考强度（reasoning_effort）", [
		["默认（不发送）", LlmProfile.THINKING_DEFAULT],
		["关闭", "none"],
		["低", "low"],
		["中", "medium"],
		["高", "high"],
		["最大", "max"],
	])
	_fallback_option = _add_option(grid, "失败时兜底", [
		["简单电脑", "easy"], ["普通电脑", "normal"], ["困难电脑", "hard"],
	])
	_personality_option = _add_option(grid, "性格", [
		["均衡", "balanced"], ["激进", "aggressive"], ["保守", "conservative"], ["阻挡", "blocking"],
	])

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 8)
	outer.add_child(button_row)
	_test_button = Button.new()
	_test_button.text = "测试连接"
	_test_button.pressed.connect(_on_test_pressed)
	button_row.add_child(_test_button)
	var save_button := Button.new()
	save_button.text = "保存"
	save_button.pressed.connect(_on_save_pressed)
	button_row.add_child(save_button)
	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.pressed.connect(_on_close_pressed)
	button_row.add_child(close_button)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.modulate = Color(1, 0.75, 0.45)
	outer.add_child(_status_label)

	_test_timer = Timer.new()
	_test_timer.wait_time = 0.2
	_test_timer.timeout.connect(_on_test_timer)
	add_child(_test_timer)

# ---------------------------------------------------------------- 表单

func _load_profile(profile_id: String) -> void:
	var profile: LlmProfile = AppConfig.llm_profile(profile_id)
	if profile == null:
		_clear_fields()
		_set_buttons_enabled(false)
		return
	_current_id = profile.id
	_set_buttons_enabled(true)
	_id_label.text = "配置档 id：%s" % profile.id
	_display_name_edit.text = profile.display_name
	_base_url_edit.text = profile.base_url
	_api_key_edit.text = profile.api_key
	_model_edit.text = profile.model
	_temperature_spin.value = profile.temperature
	_max_tokens_spin.value = profile.max_tokens
	_request_timeout_spin.value = profile.request_timeout_ms
	_think_budget_spin.value = profile.think_budget_ms
	_max_retries_spin.value = profile.max_retries
	_select_option(_structured_option, profile.structured_output)
	_select_option(_thinking_option, profile.thinking_effort)
	_select_option(_fallback_option, profile.fallback_difficulty)
	_select_option(_personality_option, profile.personality)
	_status_label.text = ""

func _clear_fields() -> void:
	_id_label.text = ""
	_display_name_edit.text = ""
	_base_url_edit.text = ""
	_api_key_edit.text = ""
	_model_edit.text = ""
	_temperature_spin.value = 0.7
	_max_tokens_spin.value = 1024
	_request_timeout_spin.value = 20000
	_think_budget_spin.value = 30000
	_max_retries_spin.value = 2

func _set_buttons_enabled(enabled: bool) -> void:
	_test_button.disabled = not enabled
	_display_name_edit.editable = enabled
	_base_url_edit.editable = enabled
	_api_key_edit.editable = enabled
	_model_edit.editable = enabled
	_temperature_spin.editable = enabled
	_max_tokens_spin.editable = enabled
	_request_timeout_spin.editable = enabled
	_think_budget_spin.editable = enabled
	_max_retries_spin.editable = enabled
	_structured_option.disabled = not enabled
	_thinking_option.disabled = not enabled
	_fallback_option.disabled = not enabled
	_personality_option.disabled = not enabled

## 从表单构造 LlmProfile；校验失败时把原因写到状态栏并返回 null。
func _profile_from_fields() -> LlmProfile:
	if _current_id.is_empty():
		_status_label.text = "✗ 没有选中的配置档"
		return null
	var data: Dictionary = {
		"display_name": _display_name_edit.text.strip_edges(),
		"base_url": _base_url_edit.text.strip_edges(),
		"api_key": _api_key_edit.text.strip_edges(),
		"model": _model_edit.text.strip_edges(),
		"temperature": _temperature_spin.value,
		"max_tokens": int(_max_tokens_spin.value),
		"request_timeout_ms": int(_request_timeout_spin.value),
		"think_budget_ms": int(_think_budget_spin.value),
		"max_retries": int(_max_retries_spin.value),
		"structured_output": String(_structured_option.get_item_metadata(
				_structured_option.selected)),
		"thinking_effort": String(_thinking_option.get_item_metadata(
				_thinking_option.selected)),
		"fallback_difficulty": String(_fallback_option.get_item_metadata(
				_fallback_option.selected)),
		"personality": String(_personality_option.get_item_metadata(
				_personality_option.selected)),
	}
	var errors: Array[String] = []
	var profile: LlmProfile = LlmProfile.from_dict(data, _current_id, errors)
	if profile == null:
		_status_label.text = "✗ " + "；".join(errors)
		return null
	return profile

# ---------------------------------------------------------------- 按钮

func _on_profile_selected(index: int) -> void:
	var metadata: Variant = _profile_option.get_item_metadata(index)
	if metadata == null:
		return
	_load_profile(String(metadata))

func _on_new_pressed() -> void:
	var data: Dictionary = AppConfig.example_profile_data()
	var new_id: String = AppConfig.new_profile_id()
	data["display_name"] = "新配置档"
	data["api_key"] = ""
	var errors: Array[String] = []
	var profile: LlmProfile = LlmProfile.from_dict(data, new_id, errors)
	if profile == null:
		_status_label.text = "✗ 示例配置不可用：" + "；".join(errors)
		return
	if not AppConfig.save_llm_profile(profile):
		_status_label.text = "✗ " + AppConfig.last_operation_error()
		return
	_current_id = new_id
	refresh_from_config()
	_status_label.text = "已新建配置档 %s，填好后点「保存」。" % new_id

func _on_delete_pressed() -> void:
	if _current_id.is_empty():
		return
	if not AppConfig.delete_llm_profile(_current_id):
		_status_label.text = "✗ " + AppConfig.last_operation_error()
		return
	_current_id = ""
	refresh_from_config()
	_status_label.text = "已删除。"

func _on_save_pressed() -> void:
	var profile: LlmProfile = _profile_from_fields()
	if profile == null:
		return
	if not AppConfig.save_llm_profile(profile):
		_status_label.text = "✗ " + AppConfig.last_operation_error()
		return
	refresh_from_config()
	_status_label.text = "✓ 已保存到 user://config.json。"

func _on_test_pressed() -> void:
	if _test_client != null:
		return
	var profile: LlmProfile = _profile_from_fields()
	if profile == null:
		return
	_test_button.disabled = true
	_status_label.text = "连接中…"
	_test_started_ms = Time.get_ticks_msec()
	_test_timer.start()
	_test_client = LlmClient.new()
	add_child(_test_client)
	_test_client.test_finished.connect(_on_test_finished)
	var timeout_ms: int = mini(profile.request_timeout_ms, 20000)
	_test_client.test_connection(profile, timeout_ms)

func _on_test_finished(ok: bool, message: String, elapsed_ms: int) -> void:
	_test_timer.stop()
	if _test_client != null:
		_test_client.queue_free()
		_test_client = null
	_test_button.disabled = false
	if ok:
		_status_label.text = "✓ %s · %.1f 秒" % [message, float(elapsed_ms) / 1000.0]
	else:
		_status_label.text = "✗ 连接失败：%s" % message

func _on_test_timer() -> void:
	if _test_client == null:
		return
	var elapsed: float = float(Time.get_ticks_msec() - _test_started_ms) / 1000.0
	_status_label.text = "连接中… 已等 %.1f 秒" % elapsed

func _on_close_pressed() -> void:
	if _test_client != null:
		_test_client.cancel()
		_test_client.queue_free()
		_test_client = null
	_test_timer.stop()
	hide()
	closed.emit()

# ---------------------------------------------------------------- 小工具

func _add_line_edit(grid: GridContainer, label_text: String) -> LineEdit:
	grid.add_child(_label(label_text))
	var edit := LineEdit.new()
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(edit)
	return edit

func _add_spin(grid: GridContainer, label_text: String, minimum: float,
		maximum: float, step: float) -> SpinBox:
	grid.add_child(_label(label_text))
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(spin)
	return spin

func _add_option(grid: GridContainer, label_text: String, items: Array) -> OptionButton:
	grid.add_child(_label(label_text))
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item: Array in items:
		option.add_item(String(item[0]))
		option.set_item_metadata(option.item_count - 1, String(item[1]))
	grid.add_child(option)
	return option

func _select_option(option: OptionButton, value: String) -> void:
	for index: int in option.item_count:
		if String(option.get_item_metadata(index)) == value:
			option.select(index)
			return

func _config_errors_text() -> String:
	var errors: Array[String] = AppConfig.get_errors()
	if errors.is_empty():
		return ""
	return "✗ 配置有问题：%s" % "；".join(errors)

func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label
