## 同屏换人遮挡（09）：整屏实色盖住，确认后才显示下一位玩家的私密信息。
## 出现条件由 UiTableFlow 判断；这里只负责画面和“我是某某，开始我的回合”按钮。
class_name UiHotseatCover
extends Control

signal start_pressed

var next_seat: int = 0
var next_name: String = ""
var previous_seat: int = -1
var previous_name: String = ""
var summary: String = ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var background := UiAssets.tiled(UiAssets.texture("tile_paper.png"))
	background.name = "Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)

	var avatars := HBoxContainer.new()
	avatars.name = "Avatars"
	avatars.alignment = BoxContainer.ALIGNMENT_CENTER
	avatars.add_theme_constant_override("separation", 18)
	column.add_child(avatars)
	if previous_seat >= 0:
		var previous := UiAssets.mascot_icon(previous_seat, 32)
		previous.name = "PreviousMascot"
		previous.modulate = Color(1, 1, 1, 0.35)
		avatars.add_child(previous)
	var next := UiAssets.mascot_icon(next_seat, 76)
	next.name = "NextMascot"
	avatars.add_child(next)

	var tag := UiTag.new()
	tag.name = "CoverTag"
	tag.text = "同屏 · 换人"
	tag.variant = &"dark"
	tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(tag)

	var title := Label.new()
	title.name = "CoverTitle"
	title.theme_type_variation = &"UiHero"
	title.text = "轮到 %s" % next_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var description := Label.new()
	description.name = "CoverDescription"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.x = 620
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.add_theme_color_override("font_color", UiPalette.INK_2)
	description.text = "其他人请先别看屏幕。点下面的按钮后才会显示你的宝石和预留牌（包括盲抽的那张）。"
	column.add_child(description)

	var summary_frame := UiFrame.new()
	summary_frame.name = "CoverSummary"
	summary_frame.frame_texture = UiAssets.frame_s("hot")
	summary_frame.frame_border = 2
	summary_frame.background_color = UiPalette.EVENT_BG
	summary_frame.content_padding = Vector4i(12, 8, 14, 8)
	summary_frame.shadow_enabled = true
	summary_frame.shadow_offset = Vector2i(0, 3)
	summary_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(summary_frame)
	var summary_row := HBoxContainer.new()
	summary_row.add_theme_constant_override("separation", 8)
	summary_frame.content.add_child(summary_row)
	if previous_seat >= 0:
		summary_row.add_child(UiAssets.mascot_icon(previous_seat, 22))
	var summary_label := Label.new()
	summary_label.name = "SummaryText"
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.custom_minimum_size.x = 520
	summary_label.text = summary
	summary_row.add_child(summary_label)

	var start := UiButton.new()
	start.name = "CoverStart"
	start.variant = &"accent"
	start.size_key = &"lg"
	start.text = "我是%s，开始我的回合" % next_name
	start.focus_mode = Control.FOCUS_ALL
	start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start.pressed.connect(func() -> void: start_pressed.emit())
	column.add_child(start)

	var hint := Label.new()
	hint.name = "CoverHint"
	hint.text = "只在有 2 个以上人类座位时出现；可在开局设置里关掉。"
	hint.add_theme_color_override("font_color", UiPalette.INK_3)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("spl_confirm"):
		get_viewport().set_input_as_handled()
		start_pressed.emit()
