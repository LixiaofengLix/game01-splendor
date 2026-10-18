## 读档列表的一行：头像 + 名称 / 摘要 + 状态标签 / 类型标签 / 时间。
## 选中样式沿用 UiListRow（2px INK 外框 + 浅底）。
class_name UiSaveRow
extends Button

var entry: UiSaveEntry = null
var selected: bool = false:
	set(value):
		selected = value
		_apply_styles()

var _normal: StyleBoxFlat
var _hover: StyleBoxFlat
var _pressed: StyleBoxFlat
var _chosen: StyleBoxFlat


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size.y = 60
	text = ""
	_normal = _make_style(Color(0, 0, 0, 0), UiPalette.LINE, false)
	_hover = _make_style(UiPalette.CARD_SOFT, UiPalette.LINE, false)
	_pressed = _make_style(Color("#fff6df"), UiPalette.LINE, false)
	_chosen = _make_style(Color("#fff6df"), UiPalette.INK, true)
	_apply_styles()
	if entry != null:
		_build()


func set_entry(value: UiSaveEntry) -> void:
	entry = value
	if is_node_ready():
		_build()


func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if entry == null:
		return
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	var mascot := UiAssets.mascot_icon(entry.mascot_seat(), 30)
	mascot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(mascot)

	var labels := VBoxContainer.new()
	labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.add_theme_constant_override("separation", 2)
	row.add_child(labels)

	var title := Label.new()
	title.name = "Title"
	title.text = entry.display_name
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.add_child(title)

	var summary := Label.new()
	summary.name = "Summary"
	summary.text = entry.summary_line()
	summary.add_theme_color_override("font_color", UiPalette.INK_3)
	summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.add_child(summary)

	var right := VBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_theme_constant_override("separation", 3)
	row.add_child(right)

	var tags := HBoxContainer.new()
	tags.alignment = BoxContainer.ALIGNMENT_END
	tags.add_theme_constant_override("separation", 4)
	tags.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(tags)
	var status := UiTag.new()
	status.name = "StatusTag"
	status.text = entry.status_label()
	status.variant = entry.status_variant()
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tags.add_child(status)
	if entry.readable():
		var kind := UiTag.new()
		kind.name = "KindTag"
		kind.text = entry.kind_label()
		kind.variant = entry.kind_variant()
		kind.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tags.add_child(kind)

	var time := Label.new()
	time.name = "Time"
	time.text = entry.saved_text()
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time.add_theme_color_override("font_color", UiPalette.INK_3)
	time.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(time)


func _make_style(bg: Color, line: Color, outlined: bool) -> StyleBoxFlat:
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
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
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
