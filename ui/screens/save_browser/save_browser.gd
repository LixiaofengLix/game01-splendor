## 读档（03）：左侧存档列表，右侧详情 + 继续 / 删除。
## 读不了的存档也留在列表里并写明原因（22 的入口）；“从头看回放”在 U6 打开。
class_name UiSaveBrowser
extends Control

signal back_requested
signal continue_requested(entry: UiSaveEntry)
signal replay_requested(entry: UiSaveEntry)

var _store: UiSaveStore = null
var _back_label: String = "‹ 主菜单"
var _entries: Array[UiSaveEntry] = []
var _selected: UiSaveEntry = null
var _rows: Array[UiSaveRow] = []
var _rows_box: VBoxContainer
var _empty_label: Label
var _details_box: VBoxContainer
var _back_button: UiButton
var _title_count: UiTag
var _modal_layer: Control
var _confirm: UiConfirmModal = null
var _pending_delete: UiSaveEntry = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_topbar()
	_build_body()
	_build_modal_layer()
	if _store != null:
		refresh()


func configure(store: UiSaveStore, back_label: String = "‹ 主菜单") -> void:
	_store = store
	_back_label = back_label
	if is_node_ready():
		_back_button.text = back_label
		refresh()


func refresh() -> void:
	if _store == null or _rows_box == null:
		return
	var previous_path: String = _selected.path if _selected != null else ""
	for child in _rows_box.get_children():
		_rows_box.remove_child(child)
		child.queue_free()
	_rows.clear()
	_entries = _store.list()
	var selected_restored: UiSaveEntry = null
	for entry: UiSaveEntry in _entries:
		var row := UiSaveRow.new()
		row.name = "SaveRow"
		_rows_box.add_child(row)
		row.set_entry(entry)
		row.pressed.connect(func() -> void: _select(entry))
		_rows.append(row)
		if entry.path == previous_path:
			selected_restored = entry
	_empty_label.visible = _entries.is_empty()
	if _entries.is_empty():
		_selected = null
		if _title_count != null:
			_title_count.text = "共 0 份"
		_rebuild_details()
		return
	_select(selected_restored if selected_restored != null else _entries[0])


func _build_topbar() -> void:
	var bar := Control.new()
	bar.name = "TopBar"
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 44
	bar.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(bar)

	var background := ColorRect.new()
	background.color = UiPalette.HUD
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(background)
	var border := ColorRect.new()
	border.color = UiPalette.HUD_BORDER
	border.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	border.offset_top = -4
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(border)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14
	row.offset_right = -14
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_child(row)

	_back_button = UiButton.new()
	_back_button.name = "BackButton"
	_back_button.variant = &"hud"
	_back_button.size_key = &"sm"
	_back_button.text = _back_label
	_back_button.focus_mode = Control.FOCUS_NONE
	_back_button.pressed.connect(func() -> void: back_requested.emit())
	row.add_child(_back_button)

	var title := Label.new()
	title.text = "读取存档"
	title.add_theme_color_override("font_color", UiPalette.CREAM)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	_title_count = UiTag.new()
	_title_count.name = "SaveCountTag"
	_title_count.in_hud = true
	row.add_child(_title_count)


