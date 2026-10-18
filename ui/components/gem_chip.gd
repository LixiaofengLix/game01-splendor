## 宝石筹码：金币贴图 + 中间数字；4 种尺寸 × 正常 / 空心 / 已选 +N / 待弃 −N / 无数字。
## 颜色永远同时带专属形状（bare 时显示形状，否则数字），灰度和色盲下也能区分。
class_name UiGemChip
extends Control

const SIZES: Dictionary[StringName, int] = {
	&"lg": 48,
	&"md": 36,
	&"sm": 24,
	&"xs": 12,
}

var gem_color: Enums.GemColor = Enums.GemColor.WHITE:
	set(value):
		gem_color = value
		if _coin != null:
			_refresh()

var count: int = 0:
	set(value):
		count = value
		if _coin != null:
			_refresh()

var size_key: StringName = &"lg":
	set(value):
		size_key = value
		if _coin != null:
			_apply_size()

## 已选数量：右上角显示 +N 角标。
var selected_amount: int = 0:
	set(value):
		selected_amount = value
		if _coin != null:
			_refresh()

## 待弃数量：右上角显示 −N 角标；count 由调用方给出弃后的值。
var discard_amount: int = 0:
	set(value):
		discard_amount = value
		if _coin != null:
			_refresh()

## 不显示数字，只显示 12px 单色形状（托盘、支付预览）。
var bare: bool = false:
	set(value):
		bare = value
		if _coin != null:
			_refresh()

var _shadow: TextureRect
var _coin: TextureRect
var _number: Label
var _icon: TextureRect
var _badge: PanelContainer
var _badge_label: Label
var _plus_style: StyleBoxFlat
var _minus_style: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_shadow = TextureRect.new()
	_shadow.name = "Shadow"
	_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shadow.stretch_mode = TextureRect.STRETCH_SCALE
	_shadow.modulate = Color(0.0784314, 0.0470588, 0.0313726, 0.45)
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shadow)

	_coin = TextureRect.new()
	_coin.name = "Coin"
	_coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_coin.stretch_mode = TextureRect.STRETCH_SCALE
	_coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_coin)

	_number = Label.new()
	_number.name = "Number"
	_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_number)

	_icon = UiAssets.icon(Enums.GemColor.WHITE, 12, 0.72)
	_icon.name = "Icon"
	add_child(_icon)

	_plus_style = _make_badge_style(UiPalette.ORANGE, UiPalette.INK)
	_minus_style = _make_badge_style(UiPalette.INK, UiPalette.BLACK_SHADOW)
	_badge = PanelContainer.new()
	_badge.name = "Badge"
	_badge.add_theme_stylebox_override("panel", _plus_style)
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_label = Label.new()
	_badge_label.add_theme_color_override("font_color", UiPalette.WHITE)
	_badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.add_child(_badge_label)
	add_child(_badge)

	resized.connect(_layout)
	_apply_size()


func _make_badge_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	style.anti_aliasing = false
	return style


func _apply_size() -> void:
	var side: int = SIZES.get(size_key, SIZES[&"lg"])
	custom_minimum_size = Vector2(side, side)
	size = Vector2(side, side)
	_number.theme_type_variation = &"UiNum" if side >= 48 else &"UiNumMid"
	_layout()
	_refresh()


func _layout() -> void:
	var side: int = SIZES.get(size_key, SIZES[&"lg"])
	var origin := Vector2((size.x - side) * 0.5, (size.y - side) * 0.5)
	var box := Rect2(origin, Vector2(side, side))
	_shadow.position = origin + Vector2(0, 2)
	_shadow.size = Vector2(side, side)
	_coin.position = origin
	_coin.size = Vector2(side, side)
	_number.position = origin
	_number.size = Vector2(side, side)
	_icon.position = origin + Vector2((side - 12) * 0.5, (side - 12) * 0.5)
	_icon.size = Vector2(12, 12)
	if _badge.visible:
		var badge_size := _badge.get_combined_minimum_size()
		_badge.position = origin + Vector2(side - badge_size.x + 8, -8)
		_badge.size = badge_size
	queue_redraw()


func _refresh() -> void:
	if _coin == null:
		return
	var empty := count <= 0
	_coin.texture = UiAssets.coin(gem_color, empty)
	_shadow.texture = _coin.texture
	_shadow.visible = not empty

	var font_color: Color = UiPalette.GEM_TEXT[gem_color]
	if empty:
		font_color = UiPalette.INK_3
	_number.add_theme_color_override("font_color", font_color)
	var dark_coin := gem_color != Enums.GemColor.WHITE and gem_color != Enums.GemColor.GOLD
	if dark_coin and not empty:
		_number.add_theme_color_override("font_outline_color", UiPalette.BLACK_SHADOW)
		_number.add_theme_constant_override("outline_size", 1)
	else:
		_number.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
		_number.add_theme_constant_override("outline_size", 0)

	_number.visible = not bare and size_key != &"xs"
	_number.text = str(count)
	_icon.visible = bare
	if bare:
		_icon.texture = UiAssets.gem(gem_color, true)
		var icon_color: Color = UiPalette.GEM_EDGE[gem_color] if empty else UiAssets.icon_color(gem_color)
		_icon.modulate = Color(icon_color.r, icon_color.g, icon_color.b, 0.75 if not empty else 1.0)

	if discard_amount > 0:
		_badge.visible = true
		_badge.add_theme_stylebox_override("panel", _minus_style)
		_badge_label.text = "−%d" % discard_amount
	elif selected_amount > 0:
		_badge.visible = true
		_badge.add_theme_stylebox_override("panel", _plus_style)
		_badge_label.text = "+%d" % selected_amount
	else:
		_badge.visible = false
	_layout()
	queue_redraw()


func _draw() -> void:
	# 待弃只用角标表示，不再加外框；已选才是 3px ORANGE 外框。
	if selected_amount <= 0 or discard_amount > 0:
		return
	var side: int = SIZES.get(size_key, SIZES[&"lg"])
	var origin := Vector2((size.x - side) * 0.5, (size.y - side) * 0.5)
	draw_rect(Rect2(origin - Vector2(2, 2), Vector2(side + 4, side + 4)), UiPalette.ORANGE, false, 3)
