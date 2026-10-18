## 列表行：下分隔线 2px；选中时 2px INK 外框 + #fff6df 底。标题 + 副标题 + 右侧说明。
class_name UiListRow
extends Button

var title: String = "":
	set(value):
		title = value
		_refresh()

var subtitle: String = "":
	set(value):
		subtitle = value
		_refresh()

var meta: String = "":
	set(value):
		meta = value
		_refresh()

var selected: bool = false:
	set(value):
		selected = value
		_apply_styles()

var _title_label: Label
var _subtitle_label: Label
var _meta_label: Label
var _normal: StyleBoxFlat
var _hover: StyleBoxFlat
var _pressed: StyleBoxFlat
var _chosen: StyleBoxFlat


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# 调用方可以在加入场景树之前指定更高的行（标题 + 副标题 + 状态）。
	custom_minimum_size.y = maxf(custom_minimum_size.y, 44.0)
	text = ""
	_normal = _make_style(Color(0, 0, 0, 0), UiPalette.LINE)
	_hover = _make_style(UiPalette.CARD_SOFT, UiPalette.LINE)
	_pressed = _make_style(Color("#fff6df"), UiPalette.LINE)
	_chosen = _make_style(Color("#fff6df"), UiPalette.INK, true)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var labels := VBoxContainer.new()
	labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.add_theme_constant_override("separation", 3)
	row.add_child(labels)

	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.name = "Subtitle"
	_subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle_label.add_theme_color_override("font_color", UiPalette.INK_3)
	labels.add_child(_subtitle_label)

	_meta_label = Label.new()
	_meta_label.name = "Meta"
	_meta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meta_label.add_theme_color_override("font_color", UiPalette.INK_3)
	_meta_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_meta_label)

	_apply_styles()
	_refresh()


func _make_style(bg: Color, line: Color, outlined: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = line
	if outlined:
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
	else:
		style.border_width_bottom = 2
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	style.anti_aliasing = false
	return style


func _apply_styles() -> void:
	if _normal == null:
		return
	var base_style := _chosen if selected else _normal
	add_theme_stylebox_override("normal", base_style)
	add_theme_stylebox_override("hover", base_style if selected else _hover)
	add_theme_stylebox_override("pressed", base_style if selected else _pressed)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _refresh() -> void:
	if _title_label == null:
		return
	_title_label.text = title
	_subtitle_label.text = subtitle
	_subtitle_label.visible = not subtitle.is_empty()
	_meta_label.text = meta
	_meta_label.visible = not meta.is_empty()
