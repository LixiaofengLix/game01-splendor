## 卡牌浮层：选中场面卡 / 自己的预留卡 / 牌堆后出现在右侧。
## 显示支付预览（先折扣、再同色宝石、最后金币）、买后变化，以及购买 / 预留按钮。
## 只接收显示数据；动作是否合法由牌桌算好后放进 can_buy / can_reserve。
class_name UiCardPopover
extends UiFrame

signal purchase_pressed
signal reserve_pressed

const WIDTH := 272

var _header: HBoxContainer
var _tag: UiTag
var _title: Label
var _payment_box: PanelContainer
var _payment: VBoxContainer
var _note: Label
var _change: Label
var _buttons: HBoxContainer
var _buy: UiButton
var _reserve: UiButton
var _reserve_note: Label
var _hint: Label


func _ready() -> void:
	frame_texture = UiAssets.frame_l("ink")
	frame_border = 4
	background_color = UiPalette.CARD
	content_padding = Vector4i(16, 14, 16, 14)
	shadow_enabled = true
	shadow_offset = Vector2i(0, 6)
	shadow_color = Color(0, 0, 0, 0.5)
	top_highlight = true
	super._ready()
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size.x = WIDTH

	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 10)
	content.add_child(column)

	_header = HBoxContainer.new()
	_header.name = "Header"
	_header.add_theme_constant_override("separation", 8)
	column.add_child(_header)

	_tag = UiTag.new()
	_tag.name = "Tag"
	_tag.visible = false
	_header.add_child(_tag)

	_title = Label.new()
	_title.name = "Title"
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(_title)

	var payment_style := StyleBoxFlat.new()
	payment_style.bg_color = UiPalette.CARD_SOFT
	payment_style.border_color = UiPalette.LINE
	payment_style.border_width_left = 2
	payment_style.border_width_top = 2
	payment_style.border_width_right = 2
	payment_style.border_width_bottom = 2
	payment_style.content_margin_left = 8
	payment_style.content_margin_top = 6
	payment_style.content_margin_right = 8
	payment_style.content_margin_bottom = 6
	payment_style.anti_aliasing = false
	_payment_box = PanelContainer.new()
	_payment_box.name = "PaymentBox"
	_payment_box.add_theme_stylebox_override("panel", payment_style)
	column.add_child(_payment_box)
	_payment = VBoxContainer.new()
	_payment.name = "Payment"
	_payment.add_theme_constant_override("separation", 5)
	_payment_box.add_child(_payment)

	_note = Label.new()
	_note.name = "Note"
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.add_theme_color_override("font_color", UiPalette.INK_2)
	column.add_child(_note)

	_change = Label.new()
	_change.name = "Change"
	_change.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_change.add_theme_color_override("font_color", UiPalette.INK_2)
	column.add_child(_change)

	_buttons = HBoxContainer.new()
	_buttons.name = "Buttons"
	_buttons.add_theme_constant_override("separation", 8)
	column.add_child(_buttons)

	_buy = UiButton.new()
	_buy.name = "BuyButton"
	_buy.variant = &"accent"
	_buy.size_key = &"default"
	_buy.text = "购买"
	_buy.focus_mode = Control.FOCUS_NONE
	_buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buy.pressed.connect(func() -> void: purchase_pressed.emit())
	_buttons.add_child(_buy)

	_reserve = UiButton.new()
	_reserve.name = "ReserveButton"
	_reserve.variant = &"ghost"
	_reserve.size_key = &"default"
	_reserve.text = "预留"
	_reserve.focus_mode = Control.FOCUS_NONE
	_reserve.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reserve.pressed.connect(func() -> void: reserve_pressed.emit())
	_buttons.add_child(_reserve)

	_reserve_note = Label.new()
	_reserve_note.name = "ReserveNote"
	_reserve_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reserve_note.add_theme_color_override("font_color", UiPalette.DANGER)
	column.add_child(_reserve_note)

	_hint = Label.new()
	_hint.name = "Hint"
	_hint.add_theme_color_override("font_color", UiPalette.INK_3)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hint)


## 显示数据见 ui/screens/table/README.md 的 popover 一节。
func render(data: Dictionary) -> void:
	var mode: String = String(data.get("mode", "market"))
	var tag_text: String = String(data.get("tag_text", ""))
	_tag.visible = not tag_text.is_empty()
	_tag.text = tag_text
	_tag.variant = StringName(data.get("tag_variant", "default"))
	_title.text = String(data.get("title", ""))

	_clear(_payment)
	_payment_box.visible = mode != "deck"
	var note: String = String(data.get("note", ""))
	_note.text = note
	_note.visible = not note.is_empty()
	_change.text = String(data.get("change_text", ""))
	_change.visible = not _change.text.is_empty()

	if mode != "deck" and bool(data.get("affordable", false)):
		_build_payment(data)
	elif mode != "deck":
		_build_shortfall(data)

	var can_buy: bool = bool(data.get("can_buy", false))
	_buy.visible = mode != "deck"
	_buy.text = String(data.get("buy_label", "购买"))
	_buy.disabled = not can_buy

	var can_reserve: bool = bool(data.get("can_reserve", false))
	_reserve.visible = mode != "reserved"
	_reserve.text = String(data.get("reserve_label", "预留"))
	_reserve.disabled = not can_reserve

	_reserve_note.text = String(data.get("reserve_note", ""))
	_reserve_note.visible = not _reserve_note.text.is_empty()

	_hint.text = String(data.get("hint", "Enter 购买 · R 预留 · Esc 取消"))
	if mode == "deck":
		_hint.text = "Enter 预留 · Esc 取消"
	elif mode == "reserved":
		_hint.text = "Enter 购买 · Esc 取消"
	update_minimum_size()
	reset_size()


