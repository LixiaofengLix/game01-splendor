## 阶段 4 的 AI 批量模拟（无界面）：让不同难度的电脑互打，输出胜率 / 平均分 / 回合数。
## 每个种子跑两局，第二局座位列表反转（[A,B] → [B,A]），抵消先手优势；
## 难度个数就是人数（2~4）。--sim 是总局数，必须是偶数。
## 用法：
##   godot --headless --path . tests/ai_sim.tscn -- --sim 100 easy normal [--seed 1]
## 任何一局没有正常结束 / 出现非法动作 / AI 回退时以退出码 1 结束。
extends Node

const USAGE: String = """用法：
  godot --headless --path . tests/ai_sim.tscn -- --sim <偶数局数> <难度1> <难度2> [难度3] [难度4] [--seed <种子>] [--trace]
难度：easy / normal / hard；难度个数 = 人数（2~4）。
示例：
  ... tests/ai_sim.tscn -- --sim 100 easy normal
  ... tests/ai_sim.tscn -- --sim 40 easy normal hard
  ... tests/ai_sim.tscn -- --sim 20 easy normal normal easy --seed 7
  ... tests/ai_sim.tscn -- --sim 2 normal hard --seed 8 --trace   # 打印每一步，排查死循环"""

const PROGRESS_EVERY: int = 10

var _config: RulesConfig
var _catalog: CardCatalog
var _game: GameController
var _last_winners: Array[int] = []
var _last_scores: Dictionary = {}
var _last_finished: int = 0
var _rejections: int = 0
var _ai_fallbacks: int = 0
var _hard_timeout_fallbacks: int = 0
var _hard_node_fallbacks: int = 0
var _stalled_games: int = 0
var _failure_messages: Array[String] = []
var _trace: bool = false

func _ready() -> void:
	if not DataRegistry.is_valid():
		print("数据校验失败，先跑 tests/data_report.tscn：")
		for message: String in DataRegistry.get_errors():
			print("  x %s" % message)
		get_tree().quit(1)
		return
	var parsed: Dictionary = _parse_args(OS.get_cmdline_user_args())
	if parsed.is_empty():
		print(USAGE)
		get_tree().quit(1)
		return
	_config = DataRegistry.rules()
	_catalog = DataRegistry.card_catalog()
	_run(parsed)

# ---------------------------------------------------------------- 参数

func _parse_args(args: PackedStringArray) -> Dictionary:
	var games: int = 0
	var seed_value: int = 1
	var trace: bool = false
	var profiles: Array[String] = []
	var index: int = 0
	while index < args.size():
		var arg: String = args[index]
		match arg:
			"--sim":
				if index + 1 >= args.size():
					print("✗ --sim 后面要跟局数")
					return {}
				games = int(args[index + 1])
				index += 2
			"--seed":
				if index + 1 >= args.size():
					print("✗ --seed 后面要跟整数")
					return {}
				seed_value = int(args[index + 1])
				index += 2
			"--trace":
				trace = true
				index += 1
			_:
				if arg.begins_with("--"):
					print("✗ 未知参数：%s" % arg)
					return {}
				profiles.append(arg)
				index += 1
	if games < 2 or games % 2 != 0:
		print("✗ --sim 必须是大于等于 2 的偶数（每个种子跑两局交换座位），实际为 %d" % games)
		return {}
	if profiles.size() < 2 or profiles.size() > 4:
		print("✗ 难度个数应为 2~4（等于人数），实际为 %d" % profiles.size())
		return {}
	for profile_id: String in profiles:
		if DataRegistry.ai_profile(profile_id) == null:
			print("✗ 未知难度：%s（可用：easy / normal / hard）" % profile_id)
			return {}
	return {
		"games": games,
		"profiles": profiles,
		"seed": seed_value,
		"trace": trace,
	}

# ---------------------------------------------------------------- 模拟

