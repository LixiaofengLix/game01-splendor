## 通用二次确认弹窗：删除存档等。整屏遮罩 + 居中窄框，确认 / 取消各发一个信号。
class_name UiConfirmModal
extends Control

signal confirmed
signal cancelled

var title: String = "确认"
var message: String = ""
var confirm_text: String = "确认"
var danger: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var scrim := ColorRect.new()
	scrim.color = UiPalette.SCRIM
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var frame := UiModalFrame.new()
	frame.name = "ConfirmFrame"
	frame.preferred_width = 420
	frame.title = title
	center.add_child(frame)

	var label := Label.new()
	label.name = "ConfirmMessage"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = message
	frame.body().add_child(label)

	var cancel := UiButton.new()
	cancel.name = "ConfirmCancel"
	cancel.variant = &"quiet"
	cancel.text = "取消"
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.pressed.connect(func() -> void: cancelled.emit())
	frame.add_action(cancel)

	var confirm := UiButton.new()
	confirm.name = "ConfirmOk"
	confirm.variant = &"danger" if danger else &"accent"
	confirm.text = confirm_text
	confirm.focus_mode = Control.FOCUS_NONE
	confirm.pressed.connect(func() -> void: confirmed.emit())
	frame.add_action(confirm)
