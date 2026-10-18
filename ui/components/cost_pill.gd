## 花费药丸：本色底、2px INK 边、单色形状 12 + 数字；普通高 20、迷你高 17。
class_name UiCostPill
extends PanelContainer

var gem_color: Enums.GemColor = Enums.GemColor.WHITE:
	set(value):
		gem_color = value
		if _label != null:
			_refresh()

var amount: int = 0:
	set(value):
		amount = value
		if _label != null:
			_refresh()

var mini: bool = false:
	set(value):
		mini = value
		if _label != null:
			_apply_size()

var _icon: TextureRect
var _label: Label
var _style: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style = StyleBoxFlat.new()
	_style.content_margin_left = 4
	_style.content_margin_top = 0
	_style.content_margin_right = 7
	_style.content_margin_bottom = 0
	_style.anti_aliasing = false
	add_theme_stylebox_override("panel", _style)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	_icon = UiAssets.icon(Enums.GemColor.WHITE, 12, 0.8)
	_icon.name = "Icon"
	row.add_child(_icon)

	_label = Label.new()
	_label.name = "Amount"
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_label)

	_apply_size()


func _apply_size() -> void:
	custom_minimum_size = Vector2(30, 17) if mini else Vector2(34, 20)
	_layout()


func _refresh() -> void:
	_style.bg_color = UiPalette.GEM_BASE[gem_color]
	_style.border_color = UiPalette.INK
	_style.border_width_left = 2
	_style.border_width_top = 2
	_style.border_width_right = 2
	_style.border_width_bottom = 2
	_label.text = str(amount)
	_label.add_theme_color_override("font_color", UiPalette.GEM_TEXT[gem_color])
	_icon.texture = UiAssets.gem(gem_color, true)
	var tint := UiAssets.icon_color(gem_color)
	_icon.modulate = Color(tint.r, tint.g, tint.b, 0.8)


func _layout() -> void:
	_refresh()
	reset_size()
