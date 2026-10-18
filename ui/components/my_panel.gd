## 我的面板（左栏底部，高 246）：左侧橙条，顶部状态条 + 身份 / 资源 / 预留三列。
## 只吃显示数据；视图到显示数据的换算在牌桌里完成（UiViewMath）。
class_name UiMyPanel
extends UiFrame

signal confirm_pressed
signal cancel_pressed
signal reserved_card_clicked(card_id: String)

const HEIGHT := 246
const STRIP_HEIGHT := 36
const EVENT_STRIP_HEIGHT := 40

var _strip: UiFrame
var _strip_row: HBoxContainer
var _strip_avatar: TextureRect
var _bullet_holder: Control
var _strip_text: RichTextLabel
var _tray: HBoxContainer
var _tray_chips: HBoxContainer
var _tray_label: Label
var _cancel: UiButton
var _confirm: UiButton
var _strip_time: Label
var _strip_line: ColorRect

var _avatar: TextureRect
var _name: Label
var _me_tag: UiTag
var _score: Label
var _win_label: Label
var _cards_label: Label
var _tokens_label: Label
var _chips: Array[UiGemChip] = []
var _bonus_label: Label
var _tiles: Array[UiBonusTile] = []
var _reserved_label: Label
var _reserved_cards: HBoxContainer

var _last_data: Dictionary = {}


func _ready() -> void:
	frame_texture = UiAssets.frame_l("ink")
	frame_border = 4
	background_color = UiPalette.CARD
	content_padding = Vector4i(16, 8, 16, 12)
	shadow_enabled = true
	shadow_offset = Vector2i(0, 4)
	top_highlight = true
	side_bar = true
	super._ready()
	custom_minimum_size.y = HEIGHT

	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 8)
	content.add_child(column)

	_build_strip(column)
	_build_body(column)


func _build_strip(column: VBoxContainer) -> void:
	_strip = UiFrame.new()
	_strip.name = "Strip"
	_strip.frame_border = 2
	_strip.content_padding = Vector4i(2, 0, 2, 0)
	_strip.custom_minimum_size.y = STRIP_HEIGHT
	column.add_child(_strip)

	_strip_line = ColorRect.new()
	_strip_line.name = "StripLine"
	_strip_line.color = UiPalette.LINE
	_strip_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.add_child(_strip_line)
	_strip.resized.connect(_layout_strip_line)

	_strip_row = HBoxContainer.new()
	_strip_row.name = "StripRow"
	_strip_row.add_theme_constant_override("separation", 8)
	_strip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_strip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.content.add_child(_strip_row)

	_strip_avatar = UiAssets.mascot_icon(0, 24)
	_strip_avatar.name = "StripAvatar"
	_strip_row.add_child(_strip_avatar)

	_bullet_holder = _make_bullet_holder()
	_bullet_holder.name = "Bullet"
	_strip_row.add_child(_bullet_holder)

	_strip_text = RichTextLabel.new()
	_strip_text.name = "StripText"
	_strip_text.bbcode_enabled = true
	_strip_text.fit_content = true
	_strip_text.scroll_active = false
	_strip_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_strip_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_strip_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_strip_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_rich_font(_strip_text)
	_strip_text.add_theme_color_override("default_color", UiPalette.INK_2)
	_strip_row.add_child(_strip_text)

	_tray = HBoxContainer.new()
	_tray.name = "Tray"
	_tray.add_theme_constant_override("separation", 8)
	_tray.alignment = BoxContainer.ALIGNMENT_CENTER
	_strip_row.add_child(_tray)
	_tray_chips = HBoxContainer.new()
	_tray_chips.name = "TrayChips"
	_tray_chips.add_theme_constant_override("separation", 2)
	_tray_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tray.add_child(_tray_chips)
	_tray_label = Label.new()
	_tray_label.name = "TrayLabel"
	_tray_label.add_theme_color_override("font_color", UiPalette.INK_3)
	_tray.add_child(_tray_label)
	_cancel = UiButton.new()
	_cancel.name = "CancelButton"
	_cancel.variant = &"ghost"
	_cancel.size_key = &"sm"
	_cancel.text = "取消"
	_cancel.disabled = true
	_cancel.focus_mode = Control.FOCUS_NONE
	_cancel.pressed.connect(func() -> void: cancel_pressed.emit())
	_tray.add_child(_cancel)

	_confirm = UiButton.new()
	_confirm.name = "ConfirmButton"
	_confirm.variant = &"accent"
	_confirm.size_key = &"sm"
	_confirm.text = "确认拿取"
	_confirm.disabled = true
	_confirm.focus_mode = Control.FOCUS_NONE
	_confirm.pressed.connect(func() -> void: confirm_pressed.emit())
	_tray.add_child(_confirm)

	_strip_time = Label.new()
	_strip_time.name = "StripTime"
	_strip_time.add_theme_color_override("font_color", UiPalette.INK_2)
	_strip_time.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_strip_row.add_child(_strip_time)


