## 卡牌引用：tint 底的小块，[形状] 二级红 · 1 分，用于日志和事件文字。
class_name UiCardRef
extends UiFrame

const LEVEL_ZH: Array[String] = ["", "一级", "二级", "三级"]

var catalog: CardCatalog = null:
	set(value):
		catalog = value
		_refresh()

var card_id: String = "":
	set(value):
		card_id = value
		_refresh()

var _icon: TextureRect
var _label: Label


func _ready() -> void:
	frame_texture = null
	draw_background = true
	background_color = UiPalette.CARD_SOFT
	content_padding = Vector4i(6, 2, 6, 2)
	super._ready()

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(row)

	_icon = UiAssets.gem_icon(Enums.GemColor.WHITE, 12)
	_icon.name = "Icon"
	row.add_child(_icon)

	_label = Label.new()
	_label.name = "Text"
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_label)
	_refresh()


func _refresh() -> void:
	if _label == null:
		return
	var card: CardData = null
	if catalog != null and not card_id.is_empty():
		card = catalog.card(card_id)
	if card == null:
		_label.text = card_id
		_icon.visible = false
		return
	_icon.visible = true
	_icon.texture = UiAssets.gem(card.bonus)
	background_color = UiPalette.GEM_TINT[card.bonus]
	var text := "%s%s" % [
		LEVEL_ZH[clampi(card.level, 0, 3)],
		Enums.color_to_zh(card.bonus),
	]
	if card.points > 0:
		text += " · %d 分" % card.points
	_label.text = text
