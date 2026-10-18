## 回放播放条：当前步说明、视角分段、按座位着色时间轴、播放控制与速度。
## 只发信号，不自己推进步数；步进 / 播放计时由 UiReplayScreen 负责。
class_name UiReplayBar
extends UiFrame

signal seek_requested(step: int)
## 【下一步】走“播动效再落地”的路径；时间轴 / 上一步 / 开头 / 结尾是直接跳转。
signal next_step_requested
signal play_toggle_requested
signal view_changed(seat: int)
signal speed_changed(multiplier: float)

const SPEEDS: Array[float] = [0.5, 1.0, 2.0]
const VIEW_ALL_LABEL: String = "全部公开"

var _avatar: TextureRect
var _step_label: Label
var _action_text: RichTextLabel
var _viewer_segment: UiSegmented
var _timeline: UiReplayTimeline
var _legend: HBoxContainer
var _play_button: UiButton
var _speed_segment: UiSegmented
var _step: int = 0
var _step_count: int = 0
var _names: Array[String] = []
var _catalog: CardCatalog = null
var _speed_index: int = 1
var _suppress_view_signal: bool = false
var _action_source_text: String = ""


func _ready() -> void:
	frame_texture = UiAssets.frame_l("ink")
	frame_border = 4
	background_color = UiPalette.CARD
	content_padding = Vector4i(14, 10, 14, 12)
	shadow_enabled = true
	shadow_offset = Vector2i(0, 4)
	top_highlight = true
	super._ready()
	custom_minimum_size.y = 246

	var column := VBoxContainer.new()
	column.name = "Column"
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 8)
	content.add_child(column)

	_build_now_row(column)
	_build_view_row(column)
	_build_legend_row(column)

	_timeline = UiReplayTimeline.new()
	_timeline.name = "Timeline"
	_timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timeline.seek_requested.connect(func(step: int) -> void: seek_requested.emit(step))
	column.add_child(_timeline)

	_build_controls(column)
	_render_action()


func _build_now_row(column: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.name = "NowRow"
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)

	_avatar = TextureRect.new()
	_avatar.name = "Avatar"
	_avatar.custom_minimum_size = Vector2(40, 40)
	_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_avatar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_avatar.visible = false
	row.add_child(_avatar)

	var text_column := VBoxContainer.new()
	text_column.name = "Text"
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.add_theme_constant_override("separation", 2)
	row.add_child(text_column)

	_step_label = Label.new()
	_step_label.name = "StepLabel"
	_step_label.theme_type_variation = &"UiNumMid"
	_step_label.add_theme_color_override("font_color", UiPalette.INK_3)
	text_column.add_child(_step_label)

	_action_text = RichTextLabel.new()
	_action_text.name = "ActionText"
	_action_text.bbcode_enabled = true
	_action_text.fit_content = true
	_action_text.scroll_active = false
	_action_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_action_text.custom_minimum_size.y = 22
	_action_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_text.add_theme_font_override("normal_font", get_theme_default_font())
	_action_text.add_theme_font_size_override("normal_font_size", get_theme_default_font_size())
	_action_text.add_theme_color_override("default_color", UiPalette.INK)
	text_column.add_child(_action_text)


func _build_view_row(column: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.name = "ViewRow"
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)

	var label := Label.new()
	label.text = "视角"
	label.add_theme_color_override("font_color", UiPalette.INK_3)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	_viewer_segment = UiSegmented.new()
	_viewer_segment.name = "ViewerSegment"
	_viewer_segment.selected_changed.connect(_on_viewer_selected)
	row.add_child(_viewer_segment)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)


## 时间轴图例：每格 = 一步，颜色 = 行动者（和吉祥物同色）。
func _build_legend_row(column: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.name = "LegendRow"
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)

	var hint := Label.new()
	hint.text = "每格 = 一步 · 颜色 = 行动者"
	hint.add_theme_color_override("font_color", UiPalette.INK_3)
	row.add_child(hint)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	_legend = HBoxContainer.new()
	_legend.name = "Legend"
	_legend.add_theme_constant_override("separation", 10)
	row.add_child(_legend)


