## 设置 · 大模型配置档（16）：左侧列表 + 右侧连接参数 / 出手 / 兜底。
## 配置档读写走 UiLlmBridge（AppConfig）；测试连接走 LlmClient，结果只在界面里显示。
class_name UiSettingsLlmPage
extends Control

const BUDGET_LABELS: Array[String] = ["15 秒", "30 秒", "60 秒", "不限"]
const BUDGET_VALUES: Array[int] = [15000, 30000, 60000, 0]
const RETRY_LABELS: Array[String] = ["0 次", "2 次", "4 次"]
const RETRY_VALUES: Array[int] = [0, 2, 4]
const FALLBACK_LABELS: Array[String] = ["简单", "普通", "困难"]
const FALLBACK_VALUES: Array[String] = ["easy", "normal", "hard"]
const PERSONALITY_LABELS: Array[String] = ["均衡", "激进", "保守", "阻挡"]
const PERSONALITY_VALUES: Array[String] = ["balanced", "aggressive", "conservative", "blocking"]
const THINKING_LABELS: Array[String] = ["默认", "关闭", "低", "中", "高", "最大"]
const THINKING_VALUES: Array[String] = ["default", "none", "low", "medium", "high", "max"]
const STRUCTURED_LABELS: Array[String] = ["自动", "JSON", "format", "关闭"]
const STRUCTURED_VALUES: Array[String] = [
	"auto", "json_object", "ollama_format", "none",
]

var _bridge: UiLlmBridge
var _usage: Dictionary = {}
var _current_id: String = ""
## profile_id -> {ok, message, elapsed_ms}；只存在本次会话里。
var _test_results: Dictionary = {}
var _test_elapsed_ms: int = 0
var _tick_accum: float = 0.0
var _delete_armed: bool = false

var _list: VBoxContainer
var _new_button: UiButton
var _delete_button: UiButton
var _test_button: UiButton
var _save_button: UiButton
var _status_label: Label
var _name_input: UiInput
var _url_input: UiInput
var _key_input: UiInput
var _model_input: UiInput
var _temperature_input: UiInput
var _max_tokens_input: UiInput
var _request_timeout_input: UiInput
var _budget_segment: UiSegmented
var _retry_segment: UiSegmented
var _thinking_segment: UiSegmented
var _structured_segment: UiSegmented
var _fallback_segment: UiSegmented
var _personality_segment: UiSegmented


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bridge = UiLlmBridge.new()
	_bridge.name = "LlmBridge"
	add_child(_bridge)
	_bridge.test_finished.connect(_on_test_finished)
	_build()
	refresh()


## 应用入口把当前对局里各配置档的座位数传进来。
func set_usage(usage: Dictionary) -> void:
	_usage = usage.duplicate(true)
	if is_node_ready():
		_refresh_list()


# ---------------------------------------------------------------- 布局

func _build() -> void:
	var columns := HBoxContainer.new()
	columns.name = "Columns"
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	columns.add_theme_constant_override("separation", 20)
	add_child(columns)

	var left := VBoxContainer.new()
	left.name = "Left"
	left.custom_minimum_size.x = 340
	left.add_theme_constant_override("separation", 12)
	columns.add_child(left)
	_build_list_panel(left)

	# 新的连接 / 出手设置较多，1280×800 下右栏需要滚动，否则“兜底与性格”会被裁掉。
	var right_scroll := ScrollContainer.new()
	right_scroll.name = "RightScroll"
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(right_scroll)
	var right := VBoxContainer.new()
	right.name = "Right"
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	right_scroll.add_child(right)
	_build_connection_panel(right)
	_build_decision_panel(right)
	_build_fallback_panel(right)


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


