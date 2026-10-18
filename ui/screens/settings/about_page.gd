## 设置 · 关于：版本号、字体许可证、卡表来源、设置文件位置。
class_name UiSettingsAboutPage
extends Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := UiFrame.new()
	panel.name = "AboutPanel"
	panel.frame_texture = UiAssets.frame_l("ink")
	panel.frame_border = 4
	panel.background_color = UiPalette.CARD
	panel.content_padding = Vector4i(24, 18, 24, 20)
	panel.shadow_enabled = true
	panel.shadow_offset = Vector2i(0, 4)
	panel.top_highlight = true
	panel.custom_minimum_size.x = 620
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.content.add_child(column)

	var title := Label.new()
	title.name = "AboutTitle"
	title.theme_type_variation = &"UiTitle"
	title.text = "璀璨宝石 %s" % UiMainMenu.VERSION_TEXT
	column.add_child(title)

	_add_line(column, "版本", UiMainMenu.VERSION_TEXT)
	_add_line(column, "字体",
			"Fusion Pixel 12px Proportional 简体中文（OFL-1.1）\n"
			+ "Press Start 2P（OFL-1.1）\n"
			+ "许可证全文见 ui/theme/fonts/OFL_*.txt。")
	_add_line(column, "卡表",
			"卡牌、贵族与规则数值来自基础版实体卡；数值可改，已有卡牌 id 不改。")
	_add_line(column, "设置文件", "user://ui_settings.json")
	_add_line(column, "存档目录", "user://saves/")

	var note := Label.new()
	note.name = "AboutNote"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", UiPalette.INK_3)
	note.text = "大模型 API Key 只保存在本机 user://config.json，不进存档、不发给联网对手。"
	column.add_child(note)


func _add_line(parent: VBoxContainer, title: String, detail: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size.x = 96
	label.add_theme_color_override("font_color", UiPalette.INK_3)
	row.add_child(label)
	var value := Label.new()
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.add_theme_color_override("font_color", UiPalette.INK)
	value.text = detail
	row.add_child(value)


func text() -> String:
	var result: String = ""
	for node: Node in find_children("*", "Label", true, false):
		result += (node as Label).text + "\n"
	return result
