## 对手面板：头像 / 名字 / 类型标签 / 分数 + 进度条 + 6 列“折扣 + 宝石”网格 + 预留标记。
## 当前行动者用大框 hot + 左侧橙条；电脑回合显示带转圈的“思考中”标签。
class_name UiOpponentPanel
extends UiFrame

const AVATAR_SIZE := 30
const THREAT_DISTANCE := 3
const MARKER_SIZE := Vector2(20, 24)

var _avatar: TextureRect
var _name: Label
var _type_tag: UiTag
var _thinking_badge: UiFrame
var _score: Label
var _win_label: Label
var _progress: UiProgressBar
var _grid: HBoxContainer
var _bonus_tiles: Dictionary[int, UiBonusTile] = {}
var _gold_cells: Dictionary[int, Control] = {}
var _chips: Dictionary[int, UiGemChip] = {}
var _tokens_label: Label
var _nobles_label: Label
var _markers: HBoxContainer

var _last_data: Dictionary = {}


func _ready() -> void:
	frame_texture = UiAssets.frame_l("ink")
	frame_border = 4
	background_color = UiPalette.CARD
	content_padding = Vector4i(10, 8, 10, 8)
	shadow_enabled = true
	shadow_offset = Vector2i(0, 4)
	top_highlight = true
	super._ready()

	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 4)
	content.add_child(column)

	_build_header(column)
	_progress = UiProgressBar.new()
	_progress.name = "Progress"
	_progress.custom_minimum_size.y = 6
	_progress.fill_color = UiPalette.PROGRESS_FILL
	column.add_child(_progress)
	_build_grid(column)
	_build_footer(column)


func _build_header(column: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 8)
	column.add_child(header)

	_avatar = UiAssets.mascot_icon(0, AVATAR_SIZE)
	_avatar.name = "Avatar"
	header.add_child(_avatar)

	var meta := VBoxContainer.new()
	meta.name = "Meta"
	meta.add_theme_constant_override("separation", 2)
	meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(meta)

	_name = Label.new()
	_name.name = "Name"
	meta.add_child(_name)

	var tags := HBoxContainer.new()
	tags.name = "Tags"
	tags.add_theme_constant_override("separation", 4)
	meta.add_child(tags)

	_type_tag = UiTag.new()
	_type_tag.name = "TypeTag"
	tags.add_child(_type_tag)
	_thinking_badge = _make_thinking_badge()
	tags.add_child(_thinking_badge)

	var score_row := HBoxContainer.new()
	score_row.add_theme_constant_override("separation", 4)
	score_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(score_row)
	_score = Label.new()
	_score.name = "Score"
	_score.theme_type_variation = &"UiNum"
	score_row.add_child(_score)
	_win_label = Label.new()
	_win_label.name = "WinLabel"
	_win_label.add_theme_color_override("font_color", UiPalette.INK_3)
	_win_label.size_flags_vertical = Control.SIZE_SHRINK_END
	score_row.add_child(_win_label)


func _make_thinking_badge() -> UiFrame:
	var badge := UiFrame.new()
	badge.name = "Thinking"
	badge.frame_texture = UiAssets.frame_s("ink")
	badge.frame_border = 2
	badge.background_color = UiPalette.TAG_ORANGE_BG
	badge.content_padding = Vector4i(6, 1, 6, 1)
	badge.visible = false
	# UiFrame 的 content 在 _ready 里才创建；这个零件在加入场景树之前就要填内容，
	# 所以先把 row 建好挂到 badge 上，等 _ready 时再挪进 content。
	var row := HBoxContainer.new()
	row.name = "ThinkingRow"
	row.add_theme_constant_override("separation", 4)
	badge.add_child(row)
	row.add_child(UiSpinner.new())
	var label := Label.new()
	label.text = "思考中"
	label.add_theme_color_override("font_color", UiPalette.TAG_ORANGE_TEXT)
	row.add_child(label)
	badge.ready.connect(func() -> void:
		badge.remove_child(row)
		badge.content.add_child(row)
	)
	return badge


