## 一档程序 AI 的配置（对应 data/ai/*.json）：策略、搜索预算、思考延迟与评分权重。
## 权重全部是整数（"厘分"，100 = 1 分），扣分项在代码里应用符号；本类只负责解析与校验。
## 由 DataRegistry 加载并校验，校验失败时逐条写进 errors，不静默使用坏配置。
class_name AIProfile
extends RefCounted

const SCHEMA_VERSION: int = 1

const STRATEGY_GREEDY: String = "greedy"
const STRATEGY_ONE_STEP: String = "one_step"
const STRATEGY_TWO_PLY: String = "two_ply"
const STRATEGIES: Array[String] = [STRATEGY_GREEDY, STRATEGY_ONE_STEP, STRATEGY_TWO_PLY]

## 权重键必须恰好是这一组（拼错 / 多写 / 少写都会报错）。
const WEIGHT_KEYS: Array[String] = [
	"points", "card_bonus", "token", "gold", "noble_gap",
	"target_points", "target_bonus", "target_gap",
	"affordable", "opponent_threat", "block_bonus", "reserve_gap",
	"waste", "win",
]

var id: String = ""
var display_name: String = ""
var strategy: String = ""
## 用于派生每个座位的随机种子（不同难度用不同的盐）。
var seed_salt: int = 0
## 界面观察用的思考延迟；模拟 / 自检会覆盖为 0。
var thinking_delay_ms: int = 0
## 简单难度的随机扰动幅度（厘分）。
var random_noise: int = 0
## 简单难度“偶尔犯错”的概率（0~1）。
var mistake_chance: float = 0.0

# 搜索预算（two_ply 才用到；其他策略允许为 0）。
var top_k: int = 1
var opponent_top_m: int = 0
var max_nodes: int = 0
var timeout_ms: int = 0

# 评分权重（厘分）。
var weight_points: int = 0
var weight_card_bonus: int = 0
var weight_token: int = 0
var weight_gold: int = 0
var weight_noble_gap: int = 0
var weight_target_points: int = 0
var weight_target_bonus: int = 0
var weight_target_gap: int = 0
var weight_affordable: int = 0
var weight_opponent_threat: int = 0
var weight_block_bonus: int = 0
var weight_reserve_gap: int = 0
var weight_waste: int = 0
var weight_win: int = 0

