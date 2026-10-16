## 一局游戏的规则参数（对应 data/rules.json）。
## core/ 不读文件也不读单例：规则函数需要的所有数值都从这个对象取，方便存档与测试替换。
class_name RulesConfig
extends RefCounted

var schema_version: int = 0
## 人数 -> 每种颜色的宝石枚数（2 人 4 / 3 人 5 / 4 人 7）。
var gems_per_color: Dictionary[int, int] = {}
## 人数 -> 贵族张数（= 人数 + 1）。
var nobles_count: Dictionary[int, int] = {}
var gold_count: int = 0
var win_points: int = 0
## 回合结束时允许持有的宝石上限（含金币）。
var max_tokens: int = 0
## 每人最多预留的卡牌数。
var max_reserved: int = 0
## 每级场面翻开的卡牌数。
var board_slots_per_level: int = 0
## 拿两枚同色时，该颜色在银行里至少要有这么多枚。
var take_two_min_remaining: int = 0
## 规则细节开关，含义见 data/README.md。
var switches: Dictionary[String, bool] = {}

static func from_dict(data: Dictionary) -> RulesConfig:
	var config := RulesConfig.new()
	config.schema_version = int(data.get("schema_version", 0))
	var raw_players: Dictionary = data.get("players", {})
	for key: Variant in raw_players:
		var player_count: int = int(key)
		var entry: Dictionary = raw_players[key]
		config.gems_per_color[player_count] = int(entry.get("gems_per_color", 0))
		config.nobles_count[player_count] = int(entry.get("nobles", 0))
	config.gold_count = int(data.get("gold_count", 0))
	config.win_points = int(data.get("win_points", 0))
	config.max_tokens = int(data.get("max_tokens", 0))
	config.max_reserved = int(data.get("max_reserved", 0))
	config.board_slots_per_level = int(data.get("board_slots_per_level", 0))
	config.take_two_min_remaining = int(data.get("take_two_min_remaining", 0))
	var raw_switches: Dictionary = data.get("switches", {})
	for switch_name: String in raw_switches:
		config.switches[switch_name] = bool(raw_switches[switch_name])
	return config

## 支持的人数，升序。
func supported_player_counts() -> Array[int]:
	var counts: Array[int] = []
	for player_count: int in gems_per_color:
		counts.append(player_count)
	counts.sort()
	return counts

func gems_per_color_for(player_count: int) -> int:
	return gems_per_color.get(player_count, 0)

func nobles_for(player_count: int) -> int:
	return nobles_count.get(player_count, 0)

## 取开关。名字写错时返回 false 并报错，避免"开关拼错导致规则静默变形"。
func is_enabled(switch_name: String) -> bool:
	if not switches.has(switch_name):
		push_error("rules.json 里没有开关 %s" % switch_name)
		return false
	return switches[switch_name]