func _build_list_panel(parent: VBoxContainer) -> void:
	var panel := _make_panel("ProfilesPanel")
	panel.feature_bar = true
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.content.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	column.add_child(header)
	var title := Label.new()
	title.text = "大模型配置档"
	title.theme_type_variation = &"UiTitle"
	header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_new_button = UiButton.new()
	_new_button.name = "NewProfile"
	_new_button.variant = &"quiet"
	_new_button.size_key = &"sm"
	_new_button.text = "＋ 新建"
	_new_button.focus_mode = Control.FOCUS_NONE
	_new_button.pressed.connect(_on_new_pressed)
	header.add_child(_new_button)

	var scroll := ScrollContainer.new()
	scroll.name = "ProfileScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_list = VBoxContainer.new()
	_list.name = "ProfileList"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)

	var hint := Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", UiPalette.INK_3)
	hint.text = "模型失败或超时后由所选难度的电脑当场代打；4 人局一局大约 60–120 次请求。"
	column.add_child(hint)


func _build_connection_panel(parent: VBoxContainer) -> void:
	var panel := _make_panel("ConnectionPanel")
	panel.feature_bar = true
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.content.add_child(column)

	var title := Label.new()
	title.text = "连接配置"
	title.theme_type_variation = &"UiTitle"
	column.add_child(title)

	_name_input = _make_input("DisplayName", "显示名")
	_url_input = _make_input("BaseUrl", "BASE URL")
	_key_input = _make_input("ApiKey", "API KEY")
	_key_input.secret = true
	_model_input = _make_input("Model", "模型名")
	_add_field(column, "名称", _name_input)
	_add_field(column, "BASE URL", _url_input)
	_add_field(column, "API KEY", _key_input)
	_add_field(column, "模型名", _model_input)

	var note := Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", UiPalette.INK_3)
	note.text = "兼容 OpenAI 接口格式。API Key 只存在本机 user://config.json，不进存档、不发给联网对手。"
	column.add_child(note)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	_test_button = UiButton.new()
	_test_button.name = "TestConnection"
	_test_button.variant = &"ghost"
	_test_button.size_key = &"sm"
	_test_button.text = "测试连接"
	_test_button.focus_mode = Control.FOCUS_NONE
	_test_button.pressed.connect(_on_test_pressed)
	row.add_child(_test_button)
	_save_button = UiButton.new()
	_save_button.name = "SaveProfile"
	_save_button.variant = &"accent"
	_save_button.size_key = &"sm"
	_save_button.text = "保存"
	_save_button.focus_mode = Control.FOCUS_NONE
	_save_button.pressed.connect(_on_save_pressed)
	row.add_child(_save_button)
	_delete_button = UiButton.new()
	_delete_button.name = "DeleteProfile"
	_delete_button.variant = &"quiet"
	_delete_button.size_key = &"sm"
	_delete_button.text = "删除"
	_delete_button.focus_mode = Control.FOCUS_NONE
	_delete_button.pressed.connect(_on_delete_pressed)
	row.add_child(_delete_button)
	_status_label = Label.new()
	_status_label.name = "LlmStatus"
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.add_theme_color_override("font_color", UiPalette.INK_2)
	row.add_child(_status_label)