func _build_grid(column: VBoxContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = UiPalette.CARD_SOFT
	style.border_color = UiPalette.LINE
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.content_margin_left = 4
	style.content_margin_top = 5
	style.content_margin_right = 4
	style.content_margin_bottom = 4
	style.anti_aliasing = false

	var panel := PanelContainer.new()
	panel.name = "Grid"
	panel.add_theme_stylebox_override("panel", style)
	column.add_child(panel)

	_grid = HBoxContainer.new()
	_grid.add_theme_constant_override("separation", 4)
	panel.add_child(_grid)

	for color: Enums.GemColor in Enums.ALL_COLORS:
		var cell := VBoxContainer.new()
		cell.name = "Column_%s" % Enums.color_to_letter(color)
		cell.add_theme_constant_override("separation", 3)
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.tooltip_text = "%s：折扣 %s · 宝石 0" % [
			Enums.color_to_zh(color), "—" if color == Enums.GemColor.GOLD else "0",
		]
		_grid.add_child(cell)

		if color == Enums.GemColor.GOLD:
			var placeholder := CenterContainer.new()
			placeholder.custom_minimum_size = Vector2(30, 27)
			placeholder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			var dash := Label.new()
			dash.text = "—"
			dash.add_theme_color_override("font_color", UiPalette.INK_3)
			placeholder.add_child(dash)
			cell.add_child(placeholder)
			_gold_cells[color] = placeholder
		else:
			var tile := UiBonusTile.new()
			tile.gem_color = color
			tile.size_key = &"opp"
			tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			cell.add_child(tile)
			_bonus_tiles[color] = tile

		var chip := UiGemChip.new()
		chip.gem_color = color
		chip.size_key = &"sm"
		chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.add_child(chip)
		_chips[color] = chip


func _build_footer(column: VBoxContainer) -> void:
	var footer := HBoxContainer.new()
	footer.name = "Footer"
	footer.add_theme_constant_override("separation", 6)
	column.add_child(footer)

	_tokens_label = Label.new()
	_tokens_label.name = "TokensLabel"
	_tokens_label.add_theme_color_override("font_color", UiPalette.INK_2)
	footer.add_child(_tokens_label)

	_nobles_label = Label.new()
	_nobles_label.name = "NoblesLabel"
	_nobles_label.add_theme_color_override("font_color", UiPalette.INK_2)
	footer.add_child(_nobles_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)

	var reserved_word := Label.new()
	reserved_word.text = "预留"
	reserved_word.add_theme_color_override("font_color", UiPalette.INK_3)
	footer.add_child(reserved_word)

	_markers = HBoxContainer.new()
	_markers.name = "ReservedMarkers"
	_markers.add_theme_constant_override("separation", 4)
	footer.add_child(_markers)


## 显示数据：seat / name / seat_type / score / win_points / tokens / bonuses /
## noble_count / reserved / max_tokens / catalog / active / thinking。
func render(data: Dictionary) -> void:
	_last_data = data.duplicate(true)
	var catalog: CardCatalog = data.get("catalog")
	var seat: int = int(data.get("seat", 0))
	var active: bool = bool(data.get("active", false))
	var thinking: bool = bool(data.get("thinking", false))

	frame_texture = UiAssets.frame_l("hot" if active else "ink")
	side_bar = active
	_avatar.texture = UiAssets.mascot(seat)
	_name.text = String(data.get("name", "座位 %d" % (seat + 1)))

	var seat_type: String = String(data.get("seat_type", "human"))
	_type_tag.text = UiViewMath.seat_type_label(seat_type)
	_type_tag.variant = UiViewMath.seat_type_tag_variant(seat_type)
	_thinking_badge.visible = thinking

	var score: int = int(data.get("score", 0))
	var win_points: int = int(data["win_points"])
	_score.text = str(score)
	_win_label.text = "/ %d" % win_points
	_progress.ratio = float(score) / maxf(float(win_points), 1.0)
	_progress.fill_color = (
			UiPalette.ORANGE if score >= win_points - THREAT_DISTANCE
			else UiPalette.PROGRESS_FILL)

	var tokens: Dictionary = data.get("tokens", {})
	var bonuses: Dictionary = data.get("bonuses", {})
	var total_tokens: int = 0
	for color: Enums.GemColor in Enums.ALL_COLORS:
		var amount: int = int(tokens.get(color, 0))
		var bonus: int = int(bonuses.get(color, 0))
		total_tokens += amount
		_chips[color].count = amount
		if _bonus_tiles.has(color):
			_bonus_tiles[color].count = bonus
		var cell: Control = _grid.get_node("Column_%s" % Enums.color_to_letter(color))
		cell.tooltip_text = "%s：折扣 %s · 宝石 %d" % [
			Enums.color_to_zh(color),
			"—" if color == Enums.GemColor.GOLD else str(bonus),
			amount,
		]

	var max_tokens: int = int(data["max_tokens"])
	_tokens_label.text = "宝石 %d / %d" % [total_tokens, max_tokens]
	_tokens_label.add_theme_color_override(
			"font_color",
			UiPalette.DANGER if total_tokens >= max_tokens - 1 else UiPalette.INK_2)
	_nobles_label.text = "· 贵族 %d" % int(data.get("noble_count", 0))

	var reserved: Array = data.get("reserved", [])
	_render_markers(reserved, catalog)


func _render_markers(reserved: Array, catalog: CardCatalog) -> void:
	for child in _markers.get_children():
		_markers.remove_child(child)
		child.queue_free()
	if reserved.is_empty():
		var none := Label.new()
		none.text = "无"
		none.add_theme_color_override("font_color", UiPalette.INK_3)
		_markers.add_child(none)
		return
	for entry: Dictionary in reserved:
		_markers.add_child(_make_marker(entry, catalog))


func _make_marker(entry: Dictionary, catalog: CardCatalog) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.border_color = UiPalette.INK
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.content_margin_left = 1
	style.content_margin_top = 1
	style.content_margin_right = 1
	style.content_margin_bottom = 1
	style.anti_aliasing = false
	panel.custom_minimum_size = MARKER_SIZE
	panel.add_theme_stylebox_override("panel", style)

	var card_id: String = UiViewMath.reserved_card_id(entry)
	var card: CardData = catalog.card(card_id) if catalog != null and not card_id.is_empty() else null
	if card == null:
		style.bg_color = UiPalette.HUD
		var roman := Label.new()
		roman.theme_type_variation = &"UiNumSmall"
		roman.text = ["", "I", "II", "III"][clampi(int(entry.get("level", 1)), 0, 3)]
		roman.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		roman.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		roman.add_theme_color_override("font_color", UiPalette.GOLD)
		panel.add_child(roman)
		return panel

	style.bg_color = UiPalette.GEM_BASE[card.bonus]
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 0)
	panel.add_child(row)
	row.add_child(UiAssets.icon(card.bonus, 8, 0.9))
	if card.points > 0:
		var points := Label.new()
		points.theme_type_variation = &"UiNumSmall"
		points.text = str(card.points)
		points.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		points.add_theme_color_override("font_color", UiPalette.GEM_TEXT[card.bonus])
		row.add_child(points)
	return panel


func get_render_data() -> Dictionary:
	return _last_data.duplicate(true)


## 动效定位：分数 / 宝石 / 折扣块的屏幕矩形。
func score_control() -> Control:
	return _score


func token_chip(color: Enums.GemColor) -> UiGemChip:
	return _chips.get(color)


func bonus_tile(color: Enums.GemColor) -> UiBonusTile:
	return _bonus_tiles.get(color)


func panel_rect() -> Rect2:
	return get_global_rect()
