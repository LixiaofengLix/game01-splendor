## 全局单例（autoload 名 DataRegistry）：启动时加载 data/ 下的 JSON，校验后以 core/ 的类型化对象对外提供。
## 校验失败不崩溃：每一条问题（含出错的卡牌 / 贵族 id）都收进 get_errors()，
## 由调用方决定怎么处理（tests/data_report.tscn 会打印全部问题并以退出码 1 结束）。
## 注意：autoload 脚本不能写 class_name（会与单例名冲突），用单例名直接访问即可。
extends Node

const CARDS_PATH: String = "res://data/cards.json"
const NOBLES_PATH: String = "res://data/nobles.json"
const RULES_PATH: String = "res://data/rules.json"
const SUPPORTED_SCHEMA_VERSION: int = 1

## 官方基础版的卡牌分布：每级总张数、每级每种颜色的张数。
const EXPECTED_LEVEL_TOTALS: Dictionary[int, int] = {1: 40, 2: 30, 3: 20}
const EXPECTED_PER_COLOR: Dictionary[int, int] = {1: 8, 2: 6, 3: 4}
const EXPECTED_NOBLE_COUNT: int = 10
const NOBLE_POINTS: int = 3
## 官方贵族只有两种要求形态：两个 4，或三个 3。
const NOBLE_REQUIREMENT_SHAPES: Array = [[4, 4], [3, 3, 3]]
## 单张卡牌在一种颜色上的花费上限。
const MAX_SINGLE_COST: int = 7
## rules.json 里必须存在的开关，拼错名字会在这里被发现。
const REQUIRED_SWITCHES: Array[String] = [
	"allow_take_fewer_when_colors_short", "reserve_takes_gold",
	"noble_visit_at_turn_end", "max_one_noble_per_turn",
]
## 锚点卡：官方卡表里容易录错的标志性卡牌。只校验"存在这样一张卡"，不依赖 id 编号。
const ANCHOR_CARDS: Array = [
	{"level": 3, "bonus": "red", "points": 4, "cost": {"green": 7}},
]

var _cards_by_id: Dictionary[String, CardData] = {}
var _cards_by_level: Dictionary = {}
var _nobles: Array[NobleData] = []
var _rules: RulesConfig = null
var _errors: Array[String] = []

func _ready() -> void:
	load_all()

## 重新加载全部数据。任何时候都可以调用（改完 JSON 不必重启）。
func load_all() -> void:
	_errors.clear()
	_cards_by_id.clear()
	_cards_by_level.clear()
	_nobles.clear()
	_rules = null
	_load_rules()
	_load_cards()
	_load_nobles()

# ---------------------------------------------------------------- 对外接口

func rules() -> RulesConfig:
	return _rules

func get_card(card_id: String) -> CardData:
	return _cards_by_id.get(card_id)

func has_card(card_id: String) -> bool:
	return _cards_by_id.has(card_id)

func all_cards() -> Array[CardData]:
	var result: Array[CardData] = []
	for level: int in EXPECTED_LEVEL_TOTALS:
		result.append_array(cards_in_level(level))
	return result

## 某一级的所有卡牌，顺序与 cards.json 中一致。
func cards_in_level(level: int) -> Array[CardData]:
	if not _cards_by_level.has(level):
		return []
	var result: Array[CardData] = []
	result.assign(_cards_by_level[level])
	return result

func all_nobles() -> Array[NobleData]:
	return _nobles.duplicate()

func is_valid() -> bool:
	return _errors.is_empty()

func get_errors() -> Array[String]:
	return _errors.duplicate()

# ---------------------------------------------------------------- 加载

## 读文件并解析 JSON。失败时记录一条问题并返回 null。
func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		_errors.append("%s：文件不存在" % path.get_file())
		return null
	var json := JSON.new()
	var error: Error = json.parse(FileAccess.get_file_as_string(path))
	if error != OK:
		_errors.append("%s：第 %d 行 JSON 语法错误：%s"
				% [path.get_file(), json.get_error_line(), json.get_error_message()])
		return null
	return json.data

## 取出顶层的 records 数组，同时校验 schema_version 与整体结构。
func _read_records(path: String, records_key: String) -> Array:
	var data: Variant = _read_json(path)
	if data == null:
		return []
	if not data is Dictionary:
		_errors.append("%s：顶层必须是一个对象" % path.get_file())
		return []
	var dict: Dictionary = data
	var version: int = int(dict.get("schema_version", 0))
	if version != SUPPORTED_SCHEMA_VERSION:
		_errors.append("%s：schema_version 应为 %d，实际为 %d（数据结构变了吗？）"
				% [path.get_file(), SUPPORTED_SCHEMA_VERSION, version])
	var records: Variant = dict.get(records_key)
	if not records is Array:
		_errors.append("%s：缺少数组字段 %s" % [path.get_file(), records_key])
		return []
	return records

func _load_rules() -> void:
	var data: Variant = _read_json(RULES_PATH)
	if data == null:
		return
	if not data is Dictionary:
		_errors.append("rules.json：顶层必须是一个对象")
		return
	var dict: Dictionary = data
	var version: int = int(dict.get("schema_version", 0))
	if version != SUPPORTED_SCHEMA_VERSION:
		_errors.append("rules.json：schema_version 应为 %d，实际为 %d"
				% [SUPPORTED_SCHEMA_VERSION, version])
	_rules = RulesConfig.from_dict(dict)

	if _rules.gold_count <= 0:
		_errors.append("rules.json：gold_count 应为正数，实际为 %d" % _rules.gold_count)
	if _rules.win_points <= 0:
		_errors.append("rules.json：win_points 应为正数，实际为 %d" % _rules.win_points)
	if _rules.max_tokens <= 0:
		_errors.append("rules.json：max_tokens 应为正数，实际为 %d" % _rules.max_tokens)
	if _rules.max_reserved <= 0:
		_errors.append("rules.json：max_reserved 应为正数，实际为 %d" % _rules.max_reserved)
	if _rules.board_slots_per_level <= 0:
		_errors.append("rules.json：board_slots_per_level 应为正数")
	if _rules.take_two_min_remaining <= 0:
		_errors.append("rules.json：take_two_min_remaining 应为正数")

	for player_count: int in [2, 3, 4]:
		var gems: int = _rules.gems_per_color_for(player_count)
		var nobles: int = _rules.nobles_for(player_count)
		if gems <= 0:
			_errors.append("rules.json：players.%d.gems_per_color 缺失或非正数" % player_count)
		if nobles != player_count + 1:
			_errors.append("rules.json：players.%d.nobles 应为 %d（人数 + 1），实际为 %d"
					% [player_count, player_count + 1, nobles])

	for switch_name: String in REQUIRED_SWITCHES:
		if not _rules.switches.has(switch_name):
			_errors.append("rules.json：switches 缺少 %s（见 data/README.md）" % switch_name)
	for switch_name: String in _rules.switches:
		if not REQUIRED_SWITCHES.has(switch_name):
			_errors.append("rules.json：switches 里有未知开关 %s（拼错了？）" % switch_name)

func _load_cards() -> void:
	var records: Array = _read_records(CARDS_PATH, "cards")
	if records.is_empty() and not _errors.is_empty():
		return
	var signatures: Dictionary = {}
	for index: int in records.size():
		var entry: Variant = records[index]
		if not entry is Dictionary:
			_errors.append("cards.json 第 %d 条：必须是对象" % (index + 1))
			continue
		var card: CardData = _parse_card(entry, index)
		if card == null:
			continue
		_cards_by_id[card.id] = card
		if not _cards_by_level.has(card.level):
			_cards_by_level[card.level] = []
		_cards_by_level[card.level].append(card)
		var signature: String = "%d/%d/%d/%s" % [card.level, card.bonus, card.points,
				_canonical_cost_by_color(card.cost)]
		if signatures.has(signature):
			_errors.append("cards.json %s：与 %s 完全重复" % [card.id, signatures[signature]])
		signatures[signature] = card.id

	_check_level_distribution()
	_check_anchors()

func _parse_card(entry: Dictionary, index: int) -> CardData:
	var where: String = "cards.json 第 %d 条" % (index + 1)
	var card_id: String = String(entry.get("id", ""))
	if card_id.is_empty():
		_errors.append("%s：缺少 id" % where)
		return null
	where = "cards.json %s" % card_id
	if _cards_by_id.has(card_id):
		_errors.append("%s：id 与前面的卡牌重复" % where)
		return null
	var failed: bool = false

	var level: int = int(entry.get("level", 0))
	if not EXPECTED_LEVEL_TOTALS.has(level):
		_errors.append("%s：level 必须是 1/2/3，实际为 %s" % [where, entry.get("level")])
		failed = true

	var bonus_name: String = String(entry.get("bonus", ""))
	var bonus: int = Enums.color_from_string(bonus_name)
	if bonus < 0:
		_errors.append("%s：bonus 不是合法颜色：\"%s\"" % [where, bonus_name])
		failed = true
	elif not Enums.is_purchasable(bonus):
		_errors.append("%s：bonus 不能是 gold" % where)
		failed = true

	var points: int = int(entry.get("points", 0))
	if points < 0:
		_errors.append("%s：points 不能为负数" % where)
		failed = true

	var raw_cost: Variant = entry.get("cost")
	if not raw_cost is Dictionary:
		_errors.append("%s：缺少 cost 对象" % where)
		return null
	var cost: Dictionary = raw_cost
	if cost.is_empty():
		_errors.append("%s：cost 不能为空" % where)
		failed = true
	for color_name: String in cost:
		var color: int = Enums.color_from_string(color_name)
		var amount: int = int(cost[color_name])
		if color < 0:
			_errors.append("%s：cost 里有非法颜色 \"%s\"" % [where, color_name])
			failed = true
			continue
		if not Enums.is_purchasable(color):
			_errors.append("%s：cost 不能包含 gold" % where)
			failed = true
		if amount <= 0:
			_errors.append("%s：cost.%s 必须为正数，实际为 %d" % [where, color_name, amount])
			failed = true
		elif amount > MAX_SINGLE_COST:
			_errors.append("%s：cost.%s = %d 超过单色花费上限 %d"
					% [where, color_name, amount, MAX_SINGLE_COST])
			failed = true

	if failed:
		return null
	return CardData.from_dict(entry)

func _check_level_distribution() -> void:
	for level: int in EXPECTED_LEVEL_TOTALS:
		var actual_total: int = _cards_by_level.get(level, []).size()
		var expected_total: int = EXPECTED_LEVEL_TOTALS[level]
		if actual_total != expected_total:
			_errors.append("cards.json：%d 级卡牌应为 %d 张，实际 %d 张"
					% [level, expected_total, actual_total])
		for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
			var actual: int = _count_cards(level, color)
			var expected: int = EXPECTED_PER_COLOR[level]
			if actual != expected:
				_errors.append("cards.json：%d 级 %s 色卡牌应为 %d 张，实际 %d 张"
						% [level, Enums.color_to_string(color), expected, actual])

func _count_cards(level: int, color: Enums.GemColor) -> int:
	var count: int = 0
	for card: CardData in _cards_by_level.get(level, []):
		if card.bonus == color:
			count += 1
	return count

func _check_anchors() -> void:
	for anchor: Dictionary in ANCHOR_CARDS:
		var expected_cost: String = _canonical_cost(anchor["cost"])
		var found: bool = false
		for card: CardData in _cards_by_level.get(int(anchor["level"]), []):
			if card.bonus != Enums.color_from_string(anchor["bonus"]) \
					or card.points != int(anchor["points"]):
				continue
			if _canonical_cost_by_color(card.cost) == expected_cost:
				found = true
				break
		if not found:
			_errors.append("cards.json：找不到锚点卡（%d 级 %s 加成 %d 分 花费 %s）——整表可能错位了"
					% [anchor["level"], anchor["bonus"], anchor["points"], expected_cost])

## 把「颜色名 -> 数量」的字典（键是字符串，来自 JSON）规范成稳定字符串，用来做与顺序无关的比较。
func _canonical_cost(raw_cost: Dictionary) -> String:
	var parts: Array[String] = []
	for color_name: String in raw_cost:
		parts.append("%s=%d" % [color_name, int(raw_cost[color_name])])
	parts.sort()
	return ",".join(parts)

## 同上，但输入是 Enums.GemColor 作键的字典。
func _canonical_cost_by_color(cost: Dictionary[int, int]) -> String:
	var parts: Array[String] = []
	for color: Enums.GemColor in cost:
		parts.append("%s=%d" % [Enums.color_to_string(color), cost[color]])
	parts.sort()
	return ",".join(parts)

func _load_nobles() -> void:
	var records: Array = _read_records(NOBLES_PATH, "nobles")
	if records.is_empty() and not _errors.is_empty():
		return
	var seen_ids: Dictionary = {}
	for index: int in records.size():
		var entry: Variant = records[index]
		if not entry is Dictionary:
			_errors.append("nobles.json 第 %d 条：必须是对象" % (index + 1))
			continue
		var noble: NobleData = _parse_noble(entry, index, seen_ids)
		if noble != null:
			_nobles.append(noble)
	if _nobles.size() != EXPECTED_NOBLE_COUNT:
		_errors.append("nobles.json：贵族应为 %d 位，实际 %d 位" % [EXPECTED_NOBLE_COUNT, _nobles.size()])

func _parse_noble(entry: Dictionary, index: int, seen_ids: Dictionary) -> NobleData:
	var where: String = "nobles.json 第 %d 条" % (index + 1)
	var noble_id: String = String(entry.get("id", ""))
	if noble_id.is_empty():
		_errors.append("%s：缺少 id" % where)
		return null
	where = "nobles.json %s" % noble_id
	if seen_ids.has(noble_id):
		_errors.append("%s：id 与前面的贵族重复" % where)
		return null
	seen_ids[noble_id] = true
	var failed: bool = false

	var points: int = int(entry.get("points", 0))
	if points != NOBLE_POINTS:
		_errors.append("%s：points 应为 %d，实际为 %d" % [where, NOBLE_POINTS, points])
		failed = true

	var raw_requirement: Variant = entry.get("requirement")
	if not raw_requirement is Dictionary:
		_errors.append("%s：缺少 requirement 对象" % where)
		return null
	var requirement: Dictionary = raw_requirement
	var amounts: Array[int] = []
	for color_name: String in requirement:
		var color: int = Enums.color_from_string(color_name)
		var amount: int = int(requirement[color_name])
		if color < 0:
			_errors.append("%s：requirement 里有非法颜色 \"%s\"" % [where, color_name])
			failed = true
			continue
		if not Enums.is_purchasable(color):
			_errors.append("%s：requirement 不能包含 gold" % where)
			failed = true
		if amount <= 0:
			_errors.append("%s：requirement.%s 必须为正数，实际为 %d" % [where, color_name, amount])
			failed = true
		else:
			amounts.append(amount)
	amounts.sort()
	if not failed and not NOBLE_REQUIREMENT_SHAPES.has(amounts):
		_errors.append("%s：要求必须是「两个 4」或「三个 3」，实际为 %s" % [where, amounts])

	if failed:
		return null
	return NobleData.from_dict(entry)
