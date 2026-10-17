## 全局枚举，以及枚举与字符串的互转。
## 枚举序号不写进存档：所有序列化都用字符串（见 CLAUDE.md），因此以后可以安全地新增枚举项。
class_name Enums
extends RefCounted

## 宝石颜色。前 5 种是发展卡的加成色；GOLD 只出现在银行与玩家手中，不能作为加成色或卡牌花费。
enum GemColor { WHITE, BLUE, GREEN, RED, BLACK, GOLD }

## 动作类型。每种动作对应 core/action.gd 里的一组参数字段（阶段 2）。
enum ActionType { TAKE_THREE, TAKE_TWO, RESERVE, PURCHASE, DISCARD, CHOOSE_NOBLE }

## 事件类型。规则引擎 apply 的返回值（core/game_event.gd），供日志、界面与联网同步用。
enum EventType {
	GEMS_TAKEN, CARD_RESERVED, CARD_PURCHASED, GEMS_DISCARDED,
	NOBLE_VISITED, NOBLE_CHOICE_REQUIRED, DISCARD_REQUIRED,
	TURN_STARTED, TURN_ENDED, PLAYER_SKIPPED, ENDGAME_TRIGGERED, GAME_FINISHED,
}

## 对局阶段。终局标记是 GameState 里的独立字段，不是阶段。
enum GamePhase { PLAYING, DISCARD, CHOOSE_NOBLE, FINISHED }

## 可拿取 / 可购买的 5 种颜色，也是卡表与统计的固定排序。
const PURCHASABLE_COLORS: Array[GemColor] = [
	GemColor.WHITE, GemColor.BLUE, GemColor.GREEN, GemColor.RED, GemColor.BLACK,
]

## 全部 6 种颜色（含金币）：银行与玩家手中宝石的固定遍历顺序。
const ALL_COLORS: Array[GemColor] = [
	GemColor.WHITE, GemColor.BLUE, GemColor.GREEN, GemColor.RED, GemColor.BLACK, GemColor.GOLD,
]

const COLOR_NAMES: Array[String] = ["white", "blue", "green", "red", "black", "gold"]
const COLOR_LETTERS: Array[String] = ["W", "U", "G", "R", "K", "X"]
const COLOR_NAMES_ZH: Array[String] = ["白", "蓝", "绿", "红", "黑", "金"]

const ACTION_TYPE_NAMES: Array[String] = [
	"take_three", "take_two", "reserve", "purchase", "discard", "choose_noble",
]
const GAME_PHASE_NAMES: Array[String] = ["playing", "discard", "choose_noble", "finished"]
const EVENT_TYPE_NAMES: Array[String] = [
	"gems_taken", "card_reserved", "card_purchased", "gems_discarded",
	"noble_visited", "noble_choice_required", "discard_required",
	"turn_started", "turn_ended", "player_skipped", "endgame_triggered", "game_finished",
]

## 解析失败返回 -1，由调用方决定怎么报错。
static func color_from_string(color_name: String) -> int:
	return COLOR_NAMES.find(color_name)

static func color_to_string(color: GemColor) -> String:
	return COLOR_NAMES[color]

static func color_to_letter(color: GemColor) -> String:
	return COLOR_LETTERS[color]

static func color_to_zh(color: GemColor) -> String:
	return COLOR_NAMES_ZH[color]

## 金币不能出现在卡牌花费或贵族要求里。
static func is_purchasable(color: int) -> bool:
	return color >= 0 and color < PURCHASABLE_COLORS.size()

## 解析失败返回 -1。
static func action_type_from_string(action_name: String) -> int:
	return ACTION_TYPE_NAMES.find(action_name)

static func action_type_to_string(action_type: ActionType) -> String:
	return ACTION_TYPE_NAMES[action_type]

## 解析失败返回 -1。
static func phase_from_string(phase_name: String) -> int:
	return GAME_PHASE_NAMES.find(phase_name)

static func phase_to_string(phase: GamePhase) -> String:
	return GAME_PHASE_NAMES[phase]

## 解析失败返回 -1。
static func event_type_from_string(event_name: String) -> int:
	return EVENT_TYPE_NAMES.find(event_name)

static func event_type_to_string(event_type: EventType) -> String:
	return EVENT_TYPE_NAMES[event_type]
