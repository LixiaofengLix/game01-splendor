## 主菜单（01）：继续上一局、本地游戏、联网（禁用）、读取存档 / 设置 / 退出，
## 右半区用零件拼一桌桌面静物。数据只有存档摘要和 RulesConfig。
class_name UiMainMenu
extends Control

signal continue_pressed
signal local_pressed
signal saves_pressed
signal settings_pressed
signal quit_pressed

const VERSION_TEXT: String = "v0.4 · 基础版"
const FAN_CARDS: Array[String] = ["L1-W-01", "L2-U-01", "L3-G-01"]

var _continue_button: UiMenuButton
var _local_button: UiMenuButton
var _online_button: UiMenuButton
var _saves_button: UiButton
var _settings_button: UiButton
var _quit_button: UiButton
var _right: Control
var _fan: Array[UiDevCard] = []
var _deck: UiDeckPile
var _noble: UiNobleTile
var _chips: Array[UiGemChip] = []
var _mascot: TextureRect


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()
	_layout_still_life()


func configure(summary: Dictionary) -> void:
	if _continue_button == null:
		return
	var has_continue: bool = not summary.is_empty()
	_continue_button.visible = has_continue
	if has_continue:
		_continue_button.subtitle = String(summary.get("text", ""))


func _build() -> void:
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 56)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)

	var columns := HBoxContainer.new()
	columns.name = "Columns"
	columns.add_theme_constant_override("separation", 24)
	margin.add_child(columns)

	var left := VBoxContainer.new()
	left.name = "Left"
	left.custom_minimum_size.x = 520
	left.add_theme_constant_override("separation", 10)
	columns.add_child(left)

	var rules: RulesConfig = DataRegistry.rules()
	var counts: Array[int] = rules.supported_player_counts()
	var count_text: String = "2–4 人"
	if not counts.is_empty():
		count_text = "%d–%d 人" % [counts[0], counts[counts.size() - 1]]
	var eyebrow := UiTag.new()
	eyebrow.name = "Eyebrow"
	eyebrow.text = "基础版 · %s" % count_text
	eyebrow.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(eyebrow)

	var title := Label.new()
	title.name = "HeroTitle"
	title.theme_type_variation = &"UiHero"
	title.text = "璀璨宝石"
	left.add_child(title)

	var description := Label.new()
	description.name = "Description"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.x = 500
	description.add_theme_color_override("font_color", UiPalette.INK_2)
	description.text = "收集宝石、购买发展卡、吸引贵族来访。率先达到 %d 分，并在终局轮保持领先。"
	description.text = description.text % int(rules.win_points)
	left.add_child(description)

	var top_spacer := Control.new()
	top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_spacer.custom_minimum_size.y = 30
	left.add_child(top_spacer)

	var buttons := VBoxContainer.new()
	buttons.name = "MenuButtons"
	buttons.custom_minimum_size.x = 360
	buttons.add_theme_constant_override("separation", 9)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(buttons)

	_continue_button = _make_menu_button("继续上一局", "", &"accent")
	_continue_button.name = "ContinueButton"
	_continue_button.visible = false
	_continue_button.pressed.connect(func() -> void: continue_pressed.emit())
	buttons.add_child(_continue_button)

	_local_button = _make_menu_button("本地游戏", "你和电脑，或同屏多人", &"dark")
	_local_button.name = "LocalGameButton"
	_local_button.pressed.connect(func() -> void: local_pressed.emit())
	buttons.add_child(_local_button)

	_online_button = _make_menu_button("联网游戏", "开发中", &"ghost")
	_online_button.name = "OnlineGameButton"
	_online_button.disabled = true
	_online_button.tooltip_text = "联网玩法将在后续版本开放"
	buttons.add_child(_online_button)

	var row := HBoxContainer.new()
	row.name = "SmallButtons"
	row.add_theme_constant_override("separation", 8)
	buttons.add_child(row)

	_saves_button = _make_small_button("读取存档")
	_saves_button.name = "SavesButton"
	_saves_button.pressed.connect(func() -> void: saves_pressed.emit())
	row.add_child(_saves_button)

	_settings_button = _make_small_button("设置")
	_settings_button.name = "SettingsButton"
	_settings_button.disabled = true
	_settings_button.tooltip_text = "设置页将在后续版本开放"
	row.add_child(_settings_button)

	_quit_button = _make_small_button("退出")
	_quit_button.name = "QuitButton"
	_quit_button.pressed.connect(func() -> void: quit_pressed.emit())
	row.add_child(_quit_button)

	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(bottom_spacer)

	var version := Label.new()
	version.name = "Version"
	version.text = VERSION_TEXT
	version.add_theme_color_override("font_color", UiPalette.INK_3)
	left.add_child(version)

	_right = Control.new()
	_right.name = "StillLife"
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_right.custom_minimum_size = Vector2(520, 0)
	_right.resized.connect(_layout_still_life)
	columns.add_child(_right)
	_build_still_life()