func _build_decision_panel(parent: VBoxContainer) -> void:
	var panel := _make_panel("DecisionPanel")
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.content.add_child(column)

	var title := Label.new()
	title.text = "出手"
	title.theme_type_variation = &"UiTitle"
	column.add_child(title)

	_budget_segment = UiSegmented.new()
	_budget_segment.name = "ThinkBudget"
	_budget_segment.items = BUDGET_LABELS
	_add_field(column, "每步思考上限", _budget_segment)

	_retry_segment = UiSegmented.new()
	_retry_segment.name = "MaxRetries"
	_retry_segment.items = RETRY_LABELS
	_add_field(column, "解析失败重试", _retry_segment)

	_temperature_input = _make_input("Temperature", "0.7")
	_temperature_input.custom_minimum_size.x = 90
	_add_field(column, "温度", _temperature_input, "0 ~ 2；越低越稳定。")

	var limits := HBoxContainer.new()
	limits.add_theme_constant_override("separation", 8)
	column.add_child(limits)
	var tokens_label := Label.new()
	tokens_label.text = "最大回复 token"
	tokens_label.custom_minimum_size.x = 118
	tokens_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tokens_label.add_theme_color_override("font_color", UiPalette.INK_2)
	limits.add_child(tokens_label)
	_max_tokens_input = _make_input("MaxTokens", "1024")
	_max_tokens_input.custom_minimum_size.x = 80
	_max_tokens_input.size_flags_horizontal = Control.SIZE_FILL
	limits.add_child(_max_tokens_input)
	var timeout_label := Label.new()
	timeout_label.text = "单次超时 (ms)"
	timeout_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timeout_label.add_theme_color_override("font_color", UiPalette.INK_2)
	limits.add_child(timeout_label)
	_request_timeout_input = _make_input("RequestTimeout", "20000")
	_request_timeout_input.custom_minimum_size.x = 96
	_request_timeout_input.size_flags_horizontal = Control.SIZE_FILL
	limits.add_child(_request_timeout_input)
	var limits_spacer := Control.new()
	limits_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	limits.add_child(limits_spacer)
	var limits_note := Label.new()
	limits_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	limits_note.add_theme_color_override("font_color", UiPalette.INK_3)
	limits_note.text = "推理模型建议把思考强度设为关闭/低；若保持思考，max_tokens 建议 4096 以上。"
	column.add_child(limits_note)

	_thinking_segment = UiSegmented.new()
	_thinking_segment.name = "ThinkingEffort"
	_thinking_segment.items = THINKING_LABELS
	_add_field(column, "思考强度", _thinking_segment, "作为 reasoning_effort 发送；不支持的模型选“默认”。")

	_structured_segment = UiSegmented.new()
	_structured_segment.name = "StructuredOutput"
	_structured_segment.items = STRUCTURED_LABELS
	_add_field(column, "结构化输出", _structured_segment, "服务不支持时会自动去掉参数重试。")


func _build_fallback_panel(parent: VBoxContainer) -> void:
	var panel := _make_panel("FallbackPanel")
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.content.add_child(column)

	var title := Label.new()
	title.text = "兜底与性格"
	title.theme_type_variation = &"UiTitle"
	column.add_child(title)

	_fallback_segment = UiSegmented.new()
	_fallback_segment.name = "FallbackDifficulty"
	_fallback_segment.items = FALLBACK_LABELS
	_add_field(column, "失败时交给", _fallback_segment)

	_personality_segment = UiSegmented.new()
	_personality_segment.name = "Personality"
	_personality_segment.items = PERSONALITY_LABELS
	_add_field(column, "性格", _personality_segment)


func _make_input(input_name: String, placeholder: String) -> UiInput:
	var input := UiInput.new()
	input.name = input_name
	input.placeholder_text = placeholder
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return input


func _add_field(parent: VBoxContainer, title: String, control: Control,
		hint: String = "") -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size.x = 118
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", UiPalette.INK_2)
	row.add_child(label)
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if control is LineEdit:
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	if not hint.is_empty():
		var note := Label.new()
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.add_theme_color_override("font_color", UiPalette.INK_3)
		note.text = hint
		parent.add_child(note)


# ---------------------------------------------------------------- 列表 / 选择

func refresh() -> void:
	if _bridge == null:
		return
	var ids: Array[String] = UiLlmBridge.profile_ids()
	if _current_id.is_empty() or not ids.has(_current_id):
		_current_id = ids[0] if not ids.is_empty() else ""
	_refresh_list()
	if _current_id.is_empty():
		_clear_fields()
		_set_enabled(false)
		_status_label.text = "还没有配置档，点「新建」创建一个。"
	else:
		_load_profile(_current_id)
		_set_enabled(true)