func _build_payment(data: Dictionary) -> void:
	var payment: Dictionary = data.get("payment", {})
	var bonus: Dictionary = payment.get("bonus", {})
	var gems: Dictionary = payment.get("gems", {})
	var gold: int = int(payment.get("gold", 0))
	var total: int = int(payment.get("total", 0))
	var bonus_row := _new_row("折扣", "共 %d 点" % _sum(bonus))
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		var amount: int = int(bonus.get(color, 0))
		if amount <= 0:
			continue
		var tile := UiBonusTile.new()
		tile.gem_color = color
		tile.count = amount
		tile.size_key = &"noble"
		bonus_row.add_child(tile)
	_add_none_if_empty(bonus_row)
	var gem_row := _new_row("宝石", "共 %d 枚" % _sum(gems))
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		var amount: int = int(gems.get(color, 0))
		if amount <= 0:
			continue
		var chip := UiGemChip.new()
		chip.gem_color = color
		chip.count = amount
		chip.size_key = &"sm"
		gem_row.add_child(chip)
	_add_none_if_empty(gem_row)
	var gold_summary: String = "—" if gold <= 0 else "补 %d 枚" % gold
	var gold_row := _new_row("金币", gold_summary)
	if gold > 0:
		var chip := UiGemChip.new()
		chip.gem_color = Enums.GemColor.GOLD
		chip.count = gold
		chip.size_key = &"sm"
		gold_row.add_child(chip)
	_add_none_if_empty(gold_row)
	_add_summary("合计 %d 枚 · 自动支付" % total)


func _build_shortfall(data: Dictionary) -> void:
	var missing: Array = data.get("missing", [])
	var need_row := _new_row("需要", "差 %d 枚" % int(data.get("shortfall", 0)))
	for entry: Variant in missing:
		var item: Dictionary = entry if entry is Dictionary else {}
		var pill := UiCostPill.new()
		pill.gem_color = int(item.get("color", Enums.GemColor.WHITE))
		pill.amount = int(item.get("amount", 0))
		pill.mini = true
		need_row.add_child(pill)
	var bonuses: Dictionary = data.get("bonuses", {})
	var tokens: Dictionary = data.get("tokens", {})
	var have_row := _new_row("已有", "")
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		var bonus: int = int(bonuses.get(color, 0))
		if bonus > 0:
			var tile := UiBonusTile.new()
			tile.gem_color = color
			tile.count = bonus
			tile.size_key = &"noble"
			tile.tooltip_text = "%s折扣 %d" % [Enums.color_to_zh(color), bonus]
			have_row.add_child(tile)
		var amount: int = int(tokens.get(color, 0))
		if amount > 0:
			var chip := UiGemChip.new()
			chip.gem_color = color
			chip.count = amount
			chip.size_key = &"sm"
			have_row.add_child(chip)
	var gold: int = int(tokens.get(Enums.GemColor.GOLD, 0))
	if gold > 0:
		var gold_chip := UiGemChip.new()
		gold_chip.gem_color = Enums.GemColor.GOLD
		gold_chip.count = gold
		gold_chip.size_key = &"sm"
		have_row.add_child(gold_chip)
	if have_row.get_child_count() == 0:
		var none := Label.new()
		none.text = "无"
		none.add_theme_color_override("font_color", UiPalette.INK_3)
		have_row.add_child(none)
	var can_pay: int = int(data.get("gold_can_pay", 0))
	if can_pay > 0:
		_add_summary("金币最多可抵 %d 枚" % can_pay)


## 返回这一行的填充容器：调用方往里加折扣块 / 筹码；右侧小结已经放好。
func _new_row(label_text: String, summary: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_payment.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", UiPalette.INK_3)
	label.custom_minimum_size.x = 34
	row.add_child(label)
	var fill := HBoxContainer.new()
	fill.add_theme_constant_override("separation", 4)
	row.add_child(fill)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	if not summary.is_empty():
		var right := Label.new()
		right.text = summary
		right.add_theme_color_override("font_color", UiPalette.INK_2)
		right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(right)
	return fill


func _add_none_if_empty(row: HBoxContainer) -> void:
	if row.get_child_count() > 0:
		return
	var none := Label.new()
	none.text = "无"
	none.add_theme_color_override("font_color", UiPalette.INK_3)
	row.add_child(none)


func _add_summary(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", UiPalette.INK_2)
	_payment.add_child(label)


func _sum(values: Dictionary) -> int:
	var total: int = 0
	for value: Variant in values.values():
		total += int(value)
	return total


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