func _make_menu_button(title: String, subtitle: String, variant: StringName) -> UiMenuButton:
	var button := UiMenuButton.new()
	button.title = title
	button.subtitle = subtitle
	button.variant = variant
	button.focus_mode = Control.FOCUS_ALL
	return button


func _make_small_button(text: String) -> UiButton:
	var button := UiButton.new()
	button.text = text
	button.variant = &"quiet"
	button.size_key = &"sm"
	button.focus_mode = Control.FOCUS_ALL
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button


func _build_still_life() -> void:
	var catalog: CardCatalog = DataRegistry.card_catalog()
	for index: int in FAN_CARDS.size():
		var card := UiDevCard.new()
		card.name = "FanCard%d" % index
		card.catalog = catalog
		card.card_id = FAN_CARDS[index]
		card.rotation_degrees = [-8.0, 0.0, 8.0][index]
		_right.add_child(card)
		_fan.append(card)

	_deck = UiDeckPile.new()
	_deck.name = "StillDeck"
	_deck.level = 3
	_deck.remaining = 12
	_right.add_child(_deck)

	_noble = UiNobleTile.new()
	_noble.name = "StillNoble"
	_noble.catalog = catalog
	var nobles: Array[NobleData] = DataRegistry.all_nobles()
	_noble.noble_id = nobles[0].id if not nobles.is_empty() else ""
	_noble.big = true
	_right.add_child(_noble)

	for index: int in 6:
		var chip := UiGemChip.new()
		chip.name = "StillChip%d" % index
		chip.gem_color = [Enums.GemColor.WHITE, Enums.GemColor.BLUE, Enums.GemColor.GREEN,
				Enums.GemColor.RED, Enums.GemColor.BLACK, Enums.GemColor.GOLD][index]
		chip.size_key = &"lg"
		chip.count = [5, 4, 3, 2, 3, 2][index]
		_right.add_child(chip)
		_chips.append(chip)

	_mascot = UiAssets.mascot_icon(0, 76)
	_mascot.name = "StillMascot"
	_right.add_child(_mascot)

	_ignore_mouse(_right)


## 静物按右半区尺寸摆放；窗口变化时重排（U9 整数缩放后固定为 1280×800 逻辑尺寸）。
func _layout_still_life() -> void:
	if _right == null or _fan.is_empty():
		return
	var w: float = _right.size.x
	var h: float = _right.size.y
	var card_size: Vector2 = UiDevCard.MARKET_SIZE
	var center := Vector2(w * 0.54, h * 0.30)
	var offsets: Array[Vector2] = [Vector2(-150, -46), Vector2(-64, -78), Vector2(22, -46)]
	for index: int in _fan.size():
		var card: UiDevCard = _fan[index]
		card.size = card_size
		card.pivot_offset = card_size * 0.5
		card.position = (center + offsets[index] - card_size * 0.5).round()

	_deck.position = Vector2(w - 180, h * 0.34).round()
	_noble.position = Vector2(10, h - 196).round()

	var chip_start := Vector2(w - 390, h - 96)
	for index: int in _chips.size():
		var chip: UiGemChip = _chips[index]
		chip.position = (chip_start + Vector2(index * 54, (index % 2) * 6)).round()

	_mascot.position = Vector2(w - 100, h - 220).round()


func _ignore_mouse(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse(child)


# ---------------------------------------------------------------- 测试用

func continue_button() -> UiMenuButton:
	return _continue_button


func local_button() -> UiMenuButton:
	return _local_button


func online_button() -> UiMenuButton:
	return _online_button


func saves_button() -> UiButton:
	return _saves_button


func still_life_card_ids() -> Array[String]:
	var result: Array[String] = []
	for card: UiDevCard in _fan:
		result.append(card.card_id)
	return result
