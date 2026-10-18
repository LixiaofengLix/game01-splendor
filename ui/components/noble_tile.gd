## 贵族牌：金框羊皮纸，左上分数徽章、右上“贵族”、下方折扣要求块。
## 市场里宽 100、高度由贵族列平分；选贵族弹窗里用 200×170 的大号。
class_name UiNobleTile
extends UiFrame

const MARKET_MIN_SIZE := Vector2(100, 86)
const BIG_SIZE := Vector2(200, 170)

var catalog: CardCatalog = null:
	set(value):
		catalog = value
		_refresh()

var noble_id: String = "":
	set(value):
		noble_id = value
		_refresh()

var big: bool = false:
	set(value):
		big = value
		_apply_size()

var selected: bool = false:
	set(value):
		selected = value
		_apply_selected()

var taken: bool = false:
	set(value):
		taken = value
		modulate = Color(1, 1, 1, 0.4) if taken else Color.WHITE

var _badge: UiFrame
var _badge_label: Label
var _requirements: HFlowContainer
var _line_outer: Panel
var _line_inner: Panel


func _ready() -> void:
	frame_texture = UiAssets.frame_s("gold")
	frame_border = 2
	background_color = UiPalette.NOBLE_BG
	content_padding = Vector4i(8, 8, 8, 8)
	shadow_enabled = true
	shadow_texture = UiAssets.frame_s("ink_fill")
	shadow_offset = Vector2i(0, 3)
	super._ready()

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	content.add_child(column)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	column.add_child(top)

	_badge = UiFrame.new()
	_badge.name = "Badge"
	_badge.frame_texture = UiAssets.frame_s("gold")
	_badge.frame_border = 2
	_badge.background_color = UiPalette.GOLD
	_badge.content_padding = Vector4i.ZERO
	_badge.top_highlight = true
	_badge.highlight_color = UiPalette.GOLD_LIGHT
	_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_badge)
	_badge_label = Label.new()
	_badge_label.name = "Points"
	_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge_label.add_theme_color_override("font_color", UiPalette.INK)
	_badge.content.add_child(_badge_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var noble_label := Label.new()
	noble_label.text = "贵族"
	noble_label.add_theme_color_override("font_color", UiPalette.INK_3)
	top.add_child(noble_label)

	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(gap)

	_requirements = HFlowContainer.new()
	_requirements.name = "Requirements"
	_requirements.alignment = FlowContainer.ALIGNMENT_CENTER
	_requirements.add_theme_constant_override("h_separation", 4)
	_requirements.add_theme_constant_override("v_separation", 4)
	column.add_child(_requirements)

	_line_outer = _make_line(UiPalette.NOBLE_INNER)
	add_decoration(_line_outer)
	_line_inner = _make_line(UiPalette.NOBLE_INNER_2)
	add_decoration(_line_inner)

	resized.connect(_layout_decor)
	_apply_size()
	_apply_selected()


func _make_line(color: Color) -> Panel:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.anti_aliasing = false
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func _apply_size() -> void:
	if _requirements == null:
		return
	var tile_size := BIG_SIZE if big else MARKET_MIN_SIZE
	custom_minimum_size = tile_size
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN if big else Control.SIZE_EXPAND_FILL
	var badge_size := Vector2(36, 36) if big else Vector2(26, 26)
	_badge.custom_minimum_size = badge_size
	_badge.size = badge_size
	_badge_label.text = _noble_points_text()
	var req_key: StringName = &"big" if big else &"noble"
	for child in _requirements.get_children():
		_requirements.remove_child(child)
		child.queue_free()
	if catalog != null and not noble_id.is_empty():
		var noble := catalog.noble(noble_id)
		if noble != null:
			for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
				var amount := noble.requirement_of(color)
				if amount <= 0:
					continue
				var tile := UiBonusTile.new()
				tile.gem_color = color
				tile.count = amount
				tile.size_key = req_key
				_requirements.add_child(tile)
	_layout_decor()
	update_minimum_size()


func _noble_points_text() -> String:
	if catalog != null and not noble_id.is_empty():
		var noble := catalog.noble(noble_id)
		if noble != null:
			return str(noble.points)
	return ""


func _apply_selected() -> void:
	if _label_ready():
		frame_texture = UiAssets.frame_s("ink" if selected else "gold")
		background_color = Color("#ffe9cf") if selected else UiPalette.NOBLE_BG
	queue_redraw()


func _label_ready() -> bool:
	return _badge != null


func _refresh() -> void:
	if _requirements == null:
		return
	_badge_label.text = _noble_points_text()
	_apply_size()


func _layout_decor() -> void:
	if _line_outer == null:
		return
	_line_outer.position = Vector2(2, 2)
	_line_outer.size = size - Vector2(4, 4)
	_line_inner.position = Vector2(4, 4)
	_line_inner.size = size - Vector2(8, 8)


func _draw() -> void:
	if selected:
		draw_rect(Rect2(Vector2(-2, -2), size + Vector2(4, 4)), UiPalette.ORANGE, false, 3)
