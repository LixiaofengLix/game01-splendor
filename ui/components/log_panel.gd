## 对局日志：标题 + 第 N 轮，最新一条高亮；支持卡牌引用与宝石小图标的内联标记。
## 默认只显示最近几条（条数由牌桌按对手数决定），底部留“全部记录 L”入口。
class_name UiLogPanel
extends UiFrame

var _round_label: Label
var _list: VBoxContainer
var _empty_label: Label


func _ready() -> void:
	frame_texture = UiAssets.frame_l("ink")
	frame_border = 4
	background_color = UiPalette.CARD
	content_padding = Vector4i(10, 8, 10, 8)
	shadow_enabled = true
	shadow_offset = Vector2i(0, 4)
	top_highlight = true
	super._ready()
	custom_minimum_size.y = 130

	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 6)
	content.add_child(column)

	var title_row := HBoxContainer.new()
	title_row.name = "TitleRow"
	title_row.add_theme_constant_override("separation", 6)
	column.add_child(title_row)
	title_row.add_child(_make_bullet())
	var title := Label.new()
	title.text = "对局日志"
	title.add_theme_color_override("font_color", UiPalette.INK_2)
	title_row.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(spacer)
	_round_label = Label.new()
	_round_label.name = "Round"
	_round_label.add_theme_color_override("font_color", UiPalette.INK_3)
	title_row.add_child(_round_label)

	_list = VBoxContainer.new()
	_list.name = "Entries"
	_list.add_theme_constant_override("separation", 2)
	column.add_child(_list)

	_empty_label = Label.new()
	_empty_label.name = "Empty"
	_empty_label.text = "还没有记录"
	_empty_label.add_theme_color_override("font_color", UiPalette.INK_3)
	_empty_label.visible = false
	column.add_child(_empty_label)

	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(filler)

	var footer := HBoxContainer.new()
	footer.name = "Footer"
	footer.add_theme_constant_override("separation", 6)
	column.add_child(footer)
	var more := Label.new()
	more.text = "全部记录"
	more.add_theme_color_override("font_color", UiPalette.INK_2)
	footer.add_child(more)
	var kbd := UiKbd.new()
	kbd.text = "L"
	footer.add_child(kbd)


## entries 从新到旧：[{seat, text, time}]；text 支持 {card:id} / {gem:color} 标记。
func render(entries: Array, round_number: int, limit: int = 7,
		catalog: CardCatalog = null) -> void:
	_round_label.text = "第 %d 轮" % round_number
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var shown: int = mini(limit, entries.size())
	for index: int in shown:
		_list.add_child(_make_entry(entries[index], index == 0, catalog))
	_empty_label.visible = entries.is_empty()


func log_count() -> int:
	return _list.get_child_count()


func _make_entry(entry: Variant, latest: bool, catalog: CardCatalog) -> Control:
	var data: Dictionary = entry if entry is Dictionary else {}
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = UiPalette.LOG_NEW if latest else Color(0, 0, 0, 0)
	style.content_margin_left = 4
	style.content_margin_top = 2
	style.content_margin_right = 4
	style.content_margin_bottom = 2
	style.anti_aliasing = false
	panel.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)

	var seat: int = int(data.get("seat", -1))
	if seat >= 0:
		row.add_child(UiAssets.mascot_icon(seat, 16))
	else:
		var gap := Control.new()
		gap.custom_minimum_size.x = 16
		row.add_child(gap)

	var text := RichTextLabel.new()
	text.name = "Text"
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_font_override("normal_font", get_theme_default_font())
	text.add_theme_font_size_override("normal_font_size", get_theme_default_font_size())
	text.add_theme_color_override("default_color", UiPalette.INK)
	text.text = UiMarkup.to_bbcode(String(data.get("text", "")), catalog)
	row.add_child(text)

	var time := Label.new()
	time.name = "Time"
	time.text = String(data.get("time", ""))
	time.add_theme_color_override("font_color", UiPalette.INK_3)
	time.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(time)
	return panel


func _make_bullet() -> Control:
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(12, 12)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bullet := ColorRect.new()
	bullet.custom_minimum_size = Vector2(7, 7)
	bullet.size = Vector2(7, 7)
	bullet.pivot_offset = Vector2(3.5, 3.5)
	bullet.color = Color("#c79a5b")
	bullet.rotation = PI / 4
	bullet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(bullet)
	return holder
