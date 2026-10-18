## UI 调色板：界面用到的全部颜色常量，数值对应 docs/ui/VISUAL_SPEC.md 第 2 节。
## 零件只引用这里的常量名，不写十六进制颜色；宝石色按 Enums.GemColor 索引。
class_name UiPalette
extends RefCounted

# ---------------------------------------------------------------- 基础色

const BG := Color("#e9d8b4")
## 棋盘格的另一色（BG 与它组成 4×4 平铺）。
const BG_ALT := Color("#e3d0a8")
const BG_SOFT := Color("#dcc59a")
const CARD := Color("#fbf3df")
const CARD_SOFT := Color("#f4e8cb")
## 输入框、kbd、内高光等最浅的底。
const SURFACE := Color("#fffaf0")
const INK := Color("#2a1c12")
const INK_2 := Color("#5b4632")
const INK_3 := Color("#8a7155")
const CAPTION := Color("#716b60")
const LINE := Color("#cdb68c")
const ORANGE := Color("#e8582a")
const OK := Color("#2f9e5f")
const GOLD := Color("#f2b630")
const GOLD_TEXT := Color("#ffd23f")
const GOLD_DARK := Color("#8a6420")
const GOLD_EDGE := Color("#5a3a06")
const GOLD_LIGHT := Color("#ffe28a")
const CREAM := Color("#f3e6c8")
const PURPLE := Color("#7b6cf6")
const DANGER := Color("#c8322e")
const WOOD_A := Color("#4a3424")
const WOOD_B := Color("#452f20")
const HUD := Color("#3a281b")
const HUD_BORDER := Color("#1a110b")
const HUD_HIGHLIGHT := Color("#5a4030")
## 弹窗遮罩：rgba(26, 17, 10, .72)。
const SCRIM := Color(0.1019608, 0.0666667, 0.0392157, 0.72)
const EVENT_BG := Color("#ffe7cc")
const LOG_NEW := Color("#ffe3c8")
const BLACK_SHADOW := Color("#120c08")
const WHITE := Color("#ffffff")

# ---------------------------------------------------------------- 零件专用色

const SEGMENT_BG := Color("#e4cfa2")
const PROGRESS_BG := Color("#d8c296")
## 对手分数进度条未进入终局威胁区时的填充色。
const PROGRESS_FILL := Color("#bdb3a2")
const NOBLE_BG := Color("#f6e7c1")
const NOBLE_INNER := Color("#fff6dc")
const NOBLE_INNER_2 := Color("#e0c58a")
const OFFLINE_BG := Color("#eadcbc")
const DECK_TILE_BASE := Color("#2e2922")
const DECK_TILE_STRIPE := Color("#37332c")
## 白 / 金这类浅色上的宝石形状图标。
const GEM_LIGHT_ICON := Color("#7d7465")
## 黑卡色带上彩色宝石形状的描边（见 VISUAL_SPEC 4.3）。
const GEM_BLACK_OUTLINE := Color("#b9ab95")

# ---------------------------------------------------------------- 标签 tag

const TAG_BG := Color("#e4cfa2")
const TAG_TEXT := INK
const TAG_DARK_BG := Color("#3a281b")
const TAG_DARK_TEXT := GOLD
const TAG_MINT_BG := Color("#cdeed6")
const TAG_MINT_TEXT := Color("#1d6b3d")
const TAG_ORANGE_BG := Color("#ffd9c2")
const TAG_ORANGE_TEXT := Color("#9a3510")
const TAG_PURPLE_BG := Color("#e2dcff")
const TAG_PURPLE_TEXT := Color("#4b39c4")
const TAG_RED_BG := Color("#ffd6d0")
const TAG_RED_TEXT := Color("#a3201c")

# ---------------------------------------------------------------- 宝石色

## 宝石底色（彩色形状与折扣块用）。
const GEM_BASE: Dictionary = {
	Enums.GemColor.WHITE: Color("#ffffff"),
	Enums.GemColor.BLUE: Color("#2f6fe4"),
	Enums.GemColor.GREEN: Color("#15966a"),
	Enums.GemColor.RED: Color("#e0403c"),
	Enums.GemColor.BLACK: Color("#2a2621"),
	Enums.GemColor.GOLD: Color("#f2b630"),
}

## 宝石底上的字色。
const GEM_TEXT: Dictionary = {
	Enums.GemColor.WHITE: Color("#211f1a"),
	Enums.GemColor.BLUE: Color("#ffffff"),
	Enums.GemColor.GREEN: Color("#ffffff"),
	Enums.GemColor.RED: Color("#ffffff"),
	Enums.GemColor.BLACK: Color("#ffffff"),
	Enums.GemColor.GOLD: Color("#211f1a"),
}

## 卡面浅底。
const GEM_TINT: Dictionary = {
	Enums.GemColor.WHITE: Color("#f6f3eb"),
	Enums.GemColor.BLUE: Color("#e5edfc"),
	Enums.GemColor.GREEN: Color("#def2e8"),
	Enums.GemColor.RED: Color("#fbe4e1"),
	Enums.GemColor.BLACK: Color("#e6e2da"),
	Enums.GemColor.GOLD: Color("#fcefcc"),
}

## 空心描边。
const GEM_EDGE: Dictionary = {
	Enums.GemColor.WHITE: Color("#b8ae9c"),
	Enums.GemColor.BLUE: Color("#2f6fe4"),
	Enums.GemColor.GREEN: Color("#15966a"),
	Enums.GemColor.RED: Color("#e0403c"),
	Enums.GemColor.BLACK: Color("#2a2621"),
	Enums.GemColor.GOLD: Color("#d49a17"),
}


static func gem_base(color: Enums.GemColor) -> Color:
	return GEM_BASE[color]


static func gem_text(color: Enums.GemColor) -> Color:
	return GEM_TEXT[color]


static func gem_tint(color: Enums.GemColor) -> Color:
	return GEM_TINT[color]


static func gem_edge(color: Enums.GemColor) -> Color:
	return GEM_EDGE[color]
