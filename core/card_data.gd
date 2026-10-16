## 一张发展卡的静态数据（对应 data/cards.json 的一条记录）。
## 构造后视为只读：规则引擎只读取，不修改。
class_name CardData
extends RefCounted

var id: String
var level: int
## 加成色，也就是买下后永久提供的折扣色，只可能是 5 种颜色之一。
var bonus: Enums.GemColor
var points: int
## 花费：Enums.GemColor -> 数量，只含非零项，不含 GOLD。
var cost: Dictionary[int, int]

func _init(p_id: String = "", p_level: int = 0, p_bonus: Enums.GemColor = Enums.GemColor.WHITE,
		p_points: int = 0, p_cost: Dictionary[int, int] = {}) -> void:
	id = p_id
	level = p_level
	bonus = p_bonus
	points = p_points
	cost = p_cost

## 从 cards.json 的一条记录构造。这里只做解析，合法性由 DataRegistry 统一校验并逐条报错。
static func from_dict(data: Dictionary) -> CardData:
	var parsed_cost: Dictionary[int, int] = {}
	var raw_cost: Dictionary = data.get("cost", {})
	for color_name: String in raw_cost:
		parsed_cost[Enums.color_from_string(color_name)] = int(raw_cost[color_name])
	return CardData.new(
			String(data.get("id", "")),
			int(data.get("level", 0)),
			Enums.color_from_string(String(data.get("bonus", ""))),
			int(data.get("points", 0)),
			parsed_cost)

## 在指定颜色上的花费（没有则为 0）。
func cost_of(color: Enums.GemColor) -> int:
	return cost.get(color, 0)

## 花费的总枚数。
func total_cost() -> int:
	var total: int = 0
	for amount: int in cost.values():
		total += amount
	return total

func to_dict() -> Dictionary:
	var raw_cost: Dictionary = {}
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		if cost_of(color) > 0:
			raw_cost[Enums.color_to_string(color)] = cost_of(color)
	return {
		"id": id,
		"level": level,
		"bonus": Enums.color_to_string(bonus),
		"points": points,
		"cost": raw_cost,
	}

## 一行中文描述，供日志与人工核对。
func describe() -> String:
	var parts: Array[String] = []
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		if cost_of(color) > 0:
			parts.append("%s%d" % [Enums.color_to_zh(color), cost_of(color)])
	return "%s %d级 %s加成 %d分 花费[%s]" % [id, level, Enums.color_to_zh(bonus), points, " ".join(parts)]
