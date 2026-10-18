## 顶栏正中的回合胶囊：轮到我（深底金字）、等别人（浅底墨字 + 转圈），
## 以及只有文字的“对局结束 / 回放”状态。
class_name UiTurnPill
extends UiFrame

var _row: HBoxContainer
var _avatar: TextureRect
var _label: Label
var _spinner: UiSpinner
var _extra: Label


func _ready() -> void:
	frame_border = 2
	content_padding = Vector4i(8, 3, 14, 3)
	shadow_enabled = false
	super._ready()
	custom_minimum_size.y = 30

	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 8)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_row)

	_avatar = UiAssets.mascot_icon(0, 22)
	_avatar.name = "Avatar"
	_row.add_child(_avatar)

	_label = Label.new()
	_label.name = "Text"
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(_label)

	_spinner = UiSpinner.new()
	_spinner.name = "Spinner"
	_row.add_child(_spinner)

	_extra = Label.new()
	_extra.name = "Extra"
	_extra.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_extra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(_extra)


func configure_mine(seat: int, player_name: String) -> void:
	frame_texture = UiAssets.frame_s("gold")
	background_color = UiPalette.HUD_BORDER
	_avatar.texture = UiAssets.mascot(seat)
	_avatar.visible = true
	_label.text = "轮到你 · %s" % player_name
	_label.add_theme_color_override("font_color", UiPalette.GOLD_TEXT)
	_spinner.visible = false
	_extra.visible = false
	_update_size()


func configure_waiting(seat: int, player_name: String, type_label: String,
		thinking: bool) -> void:
	frame_texture = UiAssets.frame_s("ink")
	background_color = UiPalette.CREAM
	_avatar.texture = UiAssets.mascot(seat)
	_avatar.visible = true
	_label.text = "%s · %s" % [player_name, type_label]
	_label.add_theme_color_override("font_color", UiPalette.INK)
	_spinner.visible = thinking
	_extra.visible = thinking
	_extra.text = "思考中…"
	_extra.add_theme_color_override("font_color", UiPalette.INK_2)
	_update_size()


## 纯文字状态：对局结束、弃宝石、回放步数等。
func configure_text(text: String, waiting_style: bool = false) -> void:
	frame_texture = UiAssets.frame_s("ink")
	background_color = UiPalette.CREAM if waiting_style else UiPalette.HUD_BORDER
	_avatar.visible = false
	_label.text = text
	_label.add_theme_color_override(
			"font_color", UiPalette.INK if waiting_style else UiPalette.GOLD_TEXT)
	_spinner.visible = false
	_extra.visible = false
	_update_size()


func text() -> String:
	return _label.text


func _update_size() -> void:
	content.reset_size()
	reset_size()
	update_minimum_size()
