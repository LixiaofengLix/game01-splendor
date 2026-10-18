## 生成 ui/assets/pixel/ 下的全部像素贴图：9 宫格边框、金币、宝石形状、吉祥物、平铺底纹。
## 点阵与颜色照搬 docs/ui-mockup-v4.html 的“V4 像素贴图”脚本和 docs/ui/VISUAL_SPEC.md 第 4 节。
## 重复运行结果一致；结束时自检张数与尺寸，不符就退出码 1。
## 运行：/Applications/Godot.app/Contents/MacOS/Godot --headless --path . ui/tools/build_pixel_assets.tscn
extends Node

const OUT_DIR := "res://ui/assets/pixel"
const EXPECTED_COUNT := 44

const FRAME_S_COLORS: Dictionary = {
	"ink": Color("#2a1c12"),
	"ok": Color("#2f9e5f"),
	"hot": Color("#e8582a"),
	"gold": Color("#8a6420"),
	"dark": Color("#120c08"),
}
const FRAME_L_COLORS: Dictionary = {
	"ink": Color("#2a1c12"),
	"hot": Color("#e8582a"),
}
const FRAME_L_FILL := Color("#fbf3df")

## [本色, 阴影, 高光, 外描边, 空心描边]
const COIN_COLORS: Dictionary = {
	"W": [Color("#f6f1e4"), Color("#c8bca5"), Color("#ffffff"), Color("#2a1c12"), Color("#b8ae9c")],
	"U": [Color("#3b74e0"), Color("#244c9c"), Color("#8fb3f5"), Color("#14244a"), Color("#3b74e0")],
	"G": [Color("#1f9a69"), Color("#126444"), Color("#6fd3a6"), Color("#0b3524"), Color("#1f9a69")],
	"R": [Color("#e0403c"), Color("#9c2422"), Color("#ff8f84"), Color("#4a1110"), Color("#e0403c")],
	"K": [Color("#3a332c"), Color("#1c1814"), Color("#6e655b"), Color("#0e0b08"), Color("#3a332c")],
	"X": [Color("#f2b630"), Color("#b67d12"), Color("#ffe28a"), Color("#5a3a06"), Color("#d49a17")],
}

## 10×10 点阵：`#` = 本色，`h` = 高光；自动外扩一圈 8 邻域描边后为 12×12。
const GEM_ROWS: Dictionary = {
	"W": [
		"....##....",
		"...#h##...",
		"..#h####..",
		".#h######.",
		"##########",
		"##########",
		".########.",
		"..######..",
		"...####...",
		"....##....",
	],
	"U": [
		"...####...",
		".##hh####.",
		".#h######.",
		"##h#######",
		"##########",
		"##########",
		"##########",
		".########.",
		".########.",
		"...####...",
	],
	"G": [
		"...####...",
		"..#hh###..",
		"..#h####..",
		"..#h####..",
		"..######..",
		"..######..",
		"..######..",
		"..######..",
		"..######..",
		"...####...",
	],
	"R": [
		"..........",
		".###..###.",
		"#hh#######",
		"#h########",
		"##########",
		".########.",
		"..######..",
		"...####...",
		"....##....",
		"..........",
	],
	"K": [
		"..........",
		".########.",
		".#hhh####.",
		".#h######.",
		".#h######.",
		".########.",
		".########.",
		".########.",
		".########.",
		"..........",
	],
	"X": [
		"....##....",
		"....##....",
		"...#h##...",
		"##########",
		".#h######.",
		"..######..",
		"..######..",
		".###..###.",
		".##....##.",
		"..........",
	],
}

var _saved: Dictionary = {}
var _failures: Array[String] = []


func _ready() -> void:
	var abs_dir := ProjectSettings.globalize_path(OUT_DIR)
	var make_err := DirAccess.make_dir_recursive_absolute(abs_dir)
	if make_err != OK and make_err != ERR_ALREADY_EXISTS:
		_fail("无法创建目录 %s（%s）" % [OUT_DIR, error_string(make_err)])
		_finish()
		return

	_build_frames()
	_build_coins()
	_build_gems()
	_build_mascots()
	_build_tiles()
	_verify()
	_finish()


