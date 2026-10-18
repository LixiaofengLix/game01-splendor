## 阶段 4 的 AI 自检（无界面，改完 ai/ 就跑一次）：
## 1) 三档 AIProfile 加载与坏配置校验（策略 / 权重键 / 数值范围）；
## 2) 全 AI 对局（2/3/4 人，delay=0）：无非法动作、无 fallback、正常结束、回合数相同；
## 3) 同种子同座位重开两次，动作序列与最终指纹一致；
## 4) 预设局面里的决策（含弃宝石 / 选贵族阶段）都合法，且只依赖过滤视图；
## 5) 困难 AI 的思考耗时 p50/p95/max，超时 / 节点预算回退次数为 0。
## 用法：godot --headless --path . tests/ai_selfcheck.tscn
## 任何一处违反都会打印原因，并以退出码 1 结束。
extends Node

const MAX_PRINTED_FAILURES: int = 30
const RNG_SEED: int = 20261017
const HARD_MAX_THINK_MS: int = 1000
const SCENARIOS: Array[String] = ["token_limit", "two_nobles", "endgame"]

class GameRecord:
	var rejected: int = 0
	var finished: int = 0
	var winners: Array[int] = []
	var scores: Dictionary = {}
	var final_view: Dictionary = {}
	var fallbacks: int = 0
	var timeout_fallbacks: int = 0
	var node_limit_fallbacks: int = 0
	var max_think_ms: int = 0
	var replay_actions: Array = []
	var fingerprint: String = ""

var _config: RulesConfig
var _catalog: CardCatalog
var _failures: int = 0
var _checks: int = 0
var _hard_think_times: Array[int] = []
var _hard_timeout_fallbacks: int = 0
var _hard_node_fallbacks: int = 0

func _ready() -> void:
	if not DataRegistry.is_valid():
		print("数据校验失败，先跑 tests/data_report.tscn：")
		for message: String in DataRegistry.get_errors():
			print("  x %s" % message)
		get_tree().quit(1)
		return
	_config = DataRegistry.rules()
	_catalog = DataRegistry.card_catalog()
	var started: int = Time.get_ticks_msec()
	print("=== AI 自检 ===")
	_check_profiles()
	_check_profile_validation()
	_check_games()
	_check_determinism()
	_check_scenarios()
	_check_hard_timing()
	var elapsed: float = float(Time.get_ticks_msec() - started) / 1000.0
	print("")
	if _failures == 0:
		print("OK —— 共 %d 项检查全部通过，用时 %.1f 秒。" % [_checks, elapsed])
		get_tree().quit(0)
		return
	print("失败：%d 处（共 %d 项检查，用时 %.1f 秒）" % [_failures, _checks, elapsed])
	get_tree().quit(1)

# ---------------------------------------------------------------- 配置

func _check_profiles() -> void:
	var expected: Dictionary = {"easy": AIProfile.STRATEGY_GREEDY,
			"normal": AIProfile.STRATEGY_ONE_STEP, "hard": AIProfile.STRATEGY_TWO_PLY}
	for profile_id: String in DataRegistry.ai_profile_ids():
		var profile: AIProfile = DataRegistry.ai_profile(profile_id)
		_check(profile != null, "AI 配置 %s 应加载成功" % profile_id)
		if profile == null:
			continue
		_check(profile.id == profile_id, "AI 配置 %s 的 id 应与文件名一致" % profile_id)
		_check(profile.strategy == expected[profile_id],
				"AI 配置 %s 的策略应为 %s" % [profile_id, expected[profile_id]])
		_check(profile.weight_points > 0 and profile.weight_win > 0,
				"AI 配置 %s 的核心权重应为正数" % profile_id)
	print("  三档 AI 配置加载 ✓")

func _check_profile_validation() -> void:
	var normal: Dictionary = _read_json("res://data/ai/normal.json")
	var hard: Dictionary = _read_json("res://data/ai/hard.json")

	var bad_strategy: Dictionary = normal.duplicate(true)
	bad_strategy["strategy"] = "no_such_strategy"
	_check(_expect_profile_error(bad_strategy, "normal"), "非法 strategy 应被拒绝")

	var bad_weight: Dictionary = normal.duplicate(true)
	(bad_weight["weights"] as Dictionary).erase("points")
	(bad_weight["weights"] as Dictionary)["point"] = 100
	_check(_expect_profile_error(bad_weight, "normal"), "权重键拼错应被拒绝")

	var bad_chance: Dictionary = normal.duplicate(true)
	bad_chance["mistake_chance"] = 1.5
	_check(_expect_profile_error(bad_chance, "normal"), "mistake_chance 超范围应被拒绝")

	var bad_search: Dictionary = hard.duplicate(true)
	(bad_search["search"] as Dictionary)["top_k"] = 0
	_check(_expect_profile_error(bad_search, "hard"), "two_ply 的 top_k=0 应被拒绝")
	print("  坏配置校验 ✓")

