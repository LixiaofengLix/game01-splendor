## 开局设置：人数、种子、每个座位的类型。阶段 4 开放人类与三档电脑，
## 大模型 / 远程继续置灰；默认座位 0 是人类，其余座位是普通电脑。
## 开始按钮只发出 start_requested，由主界面负责创建对局。
class_name SetupScreen
extends Control

signal start_requested(player_count: int, seed: int, seat_types: Array[String])

const MAX_SEATS: int = 4
const DEFAULT_HUMAN_SEAT_TYPE: String = "human"
const DEFAULT_BOT_SEAT_TYPE: String = "bot_normal"
## [显示名, 座位类型, 是否禁用]。阶段 5 / 6 再把对应的禁用去掉。
const SEAT_TYPE_ITEMS: Array = [
	["人类", "human", false],
	["电脑（简单）", "bot_easy", false],
	["电脑（普通）", "bot_normal", false],
	["电脑（困难）", "bot_hard", false],
	["大模型", "llm", true],
	["远程", "remote", true],
]

var _count_option: OptionButton
var _seed_edit: LineEdit
var _seat_rows: Array[HBoxContainer] = []
var _seat_options: Array[OptionButton] = []
var _start_button: Button
var _status_label: Label

func _ready() -> void:
	_build_ui()
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
	panel.custom_minimum_size = Vector2(520, 0)
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
	hint.text = "阶段 4：人类与电脑可以混合；大模型 / 远程将在后续阶段开放。"
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
	seats_grid.columns = 2
	seats_grid.add_theme_constant_override("h_separation", 12)
	seats_grid.add_theme_constant_override("v_separation", 6)
	column.add_child(seats_grid)
	for seat: int in MAX_SEATS:
		var row := HBoxContainer.new()
		row.add_child(_label("座位 %d" % seat))
		var option := OptionButton.new()
		for item: Array in SEAT_TYPE_ITEMS:
			option.add_item(String(item[0]))
			var index: int = option.item_count - 1
			option.set_item_metadata(index, String(item[1]))
			option.set_item_disabled(index, bool(item[2]))
		option.select(0)
		row.add_child(option)
		seats_grid.add_child(row)
		_seat_rows.append(row)
		_seat_options.append(option)
	# 默认人机对战：座位 0 是人类，其余座位是普通电脑。
	for seat: int in MAX_SEATS:
		var default_type: String = DEFAULT_HUMAN_SEAT_TYPE if seat == 0 else DEFAULT_BOT_SEAT_TYPE
		_select_seat_type(_seat_options[seat], default_type)

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

func _refresh_seat_rows() -> void:
	var player_count: int = _selected_player_count()
	for seat: int in _seat_rows.size():
		_seat_rows[seat].visible = seat < player_count

func _on_start_pressed() -> void:
	var seed_text: String = _seed_edit.text.strip_edges()
	if not seed_text.is_valid_int():
		_status_label.text = "✗ 种子必须是整数（可以点「随机」）"
		return
	var player_count: int = _selected_player_count()
	var seat_types: Array[String] = []
	for seat: int in player_count:
		var option: OptionButton = _seat_options[seat]
		seat_types.append(String(option.get_item_metadata(option.selected)))
	_status_label.text = ""
	start_requested.emit(player_count, int(seed_text), seat_types)

func _selected_player_count() -> int:
	return _count_option.get_item_id(_count_option.selected)

func _select_seat_type(option: OptionButton, seat_type: String) -> void:
	for index: int in option.item_count:
		if String(option.get_item_metadata(index)) == seat_type:
			option.select(index)
			return

func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label