func _build_body(column: VBoxContainer) -> void:
	var body := HBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)

	# 身份
	var ident := VBoxContainer.new()
	ident.name = "Ident"
	ident.add_theme_constant_override("separation", 6)
	ident.custom_minimum_size.x = 200
	body.add_child(ident)

	var who := HBoxContainer.new()
	who.add_theme_constant_override("separation", 10)
	ident.add_child(who)
	_avatar = UiAssets.mascot_icon(0, 50)
	_avatar.name = "Avatar"
	who.add_child(_avatar)
	var who_text := VBoxContainer.new()
	who_text.add_theme_constant_override("separation", 4)
	who_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	who.add_child(who_text)
	_name = Label.new()
	_name.name = "Name"
	_name.theme_type_variation = &"UiTitle"
	who_text.add_child(_name)
	_me_tag = UiTag.new()
	_me_tag.variant = &"dark"
	_me_tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	who_text.add_child(_me_tag)

	var score_row := HBoxContainer.new()
	score_row.add_theme_constant_override("separation", 6)
	ident.add_child(score_row)
	_score = Label.new()
	_score.name = "Score"
	_score.theme_type_variation = &"UiNumBig"
	score_row.add_child(_score)
	_win_label = Label.new()
	_win_label.name = "WinLabel"
	_win_label.add_theme_color_override("font_color", UiPalette.INK_3)
	_win_label.size_flags_vertical = Control.SIZE_SHRINK_END
	score_row.add_child(_win_label)

	_cards_label = Label.new()
	_cards_label.name = "CardsLabel"
	_cards_label.add_theme_color_override("font_color", UiPalette.INK_3)
	ident.add_child(_cards_label)

	# 资源
	var res := VBoxContainer.new()
	res.name = "Resources"
	res.add_theme_constant_override("separation", 6)
	res.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(res)

	_tokens_label = _add_labeled_row(res, "TokensLabel")
	var chips_row := HBoxContainer.new()
	chips_row.name = "Chips"
	chips_row.add_theme_constant_override("separation", 6)
	res.add_child(chips_row)
	for color: Enums.GemColor in Enums.ALL_COLORS:
		var chip := UiGemChip.new()
		chip.gem_color = color
		chip.size_key = &"md"
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chips_row.add_child(chip)
		_chips.append(chip)

	_bonus_label = _add_labeled_row(res, "BonusLabel")
	_bonus_label.text = "折扣"
	var tiles_row := HBoxContainer.new()
	tiles_row.name = "Bonuses"
	tiles_row.add_theme_constant_override("separation", 6)
	res.add_child(tiles_row)
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		var tile := UiBonusTile.new()
		tile.gem_color = color
		tile.size_key = &"md"
		tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tiles_row.add_child(tile)
		_tiles.append(tile)

	# 预留
	var reserved := VBoxContainer.new()
	reserved.name = "Reserved"
	reserved.add_theme_constant_override("separation", 6)
	body.add_child(reserved)
	_reserved_label = _add_labeled_row(reserved, "ReservedLabel")
	_reserved_cards = HBoxContainer.new()
	_reserved_cards.name = "ReservedCards"
	_reserved_cards.add_theme_constant_override("separation", 8)
	reserved.add_child(_reserved_cards)