func _expect_profile_error(data: Dictionary, expected_id: String) -> bool:
	var errors: Array[String] = []
	var profile: AIProfile = AIProfile.from_dict(data, expected_id, errors)
	return profile == null and not errors.is_empty()

# ---------------------------------------------------------------- 全 AI 对局

func _check_games() -> void:
	_run_game("easy 2 人 #1", ["easy", "easy"], RNG_SEED + 1)
	_run_game("easy 2 人 #2", ["easy", "easy"], RNG_SEED + 2)
	_run_game("normal 2 人 #1", ["normal", "normal"], RNG_SEED + 3)
	_run_game("normal 2 人 #2", ["normal", "normal"], RNG_SEED + 4)
	_run_game("hard 2 人", ["hard", "hard"], RNG_SEED + 5)
	_run_game("3 人混合", ["easy", "normal", "normal"], RNG_SEED + 6)
	_run_game("4 人混合", ["easy", "normal", "normal", "easy"], RNG_SEED + 7)
	print("  全 AI 对局（2/3/4 人）✓")

func _run_game(where: String, profile_ids: Array[String], seed_value: int) -> void:
	var record: GameRecord = _play_game(profile_ids, seed_value)
	_check(record.rejected == 0, "%s：不应有 action_rejected" % where)
	_check(record.finished == 1, "%s：game_finished 应发一次（实际 %d）" % [where, record.finished])
	_check(not record.winners.is_empty(), "%s：应有胜者" % where)
	_check(record.scores.size() == profile_ids.size(),
			"%s：比分应覆盖 %d 个座位" % [where, profile_ids.size()])
	_check(String(record.final_view.get("phase", "")) == "finished",
			"%s：最终阶段应为 finished" % where)
	_check(String(record.final_view.get("finished_reason", "")) == "win_points",
			"%s：应以 win_points 正常结束（实际 %s）"
			% [where, record.final_view.get("finished_reason", "?")])
	_check(record.fallbacks == 0, "%s：AI 不应回退到第一个合法动作" % where)
	_check(record.max_think_ms <= HARD_MAX_THINK_MS,
			"%s：单步思考 %dms 超过 %dms" % [where, record.max_think_ms, HARD_MAX_THINK_MS])
	var counts: Array = record.final_view.get("turn_counts", [])
	if counts.is_empty():
		_fail("%s：turn_counts 为空" % where)
	else:
		for count: Variant in counts:
			if int(count) != int(counts[0]):
				_fail("%s：终局时回合数不相同：%s" % [where, str(counts)])
				break
	_check(not record.final_view.has("seed") and not record.final_view.has("rng_state"),
			"%s：AI 视图里不应有种子 / 随机数状态" % where)
	var decks: Dictionary = record.final_view.get("decks", {})
	for level: int in [1, 2, 3]:
		var entry: Dictionary = decks.get(str(level), {})
		_check(not entry.has("cards"), "%s：AI 视图里不应有 %d 级牌堆顺序" % [where, level])

func _play_game(profile_ids: Array[String], seed_value: int) -> GameRecord:
	var record := GameRecord.new()
	var game := GameController.new()
	add_child(game)
	game.action_rejected.connect(func(_message: String) -> void: record.rejected += 1)
	game.game_finished.connect(func(winners: Array[int], scores: Dictionary) -> void:
		record.finished += 1
		record.winners = winners.duplicate()
		record.scores = scores.duplicate())
	var controllers: Array[PlayerController] = []
	for seat: int in profile_ids.size():
		var profile: AIProfile = DataRegistry.ai_profile(profile_ids[seat])
		var bot := BotController.new()
		bot.configure(profile, _catalog, _config,
				BotController.derive_seed(seed_value, seat, profile.seed_salt), 0.0)
		controllers.append(bot)
	if not game.start_with_controllers(profile_ids.size(), seed_value, controllers):
		_fail("种子 %d：start_with_controllers 返回失败" % seed_value)
		remove_child(game)
		game.free()
		return record
	record.final_view = game.current_view()
	record.replay_actions = (game.build_replay_data().get("actions", []) as Array).duplicate(true)
	record.fingerprint = game.fingerprint()
	for seat: int in controllers.size():
		var bot: BotController = controllers[seat] as BotController
		record.fallbacks += bot.fallback_count
		record.timeout_fallbacks += bot.timeout_fallbacks
		record.node_limit_fallbacks += bot.node_limit_fallbacks
		record.max_think_ms = maxi(record.max_think_ms, bot.max_think_ms)
		if profile_ids[seat] == "hard":
			_hard_think_times.append_array(bot.think_times)
			_hard_timeout_fallbacks += bot.timeout_fallbacks
			_hard_node_fallbacks += bot.node_limit_fallbacks
	_check(record.timeout_fallbacks == 0, "种子 %d：不应有超时回退" % seed_value)
	_check(record.node_limit_fallbacks == 0, "种子 %d：不应有节点预算回退" % seed_value)
	remove_child(game)
	game.free()
	return record

# ---------------------------------------------------------------- 确定性

