## 一位贵族的静态数据（对应 data/nobles.json 的一条记录）。
## 构造后视为只读。
class_name NobleData
extends RefCounted

var id: String
var points: int
## 要求：Enums.GemColor -> 需要的卡牌折扣数（不是宝石数），只含非零项，不含 GOLD。
var requirement: Dictionary[int, int]

func _init(p_id: String = "", p_points: int = 0, p_requirement: Dictionary[int, int] = {}) -> void:
	id = p_id
	points = p_points
	requirement = p_requirement

## 从 nobles.json 的一条记录构造。这里只做解析，合法性由 DataRegistry 统一校验并逐条报错。
static func from_dict(data: Dictionary) -> NobleData:
	var parsed_requirement: Dictionary[int, int] = {}
	var raw_requirement: Dictionary = data.get("requirement", {})
	for color_name: String in raw_requirement:
		parsed_requirement[Enums.color_from_string(color_name)] = int(raw_requirement[color_name])
	return NobleData.new(
			String(data.get("id", "")),
			int(data.get("points", 0)),
			parsed_requirement)

## 在指定颜色上需要的折扣数（没有则为 0）。
func requirement_of(color: Enums.GemColor) -> int:
	return requirement.get(color, 0)

func to_dict() -> Dictionary:
	var raw_requirement: Dictionary = {}
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		if requirement_of(color) > 0:
			raw_requirement[Enums.color_to_string(color)] = requirement_of(color)
	return {"id": id, "points": points, "requirement": raw_requirement}

## 一行中文描述，供日志与人工核对。
func describe() -> String:
	var parts: Array[String] = []
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		if requirement_of(color) > 0:
			parts.append("%s%d" % [Enums.color_to_zh(color), requirement_of(color)])
	return "%s %d分 要求[%s]" % [id, points, " ".join(parts)]