func _add_labeled_row(parent: Control, label_name: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	row.add_child(_make_bullet_holder())
	var label := Label.new()
	label.name = label_name
	label.add_theme_color_override("font_color", UiPalette.INK_3)
	row.add_child(label)
	return label


func _make_bullet_holder() -> Control:
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(12, 12)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bullet := ColorRect.new()
	bullet.custom_minimum_size = Vector2(7, 7)
	bullet.size = Vector2(7, 7)
	bullet.pivot_offset = Vector2(3.5, 3.5)
	bullet.color = Color("#c79a5b")
	bullet.rotation = PI / 4
	bullet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(bullet)
	return holder


func _apply_rich_font(rich: RichTextLabel) -> void:
	rich.add_theme_font_override("normal_font", get_theme_default_font())
	rich.add_theme_font_size_override("normal_font_size", get_theme_default_font_size())
	rich.add_theme_font_override("bold_font", get_theme_default_font())
	rich.add_theme_font_size_override("bold_font_size", get_theme_default_font_size())


func _layout_strip_line() -> void:
	if _strip_line == null or _strip == null:
		return
	_strip_line.position = Vector2(0, maxf(_strip.size.y - 2, 0))
	_strip_line.size = Vector2(_strip.size.x, 2)


## 显示数据（由牌桌用 UiViewMath 算好）：
## seat / name / seat_type / score / win_points / card_count / noble_count /
## tokens（枚举键）/ bonuses（枚举键）/ reserved / max_tokens / max_reserved / catalog /
## strip = {kind: "note"|"event", text, right, tray_text, confirm_label,
##          confirm_enabled, seat}。
func render(data: Dictionary) -> void:
	_last_data = data.duplicate(true)
	var catalog: CardCatalog = data.get("catalog")
	var seat: int = int(data.get("seat", 0))
	var name: String = String(data.get("name", "座位 %d" % (seat + 1)))

	_avatar.texture = UiAssets.mascot(seat)
	_strip_avatar.texture = UiAssets.mascot(seat)
	_name.text = name
	_me_tag.text = "你 · 座位 %d" % (seat + 1)

	var score: int = int(data.get("score", 0))
	var win_points: int = int(data["win_points"])
	_score.text = str(score)
	_win_label.text = "/ %d 分" % win_points
	_cards_label.text = "已购卡 %d 张 · 贵族 %d 位" % [
		int(data.get("card_count", 0)), int(data.get("noble_count", 0)),
	]

	var tokens: Dictionary = data.get("tokens", {})
	var total_tokens: int = 0
	for color: Enums.GemColor in Enums.ALL_COLORS:
		var amount: int = int(tokens.get(color, 0))
		total_tokens += amount
		if color < _chips.size():
			_chips[color].count = amount
	var max_tokens: int = int(data["max_tokens"])
	_tokens_label.text = "宝石 %d / %d" % [total_tokens, max_tokens]
	_tokens_label.add_theme_color_override(
			"font_color", UiPalette.DANGER if total_tokens > max_tokens else UiPalette.INK_3)

	var bonuses: Dictionary = data.get("bonuses", {})
	for index: int in _tiles.size():
		var color: Enums.GemColor = Enums.PURCHASABLE_COLORS[index]
		_tiles[index].count = int(bonuses.get(color, 0))

	var reserved: Array = data.get("reserved", [])
	var max_reserved: int = int(data["max_reserved"])
	_reserved_label.text = "预留 %d / %d" % [reserved.size(), max_reserved]
	_render_reserved(reserved, catalog, bool(data.get("can_buy", false)),
			bool(data.get("can_select_reserved", false)), max_reserved,
			String(data.get("selected_kind", "")), String(data.get("selected_id", "")))

	_render_strip(data.get("strip", {}), catalog)


func _render_reserved(reserved: Array, catalog: CardCatalog, can_buy: bool,
		can_select: bool, max_reserved: int, selected_kind: String,
		selected_id: String) -> void:
	for child in _reserved_cards.get_children():
		_reserved_cards.remove_child(child)
		child.queue_free()
	for slot: int in max_reserved:
		var card := UiDevCard.new()
		card.name = "Reserved%d" % slot
		card.catalog = catalog
		card.mini = true
		if slot < reserved.size():
			var entry: Dictionary = reserved[slot]
			var card_id: String = UiViewMath.reserved_card_id(entry)
			card.card_back = card_id.is_empty()
			card.back_level = int(entry.get("level", 1))
			card.card_id = card_id
			card.blind_label = not card_id.is_empty() and UiViewMath.is_blind(entry)
			card.affordable = can_buy and bool(entry.get("affordable", false))
			card.selected = selected_kind == "reserved" and card_id == selected_id
			if can_select and not card_id.is_empty():
				card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				card.gui_input.connect(_on_reserved_input.bind(card, card_id))
		else:
			card.empty = true
		_reserved_cards.add_child(card)


func _on_reserved_input(event: InputEvent, card: Control, card_id: String) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse := event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed:
		return
	card.accept_event()
	reserved_card_clicked.emit(card_id)


## 牌桌浮层定位用：按卡牌 id 找我的预留卡节点。
func find_reserved_card(card_id: String) -> UiDevCard:
	for child in _reserved_cards.get_children():
		if child is UiDevCard and (child as UiDevCard).card_id == card_id:
			return child
	return null


func _render_strip(strip: Dictionary, catalog: CardCatalog) -> void:
	var event: bool = String(strip.get("kind", "note")) == "event"
	var text: String = String(strip.get("text", ""))
	_strip_text.add_theme_color_override(
			"default_color", UiPalette.INK if event else UiPalette.INK_2)
	_strip_text.text = UiMarkup.to_bbcode(text, catalog)
	if event:
		_strip.frame_texture = UiAssets.frame_s("hot")
		_strip.background_color = UiPalette.EVENT_BG
		_strip.draw_background = true
		_strip.content_padding = Vector4i(10, 2, 10, 2)
		_strip.custom_minimum_size.y = EVENT_STRIP_HEIGHT
		_strip_line.visible = false
		_strip_avatar.visible = strip.has("seat")
		if strip.has("seat"):
			_strip_avatar.texture = UiAssets.mascot(int(strip.get("seat", 0)))
		_bullet_holder.visible = false
		_tray.visible = false
		_strip_time.visible = true
		_strip_time.text = String(strip.get("right", ""))
	else:
		_strip.frame_texture = null
		_strip.draw_background = false
		_strip.content_padding = Vector4i(2, 0, 2, 0)
		_strip.custom_minimum_size.y = STRIP_HEIGHT
		_strip_line.visible = true
		_strip_avatar.visible = false
		_bullet_holder.visible = true
		var tray_text: String = String(strip.get("tray_text", ""))
		_tray.visible = not tray_text.is_empty()
		_tray_label.text = tray_text
		for child in _tray_chips.get_children():
			_tray_chips.remove_child(child)
			child.queue_free()
		var tray_colors: Array = strip.get("tray_colors", [])
		for item: Variant in tray_colors:
			var chip := UiGemChip.new()
			chip.gem_color = int(item)
			chip.count = 1
			chip.size_key = &"sm"
			chip.bare = true
			_tray_chips.add_child(chip)
		_tray_chips.visible = _tray.visible and not tray_colors.is_empty()
		_confirm.text = String(strip.get("confirm_label", "确认拿取"))
		_confirm.disabled = not bool(strip.get("confirm_enabled", false))
		_cancel.disabled = not bool(strip.get("cancel_enabled", false))
		_strip_time.visible = false
	update_minimum_size()


func get_render_data() -> Dictionary:
	return _last_data.duplicate(true)
