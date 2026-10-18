## 牌桌 toast：EVENT_BG + hot 小框，头像 + 一句话 + 说明；默认 2.5 秒后消失。
## 只用于“我刚做的事成功了”，不用于别人出手或持续状态。
class_name UiToast
extends UiFrame

signal closed

var auto_hide: bool = true
var _avatar: TextureRect
var _message: Label
var _detail: Label
var _timer: Timer


func _ready() -> void:
	frame_texture = UiAssets.frame_s("hot")
	frame_border = 2
	background_color = UiPalette.EVENT_BG
	content_padding = Vector4i(10, 8, 14, 8)
	shadow_enabled = true
	shadow_offset = Vector2i(0, 3)
	super._ready()
	custom_minimum_size.x = 320

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	content.add_child(row)

	_avatar = UiAssets.mascot_icon(0, 22)
	row.add_child(_avatar)

	var labels := VBoxContainer.new()
	labels.add_theme_constant_override("separation", 2)
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(labels)

	_message = Label.new()
	_message.name = "Message"
	labels.add_child(_message)

	_detail = Label.new()
	_detail.name = "Detail"
	_detail.add_theme_color_override("font_color", UiPalette.INK_2)
	labels.add_child(_detail)

	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = 2.5
	_timer.timeout.connect(_on_timeout)
	add_child(_timer)


func show_message(seat: int, message: String, detail: String = "", duration: float = 2.5) -> void:
	_avatar.texture = UiAssets.mascot(seat)
	_message.text = message
	_detail.text = detail
	_detail.visible = not detail.is_empty()
	visible = true
	if auto_hide:
		_timer.wait_time = duration
		_timer.start()


func _on_timeout() -> void:
	visible = false
	closed.emit()