# ---------------------------------------------------------------- 生成

func _build_frames() -> void:
	for name: String in FRAME_S_COLORS:
		var color: Color = FRAME_S_COLORS[name]
		_save(_build_frame_s(color, false), "frame_s_%s.png" % name)
		_save(_build_frame_s(color, true), "frame_s_%s_fill.png" % name)
	for name: String in FRAME_L_COLORS:
		_save(_build_frame_l(FRAME_L_COLORS[name], FRAME_L_FILL), "frame_l_%s.png" % name)


func _build_coins() -> void:
	for letter: String in COIN_COLORS:
		var colors: Array = COIN_COLORS[letter]
		_save(_build_coin(colors, false), "coin_%s.png" % letter)
		_save(_build_coin(colors, true), "coin_%s_empty.png" % letter)


func _build_gems() -> void:
	for letter: String in GEM_ROWS:
		var rows: Array = GEM_ROWS[letter]
		var base: Color = UiPalette.GEM_BASE[Enums.color_from_string(_color_name(letter))]
		var outline: Color = UiPalette.GEM_BLACK_OUTLINE if letter == "K" else UiPalette.INK
		var colored := {
			"o": outline,
			"#": base,
			"h": _blend_opaque(base, Color(1, 1, 1, 0.8)),
		}
		var mono := {
			"o": Color(0, 0, 0, 0),
			"#": UiPalette.WHITE,
			"h": UiPalette.WHITE,
		}
		_save(_px_symbol(rows, colored), "gem_%s.png" % letter)
		_save(_px_symbol(rows, mono), "gem_%s_mono.png" % letter)


func _build_mascots() -> void:
	var open_eyes := func(x: int, y: int) -> bool:
		return (x == 4 or x == 5 or x == 8 or x == 9) and y >= 5 and y <= 7
	var tri_eyes := func(x: int, y: int) -> bool:
		return (x == 5 or x == 8) and y >= 8 and y <= 10
	var sleepy_eyes := func(x: int, y: int) -> bool:
		return y == 6 and ((x >= 3 and x <= 5) or (x >= 8 and x <= 10))

	var seats := [
		{"file": "mascot_1.png", "tri": false, "eyes": open_eyes, "body": Color("#26201a"), "light": Color("#5a5048")},
		{"file": "mascot_2.png", "tri": false, "eyes": open_eyes, "body": Color("#2fd3a8"), "light": Color("#9ff0d8")},
		{"file": "mascot_3.png", "tri": true, "eyes": tri_eyes, "body": Color("#7b6cf6"), "light": Color("#b9b0ff")},
		{"file": "mascot_4.png", "tri": false, "eyes": open_eyes, "body": Color("#ff6a2b"), "light": Color("#ffb08a")},
		{"file": "mascot_sleepy.png", "tri": false, "eyes": sleepy_eyes, "body": Color("#26201a"), "light": Color("#5a5048")},
	]
	for seat: Dictionary in seats:
		var rows := _blob(bool(seat["tri"]), seat["eyes"])
		var colors := {
			"o": Color("#1a120c"),
			"#": seat["body"],
			"e": Color("#ffffff"),
			"h": seat["light"],
		}
		_save(_px_symbol(rows, colors), String(seat["file"]))


func _build_tiles() -> void:
	_save(_build_paper_tile(), "tile_paper.png")
	_save(_build_wood_tile(), "tile_wood.png")
	_save(_build_card_back_tile(), "tile_card_back.png")


# ---------------------------------------------------------------- 边框

func _build_frame_s(color: Color, filled: bool) -> Image:
	var src: Array = []
	for y in 3:
		var row: Array = []
		for x in 3:
			var is_edge: bool = (x == 1) != (y == 1)
			var pixel := Color(0, 0, 0, 0)
			if is_edge:
				pixel = color
			elif filled and x == 1 and y == 1:
				pixel = UiPalette.WHITE
			row.append(pixel)
		src.append(row)
	return _scale_pixels(src, 2)