func _build_body() -> void:
	var body := MarginContainer.new()
	body.name = "Body"
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_top = 44
	body.add_theme_constant_override("margin_left", 20)
	body.add_theme_constant_override("margin_top", 16)
	body.add_theme_constant_override("margin_right", 20)
	body.add_theme_constant_override("margin_bottom", 18)
	add_child(body)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	body.add_child(columns)

	var list_panel := _make_panel("SaveListPanel")
	list_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(list_panel)
	var list_column := VBoxContainer.new()
	list_column.add_theme_constant_override("separation", 8)
	list_panel.content.add_child(list_column)
	var list_title := Label.new()
	list_title.text = "存档"
	list_title.theme_type_variation = &"UiTitle"
	list_column.add_child(list_title)

	var scroll := ScrollContainer.new()
	scroll.name = "SaveScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_column.add_child(scroll)
	_rows_box = VBoxContainer.new()
	_rows_box.name = "SaveRows"
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_box.add_theme_constant_override("separation", 0)
	scroll.add_child(_rows_box)

	_empty_label = Label.new()
	_empty_label.name = "EmptyLabel"
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_label.add_theme_color_override("font_color", UiPalette.INK_3)
	_empty_label.text = "还没有存档。对局每回合结束会自动存档，暂停菜单里也可以快速保存。"
	_empty_label.visible = false
	list_column.add_child(_empty_label)

	var details_panel := _make_panel("SaveDetailsPanel")
	details_panel.custom_minimum_size.x = 440
	columns.add_child(details_panel)
	var details_scroll := ScrollContainer.new()
	details_scroll.name = "DetailsScroll"
	details_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	details_panel.content.add_child(details_scroll)
	_details_box = VBoxContainer.new()
	_details_box.name = "Details"
	_details_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details_box.add_theme_constant_override("separation", 9)
	details_scroll.add_child(_details_box)


func _make_panel(panel_name: String) -> UiFrame:
	var panel := UiFrame.new()
	panel.name = panel_name
	panel.frame_texture = UiAssets.frame_l("ink")
	panel.frame_border = 4
	panel.background_color = UiPalette.CARD
	panel.content_padding = Vector4i(16, 12, 16, 14)
	panel.shadow_enabled = true
	panel.shadow_offset = Vector2i(0, 4)
	panel.top_highlight = true
	return panel


func _build_modal_layer() -> void:
	_modal_layer = Control.new()
	_modal_layer.name = "SaveModalLayer"
	_modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_layer.z_index = 50
	_modal_layer.visible = false
	_modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_modal_layer)


# ---------------------------------------------------------------- 选择 / 详情

func _select(entry: UiSaveEntry) -> void:
	_selected = entry
	for index: int in _rows.size():
		_rows[index].selected = index < _entries.size() and _entries[index].path == entry.path
	if _title_count != null:
		_title_count.text = "共 %d 份" % _entries.size()
	_rebuild_details()


func _rebuild_details() -> void:
	for child in _details_box.get_children():
		_details_box.remove_child(child)
		child.queue_free()
	if _selected == null:
		var empty := Label.new()
		empty.text = "选择左边的一份存档查看详情。"
		empty.add_theme_color_override("font_color", UiPalette.INK_3)
		_details_box.add_child(empty)
		return
	var entry: UiSaveEntry = _selected

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	_details_box.add_child(header)
	var title := Label.new()
	title.name = "DetailTitle"
	title.theme_type_variation = &"UiTitle"
	title.text = entry.display_name
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(title)
	var status := UiTag.new()
	status.name = "DetailStatus"
	status.text = entry.status_label()
	status.variant = entry.status_variant()
	header.add_child(status)

	var saved := Label.new()
	saved.name = "DetailSavedAt"
	saved.add_theme_color_override("font_color", UiPalette.INK_3)
	saved.text = "保存于 %s · %s" % [entry.saved_datetime_text(), entry.saved_text()]
	_details_box.add_child(saved)

	if entry.is_autosave:
		var auto_note := Label.new()
		auto_note.text = "每回合结束自动覆盖。"
		auto_note.add_theme_color_override("font_color", UiPalette.INK_3)
		_details_box.add_child(auto_note)

	if not entry.readable():
		_rebuild_unreadable(entry)
		return

	_rebuild_players(entry)
	_rebuild_facts(entry)
	_rebuild_buttons(entry)


