## 发展卡：市场 128×150 / 迷你 92×120；显示普通、可买、差 N、选中、光晕、
## 对手能买头像、空位、牌背、我的盲抽标签。只吃显示数据（card_id + CardCatalog + 状态标记）。
class_name UiDevCard
extends Control

const MARKET_SIZE := Vector2(128, 150)
const MINI_SIZE := Vector2(92, 120)
const MARKET_BAND := 42
const MINI_BAND := 30
const BORDER := 2
const ROMAN: Dictionary[int, String] = {1: "I", 2: "II", 3: "III"}
const SHADOW_COLOR := Color(0.0784314, 0.0470588, 0.0313726, 0.45)

var catalog: CardCatalog = null:
	set(value):
		catalog = value
		_refresh()

var card_id: String = "":
	set(value):
		card_id = value
		_refresh()

var mini: bool = false:
	set(value):
		mini = value
		_layout_for_mode()

var affordable: bool = false:
	set(value):
		affordable = value
		_refresh()

var shortfall: int = 0:
	set(value):
		shortfall = value
		_refresh()

## 缺口明细：[{color: Enums.GemColor, amount: int}]，由 U2 的 ViewMath 算好传进来。
var missing: Array[Dictionary] = []:
	set(value):
		missing = value.duplicate(true)
		_refresh()

var gold_can_pay: int = 0:
	set(value):
		gold_can_pay = value
		_refresh()

var selected: bool = false:
	set(value):
		selected = value
		_apply_selected()

var flash: bool = false:
	set(value):
		flash = value
		_apply_flash()

var threat_seats: Array[int] = []:
	set(value):
		threat_seats = value.duplicate()
		_refresh()

var empty: bool = false:
	set(value):
		empty = value
		_refresh()

var card_back: bool = false:
	set(value):
		card_back = value
		_refresh()

var back_level: int = 1:
	set(value):
		back_level = value
		_refresh()

var blind_label: bool = false:
	set(value):
		blind_label = value
		_refresh()

var show_id: bool = false:
	set(value):
		show_id = value
		_refresh()

## 陈列场景用：鼠标不悬停也显示缺口条。
var force_need: bool = false:
	set(value):
		force_need = value
		_refresh()

var _content: Control
var _shadow: NinePatchRect
var _back_tex: TextureRect
var _frame: NinePatchRect
var _band: ColorRect
var _band_light: ColorRect
var _band_dark: ColorRect
var _body: ColorRect
var _body_light: ColorRect
var _points: Label
var _gem_icon: TextureRect
var _costs: VBoxContainer
var _threat: UiFrame
var _threat_row: HBoxContainer
var _blind_tag: UiTag
var _id_label: Label
var _status: PanelContainer
var _status_label: Label
var _need_bar: PanelContainer
var _need_row: HBoxContainer
var _empty_label: Label
var _back_box: VBoxContainer
var _back_lv: Label
var _back_marks: Label
var _back_text: Label
var _ok_style: StyleBoxFlat
var _short_style: StyleBoxFlat

