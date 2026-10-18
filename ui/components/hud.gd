## 顶栏：左侧标题 / 人数轮数 / 终局标签，正中回合胶囊，右侧规则与菜单按钮。
## 高 44，HUD 深底 + 4px 下边框 + 2px 顶部高光（VISUAL_SPEC 6.10）。
class_name UiHud
extends Control

signal rules_requested
signal menu_requested

const HEIGHT := 44
const SIDE_MARGIN := 14

var _left: HBoxContainer
var _count_tag: UiTag
var _endgame_tag: UiTag
var _center: CenterContainer
var _pill: UiTurnPill
var _right: HBoxContainer


func _ready() -> void:
	custom_minimum_size.y = HEIGHT
	mouse_filter = Control.MOUSE_FILTER_PASS

	_left = HBoxContainer.new()
	_left.name = "Left"
	_left.add_theme_constant_override("separation", 10)
	_left.alignment = BoxContainer.ALIGNMENT_CENTER
	_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_left)

	var title := Label.new()
	title.name = "Title"
	title.text = "璀璨宝石"
	title.add_theme_color_override("font_color", UiPalette.CREAM)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left.add_child(title)

	_count_tag = UiTag.new()
	_count_tag.name = "CountTag"
	_count_tag.in_hud = true
	_count_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left.add_child(_count_tag)

	_endgame_tag = UiTag.new()
	_endgame_tag.name = "EndgameTag"
	_endgame_tag.variant = &"orange"
	_endgame_tag.in_hud = true
	_endgame_tag.visible = false
	_endgame_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left.add_child(_endgame_tag)

	_center = CenterContainer.new()
	_center.name = "Center"
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)

	_pill = UiTurnPill.new()
	_pill.name = "TurnPill"
	_center.add_child(_pill)

	_right = HBoxContainer.new()
	_right.name = "Right"
	_right.add_theme_constant_override("separation", 6)
	_right.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_right)

	var rules_button := UiButton.new()
	rules_button.name = "RulesButton"
	rules_button.variant = &"hud"
	rules_button.size_key = &"sm"
	rules_button.text = "规则"
	rules_button.focus_mode = Control.FOCUS_NONE
	rules_button.pressed.connect(func() -> void: rules_requested.emit())
	_right.add_child(rules_button)

	var menu_button := UiButton.new()
	menu_button.name = "MenuButton"
	menu_button.variant = &"hud"
	menu_button.size_key = &"sm"
	menu_button.text = "菜单 [Esc]"
	menu_button.focus_mode = Control.FOCUS_NONE
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	_right.add_child(menu_button)

	resized.connect(_layout)
	_layout()


## info = {player_count, round, endgame_remaining, pill: {kind, seat, name, type_label,
##         thinking, text}}。
func render(info: Dictionary) -> void:
	var player_count: int = int(info.get("player_count", 2))
	var round_number: int = int(info.get("round", 1))
	_count_tag.text = "%d 人局 · 第 %d 轮" % [player_count, round_number]
	var remaining: int = int(info.get("endgame_remaining", 0))
	_endgame_tag.visible = remaining > 0
	_endgame_tag.text = "终局轮 · 还剩 %d 人" % remaining

	var pill: Dictionary = info.get("pill", {})
	match String(pill.get("kind", "text")):
		"mine":
			_pill.configure_mine(int(pill.get("seat", 0)), String(pill.get("name", "")))
		"waiting":
			_pill.configure_waiting(
					int(pill.get("seat", 0)),
					String(pill.get("name", "")),
					String(pill.get("type_label", "")),
					bool(pill.get("thinking", false)))
		_:
			_pill.configure_text(String(pill.get("text", "")))
	_layout()


func _layout() -> void:
	if _left == null or _right == null:
		return
	_left.reset_size()
	_left.position = Vector2(SIDE_MARGIN, floorf((size.y - _left.size.y) * 0.5))
	_right.reset_size()
	_right.position = Vector2(
			floorf(size.x - SIDE_MARGIN - _right.size.x),
			floorf((size.y - _right.size.y) * 0.5))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiPalette.HUD)
	draw_rect(Rect2(0, 0, size.x, 2), UiPalette.HUD_HIGHLIGHT)
	draw_rect(Rect2(0, size.y - 4, size.x, 4), UiPalette.HUD_BORDER)