func _rebuild_unreadable(entry: UiSaveEntry) -> void:
	var reason := UiTag.new()
	reason.name = "DetailReason"
	reason.text = entry.reason_label()
	reason.variant = &"red"
	reason.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_details_box.add_child(reason)

	var text := Label.new()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_color_override("font_color", UiPalette.INK_2)
	match entry.reason:
		UiSaveEntry.REASON_VERSION_TOO_NEW:
			text.text = "这个存档由更新版本的游戏保存，升级后才能读取。"
		UiSaveEntry.REASON_CORRUPT:
			text.text = "文件内容不完整或不是存档。"
		_:
			text.text = "文件是有效的 JSON，但不是认识的存档类型。"
	_details_box.add_child(text)
	if not entry.reason_detail.is_empty():
		var detail := Label.new()
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.add_theme_color_override("font_color", UiPalette.INK_3)
		detail.text = "详细信息：" + entry.reason_detail
		_details_box.add_child(detail)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 8)
	_details_box.add_child(buttons)
	var delete := UiButton.new()
	delete.name = "DeleteButton"
	delete.variant = &"quiet"
	delete.text = "删除"
	delete.focus_mode = Control.FOCUS_NONE
	delete.disabled = entry.read_only
	delete.pressed.connect(request_delete)
	buttons.add_child(delete)


func _rebuild_players(entry: UiSaveEntry) -> void:
	var container := UiFrame.new()
	container.name = "DetailPlayers"
	container.frame_texture = UiAssets.frame_s("ink")
	container.frame_border = 2
	container.background_color = UiPalette.CARD_SOFT
	container.content_padding = Vector4i(10, 8, 10, 8)
	_details_box.add_child(container)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	container.content.add_child(column)

	var names: Array[String] = entry.names()
	var types: Array[String] = entry.seat_types()
	var scores: Array[int] = entry.scores()
	var count: int = maxi(entry.player_count, names.size())
	if count <= 0:
		var unknown := Label.new()
		unknown.text = "人数未知"
		unknown.add_theme_color_override("font_color", UiPalette.INK_3)
		column.add_child(unknown)
		return
	for seat: int in count:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		column.add_child(row)
		row.add_child(UiAssets.mascot_icon(seat, 24))
		var name := Label.new()
		name.text = names[seat] if seat < names.size() and not names[seat].is_empty() \
				else "座位 %d" % (seat + 1)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		var seat_type: String = types[seat] if seat < types.size() else "human"
		var tag := UiTag.new()
		tag.text = UiViewMath.seat_type_label(seat_type)
		tag.variant = UiViewMath.seat_type_tag_variant(seat_type)
		row.add_child(tag)
		var score := Label.new()
		score.text = "%d 分" % scores[seat] if seat < scores.size() else "—"
		score.add_theme_color_override("font_color", UiPalette.INK_2)
		row.add_child(score)


func _rebuild_facts(entry: UiSaveEntry) -> void:
	var facts := VBoxContainer.new()
	facts.name = "DetailFacts"
	facts.add_theme_constant_override("separation", 4)
	_details_box.add_child(facts)
	_add_fact(facts, "种子", str(entry.seed) if entry.kind == "replay" else "—")
	var summary: Dictionary = entry.summary()
	var action_text: String = "快照（没有动作序列）" if entry.kind == "snapshot" else "%d 步" % entry.action_count
	var round_number: int = int(summary.get("round", 0))
	if round_number > 0:
		action_text += " · 第 %d 轮" % round_number
	var current_seat: int = int(summary.get("current_seat", -1))
	var names: Array[String] = entry.names()
	if entry.kind == "replay" and current_seat >= 0:
		var current_name: String = names[current_seat] if current_seat < names.size() \
				else "座位 %d" % (current_seat + 1)
		action_text += " · 轮到%s" % current_name
	_add_fact(facts, "动作", action_text)

	var integrity := Label.new()
	integrity.name = "DetailIntegrity"
	integrity.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	integrity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _store != null:
		var check: Dictionary = _store.validate(entry)
		if bool(check.get("ok", false)):
			integrity.text = "✓ 可以完整重放" if entry.kind == "replay" else "✓ 快照可以载入"
			integrity.add_theme_color_override("font_color", UiPalette.OK)
		else:
			integrity.text = "✗ 校验失败：%s" % String(check.get("detail", ""))
			integrity.add_theme_color_override("font_color", UiPalette.DANGER)
	else:
		integrity.text = "—"
	integrity.tooltip_text = integrity.text
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	facts.add_child(row)
	var key := Label.new()
	key.text = "完整性"
	key.custom_minimum_size.x = 48
	key.add_theme_color_override("font_color", UiPalette.INK_3)
	row.add_child(key)
	row.add_child(integrity)

	if entry.kind == "snapshot":
		var note := Label.new()
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.add_theme_color_override("font_color", UiPalette.INK_3)
		note.text = "快照存档只有「继续」，没有「看回放」——它没有种子和动作序列。"
		_details_box.add_child(note)