var _hover := false
var _bob := 0
var _flash_on := false
var _bob_timer: Timer
var _flash_timer: Timer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_content = Control.new()
	_content.name = "Content"
	add_child(_content)

	_shadow = UiAssets.nine_patch(UiAssets.frame_s("ink_fill"), BORDER)
	_shadow.modulate = SHADOW_COLOR
	_content.add_child(_shadow)

	_back_tex = UiAssets.tiled(UiAssets.texture("tile_card_back.png"))
	_content.add_child(_back_tex)

	_frame = UiAssets.nine_patch(UiAssets.frame_s("ink_fill"), BORDER)
	_frame.name = "Frame"
	_content.add_child(_frame)

	_band = ColorRect.new()
	_band.name = "Band"
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_band)

	_band_light = ColorRect.new()
	_band_light.color = Color(1, 1, 1, 0.35)
	_band_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_band_light)

	_band_dark = ColorRect.new()
	_band_dark.color = Color(0.165, 0.110, 0.071, 0.45)
	_band_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_band_dark)

	_body = ColorRect.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_body)

	_body_light = ColorRect.new()
	_body_light.color = Color(1, 1, 1, 0.4)
	_body_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_body_light)

	_points = Label.new()
	_points.name = "Points"
	_points.theme_type_variation = &"UiNum"
	_points.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_points.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_points)

	_gem_icon = TextureRect.new()
	_gem_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_gem_icon.stretch_mode = TextureRect.STRETCH_SCALE
	_gem_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_gem_icon)

	_costs = VBoxContainer.new()
	_costs.name = "Costs"
	_costs.add_theme_constant_override("separation", 3)
	_costs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_costs)

	_threat = UiFrame.new()
	_threat.name = "Threat"
	_threat.frame_texture = UiAssets.frame_s("ink")
	_threat.frame_border = 2
	_threat.background_color = UiPalette.SURFACE
	_threat.content_padding = Vector4i(2, 2, 2, 2)
	_threat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_threat)
	_threat_row = HBoxContainer.new()
	_threat_row.add_theme_constant_override("separation", 2)
	_threat_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_threat.content.add_child(_threat_row)

	_blind_tag = UiTag.new()
	_blind_tag.name = "BlindTag"
	_blind_tag.text = "盲抽"
	_blind_tag.variant = &"dark"
	_blind_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_blind_tag)


	_id_label = Label.new()
	_id_label.name = "IdLabel"
	_id_label.add_theme_color_override("font_color", UiPalette.INK_3)
	_id_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_id_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_id_label)

	_ok_style = _make_status_style(UiPalette.OK, UiPalette.INK, 2, UiPalette.WHITE)
	_short_style = _make_status_style(Color(1, 1, 1, 0.7), UiPalette.LINE, 1, UiPalette.INK_2)
	_status = PanelContainer.new()
	_status.name = "Status"
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.add_child(_status_label)
	_content.add_child(_status)

	_need_bar = PanelContainer.new()
	_need_bar.name = "NeedBar"
	_need_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var need_style := StyleBoxFlat.new()
	need_style.bg_color = Color(0.129, 0.122, 0.102, 0.93)
	need_style.content_margin_left = 7
	need_style.content_margin_top = 5
	need_style.content_margin_right = 7
	need_style.content_margin_bottom = 5
	need_style.anti_aliasing = false
	_need_bar.add_theme_stylebox_override("panel", need_style)
	_need_row = HBoxContainer.new()
	_need_row.add_theme_constant_override("separation", 4)
	_need_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_need_bar.add_child(_need_row)
	_content.add_child(_need_bar)

	_empty_label = Label.new()
	_empty_label.name = "EmptyLabel"
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.add_theme_color_override("font_color", UiPalette.LINE)
	_empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_empty_label)

	_back_box = VBoxContainer.new()
	_back_box.name = "BackBox"
	_back_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_back_box.add_theme_constant_override("separation", 4)
	_back_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_back_box)
	_back_lv = Label.new()
	_back_lv.name = "BackLevel"
	_back_lv.theme_type_variation = &"UiNum"
	_back_lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_back_lv.add_theme_color_override("font_color", UiPalette.GOLD)
	_back_lv.add_theme_color_override("font_shadow_color", UiPalette.BLACK_SHADOW)
	_back_lv.add_theme_constant_override("shadow_offset_x", 2)
	_back_lv.add_theme_constant_override("shadow_offset_y", 2)
	_back_box.add_child(_back_lv)
	_back_marks = Label.new()
	_back_marks.name = "BackMarks"
	_back_marks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_back_marks.add_theme_color_override("font_color", UiPalette.GOLD)
	_back_box.add_child(_back_marks)
	_back_text = Label.new()
	_back_text.name = "BackText"
	_back_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_back_text.add_theme_color_override("font_color", Color("#b9b0a0"))
	_back_box.add_child(_back_text)

	_bob_timer = Timer.new()
	_bob_timer.wait_time = 0.3
	_bob_timer.timeout.connect(_on_bob)
	add_child(_bob_timer)
	_flash_timer = Timer.new()
	_flash_timer.wait_time = 0.25
	_flash_timer.timeout.connect(_on_flash)
	add_child(_flash_timer)

	mouse_entered.connect(_on_hover_changed.bind(true))
	mouse_exited.connect(_on_hover_changed.bind(false))
	resized.connect(_layout_all)

	_layout_for_mode()
	_refresh()
	_apply_selected()
	_apply_flash()