## 从 JSON 解析。expected_id 是文件名（如 "easy"），必须与 data.id 一致。
## 有任何问题都写进 errors 并返回 null。
static func from_dict(data: Dictionary, expected_id: String, errors: Array[String]) -> AIProfile:
	var before: int = errors.size()
	if int(data.get("schema_version", 0)) != SCHEMA_VERSION:
		errors.append("ai/%s.json：schema_version 应为 %d，实际为 %s"
				% [expected_id, SCHEMA_VERSION, data.get("schema_version")])

	var profile := AIProfile.new()
	profile.id = String(data.get("id", ""))
	if profile.id != expected_id:
		errors.append("ai/%s.json：id 应为 \"%s\"，实际为 \"%s\""
				% [expected_id, expected_id, profile.id])
	profile.display_name = String(data.get("display_name", expected_id))
	profile.strategy = String(data.get("strategy", ""))
	if not STRATEGIES.has(profile.strategy):
		errors.append("ai/%s.json：strategy 必须是 %s，实际为 \"%s\""
				% [expected_id, str(STRATEGIES), profile.strategy])
	profile.seed_salt = int(data.get("seed_salt", 0))
	profile.thinking_delay_ms = int(data.get("thinking_delay_ms", -1))
	if profile.thinking_delay_ms < 0:
		errors.append("ai/%s.json：thinking_delay_ms 不能为负数" % expected_id)
	profile.random_noise = int(data.get("random_noise", -1))
	if profile.random_noise < 0:
		errors.append("ai/%s.json：random_noise 不能为负数" % expected_id)
	profile.mistake_chance = float(data.get("mistake_chance", -1.0))
	if profile.mistake_chance < 0.0 or profile.mistake_chance > 1.0:
		errors.append("ai/%s.json：mistake_chance 必须在 0~1 之间" % expected_id)

	var raw_search: Variant = data.get("search")
	if not raw_search is Dictionary:
		errors.append("ai/%s.json：缺少 search 对象" % expected_id)
	else:
		var search: Dictionary = raw_search
		profile.top_k = int(search.get("top_k", -1))
		profile.opponent_top_m = int(search.get("opponent_top_m", -1))
		profile.max_nodes = int(search.get("max_nodes", -1))
		profile.timeout_ms = int(search.get("timeout_ms", -1))
		if profile.top_k < 1:
			errors.append("ai/%s.json：search.top_k 至少为 1" % expected_id)
		if profile.opponent_top_m < 0:
			errors.append("ai/%s.json：search.opponent_top_m 不能为负数" % expected_id)
		if profile.max_nodes < 0:
			errors.append("ai/%s.json：search.max_nodes 不能为负数" % expected_id)
		if profile.timeout_ms < 0:
			errors.append("ai/%s.json：search.timeout_ms 不能为负数" % expected_id)
		if profile.strategy == STRATEGY_TWO_PLY:
			if profile.opponent_top_m < 1:
				errors.append("ai/%s.json：two_ply 的 search.opponent_top_m 至少为 1" % expected_id)
			if profile.max_nodes < 1:
				errors.append("ai/%s.json：two_ply 的 search.max_nodes 至少为 1" % expected_id)
			if profile.timeout_ms < 1:
				errors.append("ai/%s.json：two_ply 的 search.timeout_ms 至少为 1" % expected_id)

	var raw_weights: Variant = data.get("weights")
	if not raw_weights is Dictionary:
		errors.append("ai/%s.json：缺少 weights 对象" % expected_id)
	else:
		var weights: Dictionary = raw_weights
		for key: String in WEIGHT_KEYS:
			if not weights.has(key):
				errors.append("ai/%s.json：weights 缺少 %s" % [expected_id, key])
		for key: String in weights:
			if not WEIGHT_KEYS.has(key):
				errors.append("ai/%s.json：weights 里有未知键 %s（拼错了？）" % [expected_id, key])
		profile.weight_points = _weight(weights, "points", expected_id, errors)
		profile.weight_card_bonus = _weight(weights, "card_bonus", expected_id, errors)
		profile.weight_token = _weight(weights, "token", expected_id, errors)
		profile.weight_gold = _weight(weights, "gold", expected_id, errors)
		profile.weight_noble_gap = _weight(weights, "noble_gap", expected_id, errors)
		profile.weight_target_points = _weight(weights, "target_points", expected_id, errors)
		profile.weight_target_bonus = _weight(weights, "target_bonus", expected_id, errors)
		profile.weight_target_gap = _weight(weights, "target_gap", expected_id, errors)
		profile.weight_affordable = _weight(weights, "affordable", expected_id, errors)
		profile.weight_opponent_threat = _weight(weights, "opponent_threat", expected_id, errors)
		profile.weight_block_bonus = _weight(weights, "block_bonus", expected_id, errors)
		profile.weight_reserve_gap = _weight(weights, "reserve_gap", expected_id, errors)
		profile.weight_waste = _weight(weights, "waste", expected_id, errors)
		profile.weight_win = _weight(weights, "win", expected_id, errors)
		if profile.weight_win <= 0:
			errors.append("ai/%s.json：weights.win 必须为正数" % expected_id)

	if errors.size() > before:
		return null
	return profile

static func _weight(weights: Dictionary, key: String, expected_id: String,
		errors: Array[String]) -> int:
	if not weights.has(key):
		return 0
	var value: int = int(weights[key])
	if value < 0:
		errors.append("ai/%s.json：weights.%s 不能为负数" % [expected_id, key])
	return value