func _refresh_list() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var ids: Array[String] = UiLlmBridge.profile_ids()
	for profile_id: String in ids:
		var profile: LlmProfile = UiLlmBridge.profile(profile_id)
		var row := UiListRow.new()
		row.name = "Profile_%s" % profile_id
		# 标题 + 副标题 + 状态需要比默认 44 更高的行，否则副标题会压到分隔线上。
		row.custom_minimum_size.y = 58
		row.title = profile.display_name if profile != null else profile_id
		var model: String = profile.model if profile != null else ""
		var used: int = int(_usage.get(profile_id, 0))
		var used_text: String = "%d 个座位在用" % used if used > 0 else "没有座位在用"
		row.subtitle = "%s · %s" % [model, used_text] if not model.is_empty() else used_text
		row.meta = _status_text(profile_id)
		row.selected = profile_id == _current_id
		row.pressed.connect(_select_profile.bind(profile_id))
		_list.add_child(row)
	if _delete_button != null:
		_delete_button.disabled = ids.size() <= 1 or _current_id.is_empty()


func _status_text(profile_id: String) -> String:
	if _test_results.has(profile_id):
		var result: Dictionary = _test_results[profile_id]
		if bool(result.get("ok", false)):
			return "✓ 已连接"
		var message: String = String(result.get("message", "")).to_lower()
		if message.contains("401") or message.contains("unauthorized") or message.contains("api key"):
			return "✗ Key 无效"
		return "✗ 连接失败"
	return "未测试"


func _select_profile(profile_id: String) -> void:
	if _current_id == profile_id:
		return
	_current_id = profile_id
	_reset_delete_arm()
	_status_label.text = ""
	_status_label.add_theme_color_override("font_color", UiPalette.INK_2)
	_load_profile(profile_id)
	_set_enabled(true)
	_refresh_list()


func _load_profile(profile_id: String) -> void:
	var profile: LlmProfile = UiLlmBridge.profile(profile_id)
	if profile == null:
		return
	_name_input.text = profile.display_name
	_url_input.text = profile.base_url
	_key_input.text = profile.api_key
	_model_input.text = profile.model
	_temperature_input.text = String.num(profile.temperature, 2).trim_suffix("0").trim_suffix(".")
	_max_tokens_input.text = str(profile.max_tokens)
	_request_timeout_input.text = str(profile.request_timeout_ms)
	_budget_segment.selected_index = _closest_index(BUDGET_VALUES, profile.think_budget_ms)
	_retry_segment.selected_index = _closest_index(RETRY_VALUES, profile.max_retries)
	_thinking_segment.selected_index = maxi(THINKING_VALUES.find(profile.thinking_effort), 0)
	_structured_segment.selected_index = maxi(STRUCTURED_VALUES.find(profile.structured_output), 0)
	_fallback_segment.selected_index = maxi(FALLBACK_VALUES.find(profile.fallback_difficulty), 0)
	_personality_segment.selected_index = maxi(PERSONALITY_VALUES.find(profile.personality), 0)


func _clear_fields() -> void:
	_name_input.text = ""
	_url_input.text = ""
	_key_input.text = ""
	_model_input.text = ""
	_temperature_input.text = ""
	_max_tokens_input.text = ""
	_request_timeout_input.text = ""
	_thinking_segment.selected_index = 0
	_structured_segment.selected_index = 0


func _set_enabled(enabled: bool) -> void:
	var controls: Array[Control] = [
		_name_input, _url_input, _key_input, _model_input, _temperature_input,
		_max_tokens_input, _request_timeout_input,
		_budget_segment, _retry_segment, _thinking_segment, _structured_segment,
		_fallback_segment, _personality_segment,
		_test_button, _save_button,
	]
	for control: Control in controls:
		if control is LineEdit:
			(control as LineEdit).editable = enabled
		elif control is UiSegmented:
			var segment: UiSegmented = control
			var disabled: Array[int] = []
			if not enabled:
				for index: int in segment.items.size():
					disabled.append(index)
			segment.disabled_indices = disabled
		elif control is BaseButton:
			(control as BaseButton).disabled = not enabled
	if _delete_button != null:
		_delete_button.disabled = not enabled or UiLlmBridge.profile_ids().size() <= 1


func _closest_index(values: Array[int], value: int) -> int:
	var best: int = 0
	var best_distance: int = 1 << 60
	for index: int in values.size():
		var distance: int = absi(values[index] - value)
		if distance < best_distance:
			best_distance = distance
			best = index
	return best


