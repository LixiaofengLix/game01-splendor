## U3 的临时开局入口：选人数和电脑难度，直接进入正式牌桌。U4 的正式设置界面出来后删除。
## 运行：godot --path . ui/dev/quick_start.tscn
extends Control

const TABLE_SCENE := "res://ui/screens/table/table_screen.tscn"
const NAMES: Array[String] = ["小明", "薄荷", "紫晶", "橘子"]
const DIFFICULTIES: Array[String] = ["easy", "normal", "hard"]
const DIFFICULTY_LABELS: Array[String] = ["简单", "普通", "困难"]

var _setup_root: Control = null
var _table: UiTableScreen = null
var _session: UiTableSession = null
var _flow: UiTableFlow = null
var _count_segment: UiSegmented = null
var _difficulty_segment: UiSegmented = null
var _seed_input: UiInput = null
var _error_label: Label = null


func _ready() -> void:
	theme = load("res://ui/theme/pixel_theme.tres")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	UiShortcuts.register()
	_show_setup()


func _show_setup() -> void:
	if _setup_root != null:
		_setup_root.queue_free()
	_setup_root = Control.new()
	_setup_root.name = "Setup"
	_setup_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_setup_root)

	var background := UiAssets.tiled(UiAssets.texture("tile_wood.png"))
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_setup_root.add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_setup_root.add_child(center)

	var panel := UiFrame.new()
	panel.name = "SetupPanel"
	panel.frame_texture = UiAssets.frame_l("ink")
	panel.frame_border = 4
	panel.background_color = UiPalette.CARD
	panel.content_padding = Vector4i(28, 22, 28, 22)
	panel.shadow_enabled = true
	panel.shadow_offset = Vector2i(0, 6)
	panel.top_highlight = true
	panel.custom_minimum_size.x = 520
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.content.add_child(column)

	var tag := UiTag.new()
	tag.text = "U3 临时入口"
	tag.variant = &"dark"
	tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(tag)

	var title := Label.new()
	title.theme_type_variation = &"UiTitle"
	title.text = "璀璨宝石 · 人机对局"
	column.add_child(title)

	var hint := Label.new()
	hint.text = "座位 1 是你，其余座位由电脑控制。按 1–5 选宝石，Enter 确认，R 预留，Esc 取消。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", UiPalette.INK_2)
	column.add_child(hint)

	var count_row := _labeled_row(column, "人数")
	_count_segment = UiSegmented.new()
	_count_segment.name = "CountSegment"
	count_row.add_child(_count_segment)
	_count_segment.items = ["2 人", "3 人", "4 人"]
	_count_segment.selected_index = 1

	var difficulty_row := _labeled_row(column, "电脑难度")
	_difficulty_segment = UiSegmented.new()
	_difficulty_segment.name = "DifficultySegment"
	difficulty_row.add_child(_difficulty_segment)
	_difficulty_segment.items = DIFFICULTY_LABELS
	_difficulty_segment.selected_index = 1

	var seed_row := _labeled_row(column, "种子")
	_seed_input = UiInput.new()
	_seed_input.name = "SeedInput"
	_seed_input.placeholder_text = "留空 = 随机"
	_seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_row.add_child(_seed_input)
	var random_button := UiButton.new()
	random_button.variant = &"quiet"
	random_button.size_key = &"sm"
	random_button.text = "随机"
	random_button.focus_mode = Control.FOCUS_NONE
	random_button.pressed.connect(func() -> void: _seed_input.text = "")
	seed_row.add_child(random_button)

	_error_label = Label.new()
	_error_label.name = "ErrorLabel"
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error_label.add_theme_color_override("font_color", UiPalette.DANGER)
	_error_label.visible = false
	column.add_child(_error_label)

	var start := UiButton.new()
	start.name = "StartButton"
	start.variant = &"accent"
	start.size_key = &"lg"
	start.text = "开始对局"
	start.focus_mode = Control.FOCUS_NONE
	start.pressed.connect(_on_start_pressed)
	column.add_child(start)

	var note := Label.new()
	note.text = "这是 U3 的开发入口；正式的主菜单与开局设置在 U4。"
	note.add_theme_color_override("font_color", UiPalette.INK_3)
	column.add_child(note)


func _labeled_row(parent: VBoxContainer, label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 84
	label.add_theme_color_override("font_color", UiPalette.INK_3)
	row.add_child(label)
	return row


func _on_start_pressed() -> void:
	var count: int = _count_segment.selected_index + 2
	var difficulty: String = DIFFICULTIES[clampi(_difficulty_segment.selected_index, 0,
			DIFFICULTIES.size() - 1)]
	var seed_value: int = -1
	var seed_text: String = _seed_input.text.strip_edges()
	if not seed_text.is_empty():
		if not seed_text.is_valid_int():
			_error_label.text = "种子必须是整数（留空则随机）"
			_error_label.visible = true
			return
		seed_value = int(seed_text)
	if not start_game(count, difficulty, seed_value):
		_error_label.text = "开局失败：见控制台输出（数据层或 AI 配置不可用）"
		_error_label.visible = true


## 供测试直接调用：difficulty 取 easy / normal / hard。
func start_game(count: int, difficulty: String, seed_value: int = -1) -> bool:
	if _setup_root != null:
		_setup_root.queue_free()
		_setup_root = null
	_table = load(TABLE_SCENE).instantiate()
	_table.name = "Table"
	_table.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_table)

	_session = UiTableSession.new()
	_session.name = "TableSession"
	add_child(_session)
	_flow = UiTableFlow.new()
	_flow.name = "TableFlow"
	add_child(_flow)
	_flow.setup(_table, _session)
	_flow.leave_requested.connect(_on_leave)

	var seats: Array[Dictionary] = []
	for seat: int in count:
		var seat_type: String = "human" if seat == 0 else "bot_" + difficulty
		seats.append({
			"name": NAMES[seat] if seat < NAMES.size() else "座位 %d" % (seat + 1),
			"type": seat_type,
		})
	var ok: bool = _session.start_local({"count": count, "seed": seed_value, "seats": seats})
	if not ok:
		_on_leave()
	return ok


func _on_leave() -> void:
	if _session != null:
		_session.close()
		_session.queue_free()
		_session = null
	if _flow != null:
		_flow.queue_free()
		_flow = null
	if _table != null:
		_table.queue_free()
		_table = null
	_show_setup()


func session() -> UiTableSession:
	return _session


func flow() -> UiTableFlow:
	return _flow


func table() -> UiTableScreen:
	return _table


func setup_root() -> Control:
	return _setup_root