func _make_status_style(bg: Color, border: Color, border_width: int, text_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	style.anti_aliasing = false
	return style


func _layout_for_mode() -> void:
	if _content == null:
		return
	var card_size := MINI_SIZE if mini else MARKET_SIZE
	custom_minimum_size = card_size
	_content.size = card_size
	_content.position = Vector2(0, -4 if selected else 0)
	_layout_all()
	_refresh()


func _layout_all() -> void:
	if _content == null:
		return
	var card_size := MINI_SIZE if mini else MARKET_SIZE
	var band_height := MINI_BAND if mini else MARKET_BAND
	var width := card_size.x
	var height := card_size.y
	var body_y := BORDER + band_height
	var body_height := height - BORDER - body_y

	_content.size = card_size
	_shadow.position = Vector2(0, 3)
	_shadow.size = card_size
	_back_tex.position = Vector2(BORDER, BORDER)
	_back_tex.size = Vector2(width - BORDER * 2, height - BORDER * 2)
	_frame.position = Vector2.ZERO
	_frame.size = card_size
	_band.position = Vector2(BORDER, BORDER)
	_band.size = Vector2(width - BORDER * 2, band_height)
	_band_light.position = Vector2(BORDER, BORDER)
	_band_light.size = Vector2(width - BORDER * 2, 2)
	_band_dark.position = Vector2(BORDER, BORDER + band_height - 2)
	_band_dark.size = Vector2(width - BORDER * 2, 2)
	_body.position = Vector2(BORDER, body_y)
	_body.size = Vector2(width - BORDER * 2, body_height)
	_body_light.position = Vector2(BORDER, body_y)
	_body_light.size = Vector2(width - BORDER * 2, 2)

	var gem_size := 12 if mini else 24
	_points.position = Vector2(6, BORDER)
	_points.size = Vector2(width - 12, band_height)
	_gem_icon.position = Vector2(width - BORDER - 6 - gem_size, BORDER + floorf((band_height - gem_size) * 0.5))
	_gem_icon.size = Vector2(gem_size, gem_size)

	_empty_label.position = Vector2.ZERO
	_empty_label.size = card_size

	_back_box.position = Vector2.ZERO
	_back_box.size = card_size
	_back_box.reset_size()
	_back_box.position = Vector2(
			floorf((width - _back_box.size.x) * 0.5),
			floorf((height - _back_box.size.y) * 0.5))

	_place_content()
	queue_redraw()


func _place_content() -> void:
	var card_size := MINI_SIZE if mini else MARKET_SIZE
	var band_height := MINI_BAND if mini else MARKET_BAND
	var width := card_size.x
	var height := card_size.y
	var body_y := BORDER + band_height

	_costs.reset_size()
	var costs_y := body_y + (6 if not mini else 4)
	if _blind_tag.visible:
		_blind_tag.reset_size()
		_blind_tag.position = Vector2(7, body_y + 4)
		_blind_tag.size = _blind_tag.get_combined_minimum_size()
		costs_y = _blind_tag.position.y + _blind_tag.size.y + 4
	_costs.position = Vector2(7, costs_y)

	_threat.reset_size()
	_threat.size = _threat.get_combined_minimum_size()
	_threat.position = Vector2(width - BORDER - 7 - _threat.size.x, body_y + 6)

	var status_visible := _status.visible
	if status_visible:
		_status.reset_size()
		_status.size = _status.get_combined_minimum_size()
		var status_y := height - BORDER - 7 - _status.size.y
		if _id_label.visible:
			status_y -= 14
		_status.position = Vector2(width - BORDER - 7 - _status.size.x, status_y)

	_id_label.size = Vector2(width - 14, 12)
	var id_y := height - BORDER - 14
	if status_visible:
		id_y = _status.position.y - 14
	_id_label.position = Vector2(7, id_y)

	var need_height := 34 if mini else 40
	_need_bar.position = Vector2(BORDER, height - BORDER - need_height)
	_need_bar.size = Vector2(width - BORDER * 2, need_height)


func _refresh() -> void:
	if _content == null:
		return
	var card: CardData = null
	if catalog != null and not card_id.is_empty():
		card = catalog.card(card_id)
	var is_empty := empty or (not card_back and card == null)
	var band_height := MINI_BAND if mini else MARKET_BAND

	# 牌背模式
	_back_tex.visible = card_back
	_back_box.visible = card_back
	_frame.texture = UiAssets.frame_s("dark") if card_back else UiAssets.frame_s("ok_fill" if affordable else "ink_fill")
	_frame.patch_margin_left = BORDER
	_frame.patch_margin_top = BORDER
	_frame.patch_margin_right = BORDER
	_frame.patch_margin_bottom = BORDER
	_shadow.visible = not is_empty
	if card_back:
		_frame.visible = true
		_back_lv.text = ROMAN.get(back_level, "I")
		_back_marks.text = "◆".repeat(back_level)
		_back_text.text = "盲抽"
		_hide_normal()
		_layout_all()
		return

	# 空位模式：透明底 + 虚线框，中间写“空位”。
	_empty_label.visible = is_empty
	_empty_label.text = "空" if mini else "空位"
	if is_empty:
		_frame.visible = false
		_hide_normal()
		_layout_all()
		queue_redraw()
		return

	_frame.visible = true
	_show_normal()
	_band.color = UiPalette.GEM_BASE[card.bonus]
	_body.color = UiPalette.GEM_TINT[card.bonus]
	_band.visible = true
	_band_light.visible = true
	_band_dark.visible = true
	_body.visible = true
	_body_light.visible = true
	_band.size.y = band_height

	_points.text = str(card.points) if card.points > 0 else ""
	_points.add_theme_color_override("font_color", UiPalette.GEM_TEXT[card.bonus])
	var has_shadow := card.bonus != Enums.GemColor.WHITE
	_points.add_theme_color_override(
			"font_shadow_color",
			Color(0, 0, 0, 0.3) if has_shadow else Color(0, 0, 0, 0))
	_points.add_theme_constant_override("shadow_offset_x", 2 if has_shadow else 0)
	_points.add_theme_constant_override("shadow_offset_y", 2 if has_shadow else 0)

	var gem_size := 12 if mini else 24
	_gem_icon.texture = UiAssets.gem(card.bonus)
	_gem_icon.custom_minimum_size = Vector2(gem_size, gem_size)
	_gem_icon.size = Vector2(gem_size, gem_size)

	_clear(_costs)
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		var amount := card.cost_of(color)
		if amount <= 0:
			continue
		var pill := UiCostPill.new()
		pill.gem_color = color
		pill.amount = amount
		pill.mini = mini
		_costs.add_child(pill)

	_clear(_threat_row)
	for seat: int in threat_seats:
		_threat_row.add_child(UiAssets.mascot_icon(seat, 16))
	_threat.visible = not mini and not threat_seats.is_empty()

	_blind_tag.visible = blind_label
	_status.visible = affordable or shortfall > 0
	if affordable:
		_status.add_theme_stylebox_override("panel", _ok_style)
		_status_label.text = "可买"
		_status_label.add_theme_color_override("font_color", UiPalette.WHITE)
	elif shortfall > 0:
		_status.add_theme_stylebox_override("panel", _short_style)
		_status_label.text = "差 %d" % shortfall
		_status_label.add_theme_color_override("font_color", UiPalette.INK_2)

	_id_label.visible = show_id
	_id_label.text = card.id if show_id else ""

	_need_bar.visible = shortfall > 0 and (_hover or force_need)
	if _need_bar.visible:
		_rebuild_need_row()

	_layout_all()


func _hide_normal() -> void:
	_band.visible = false
	_band_light.visible = false
	_band_dark.visible = false
	_body.visible = false
	_body_light.visible = false
	_points.visible = false
	_gem_icon.visible = false
	_costs.visible = false
	_threat.visible = false
	_blind_tag.visible = false
	_status.visible = false
	_need_bar.visible = false
	_id_label.visible = false
	_back_tex.visible = card_back
	_back_box.visible = card_back
	_empty_label.visible = not card_back


func _show_normal() -> void:
	_points.visible = true
	_gem_icon.visible = true
	_costs.visible = true
	_empty_label.visible = false
	_back_tex.visible = false
	_back_box.visible = false


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _rebuild_need_row() -> void:
	_clear(_need_row)
	var prefix := Label.new()
	prefix.text = "还差"
	prefix.add_theme_color_override("font_color", UiPalette.WHITE)
	_need_row.add_child(prefix)
	for entry: Dictionary in missing:
		var pill := UiCostPill.new()
		pill.gem_color = int(entry.get("color", Enums.GemColor.WHITE))
		pill.amount = int(entry.get("amount", 0))
		pill.mini = true
		_need_row.add_child(pill)
	if gold_can_pay > 0:
		var gold_label := Label.new()
		gold_label.text = "金币可抵 %d" % gold_can_pay
		gold_label.add_theme_color_override("font_color", Color("#d9d2c4"))
		_need_row.add_child(gold_label)


func _on_hover_changed(hovered: bool) -> void:
	_hover = hovered
	if _need_bar == null:
		return
	_need_bar.visible = shortfall > 0 and (_hover or force_need)
	if _need_bar.visible and _need_row.get_child_count() == 0:
		_rebuild_need_row()


func _apply_selected() -> void:
	if _content == null:
		return
	_content.position = Vector2(0, -4 if selected else 0)
	if selected:
		if _bob_timer.is_stopped():
			_bob_timer.start()
	else:
		_bob = 0
		_bob_timer.stop()
	queue_redraw()


func _apply_flash() -> void:
	if _flash_timer == null:
		return
	if flash:
		_flash_timer.start()
	else:
		_flash_timer.stop()
		_flash_on = true
	queue_redraw()


func _on_bob() -> void:
	_bob = 4 if _bob == 0 else 0
	queue_redraw()


func _on_flash() -> void:
	_flash_on = not _flash_on
	queue_redraw()


func _draw() -> void:
	var card_size := MINI_SIZE if mini else MARKET_SIZE
	var content_origin := _content.position if _content != null else Vector2.ZERO
	if selected:
		draw_rect(
				Rect2(content_origin - Vector2(2, 2), card_size + Vector2(4, 4)),
				UiPalette.ORANGE, false, 3)
		var tri_y := content_origin.y - 24 + _bob
		var center_x := card_size.x * 0.5
		var outer: PackedVector2Array = PackedVector2Array([
			Vector2(center_x - 6, tri_y),
			Vector2(center_x + 6, tri_y),
			Vector2(center_x, tri_y + 7),
		])
		var inner: PackedVector2Array = PackedVector2Array([
			Vector2(center_x - 4, tri_y + 2),
			Vector2(center_x + 4, tri_y + 2),
			Vector2(center_x, tri_y + 6),
		])
		draw_colored_polygon(outer, UiPalette.INK)
		draw_colored_polygon(inner, UiPalette.ORANGE)
	if flash:
		var color := UiPalette.GOLD_TEXT if _flash_on else UiPalette.ORANGE
		draw_rect(
				Rect2(content_origin - Vector2(3, 3), card_size + Vector2(6, 6)),
				color, false, 3)
	if _empty_label != null and _empty_label.visible:
		var rect := Rect2(content_origin + Vector2(1, 1), card_size - Vector2(2, 2))
		var dash_color := Color(0.953, 0.902, 0.784, 0.35)
		draw_dashed_line(rect.position, Vector2(rect.end.x, rect.position.y), dash_color, 2.0, 4.0)
		draw_dashed_line(Vector2(rect.end.x, rect.position.y), rect.end, dash_color, 2.0, 4.0)
		draw_dashed_line(rect.end, Vector2(rect.position.x, rect.end.y), dash_color, 2.0, 4.0)
		draw_dashed_line(Vector2(rect.position.x, rect.end.y), rect.position, dash_color, 2.0, 4.0)