func _run(parsed: Dictionary) -> void:
	var total_games: int = int(parsed["games"])
	var profiles: Array[String] = parsed["profiles"]
	var base_seed: int = int(parsed["seed"])
	var player_count: int = profiles.size()
	var pair_count: int = total_games / 2
	_trace = bool(parsed.get("trace", false))

	var stats: Dictionary = {}
	var unique_profiles: Array[String] = []
	for profile_id: String in profiles:
		if not unique_profiles.has(profile_id):
			unique_profiles.append(profile_id)
		if not stats.has(profile_id):
			stats[profile_id] = {
				"seats": 0, "wins": 0, "ties": 0, "losses": 0,
				"points": 0, "turns": 0, "actions": 0,
			}
	var seat_counts: Dictionary = {}
	for profile_id: String in profiles:
		seat_counts[profile_id] = int(seat_counts.get(profile_id, 0)) + 1

	var seat0_wins: int = 0
	var seat0_games: int = 0
	var hard_think_times: Array[int] = []
	var started: int = Time.get_ticks_msec()
	var done: int = 0

	print("=== AI 批量模拟 ===")
	print("对局数：%d（%d 个种子 × 2 局，第二局镜像交换座位）" % [total_games, pair_count])
	print("座位：%s（%d 人）" % [" ".join(profiles), player_count])
	print("种子：%d..%d" % [base_seed, base_seed + pair_count - 1])
	print("")

	_game = GameController.new()
	add_child(_game)
	_game.game_finished.connect(_on_game_finished)
	_game.action_rejected.connect(_on_action_rejected)
	if _trace:
		_game.events_emitted.connect(_on_trace_events)
		_game.state_changed.connect(_on_trace_state)

	for pair: int in pair_count:
		var seed_value: int = base_seed + pair
		for round_index: int in 2:
			var seats: Array[String] = profiles.duplicate()
			if round_index == 1:
				seats.reverse()
			_last_winners = []
			_last_scores = {}
			_last_finished = 0
			var game_ok: bool = _play_game(seats, seed_value, stats, hard_think_times)
			if game_ok:
				seat0_games += 1
				if _last_winners.has(0):
					seat0_wins += 1
			else:
				_failure_messages.append("种子 %d / 座位 %s 的对局失败" % [seed_value, " ".join(seats)])
			done += 1
			if done % PROGRESS_EVERY == 0 or done == total_games:
				var elapsed_so_far: float = float(Time.get_ticks_msec() - started) / 1000.0
				print("  进度 %d/%d：种子 %d 座位 %s（%.1f 秒）"
						% [done, total_games, seed_value, " ".join(seats), elapsed_so_far])

	var elapsed: float = float(Time.get_ticks_msec() - started) / 1000.0
	remove_child(_game)
	_game.free()

	print("")
	print("难度    局数   胜   平   负   胜率     平均分  平均回合  平均动作")
	for profile_id: String in unique_profiles:
		var entry: Dictionary = stats[profile_id]
		var seats_played: int = int(entry["seats"])
		var wins: int = int(entry["wins"])
		var ties: int = int(entry["ties"])
		var losses: int = int(entry["losses"])
		var win_rate: float = 0.0
		if seats_played > 0:
			win_rate = (float(wins) + float(ties) * 0.5) / float(seats_played) * 100.0
		print("%-7s %5d %4d %4d %4d %6.1f%% %8.1f %9.1f %9.1f"
				% [profile_id, seats_played, wins, ties, losses, win_rate,
				float(entry["points"]) / float(maxi(seats_played, 1)),
				float(entry["turns"]) / float(maxi(seats_played, 1)),
				float(entry["actions"]) / float(maxi(seats_played, 1))])
	print("")
	print("每档局数 = 该难度占用的座位数（%s）× 总对局数 %d。"
			% [_seat_count_text(seat_counts, unique_profiles), total_games])
	if seat0_games > 0:
		print("先手（座位 0）胜率：%.1f%%（%d 局）"
				% [float(seat0_wins) / float(seat0_games) * 100.0, seat0_games])
	if not hard_think_times.is_empty():
		var sorted_times: Array[int] = hard_think_times.duplicate()
		sorted_times.sort()
		var p50: int = sorted_times[int(sorted_times.size() * 0.5)]
		var p95: int = sorted_times[mini(sorted_times.size() - 1, int(sorted_times.size() * 0.95))]
		var max_ms: int = sorted_times[sorted_times.size() - 1]
		print("困难 AI 思考：p50 %dms / p95 %dms / max %dms（%d 次决策）；超时回退 %d 次，节点预算回退 %d 次"
				% [p50, p95, max_ms, sorted_times.size(),
				_hard_timeout_fallbacks, _hard_node_fallbacks])
	print("非正常终局（stalled 保险丝）：%d 局" % _stalled_games)
	print("非法动作 / 拒绝：%d 次；AI 回退：%d 次" % [_rejections, _ai_fallbacks])
	print("用时：%.1f 秒" % elapsed)

	if _rejections > 0 or _ai_fallbacks > 0 or not _failure_messages.is_empty():
		for message: String in _failure_messages:
			print("✗ %s" % message)
		print("失败：模拟过程中出现了非法动作 / 未结束的对局。")
		get_tree().quit(1)
		return
	print("OK —— %d 局全部正常结束。" % total_games)
	get_tree().quit(0)