func _build_controls(column: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.name = "Controls"
	row.add_theme_constant_override("separation", 6)
	column.add_child(row)

	var first := _make_button("FirstButton", "开头", &"ghost", &"sm")
	first.pressed.connect(func() -> void: seek_requested.emit(0))
	row.add_child(first)

	var previous := _make_button("PrevButton", "上一步", &"ghost", &"sm")
	previous.pressed.connect(func() -> void: seek_requested.emit(maxi(_step - 1, 0)))
	row.add_child(previous)

	_play_button = _make_button("PlayButton", "播放", &"accent", &"default")
	_play_button.name = "PlayButton"
	_play_button.pressed.connect(func() -> void: play_toggle_requested.emit())
	row.add_child(_play_button)

	var next := _make_button("NextButton", "下一步", &"ghost", &"sm")
	next.pressed.connect(func() -> void: next_step_requested.emit())
	row.add_child(next)

	var last := _make_button("LastButton", "结尾", &"ghost", &"sm")
	last.pressed.connect(func() -> void: seek_requested.emit(_step_count))
	row.add_child(last)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var speed_label := Label.new()
	speed_label.text = "速度"
	speed_label.add_theme_color_override("font_color", UiPalette.INK_3)
	speed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(speed_label)

	_speed_segment = UiSegmented.new()
	_speed_segment.name = "SpeedSegment"
	_speed_segment.items = ["0.5x", "1x", "2x"]
	_speed_segment.selected_index = _speed_index
	_speed_segment.selected_changed.connect(_on_speed_selected)
	row.add_child(_speed_segment)


func _make_button(node_name: String, text: String, variant: StringName,
		size_key: StringName) -> UiButton:
	var button := UiButton.new()
	button.name = node_name
	button.text = text
	button.variant = variant
	button.size_key = size_key
	button.focus_mode = Control.FOCUS_NONE
	return button


## 安装一次：总步数与玩家名（视角分段用）。
func configure(step_count: int, names: Array[String]) -> void:
	_step_count = maxi(step_count, 0)
	_names = names.duplicate()
	var items: Array[String] = [VIEW_ALL_LABEL]
	for player_name: String in _names:
		items.append(player_name)
	_viewer_segment.items = items
	_viewer_segment.selected_index = 0
	_rebuild_legend()


func _rebuild_legend() -> void:
	if _legend == null:
		return
	for child in _legend.get_children():
		_legend.remove_child(child)
		child.queue_free()
	for seat: int in _names.size():
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 4)
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(10, 10)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.color = UiReplayTimeline.SEAT_COLORS[seat % UiReplayTimeline.SEAT_COLORS.size()]
		item.add_child(swatch)
		var label := Label.new()
		label.text = _names[seat]
		label.add_theme_color_override("font_color", UiPalette.INK_2)
		item.add_child(label)
		_legend.add_child(item)


## info = {step, step_count, seat, round, text, playing, catalog}。
func render(info: Dictionary) -> void:
	_step = clampi(int(info.get("step", 0)), 0, _step_count)
	_step_count = int(info.get("step_count", _step_count))
	_catalog = info.get("catalog") as CardCatalog
	var seat: int = int(info.get("seat", -1))
	var round_number: int = int(info.get("round", 1))
	_step_label.text = "第 %d / %d 步 · 第 %d 轮" % [_step, _step_count, round_number]
	_avatar.visible = seat >= 0
	if seat >= 0:
		_avatar.texture = UiAssets.mascot(seat)
	_action_source_text = String(info.get("text", ""))
	_render_action()
	var playing: bool = bool(info.get("playing", false))
	_play_button.text = "暂停" if playing else "播放"
	var raw_seats: Variant = info.get("seat_at", [])
	var seat_list: Array = raw_seats if raw_seats is Array else []
	var seats: Array[int] = []
	for index: int in _step_count + 1:
		seats.append(int(seat_list[index]) if index < seat_list.size() else -1)
	_timeline.set_state(_step, _step_count, seats)


func _render_action() -> void:
	if _step <= 0:
		_action_text.text = UiMarkup.to_bbcode(
				"开局：还没人行动。点「播放」或按空格开始。", _catalog)
		return
	_action_text.text = UiMarkup.to_bbcode(_action_source_text, _catalog)


func set_viewer_index(index: int) -> void:
	_suppress_view_signal = true
	_viewer_segment.selected_index = clampi(index, 0, _names.size())
	_suppress_view_signal = false


func viewer_index() -> int:
	return _viewer_segment.selected_index


func _on_viewer_selected(index: int) -> void:
	if _suppress_view_signal:
		return
	view_changed.emit(index - 1)


func _on_speed_selected(index: int) -> void:
	_speed_index = clampi(index, 0, SPEEDS.size() - 1)
	speed_changed.emit(SPEEDS[_speed_index])


func speed_multiplier() -> float:
	return SPEEDS[_speed_index]


## 后台补齐时间轴颜色时只更新时间轴，不重画整条。
func set_seat_at(seats: Array[int]) -> void:
	_timeline.set_state(_step, _step_count, seats)


func timeline() -> UiReplayTimeline:
	return _timeline


func step_label_text() -> String:
	return _step_label.text


func action_source_text() -> String:
	return _action_source_text


func legend_text() -> String:
	var parts: Array[String] = []
	for child: Node in _legend.get_children():
		if child.get_child_count() < 2:
			continue
		var label := child.get_child(1) as Label
		if label != null:
			parts.append(label.text)
	return " ".join(parts)


func play_button() -> UiButton:
	return _play_button


func viewer_segment() -> UiSegmented:
	return _viewer_segment


func speed_segment() -> UiSegmented:
	return _speed_segment