func _add_fact(parent: VBoxContainer, key_text: String, value_text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var key := Label.new()
	key.text = key_text
	key.custom_minimum_size.x = 48
	key.add_theme_color_override("font_color", UiPalette.INK_3)
	row.add_child(key)
	var value := Label.new()
	value.text = value_text
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value)


func _rebuild_buttons(entry: UiSaveEntry) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 8)
	_details_box.add_child(row)

	var delete := UiButton.new()
	delete.name = "DeleteButton"
	delete.variant = &"quiet"
	delete.text = "删除"
	delete.focus_mode = Control.FOCUS_NONE
	delete.disabled = entry.read_only
	delete.pressed.connect(request_delete)
	row.add_child(delete)

	var replay := UiButton.new()
	replay.name = "ReplayButton"
	replay.variant = &"ghost"
	replay.text = "从头看回放"
	replay.focus_mode = Control.FOCUS_NONE
	replay.visible = entry.kind == "replay"
	replay.pressed.connect(func() -> void:
		if _selected != null:
			replay_requested.emit(_selected))
	row.add_child(replay)

	var continue_button := UiButton.new()
	continue_button.name = "ContinueButton"
	continue_button.variant = &"accent"
	continue_button.text = "继续这局"
	continue_button.focus_mode = Control.FOCUS_NONE
	continue_button.disabled = not entry.readable()
	continue_button.pressed.connect(func() -> void:
		if _selected != null:
			continue_requested.emit(_selected))
	row.add_child(continue_button)


# ---------------------------------------------------------------- 删除

func request_delete() -> void:
	if _selected == null or _selected.read_only:
		return
	_pending_delete = _selected
	_confirm = UiConfirmModal.new()
	_confirm.name = "DeleteConfirm"
	_confirm.title = "删除存档"
	_confirm.message = "「%s」会被永久删除，不能恢复。" % _selected.display_name
	_confirm.confirm_text = "删除"
	_confirm.danger = true
	_confirm.confirmed.connect(confirm_delete)
	_confirm.cancelled.connect(cancel_delete)
	_modal_layer.add_child(_confirm)
	_modal_layer.visible = true


func confirm_delete() -> void:
	if _pending_delete != null and _store != null:
		_store.delete_entry(_pending_delete)
	_pending_delete = null
	_close_confirm()
	refresh()


func cancel_delete() -> void:
	_pending_delete = null
	_close_confirm()


func _close_confirm() -> void:
	if _confirm != null:
		_confirm.queue_free()
		_confirm = null
	_modal_layer.visible = false


# ---------------------------------------------------------------- 测试用

func entries() -> Array[UiSaveEntry]:
	return _entries.duplicate()


func row_count() -> int:
	return _rows.size()


func select_path(path: String) -> void:
	for entry: UiSaveEntry in _entries:
		if entry.path == path:
			_select(entry)
			return


func selected_entry() -> UiSaveEntry:
	return _selected


func details_integrity_text() -> String:
	var label := find_child("DetailIntegrity", true, false) as Label
	return label.text if label != null else ""


func delete_button() -> UiButton:
	var button := find_child("DeleteButton", true, false) as UiButton
	return button


func continue_button() -> UiButton:
	var button := find_child("ContinueButton", true, false) as UiButton
	return button


func replay_button() -> UiButton:
	var button := find_child("ReplayButton", true, false) as UiButton
	return button


func confirm_modal_visible() -> bool:
	return _confirm != null


func back_button() -> UiButton:
	return _back_button
