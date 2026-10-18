## 像素标签：小框 + 6 种配色（默认 / dark / mint / orange / purple / red），内边距 2/7。
class_name UiTag
extends UiFrame

var text: String = "":
	set(value):
		text = value
		if _label != null:
			_label.text = value

var variant: StringName = &"default":
	set(value):
		variant = value
		_apply_variant()

## 顶栏里的 tag 用深色底 + 浅字（VISUAL_SPEC 2.3 最后一行的配色）。
var in_hud: bool = false:
	set(value):
		in_hud = value
		_apply_variant()

var _label: Label


func _ready() -> void:
	frame_texture = UiAssets.frame_s("ink")
	frame_border = 2
	draw_background = true
	content_padding = Vector4i(7, 2, 7, 2)
	super._ready()
	_label = Label.new()
	_label.name = "Label"
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_label)
	_label.text = text
	_apply_variant()


func _apply_variant() -> void:
	if _label == null:
		return
	var bg := UiPalette.TAG_BG
	var fg := UiPalette.TAG_TEXT
	match variant:
		&"dark":
			bg = UiPalette.TAG_DARK_BG
			fg = UiPalette.TAG_DARK_TEXT
		&"mint":
			bg = UiPalette.TAG_MINT_BG
			fg = UiPalette.TAG_MINT_TEXT
		&"orange":
			bg = UiPalette.TAG_ORANGE_BG
			fg = UiPalette.TAG_ORANGE_TEXT
		&"purple":
			bg = UiPalette.TAG_PURPLE_BG
			fg = UiPalette.TAG_PURPLE_TEXT
		&"red":
			bg = UiPalette.TAG_RED_BG
			fg = UiPalette.TAG_RED_TEXT
	if in_hud:
		match variant:
			&"orange":
				bg = UiPalette.ORANGE
				fg = UiPalette.WHITE
			&"mint":
				bg = UiPalette.OK
				fg = UiPalette.WHITE
			_:
				bg = UiPalette.HUD_HIGHLIGHT
				fg = UiPalette.CREAM
	background_color = bg
	_label.add_theme_color_override("font_color", fg)
