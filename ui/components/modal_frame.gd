## 弹窗框：大框 + 向下 6px 硬投影，标题 24 号，可带 tag；底部按钮行右对齐。
## 内容通过 body 添加，按钮通过 add_action 添加；宽度由调用方决定（弃宝石 560、结算 720 等）。
class_name UiModalFrame
extends UiFrame

var preferred_width: int = 560:
	set(value):
		preferred_width = value
		if is_node_ready():
			update_minimum_size()

var title: String = "":
	set(value):
		title = value
		if _title_label != null:
			_title_label.text = value

var _title_label: Label
var _tag: UiTag
var _body: VBoxContainer
var _actions: HBoxContainer


func _ready() -> void:
	frame_texture = UiAssets.frame_l("ink")
	frame_border = 4
	background_color = UiPalette.CARD
	content_padding = Vector4i(24, 22, 24, 22)
	shadow_enabled = true
	shadow_offset = Vector2i(0, 6)
	shadow_color = Color(0, 0, 0, 0.5)
	top_highlight = true
	super._ready()

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	content.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	column.add_child(header)

	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.theme_type_variation = &"UiTitle"
	_title_label.text = title
	header.add_child(_title_label)

	_tag = UiTag.new()
	_tag.visible = false
	header.add_child(_tag)

	_body = VBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	column.add_child(_body)

	_actions = HBoxContainer.new()
	_actions.alignment = BoxContainer.ALIGNMENT_END
	_actions.add_theme_constant_override("separation", 10)
	column.add_child(_actions)


func _get_minimum_size() -> Vector2:
	var minimum := super._get_minimum_size()
	minimum.x = maxf(minimum.x, float(preferred_width))
	return minimum


func body() -> VBoxContainer:
	return _body


func add_action(button: Control) -> void:
	_actions.add_child(button)


func set_tag(text: String, variant: StringName = &"default") -> void:
	if _tag == null:
		return
	_tag.text = text
	_tag.variant = variant
	_tag.visible = not text.is_empty()
