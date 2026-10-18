## UI 零件共用的贴图工具：按颜色取筹码 / 宝石 / 吉祥物，生成固定像素尺寸的图标节点。
## 贴图是 2px = 1 像素画出来的，显示尺寸只取整数倍，避免像素被拉成两种大小。
class_name UiAssets
extends RefCounted

const DIR := "res://ui/assets/pixel/"

static var _cache: Dictionary[String, Texture2D] = {}


static func texture(file_name: String) -> Texture2D:
	if not _cache.has(file_name):
		_cache[file_name] = load(DIR + file_name) as Texture2D
	return _cache[file_name]


static func frame_s(name: String) -> Texture2D:
	return texture("frame_s_%s.png" % name)


static func frame_l(name: String) -> Texture2D:
	return texture("frame_l_%s.png" % name)


static func coin(color: Enums.GemColor, empty: bool = false) -> Texture2D:
	var suffix := "_empty" if empty else ""
	return texture("coin_%s%s.png" % [Enums.color_to_letter(color), suffix])


static func gem(color: Enums.GemColor, mono: bool = false) -> Texture2D:
	var suffix := "_mono" if mono else ""
	return texture("gem_%s%s.png" % [Enums.color_to_letter(color), suffix])


static func mascot(seat: int) -> Texture2D:
	if seat < 0 or seat > 3:
		return texture("mascot_sleepy.png")
	return texture("mascot_%d.png" % (seat + 1))


## 白 / 金这类浅色上的单色形状用深灰，其余颜色用宝石字色。
static func icon_color(color: Enums.GemColor) -> Color:
	if color == Enums.GemColor.WHITE or color == Enums.GemColor.GOLD:
		return UiPalette.GEM_LIGHT_ICON
	return UiPalette.GEM_TEXT[color]


## 单色宝石形状，指定显示尺寸（12 的整数倍）。
static func icon(color: Enums.GemColor, display_size: int, alpha: float = 0.75) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = gem(color, true)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.custom_minimum_size = Vector2(display_size, display_size)
	rect.size = rect.custom_minimum_size
	var color_value := icon_color(color)
	rect.modulate = Color(color_value.r, color_value.g, color_value.b, alpha)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## 彩色宝石形状（卡牌色带、卡牌引用用）。
static func gem_icon(color: Enums.GemColor, display_size: int) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = gem(color)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.custom_minimum_size = Vector2(display_size, display_size)
	rect.size = rect.custom_minimum_size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


static func mascot_icon(seat: int, display_size: int) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = mascot(seat)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.custom_minimum_size = Vector2(display_size, display_size)
	rect.size = rect.custom_minimum_size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## 平铺贴图：木纹、纸纹、牌背斜纹。
static func tiled(tex: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_TILE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## 9 宫格框。border 是贴图原尺寸上的切片宽度（小框 2、大框 4）。
static func nine_patch(tex: Texture2D, border: int) -> NinePatchRect:
	var rect := NinePatchRect.new()
	rect.texture = tex
	rect.patch_margin_left = border
	rect.patch_margin_top = border
	rect.patch_margin_right = border
	rect.patch_margin_bottom = border
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect
