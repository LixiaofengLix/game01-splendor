## 一个动作的数据对象：拿宝石、预留、购买、弃宝石、选贵族都是它。
## 只用稳定引用（card_id、等级、颜色）指向数据，序列化一律用字符串，方便存档、联网与大模型。
##
## JSON 形态（存档、网络协议、大模型输出都用这一套；`.` 表示该类型没有这个键）：
##   {"type": "take_three", "colors": ["white", "blue", "red"]}   # 拿 1~3 种不同色各 1 枚
##   {"type": "take_two",   "color": "blue"}                      # 拿 2 枚同色
##   {"type": "reserve",    "card_id": "L2-G-01"}                 # 预留场面卡
##   {"type": "reserve",    "level": 3}                           # 盲抽预留牌堆顶
##   {"type": "purchase",   "card_id": "L1-U-03"}                 # 购买（场面卡或自己预留的卡）
##   {"type": "discard",    "color": "gold"}                      # 弃掉 1 枚宝石
##   {"type": "choose_noble", "noble_id": "N-01"}                 # 选贵族
class_name Action
extends RefCounted

var type: Enums.ActionType = Enums.ActionType.TAKE_THREE
## TAKE_THREE（拿 1~3 种不同色）/ TAKE_TWO（1 种色）要拿的颜色。
var colors: Array[Enums.GemColor] = []
## RESERVE 场面卡 / PURCHASE 用：cards.json 里的卡牌 id。
var card_id: String = ""
## RESERVE 盲抽时用：从哪一级的牌堆顶抽。
var level: int = 0
## DISCARD 用：弃掉哪种颜色的 1 枚宝石。
var color: Enums.GemColor = Enums.GemColor.WHITE
## CHOOSE_NOBLE 用。
var noble_id: String = ""

static func take_three(p_colors: Array[Enums.GemColor]) -> Action:
	var action := Action.new()
	action.type = Enums.ActionType.TAKE_THREE
	action.colors = p_colors
	return action

static func take_two(p_color: Enums.GemColor) -> Action:
	var action := Action.new()
	action.type = Enums.ActionType.TAKE_TWO
	action.colors = [p_color]
	return action

static func reserve_card(p_card_id: String) -> Action:
	var action := Action.new()
	action.type = Enums.ActionType.RESERVE
	action.card_id = p_card_id
	return action

static func reserve_blind(p_level: int) -> Action:
	var action := Action.new()
	action.type = Enums.ActionType.RESERVE
	action.level = p_level
	return action

static func purchase(p_card_id: String) -> Action:
	var action := Action.new()
	action.type = Enums.ActionType.PURCHASE
	action.card_id = p_card_id
	return action

static func discard(p_color: Enums.GemColor) -> Action:
	var action := Action.new()
	action.type = Enums.ActionType.DISCARD
	action.color = p_color
	return action

static func choose_noble(p_noble_id: String) -> Action:
	var action := Action.new()
	action.type = Enums.ActionType.CHOOSE_NOBLE
	action.noble_id = p_noble_id
	return action

func to_dict() -> Dictionary:
	var name: String = Enums.action_type_to_string(type)
	match type:
		Enums.ActionType.TAKE_THREE, Enums.ActionType.TAKE_TWO:
			var color_names: Array[String] = []
			for value: Enums.GemColor in colors:
				color_names.append(Enums.color_to_string(value))
			return {"type": name, "colors": color_names}
		Enums.ActionType.RESERVE:
			if not card_id.is_empty():
				return {"type": name, "card_id": card_id}
			return {"type": name, "level": level}
		Enums.ActionType.PURCHASE:
			return {"type": name, "card_id": card_id}
		Enums.ActionType.DISCARD:
			return {"type": name, "color": Enums.color_to_string(color)}
		Enums.ActionType.CHOOSE_NOBLE:
			return {"type": name, "noble_id": noble_id}
	return {"type": name}