# ---------------------------------------------------------------- 编辑

## 当前表单 -> LlmProfile；保留界面没暴露的字段（max_tokens / 超时 / 结构化输出）。
func _profile_from_fields(errors: Array[String]) -> LlmProfile:
	if _current_id.is_empty():
		errors.append("没有选中的配置档")
		return null
	var base: LlmProfile = UiLlmBridge.profile(_current_id)
	var data: Dictionary = base.to_dict() if base != null else UiLlmBridge.example_profile_data()
	data["display_name"] = _name_input.text.strip_edges()
	data["base_url"] = _url_input.text.strip_edges()
	data["api_key"] = _key_input.text.strip_edges()
	data["model"] = _model_input.text.strip_edges()
	var temperature_text: String = _temperature_input.text.strip_edges()
	if not temperature_text.is_valid_float():
		errors.append("温度必须是数字（0 ~ 2）")
		return null
	var max_tokens_text: String = _max_tokens_input.text.strip_edges()
	if not max_tokens_text.is_valid_int():
		errors.append("最大回复 token 必须是整数")
		return null
	var timeout_text: String = _request_timeout_input.text.strip_edges()
	if not timeout_text.is_valid_int():
		errors.append("单次请求超时必须是整数（毫秒）")
		return null
	data["temperature"] = float(temperature_text)
	data["max_tokens"] = int(max_tokens_text)
	data["request_timeout_ms"] = int(timeout_text)
	data["think_budget_ms"] = BUDGET_VALUES[clampi(_budget_segment.selected_index, 0, 3)]
	data["max_retries"] = RETRY_VALUES[clampi(_retry_segment.selected_index, 0, 2)]
	data["thinking_effort"] = THINKING_VALUES[
			clampi(_thinking_segment.selected_index, 0, THINKING_VALUES.size() - 1)]
	data["structured_output"] = STRUCTURED_VALUES[
			clampi(_structured_segment.selected_index, 0, STRUCTURED_VALUES.size() - 1)]
	data["fallback_difficulty"] = FALLBACK_VALUES[
			clampi(_fallback_segment.selected_index, 0, 2)]
	data["personality"] = PERSONALITY_VALUES[
			clampi(_personality_segment.selected_index, 0, 3)]
	return _bridge.build_profile(_current_id, data, errors)


func _on_new_pressed() -> void:
	var data: Dictionary = UiLlmBridge.example_profile_data()
	if data.is_empty():
		_status_label.text = "✗ 读不到示例配置 data/llm/llm_config.example.json"
		return
	var new_id: String = UiLlmBridge.new_profile_id()
	data["display_name"] = "新配置档"
	data["api_key"] = ""
	var errors: Array[String] = []
	var profile: LlmProfile = _bridge.build_profile(new_id, data, errors)
	if profile == null:
		_status_label.text = "✗ " + "；".join(errors)
		return
	if not _bridge.save_profile(profile):
		_status_label.text = "✗ " + _bridge.last_error()
		return
	_current_id = new_id
	_reset_delete_arm()
	refresh()
	_status_label.add_theme_color_override("font_color", UiPalette.INK_2)
	_status_label.text = "已新建配置档，填好后点「保存」。"


func _on_save_pressed() -> void:
	var errors: Array[String] = []
	var profile: LlmProfile = _profile_from_fields(errors)
	if profile == null:
		_status_label.text = "✗ " + "；".join(errors)
		return
	if not _bridge.save_profile(profile):
		_status_label.text = "✗ " + _bridge.last_error()
		return
	_reset_delete_arm()
	_status_label.text = "✓ 已保存。"
	_load_profile(_current_id)
	_refresh_list()


func _on_delete_pressed() -> void:
	if _current_id.is_empty():
		return
	if not _delete_armed:
		_delete_armed = true
		_delete_button.text = "确认删除"
		_delete_button.variant = &"danger"
		_status_label.text = "再点一次删除「%s」。" % _name_input.text
		return
	if not _bridge.delete_profile(_current_id):
		_status_label.text = "✗ " + _bridge.last_error()
		_reset_delete_arm()
		return
	_current_id = ""
	_reset_delete_arm()
	refresh()
	_status_label.text = "已删除。"


