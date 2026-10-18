## 牌堆：96×150，斜纹深色厚卡 + 金色罗马数字 + 剩余张数；空了画虚线空位，选中加 ORANGE 外框。
class_name UiDeckPile
extends Control

const SIZE := Vector2(96, 150)
const ROMAN: Dictionary[int, String] = {1: "I", 2: "II", 3: "III"}

var level: int = 1:
	set(value):
		level = value
		_refresh()

var remaining: int = 0:
	set(value):
		remaining = value
		_refresh()

var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()

var _tex: TextureRect
var _frame: NinePatchRect
var _box: VBoxContainer
var _roman: Label
var _marks: Label
var _count: Label


func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_PASS

	_tex = UiAssets.tiled(UiAssets.texture("tile_card_back.png"))
	_tex.name = "Texture"
	add_child(_tex)

	_frame = UiAssets.nine_patch(UiAssets.frame_s("dark"), 2)
	_frame.name = "Frame"
	add_child(_frame)

	_box = VBoxContainer.new()
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 5)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)

	_roman = Label.new()
	_roman.name = "Roman"
	_roman.theme_type_variation = &"UiNum"
	_roman.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_roman.add_theme_color_override("font_color", UiPalette.GOLD)
	_roman.add_theme_color_override("font_shadow_color", UiPalette.BLACK_SHADOW)
	_roman.add_theme_constant_override("shadow_offset_x", 2)
	_roman.add_theme_constant_override("shadow_offset_y", 2)
	_box.add_child(_roman)

	_marks = Label.new()
	_marks.name = "Marks"
	_marks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_marks.add_theme_color_override("font_color", UiPalette.GOLD)
	_box.add_child(_marks)

	_count = Label.new()
	_count.name = "Count"
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.add_theme_color_override("font_color", Color("#b9b0a0"))
	_box.add_child(_count)

	resized.connect(_layout)
	_layout()
	_refresh()


func _layout() -> void:
	var pile_size := size if size.length() > 0 else SIZE
	_tex.position = Vector2(2, 2)
	_tex.size = pile_size - Vector2(4, 4)
	_frame.position = Vector2.ZERO
	_frame.size = pile_size
	_box.reset_size()
	_box.position = Vector2(
			floorf((pile_size.x - _box.size.x) * 0.5),
			floorf((pile_size.y - _box.size.y) * 0.5))
	queue_redraw()


func _refresh() -> void:
	if _box == null:
		return
	_roman.text = ROMAN.get(level, "I")
	var empty := remaining <= 0
	_tex.visible = not empty
	_frame.visible = not empty
	_marks.visible = not empty
	_marks.text = "◆".repeat(level)
	_count.text = "剩 %d" % remaining if not empty else "已空"
	_count.add_theme_color_override("font_color", Color("#b9b0a0") if not empty else UiPalette.INK_3)
	_box.reset_size()
	_layout()


func _draw() -> void:
	var pile_size := size if size.length() > 0 else SIZE
	if remaining <= 0:
		var dash := Color(0.953, 0.902, 0.784, 0.35)
		var rect := Rect2(Vector2(1, 1), pile_size - Vector2(2, 2))
		draw_dashed_line(rect.position, Vector2(rect.end.x, rect.position.y), dash, 2.0, 4.0)
		draw_dashed_line(Vector2(rect.end.x, rect.position.y), rect.end, dash, 2.0, 4.0)
		draw_dashed_line(rect.end, Vector2(rect.position.x, rect.end.y), dash, 2.0, 4.0)
		draw_dashed_line(Vector2(rect.position.x, rect.end.y), rect.position, dash, 2.0, 4.0)
		return
	draw_rect(Rect2(1, 6, pile_size.x - 2, pile_size.y), Color("#1a110b"))
	draw_rect(Rect2(1, 3, pile_size.x - 2, pile_size.y), Color("#6b5440"))
	if selected:
		draw_rect(Rect2(Vector2(-2, -2), pile_size + Vector2(4, 4)), UiPalette.ORANGE, false, 3)