## 解析失败（类型拼错、字段缺失、颜色非法等）时 push_error 并返回 null。
static func from_dict(data: Dictionary) -> Action:
	var type_name: String = String(data.get("type", ""))
	var parsed: int = Enums.action_type_from_string(type_name)
	if parsed < 0:
		push_error("Action.from_dict：未知动作类型 \"%s\"" % type_name)
		return null
	var action := Action.new()
	action.type = parsed
	match parsed:
		Enums.ActionType.TAKE_THREE, Enums.ActionType.TAKE_TWO:
			var raw_colors: Variant = data.get("colors")
			if not raw_colors is Array or (raw_colors as Array).is_empty():
				push_error("Action.from_dict：%s 缺少 colors 数组" % type_name)
				return null
			for item: Variant in raw_colors:
				var color: int = Enums.color_from_string(String(item))
				if not Enums.is_purchasable(color):
					push_error("Action.from_dict：%s 的 colors 里有非法颜色 \"%s\"" % [type_name, item])
					return null
				action.colors.append(color)
			var wanted: int = 3 if parsed == Enums.ActionType.TAKE_THREE else 1
			if action.colors.size() > wanted:
				push_error("Action.from_dict：%s 最多 %d 种颜色，实际 %d 种" % [type_name, wanted, action.colors.size()])
				return null
		Enums.ActionType.RESERVE:
			if data.has("card_id"):
				action.card_id = String(data["card_id"])
				if action.card_id.is_empty():
					push_error("Action.from_dict：reserve 的 card_id 不能为空")
					return null
			elif data.has("level"):
				action.level = int(data["level"])
				if action.level < 1 or action.level > 3:
					push_error("Action.from_dict：reserve 的 level 必须是 1/2/3，实际 %s" % data["level"])
					return null
			else:
				push_error("Action.from_dict：reserve 需要 card_id 或 level")
				return null
		Enums.ActionType.PURCHASE:
			action.card_id = String(data.get("card_id", ""))
			if action.card_id.is_empty():
				push_error("Action.from_dict：purchase 缺少 card_id")
				return null
		Enums.ActionType.DISCARD:
			var color: int = Enums.color_from_string(String(data.get("color", "")))
			if color < 0:
				push_error("Action.from_dict：discard 的 color 非法：\"%s\"" % data.get("color"))
				return null
			action.color = color
		Enums.ActionType.CHOOSE_NOBLE:
			action.noble_id = String(data.get("noble_id", ""))
			if action.noble_id.is_empty():
				push_error("Action.from_dict：choose_noble 缺少 noble_id")
				return null
	return action

## 同类型且引用一致即相等；颜色数组按"集合"比较（顺序无关）。
func equals(other: Action) -> bool:
	if other == null or type != other.type:
		return false
	match type:
		Enums.ActionType.TAKE_THREE, Enums.ActionType.TAKE_TWO:
			if colors.size() != other.colors.size():
				return false
			for value: Enums.GemColor in colors:
				if not other.colors.has(value):
					return false
			return true
		Enums.ActionType.RESERVE:
			return card_id == other.card_id and level == other.level
		Enums.ActionType.PURCHASE:
			return card_id == other.card_id
		Enums.ActionType.DISCARD:
			return color == other.color
		Enums.ActionType.CHOOSE_NOBLE:
			return noble_id == other.noble_id
	return false

## 一行中文描述。这里不查卡牌数值（core/ 不引用数据层），日志里需要细节时由调用方补充。
func describe() -> String:
	match type:
		Enums.ActionType.TAKE_THREE:
			return "拿 %d 枚不同色：%s" % [colors.size(), _color_names()]
		Enums.ActionType.TAKE_TWO:
			return "拿 2 枚同色：%s" % _color_names()
		Enums.ActionType.RESERVE:
			if not card_id.is_empty():
				return "预留场面卡 %s" % card_id
			return "盲抽预留 %d 级牌堆顶" % level
		Enums.ActionType.PURCHASE:
			return "购买 %s" % card_id
		Enums.ActionType.DISCARD:
			return "弃掉 1 枚%s" % Enums.color_to_zh(color)
		Enums.ActionType.CHOOSE_NOBLE:
			return "选择贵族 %s" % noble_id
	return "未知动作"

func _color_names() -> String:
	var names: Array[String] = []
	for value: Enums.GemColor in colors:
		names.append(Enums.color_to_zh(value))
	return " ".join(names)