func _reset_delete_arm() -> void:
	_delete_armed = false
	if _delete_button != null:
		_delete_button.text = "删除"
		_delete_button.variant = &"quiet"


# ---------------------------------------------------------------- 测试连接

func _on_test_pressed() -> void:
	if _bridge.is_testing():
		return
	var errors: Array[String] = []
	var profile: LlmProfile = _profile_from_fields(errors)
	if profile == null:
		_status_label.text = "✗ " + "；".join(errors)
		return
	if not _bridge.test_connection(profile):
		_status_label.text = "✗ 上一个测试还没结束"
		return
	_test_button.disabled = true
	_test_elapsed_ms = Time.get_ticks_msec()
	_tick_accum = 0.0
	_status_label.add_theme_color_override("font_color", UiPalette.INK_2)
	_status_label.text = "连接中…"


func _on_test_finished(ok: bool, message: String, elapsed_ms: int) -> void:
	_test_button.disabled = false
	if not _current_id.is_empty():
		_test_results[_current_id] = {
			"ok": ok, "message": message, "elapsed_ms": elapsed_ms,
		}
	if ok:
		_status_label.add_theme_color_override("font_color", UiPalette.OK)
		var suffix: String = "（已自动关闭不支持的参数）" \
				if message.contains("已自动关闭") else ""
		_status_label.text = "✓ 连接成功 · %.1f 秒%s" % [
			float(elapsed_ms) / 1000.0, suffix,
		]
	else:
		_status_label.add_theme_color_override("font_color", UiPalette.DANGER)
		_status_label.text = "✗ %s" % _failure_text(message)
	_refresh_list()


func _failure_text(message: String) -> String:
	var lower: String = message.to_lower()
	if lower.contains("401") or lower.contains("unauthorized") or lower.contains("api key"):
		return "Key 无效：%s" % message
	return "连接失败：%s" % message


func _process(delta: float) -> void:
	if _bridge == null or not _bridge.is_testing() or _status_label == null:
		return
	_tick_accum += delta
	if _tick_accum < 0.1:
		return
	_tick_accum = 0.0
	var elapsed: float = float(Time.get_ticks_msec() - _test_elapsed_ms) / 1000.0
	_status_label.text = "连接中… 已等 %.1f 秒" % elapsed


# ---------------------------------------------------------------- 测试用

func current_profile_id() -> String:
	return _current_id


func profile_row_count() -> int:
	return _list.get_child_count() if _list != null else 0


func status_text() -> String:
	return _status_label.text if _status_label != null else ""


func select_profile(profile_id: String) -> void:
	_select_profile(profile_id)


func new_button() -> UiButton:
	return _new_button


func save_button() -> UiButton:
	return _save_button


func test_button() -> UiButton:
	return _test_button


func delete_button() -> UiButton:
	return _delete_button


func name_input() -> UiInput:
	return _name_input


func url_input() -> UiInput:
	return _url_input


func key_input() -> UiInput:
	return _key_input


func model_input() -> UiInput:
	return _model_input


func temperature_input() -> UiInput:
	return _temperature_input


func max_tokens_input() -> UiInput:
	return _max_tokens_input


func request_timeout_input() -> UiInput:
	return _request_timeout_input


func budget_segment() -> UiSegmented:
	return _budget_segment


func thinking_segment() -> UiSegmented:
	return _thinking_segment


func structured_segment() -> UiSegmented:
	return _structured_segment


func retry_segment() -> UiSegmented:
	return _retry_segment


func fallback_segment() -> UiSegmented:
	return _fallback_segment


func personality_segment() -> UiSegmented:
	return _personality_segment


func test_result(profile_id: String) -> Dictionary:
	return (_test_results.get(profile_id) as Dictionary).duplicate(true) \
			if _test_results.has(profile_id) else {}
