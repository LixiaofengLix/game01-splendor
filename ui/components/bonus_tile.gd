## 折扣块：方块（区别于圆形筹码），本色底 + 2px INK 边 + 单色形状 + 数字。
## 数量为 0 时改成 CARD 底 + edge 色描边 + INK_3 字。
class_name UiBonusTile
extends Control

const SIZES: Dictionary[StringName, Vector2i] = {
	&"noble": Vector2i(24, 30),
	&"opp": Vector2i(30, 27),
	&"base": Vector2i(28, 32),
	&"big": Vector2i(42, 50),
	&"md": Vector2i(44, 48),
}

var gem_color: Enums.GemColor = Enums.GemColor.WHITE:
	set(value):
		gem_color = value
		if _label != null:
			_refresh()

var count: int = 0:
	set(value):
		count = value
		if _label != null:
			_refresh()

var size_key: StringName = &"base":
	set(value):
		size_key = value
		if _label != null:
			_apply_size()

var _icon: TextureRect
var _label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon = UiAssets.icon(Enums.GemColor.WHITE, 12, 0.68)
	_icon.name = "Icon"
	add_child(_icon)
	_label = Label.new()
	_label.name = "Number"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_apply_size()


func _apply_size() -> void:
	var tile_size: Vector2i = SIZES.get(size_key, SIZES[&"base"])
	custom_minimum_size = Vector2(tile_size)
	size = Vector2(tile_size)
	_label.theme_type_variation = &"UiNum" if size_key == &"md" or size_key == &"big" else &""
	_layout()
	_refresh()


func _layout() -> void:
	var icon_size := 12.0
	var label_height := 12.0
	var inner := size - Vector2(4, 4)
	var gap := clampf(inner.y - icon_size - label_height, -2.0, 3.0)
	var content_height := icon_size + label_height + gap
	var top := 2.0 + floorf((inner.y - content_height) * 0.5)
	_icon.position = Vector2(floorf((size.x - icon_size) * 0.5), top)
	_icon.size = Vector2(icon_size, icon_size)
	_label.position = Vector2(0, top + icon_size + gap)
	_label.size = Vector2(size.x, label_height)
	queue_redraw()


func _refresh() -> void:
	if _label == null:
		return
	var empty := count <= 0
	_label.text = str(count)
	_icon.texture = UiAssets.gem(gem_color, true)
	if empty:
		_label.add_theme_color_override("font_color", UiPalette.INK_3)
		var edge: Color = UiPalette.GEM_EDGE[gem_color]
		_icon.modulate = edge
	else:
		_label.add_theme_color_override("font_color", UiPalette.GEM_TEXT[gem_color])
		var tint := UiAssets.icon_color(gem_color)
		_icon.modulate = Color(tint.r, tint.g, tint.b, 0.68)
	_layout()
	queue_redraw()


func _draw() -> void:
	var empty := count <= 0
	var bg: Color = UiPalette.CARD if empty else UiPalette.GEM_BASE[gem_color]
	var border: Color = UiPalette.GEM_EDGE[gem_color] if empty else UiPalette.INK
	draw_rect(Rect2(Vector2.ZERO, size), bg)
	draw_rect(Rect2(Vector2.ZERO, size), border, false, 2)
	if not empty:
		draw_rect(Rect2(2, 2, maxf(size.x - 4, 0), 2), Color(1, 1, 1, 0.3))
		draw_rect(Rect2(2, maxf(size.y - 4, 0), maxf(size.x - 4, 0), 2), Color(0, 0, 0, 0.25))
