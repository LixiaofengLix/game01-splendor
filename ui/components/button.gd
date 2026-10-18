## 像素风按钮：5 种配色变体 × 3 种尺寸，带悬停抬起 / 按下压扁 / 硬投影。
## 状态样式来自 Theme 的 UiButton* 变体；尺寸只改内边距，字号统一 12。
class_name UiButton
extends Button

const VARIATIONS: Dictionary[StringName, StringName] = {
	&"ghost": &"UiButtonGhost",
	&"accent": &"UiButtonAccent",
	&"dark": &"UiButtonDark",
	&"quiet": &"UiButtonQuiet",
	&"danger": &"UiButtonDanger",
	&"hud": &"UiButtonHud",
}
## [左右, 上, 下]
const PADDING: Dictionary[StringName, Vector3i] = {
	&"sm": Vector3i(10, 4, 6),
	&"default": Vector3i(14, 7, 9),
	&"lg": Vector3i(20, 11, 13),
}
const LIFT := 2
const SHADOW_DROP := 3
const SHADOW_COLOR := Color(0.0784314, 0.0470588, 0.0313726, 0.45)

var variant: StringName = &"ghost":
	set(value):
		variant = value
		if is_node_ready():
			_apply_style()

var size_key: StringName = &"default":
	set(value):
		size_key = value
		if is_node_ready():
			_apply_style()

## 陈列场景专用：强制显示 normal / hover / pressed / disabled 之一。留空表示正常交互。
var preview_state: StringName = &"":
	set(value):
		preview_state = value
		if is_node_ready():
			_apply_style()

var _shadow: NinePatchRect
var _hovering := false
var _down := false
var _rest_y := 0.0


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_shadow = UiAssets.nine_patch(null, 2)
	_shadow.show_behind_parent = true
	_shadow.modulate = SHADOW_COLOR
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shadow)
	_apply_style()
	resized.connect(_layout_shadow)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	pressed.connect(func() -> void: UiSfx.play("click"))
	_layout_shadow()


func _apply_style() -> void:
	var type_name: StringName = VARIATIONS.get(variant, &"UiButtonGhost")
	theme_type_variation = type_name

	var padding: Vector3i = PADDING.get(size_key, PADDING[&"default"])
	var states: Array[StringName] = [&"normal", &"hover", &"pressed", &"disabled"]
	for state: StringName in states:
		# 运行时切换 variant 时，旧的 StyleBox override 会挡住新变体的主题样式，先清掉。
		remove_theme_stylebox_override(state)
		var source: StyleBox = get_theme_stylebox(state, type_name)
		if source == null:
			continue
		var box: StyleBox = source.duplicate()
		if box is StyleBoxTexture:
			box.content_margin_left = padding.x
			box.content_margin_right = padding.x
			box.content_margin_top = padding.y
			box.content_margin_bottom = padding.z
		add_theme_stylebox_override(state, box)

	var normal_box := get_theme_stylebox(&"normal", type_name) as StyleBoxTexture
	if normal_box != null and _shadow != null:
		_shadow.texture = normal_box.texture
		_shadow.patch_margin_left = 2
		_shadow.patch_margin_top = 2
		_shadow.patch_margin_right = 2
		_shadow.patch_margin_bottom = 2
		_shadow.visible = true

	var preview := String(preview_state)
	if preview != "":
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		var state_name := StringName(preview)
		var preview_box: StyleBox = get_theme_stylebox(state_name, type_name)
		if preview_box != null:
			var dup: StyleBox = preview_box.duplicate()
			if dup is StyleBoxTexture:
				dup.content_margin_left = padding.x
				dup.content_margin_right = padding.x
				dup.content_margin_top = padding.y
				dup.content_margin_bottom = padding.z
			for state: StringName in states:
				add_theme_stylebox_override(state, dup)
		remove_theme_color_override("font_color")
		var color_name := "font_color"
		if preview != "normal":
			color_name = "font_%s_color" % preview
		add_theme_color_override("font_color", get_theme_color(color_name, type_name))
		if _shadow != null:
			_shadow.visible = preview != "pressed" and preview != "disabled"
	else:
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_ALL
		remove_theme_color_override("font_color")
	queue_redraw()


func _layout_shadow() -> void:
	if _shadow == null:
		return
	_shadow.position = Vector2(0, SHADOW_DROP)
	_shadow.size = size


func _draw() -> void:
	# 顶部 2px 内高光、底部 3px 内阴影，和样张的厚块按钮一致。
	draw_rect(Rect2(2, 2, maxf(size.x - 4, 0), 2), Color(1, 1, 1, 0.3))
	draw_rect(Rect2(2, maxf(size.y - 5, 0), maxf(size.x - 4, 0), 3), Color(0, 0, 0, 0.28))


func _on_mouse_entered() -> void:
	if disabled or preview_state != &"":
		return
	_hovering = true
	_rest_y = position.y
	if not _down:
		position.y = _rest_y - LIFT


func _on_mouse_exited() -> void:
	if not _hovering:
		return
	_hovering = false
	position.y = _rest_y


func _on_button_down() -> void:
	if preview_state != &"":
		return
	_down = true
	position.y = _rest_y + LIFT
	if _shadow != null:
		_shadow.visible = false


func _on_button_up() -> void:
	if preview_state != &"":
		return
	_down = false
	position.y = _rest_y - (LIFT if _hovering else 0)
	if _shadow != null:
		_shadow.visible = true