func _build_frame_l(color: Color, fill: Color) -> Image:
	var border_cells := {
		Vector2i(2, 0): true, Vector2i(1, 1): true, Vector2i(3, 1): true,
		Vector2i(0, 2): true, Vector2i(4, 2): true,
		Vector2i(1, 3): true, Vector2i(3, 3): true, Vector2i(2, 4): true,
	}
	var fill_cells := {
		Vector2i(2, 1): true, Vector2i(1, 2): true, Vector2i(2, 2): true,
		Vector2i(3, 2): true, Vector2i(2, 3): true,
	}
	var src: Array = []
	for y in 5:
		var row: Array = []
		for x in 5:
			var cell := Vector2i(x, y)
			var pixel := Color(0, 0, 0, 0)
			if border_cells.has(cell):
				pixel = color
			elif fill_cells.has(cell):
				pixel = fill
			row.append(pixel)
		src.append(row)
	return _scale_pixels(src, 2)


# ---------------------------------------------------------------- 金币 / 宝石 / 吉祥物

func _build_coin(colors: Array, empty: bool) -> Image:
	var base: Color = colors[0]
	var shade: Color = colors[1]
	var light: Color = colors[2]
	var outline: Color = colors[3]
	var empty_edge: Color = colors[4]
	var img := Image.create_empty(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 12:
		for x in 12:
			var d := Vector2(x - 5.5, y - 5.5).length()
			if d > 5.9:
				continue
			var is_edge := false
			for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if not _coin_inside(x + dir.x, y + dir.y):
					is_edge = true
			var pixel: Color
			if is_edge:
				pixel = empty_edge if empty else outline
			elif empty:
				pixel = UiPalette.CARD
			elif (d > 3.4 and d <= 4.3) or (d > 4.3 and y >= 7):
				pixel = shade
			elif d > 4.3 and x + y <= 6:
				pixel = light
			else:
				pixel = base
			img.set_pixel(x, y, pixel)
	return img


func _coin_inside(x: int, y: int) -> bool:
	return Vector2(x - 5.5, y - 5.5).length() <= 5.9


## 点阵 → 贴图：自动在四周补一圈 8 邻域描边，输出 = 输入 + 2。
func _px_symbol(rows: Array, colors: Dictionary) -> Image:
	var src_width: int = String(rows[0]).length()
	var width := src_width + 2
	var height := rows.size() + 2
	var pad: Array[String] = []
	pad.append(".".repeat(width))
	for row: String in rows:
		pad.append("." + row + ".")
	pad.append(".".repeat(width))

	var img := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in height:
		for x in width:
			var ch := _pad_at(pad, x, y)
			var key := ""
			if ch != ".":
				key = ch
			elif _has_filled_neighbor(pad, x, y):
				key = "o"
			if key != "" and colors.has(key):
				img.set_pixel(x, y, colors[key])
	return img


func _blob(tri: bool, eyes: Callable) -> Array[String]:
	var rows: Array[String] = []
	for y in 14:
		var line := ""
		for x in 14:
			var inside: bool
			if tri:
				inside = y >= 1 and absf(x - 6.5) <= (y + 1) / 2.0
			else:
				inside = Vector2(x - 6.5, y - 6.5).length() <= 6.8
			if not inside:
				line += "."
			elif bool(eyes.call(x, y)):
				line += "e"
			elif not tri and ((x == 3 and y == 3) or (x == 4 and y == 2) or (x == 2 and y == 4)):
				line += "h"
			else:
				line += "#"
		rows.append(line)
	return rows


# ---------------------------------------------------------------- 平铺底纹

func _build_paper_tile() -> Image:
	var img := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	for y in 4:
		for x in 4:
			var first: bool = (x < 2) == (y < 2)
			img.set_pixel(x, y, UiPalette.BG if first else UiPalette.BG_ALT)
	return img


func _build_wood_tile() -> Image:
	var size := 48
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var cell_x := int(x / 2.0)
			var cell_y := int(y / 2.0)
			var first := (cell_x + cell_y) % 2 == 0
			var pixel: Color = UiPalette.WOOD_A if first else UiPalette.WOOD_B
			if y >= 46:
				pixel = _blend_opaque(pixel, Color(0, 0, 0, 0.22))
			img.set_pixel(x, y, pixel)
	return img


func _build_card_back_tile() -> Image:
	var size := 10
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var striped := (x + y) % 10 < 5
			img.set_pixel(x, y, UiPalette.DECK_TILE_STRIPE if striped else UiPalette.DECK_TILE_BASE)
	return img


# ---------------------------------------------------------------- 工具

func _scale_pixels(src: Array, scale: int) -> Image:
	var src_height := src.size()
	var src_width: int = (src[0] as Array).size()
	var img := Image.create_empty(src_width * scale, src_height * scale, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in src_height:
		for x in src_width:
			var pixel: Color = src[y][x]
			if pixel.a <= 0.0:
				continue
			for dy in scale:
				for dx in scale:
					img.set_pixel(x * scale + dx, y * scale + dy, pixel)
	return img


## 把半透明颜色叠在不透明底色上，结果仍不透明。
func _blend_opaque(base: Color, top: Color) -> Color:
	var a := top.a
	return Color(
		base.r * (1.0 - a) + top.r * a,
		base.g * (1.0 - a) + top.g * a,
		base.b * (1.0 - a) + top.b * a,
		1.0
	)


func _pad_at(pad: Array[String], x: int, y: int) -> String:
	if y < 0 or y >= pad.size():
		return "."
	var row := pad[y]
	if x < 0 or x >= row.length():
		return "."
	return row[x]


func _has_filled_neighbor(pad: Array[String], x: int, y: int) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			if _pad_at(pad, x + dx, y + dy) != ".":
				return true
	return false


func _color_name(letter: String) -> String:
	var index := Enums.COLOR_LETTERS.find(letter)
	return Enums.COLOR_NAMES[index] if index >= 0 else ""


func _save(img: Image, file_name: String) -> void:
	var path := OUT_DIR.path_join(file_name)
	var err := img.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		_fail("保存 %s 失败：%s" % [file_name, error_string(err)])
		return
	_saved[file_name] = img.get_size()


# ---------------------------------------------------------------- 自检

func _verify() -> void:
	if _saved.size() != EXPECTED_COUNT:
		_fail("生成张数 %d，应为 %d" % [_saved.size(), EXPECTED_COUNT])

	for file_name: String in _saved:
		var path := OUT_DIR.path_join(file_name)
		var expected: Vector2i = _saved[file_name]
		var loaded := Image.load_from_file(ProjectSettings.globalize_path(path))
		if loaded == null:
			_fail("%s 无法重新读取" % file_name)
		elif loaded.get_size() != expected:
			_fail("%s 尺寸 %s，应为 %s" % [file_name, str(loaded.get_size()), str(expected)])

	var dir := DirAccess.open(OUT_DIR)
	if dir == null:
		_fail("无法打开 %s" % OUT_DIR)
		return
	var actual: Array[String] = []
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".png"):
			actual.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	for file_name: String in actual:
		if not _saved.has(file_name):
			_fail("目录里有多余的贴图：%s" % file_name)
	for file_name: String in _saved:
		if not actual.has(file_name):
			_fail("目录里缺少贴图：%s" % file_name)

	if _failures.is_empty():
		print("像素贴图：生成 %d 张，尺寸自检通过。" % _saved.size())
	else:
		for message: String in _failures:
			printerr(message)


func _fail(message: String) -> void:
	_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		get_tree().quit(0)
	else:
		printerr("像素贴图生成失败：%d 个问题。" % _failures.size())
		get_tree().quit(1)
