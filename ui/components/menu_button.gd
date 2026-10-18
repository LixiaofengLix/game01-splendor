## 主菜单大按钮：24 号主文字 + 12 号副文字，右侧一个 ›。配色沿用 UiButton 变体。
class_name UiMenuButton
extends UiButton

var title: String = "":
	set(value):
		title = value
		_refresh()

var subtitle: String = "":
	set(value):
		subtitle = value
		_refresh()

var _title_label: Label
var _subtitle_label: Label
var _arrow_label: Label


func _init() -> void:
	size_key = &"lg"
	custom_minimum_size = Vector2(360, 64)


func _ready() -> void:
	super._ready()
	text = ""
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 11)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 13)
	add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var labels := VBoxContainer.new()
	labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.add_theme_constant_override("separation", 2)
	row.add_child(labels)

	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.theme_type_variation = &"UiTitle"
	labels.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.name = "Subtitle"
	_subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.add_child(_subtitle_label)

	_arrow_label = Label.new()
	_arrow_label.name = "Arrow"
	_arrow_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow_label.text = "›"
	_arrow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_arrow_label)

	_refresh()


func _apply_style() -> void:
	super._apply_style()
	_refresh()


func _refresh() -> void:
	if _title_label == null:
		return
	_title_label.text = title
	_subtitle_label.text = subtitle
	var title_color := UiPalette.INK
	var subtitle_color := UiPalette.INK_2
	match variant:
		&"accent":
			title_color = UiPalette.WHITE
			subtitle_color = Color(1, 1, 1, 0.75)
		&"dark":
			title_color = UiPalette.CREAM
			subtitle_color = Color(UiPalette.CREAM.r, UiPalette.CREAM.g, UiPalette.CREAM.b, 0.7)
	_title_label.add_theme_color_override("font_color", title_color)
	_subtitle_label.add_theme_color_override("font_color", subtitle_color)
	_arrow_label.add_theme_color_override("font_color", subtitle_color)
