## 右栏提示卡：EVENT_BG + hot 小框，持续状态（掉线、电脑代打）用，状态结束才移除。
class_name UiNoticeCard
extends UiFrame

var _avatar: TextureRect
var _title: Label
var _detail: Label


func _ready() -> void:
	frame_texture = UiAssets.frame_s("hot")
	frame_border = 2
	background_color = UiPalette.EVENT_BG
	content_padding = Vector4i(11, 9, 11, 9)
	shadow_enabled = true
	shadow_offset = Vector2i(0, 3)
	super._ready()
	custom_minimum_size.x = 300

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	content.add_child(row)

	_avatar = UiAssets.mascot_icon(0, 22)
	row.add_child(_avatar)

	var labels := VBoxContainer.new()
	labels.add_theme_constant_override("separation", 2)
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(labels)

	_title = Label.new()
	_title.name = "Title"
	labels.add_child(_title)

	_detail = Label.new()
	_detail.name = "Detail"
	_detail.add_theme_color_override("font_color", UiPalette.INK_2)
	labels.add_child(_detail)


func set_content(seat: int, title: String, detail: String = "") -> void:
	_avatar.texture = UiAssets.mascot(seat)
	_title.text = title
	_detail.text = detail
	_detail.visible = not detail.is_empty()
