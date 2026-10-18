## 银行列：宽 100 的大框面板，从上到下是“银行”、6 枚 lg 筹码（白蓝绿红黑金）、
## 底部操作区（U2 只显示提示文字；确认 / 取消按钮留给 U3）。
class_name UiBankColumn
extends UiFrame

const WIDTH := 100

var _box: VBoxContainer
var _chips: Array[UiGemChip] = []
var _hint: Label
var _counts: Dictionary[int, int] = {}


func _ready() -> void:
	frame_texture = UiAssets.frame_l("ink")
	frame_border = 4
	background_color = UiPalette.CARD
	content_padding = Vector4i(6, 10, 6, 10)
	top_highlight = true
	shadow_enabled = true
	shadow_offset = Vector2i(0, 4)
	super._ready()
	custom_minimum_size.x = WIDTH

	_box = VBoxContainer.new()
	_box.name = "Box"
	_box.add_theme_constant_override("separation", 7)
	_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	content.add_child(_box)

	var title := Label.new()
	title.name = "Title"
	title.text = "银行"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UiPalette.INK_3)
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(title)

	for color: Enums.GemColor in Enums.ALL_COLORS:
		var chip := UiGemChip.new()
		chip.name = "Chip_%s" % Enums.color_to_letter(color)
		chip.gem_color = color
		chip.size_key = &"lg"
		chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_box.add_child(chip)
		_chips.append(chip)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_box.add_child(spacer)

	_hint = Label.new()
	_hint.name = "Hint"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_color_override("font_color", UiPalette.INK_3)
	_box.add_child(_hint)


## counts 以 Enums.GemColor 为键；缺少的颜色按 0 枚（空心）显示。
func set_counts(counts: Dictionary) -> void:
	_counts.clear()
	for color: Enums.GemColor in Enums.ALL_COLORS:
		var value: int = int(counts.get(color, 0))
		_counts[color] = value
		if color < _chips.size():
			_chips[color].count = value


func set_hint(text: String) -> void:
	_hint.text = text
	_hint.visible = not text.is_empty()


func get_counts() -> Dictionary[int, int]:
	return _counts.duplicate()