## 跑一局；统计写进 stats，hard 的思考时间写进 hard_think_times。
func _play_game(seats: Array[String], seed_value: int, stats: Dictionary,
		hard_think_times: Array[int]) -> bool:
	var controllers: Array[PlayerController] = []
	var bots: Array[BotController] = []
	for seat: int in seats.size():
		var profile: AIProfile = DataRegistry.ai_profile(seats[seat])
		var bot := BotController.new()
		bot.configure(profile, _catalog, _config,
				BotController.derive_seed(seed_value, seat, profile.seed_salt), 0.0)
		controllers.append(bot)
		bots.append(bot)
	var started: bool = _game.start_with_controllers(seats.size(), seed_value, controllers)
	_collect_bot_stats(seats, bots, hard_think_times)
	if not started:
		return false
	if _last_finished != 1:
		return false
	var view: Dictionary = _game.current_view()
	if String(view.get("phase", "")) != "finished" or _last_winners.is_empty():
		return false
	if String(view.get("finished_reason", "")) != "win_points":
		_stalled_games += 1
	var counts: Array = view.get("turn_counts", [])
	if counts.is_empty():
		return false
	var turns: int = int(counts[0])
	for count: Variant in counts:
		if int(count) != turns:
			return false
	var action_count: int = _game.action_count()
	for seat: int in seats.size():
		var profile_id: String = seats[seat]
		var entry: Dictionary = stats[profile_id]
		entry["seats"] = int(entry["seats"]) + 1
		entry["points"] = int(entry["points"]) + int(_last_scores.get(str(seat), 0))
		entry["turns"] = int(entry["turns"]) + turns
		entry["actions"] = int(entry["actions"]) + action_count
		if _last_winners.has(seat):
			if _last_winners.size() > 1:
				entry["ties"] = int(entry["ties"]) + 1
			else:
				entry["wins"] = int(entry["wins"]) + 1
		else:
			entry["losses"] = int(entry["losses"]) + 1
	return true

## 收集本局每个 AI 的 fallback 计数 / 困难 AI 的思考时间（必须在控制器释放前调用）。
func _collect_bot_stats(seats: Array[String], bots: Array[BotController],
		hard_think_times: Array[int]) -> void:
	for seat: int in bots.size():
		var bot: BotController = bots[seat]
		_ai_fallbacks += bot.fallback_count
		if seats[seat] == "hard":
			_hard_timeout_fallbacks += bot.timeout_fallbacks
			_hard_node_fallbacks += bot.node_limit_fallbacks
			hard_think_times.append_array(bot.think_times)

func _on_game_finished(winners: Array[int], scores: Dictionary) -> void:
	_last_finished += 1
	_last_winners = winners.duplicate()
	_last_scores = scores.duplicate()

func _on_trace_events(events: Array[GameEvent]) -> void:
	for event: GameEvent in events:
		if event.type == Enums.EventType.TURN_STARTED \
				or event.type == Enums.EventType.TURN_ENDED:
			continue
		print("    [动作 %d] %s" % [_game.action_count(), event.describe()])

func _on_trace_state(view: Dictionary) -> void:
	var count: int = _game.action_count()
	if count % 50 == 0:
		print("    ... 动作 %d，回合数 %s，阶段 %s，当前座位 %d"
				% [count, str(view.get("turn_counts", [])), view.get("phase", "?"),
				int(view.get("current_seat", -1))])

func _on_action_rejected(message: String) -> void:
	_rejections += 1
	if _failure_messages.size() < 10:
		_failure_messages.append("动作被拒绝：" + message)

func _seat_count_text(seat_counts: Dictionary, unique_profiles: Array[String]) -> String:
	var parts: Array[String] = []
	for profile_id: String in unique_profiles:
		parts.append("%s×%d" % [profile_id, int(seat_counts.get(profile_id, 0))])
	return "，".join(parts)
