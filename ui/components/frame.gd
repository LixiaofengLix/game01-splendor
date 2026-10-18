## 通用像素框：9 宫格边框 + 底色 + 可选硬投影 / 顶部内高光 / 重点色条。
## 小框（2px 边）用 frame_s_*、大框（4px 边）用 frame_l_*；内容放进 content（MarginContainer）。
## 这是零件的底板，标签、toast、弹窗、面板都从它长出来。
class_name UiFrame
extends Control

const BLACK_SHADOW := Color(0.0784314, 0.0470588, 0.0313726, 0.45)

var frame_texture: Texture2D = null:
	set(value):
		frame_texture = value
		if _frame != null:
			_frame.texture = value
			_frame.visible = value != null
			_update_shadow_texture()

var frame_border: int = 2:
	set(value):
		frame_border = value
		if content != null:
			_apply_patch_margins()
			_layout()

var background_color: Color = UiPalette.CARD:
	set(value):
		background_color = value
		if _bg != null:
			_bg.color = value

var draw_background: bool = true:
	set(value):
		draw_background = value
		if _bg != null:
			_bg.visible = value

## 内容边距：左 / 上 / 右 / 下。
var content_padding: Vector4i = Vector4i(7, 2, 7, 2):
	set(value):
		content_padding = value
		if content != null:
			_layout()
			update_minimum_size()

var shadow_enabled: bool = false:
	set(value):
		shadow_enabled = value
		if _shadow != null:
			_shadow.visible = value
			_layout()

var shadow_offset: Vector2i = Vector2i(0, 3)
var shadow_color: Color = BLACK_SHADOW
## 阴影剪影用的贴图；留空时用 frame_texture。小框透明中心要填成 _fill 版才像整块影子。
var shadow_texture: Texture2D = null:
	set(value):
		shadow_texture = value
		if _shadow != null:
			_update_shadow_texture()

var top_highlight: bool = false:
	set(value):
		top_highlight = value
		if _highlight != null:
			_highlight.visible = value

var highlight_color: Color = Color("#fffaf0"):
	set(value):
		highlight_color = value
		if _highlight != null:
			_highlight.color = value

var feature_bar: bool = false:
	set(value):
		feature_bar = value
		if _feature != null:
			_feature.visible = value
			_layout()

## 子节点放这里；它的最小尺寸决定整个框的最小尺寸。
var content: MarginContainer

var _shadow: NinePatchRect
var _bg: ColorRect
var _frame: NinePatchRect
var _highlight: ColorRect
var _feature: ColorRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS

	_shadow = UiAssets.nine_patch(frame_texture, frame_border)
	_shadow.modulate = shadow_color
	_shadow.visible = shadow_enabled
	add_child(_shadow)

	_bg = ColorRect.new()
	_bg.color = background_color
	_bg.visible = draw_background
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_frame = UiAssets.nine_patch(frame_texture, frame_border)
	_frame.visible = frame_texture != null
	add_child(_frame)
	_update_shadow_texture()

	_highlight = ColorRect.new()
	_highlight.color = highlight_color
	_highlight.visible = top_highlight
	_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_highlight)

	_feature = ColorRect.new()
	_feature.color = UiPalette.GOLD
	_feature.visible = feature_bar
	_feature.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_feature)

	content = MarginContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	content.minimum_size_changed.connect(update_minimum_size)
	add_child(content)

	resized.connect(_layout)
	_layout()


func _get_minimum_size() -> Vector2:
	if content == null:
		return Vector2.ZERO
	return content.get_combined_minimum_size() + Vector2(
			content_padding.x + content_padding.z,
			content_padding.y + content_padding.w)


## 把装饰层插到内容下面（贵族的双圈线之类）。
func add_decoration(node: Control) -> void:
	add_child(node)
	move_child(node, content.get_index())


func _layout() -> void:
	if _shadow != null:
		_shadow.position = Vector2(shadow_offset)
		_shadow.size = size
	if _bg != null:
		_bg.position = Vector2.ZERO
		_bg.size = size
	if _frame != null:
		_frame.position = Vector2.ZERO
		_frame.size = size
	if _highlight != null:
		_highlight.position = Vector2(frame_border, frame_border)
		_highlight.size = Vector2(maxf(size.x - frame_border * 2.0, 0.0), 2.0)
	if _feature != null:
		_feature.position = Vector2(frame_border, frame_border)
		_feature.size = Vector2(maxf(size.x - frame_border * 2.0, 0.0), 4.0)
	if content != null:
		content.position = Vector2(content_padding.x, content_padding.y)
		content.size = Vector2(
				maxf(size.x - content_padding.x - content_padding.z, 0.0),
				maxf(size.y - content_padding.y - content_padding.w, 0.0))


func _apply_patch_margins() -> void:
	for patch: NinePatchRect in [_shadow, _frame]:
		if patch == null:
			continue
		patch.patch_margin_left = frame_border
		patch.patch_margin_top = frame_border
		patch.patch_margin_right = frame_border
		patch.patch_margin_bottom = frame_border


func _update_shadow_texture() -> void:
	if _shadow == null:
		return
	_shadow.texture = shadow_texture if shadow_texture != null else frame_texture
	_shadow.modulate = shadow_color
