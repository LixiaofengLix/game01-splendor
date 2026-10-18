## 键帽：小框 + SURFACE 底，内边距 0/5，用于快捷键提示。
class_name UiKbd
extends UiFrame

var text: String = "":
	set(value):
		text = value
		if _label != null:
			_label.text = value

var _label: Label


func _ready() -> void:
	frame_texture = UiAssets.frame_s("ink")
	frame_border = 2
	background_color = UiPalette.SURFACE
	content_padding = Vector4i(5, 2, 5, 2)
	super._ready()
	_label = Label.new()
	_label.name = "Label"
	_label.text = text
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_label)