func _check_determinism() -> void:
	var first: GameRecord = _play_game(["normal", "hard"], RNG_SEED + 8)
	var second: GameRecord = _play_game(["normal", "hard"], RNG_SEED + 8)
	_check(first.finished == 1 and second.finished == 1, "确定性对局应正常结束")
	_check(JSON.stringify(first.replay_actions) == JSON.stringify(second.replay_actions),
			"同种子同座位：动作序列应完全一致")
	_check(first.fingerprint == second.fingerprint, "同种子同座位：最终指纹应一致")
	print("  同种子可复现 ✓")

# ---------------------------------------------------------------- 预设局面

func _check_scenarios() -> void:
	for scenario: String in SCENARIOS:
		var data: Dictionary = _read_json("res://tests/scenarios/%s.json" % scenario)
		var state_data: Dictionary = SaveFile.unwrap_snapshot(data)
		var errors: Array[String] = []
		var state: GameState = GameState.from_dict(state_data, _config, _catalog, errors)
		_check(state != null, "%s：快照载入失败：%s" % [scenario, "；".join(errors)])
		if state == null:
			continue
		_check_ai_choice("%s 正常阶段" % scenario, state)
	# token_limit / two_nobles 再额外验证“动作触发选择阶段后”的决策。
	_check_triggered_phase("token_limit", Enums.GamePhase.DISCARD)
	_check_triggered_phase("two_nobles", Enums.GamePhase.CHOOSE_NOBLE)
	print("  预设局面决策 ✓")

func _check_triggered_phase(scenario: String, expected_phase: Enums.GamePhase) -> void:
	var data: Dictionary = _read_json("res://tests/scenarios/%s.json" % scenario)
	var state_data: Dictionary = SaveFile.unwrap_snapshot(data)
	var errors: Array[String] = []
	var state: GameState = GameState.from_dict(state_data, _config, _catalog, errors)
	if state == null:
		return
	var view: Dictionary = state.to_dict(state.current_seat)
	var legal: Array[Action] = Rules.get_legal_actions(view, _catalog, _config)
	var trigger: Action = null
	for action: Action in legal:
		if action.type == Enums.ActionType.TAKE_THREE or action.type == Enums.ActionType.TAKE_TWO:
			trigger = action
			break
	if trigger == null:
		_fail("%s：找不到触发选择阶段的拿宝石动作" % scenario)
		return
	var after: GameState = state.duplicate_state()
	Rules.apply(after, trigger)
	_check(after.phase == expected_phase,
			"%s：拿宝石后应进入 %s 阶段，实际 %s"
			% [scenario, Enums.phase_to_string(expected_phase), Enums.phase_to_string(after.phase)])
	_check_ai_choice("%s 的 %s 阶段" % [scenario, Enums.phase_to_string(after.phase)], after)

func _check_ai_choice(where: String, state: GameState) -> void:
	var view: Dictionary = state.to_dict(state.current_seat)
	var legal: Array[Action] = Rules.get_legal_actions(view, _catalog, _config)
	_check(not legal.is_empty(), "%s：当前玩家应有合法动作" % where)
	if legal.is_empty():
		return
	for profile_id: String in DataRegistry.ai_profile_ids():
		var profile: AIProfile = DataRegistry.ai_profile(profile_id)
		var evaluator := AIEvaluator.new(profile, _catalog, _config, 12345)
		var action: Action = evaluator.choose_action(view, legal, state.current_seat)
		_check(action != null and Rules.is_action_legal(view, _catalog, _config, action),
				"%s：%s AI 应选择合法动作" % [where, profile_id])

# ---------------------------------------------------------------- 困难耗时

func _check_hard_timing() -> void:
	if _hard_think_times.is_empty():
		_fail("没有收集到困难 AI 的思考时间")
		return
	var sorted: Array[int] = _hard_think_times.duplicate()
	sorted.sort()
	var p50: int = sorted[int(sorted.size() * 0.5)]
	var p95: int = sorted[mini(sorted.size() - 1, int(sorted.size() * 0.95))]
	var max_ms: int = sorted[sorted.size() - 1]
	print("  困难 AI 思考耗时：p50 %dms / p95 %dms / max %dms（%d 次决策）"
			% [p50, p95, max_ms, sorted.size()])
	_check(max_ms <= HARD_MAX_THINK_MS,
			"困难 AI 单步思考 %dms 超过 %dms" % [max_ms, HARD_MAX_THINK_MS])
	_check(_hard_timeout_fallbacks == 0, "困难 AI 不应触发超时回退（%d 次）" % _hard_timeout_fallbacks)
	_check(_hard_node_fallbacks == 0, "困难 AI 不应触发节点预算回退（%d 次）" % _hard_node_fallbacks)

# ---------------------------------------------------------------- 工具

func _read_json(path: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		_fail("读不了 %s" % path)
		return {}
	return json.data

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	_failures += 1
	if _failures <= MAX_PRINTED_FAILURES:
		print("✗ %s" % message)
	elif _failures == MAX_PRINTED_FAILURES + 1:
		print("…… 后面的失败不再逐条打印")
