## 阶段 3 的对局流程自检（无界面，改完 game/ 就跑一次）：
## 1) 用同步控制器（只拿到过滤视图 + 合法动作）跑 2/3/4 人局，检查 GameController 的信号、
##    视图不含隐藏信息、AI 只收到合法动作、对局能正常结束；
## 2) 非法动作会被 action_rejected 拒绝，然后控制器可以继续；
## 3) 存档（种子 + 动作序列）重放后指纹一致；六个预设快照都能载入。
## 用法：godot --headless --path . tests/flow_selfcheck.tscn
## 任何一处违反都会打印原因，并以退出码 1 结束。
extends Node

const GAMES_PER_COUNT: int = 10
const RNG_SEED: int = 20261017
const MAX_PRINTED_FAILURES: int = 30
const SCENARIOS: Array[String] = [
	"token_limit", "two_nobles", "endgame", "bank_edges", "colors_short", "deck_empty",
]

## 只依赖 PlayerController 接口的测试控制器：从合法动作里随机挑一个（同步决定）。
class RandomController extends PlayerController:
	var rng := RandomNumberGenerator.new()
	var on_view: Callable = Callable()
	var requests: int = 0
	var max_requests: int = 5000

	func _init(p_seed: int = 0) -> void:
		rng.seed = p_seed

	func request_action(view: Dictionary, legal_actions: Array[Action]) -> void:
		requests += 1
		if on_view.is_valid():
			on_view.call(seat, view, legal_actions)
		if requests > max_requests:
			push_error("RandomController：请求次数超过 %d，停止" % max_requests)
			return
		if legal_actions.is_empty():
			push_error("RandomController：没有合法动作")
			return
		action_decided.emit(legal_actions[rng.randi_range(0, legal_actions.size() - 1)])

## 先提交一个必然非法的动作，再正常走——验证 action_rejected 与重试路径。
class IllegalOnceController extends PlayerController:
	var sent_illegal: bool = false

	func request_action(_view: Dictionary, legal_actions: Array[Action]) -> void:
		if not sent_illegal:
			sent_illegal = true
			action_decided.emit(Action.purchase("NO-SUCH-CARD"))
			return
		if legal_actions.is_empty():
			push_error("IllegalOnceController：没有合法动作")
			return
		action_decided.emit(legal_actions[0])

class GameRecord:
	var states: int = 0
	var events: int = 0
	var finished: int = 0
	var rejected: int = 0
	var winners: Array[int] = []
	var scores: Dictionary = {}
	var last_view: Dictionary = {}
	var event_types: Dictionary = {}

var _config: RulesConfig
var _catalog: CardCatalog
var _failures: int = 0
var _checks: int = 0
var _reject_messages: Array[String] = []

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
	print("=== 对局流程自检：2/3/4 人各 %d 局 ===" % GAMES_PER_COUNT)
	for player_count: int in [2, 3, 4]:
		for game_index: int in GAMES_PER_COUNT:
			_check_random_game(player_count, RNG_SEED + player_count * 10000 + game_index)
		print("  %d 人局：%d 局 ✓" % [player_count, GAMES_PER_COUNT])
	_check_illegal_rejection()
	_check_snapshot_loading()
	var elapsed: float = float(Time.get_ticks_msec() - started) / 1000.0
	print("")
	if _failures == 0:
		print("OK —— 共 %d 项检查全部通过，用时 %.1f 秒。" % [_checks, elapsed])
		get_tree().quit(0)
		return
	print("失败：%d 处（共 %d 项检查，用时 %.1f 秒）" % [_failures, _checks, elapsed])
	get_tree().quit(1)

# ---------------------------------------------------------------- 随机对局

func _check_random_game(player_count: int, seed_value: int) -> void:
	var where: String = "%d 人局 种子 %d" % [player_count, seed_value]
	var game := GameController.new()
	add_child(game)
	var record := GameRecord.new()
	game.state_changed.connect(_on_state_changed.bind(record, where))
	game.events_emitted.connect(_on_events.bind(record, where))
	game.game_finished.connect(_on_finished.bind(record, where))
	game.action_rejected.connect(_on_rejected.bind(record, where))
	var controllers: Array[PlayerController] = []
	for seat: int in player_count:
		var controller := RandomController.new(seed_value * 31 + seat)
		controller.on_view = _check_controller_view.bind(where)
		controllers.append(controller)
	if not game.start_with_controllers(player_count, seed_value, controllers):
		_fail(where, "start_with_controllers 返回失败")
		game.queue_free()
		return
	_checks += 1
	if record.rejected != 0:
		_fail(where, "随机合法动作被拒绝了 %d 次" % record.rejected)
	if record.finished != 1:
		_fail(where, "对局结束时 game_finished 发了 %d 次（应为 1）" % record.finished)
	if record.states == 0:
		_fail(where, "没有收到 state_changed")
	if record.events == 0:
		_fail(where, "没有收到 events_emitted")
	if String(record.last_view.get("phase", "")) != "finished":
		_fail(where, "最后一次 state_changed 的 phase 不是 finished：%s"
				% record.last_view.get("phase", "?"))
	if record.winners.is_empty():
		_fail(where, "对局结束但没有胜者")
	if record.scores.size() != player_count:
		_fail(where, "比分里应有 %d 个座位，实际 %d 个" % [player_count, record.scores.size()])
	if not record.event_types.has("game_finished"):
		_fail(where, "事件流里没有 game_finished")
	_check_turn_counts_equal(record.last_view, where)
	if not game.can_save_replay():
		_fail(where, "新开的一局应该可以存成重放文件")
	else:
		_check_replay(game, where)
	game.queue_free()

func _on_state_changed(view: Dictionary, record: GameRecord, where: String) -> void:
	record.states += 1
	record.last_view = view
	_checks += 1
	if int(view.get("viewer_seat", -99)) != int(view.get("current_seat", -100)):
		_fail(where, "state_changed 的视图不是当前玩家的视图")
	if view.has("seed") or view.has("rng_state"):
		_fail(where, "视图里有种子 / 随机数状态")
	var decks: Dictionary = view.get("decks", {})
	for level: int in [1, 2, 3]:
		if (decks.get(str(level), {}) as Dictionary).has("cards"):
			_fail(where, "视图里有 %d 级牌堆顺序" % level)
	if String(view.get("phase", "")) != "finished" \
			and Rules.get_legal_actions(view, _catalog, _config).is_empty():
		_fail(where, "当前玩家没有合法动作，但阶段不是 finished")

func _on_events(events: Array[GameEvent], record: GameRecord, _where: String) -> void:
	for event: GameEvent in events:
		record.events += 1
		record.event_types[Enums.event_type_to_string(event.type)] = true

func _on_finished(winners: Array[int], scores: Dictionary, record: GameRecord, _where: String) -> void:
	record.finished += 1
	record.winners = winners
	record.scores = scores

func _on_rejected(message: String, record: GameRecord, where: String) -> void:
	record.rejected += 1
	_fail(where, "动作被拒绝：" + message)

## GameController 传给控制器的视图 / 动作列表必须符合协议。
func _check_controller_view(seat: int, view: Dictionary, legal: Array[Action], where: String) -> void:
	_checks += 1
	if int(view.get("viewer_seat", -99)) != seat:
		_fail(where, "座位 %d 的控制器拿到了座位 %s 的视图"
				% [seat, view.get("viewer_seat", "?")])
	if int(view.get("current_seat", -99)) != seat:
		_fail(where, "座位 %d 的控制器在别人的回合被要求动作" % seat)
	if view.has("seed") or view.has("rng_state"):
		_fail(where, "控制器视图里有种子 / 随机数状态")
	var decks: Dictionary = view.get("decks", {})
	for level: int in [1, 2, 3]:
		if (decks.get(str(level), {}) as Dictionary).has("cards"):
			_fail(where, "控制器视图里有 %d 级牌堆顺序" % level)
	for player: Variant in view.get("players", []):
		var data: Dictionary = player
		if int(data.get("seat", -1)) == seat:
			continue
		for entry: Variant in data.get("reserved", []):
			var reserved: Dictionary = entry
			if bool(reserved.get("blind", false)) and reserved.get("id") != null:
				_fail(where, "座位 %d 看到了别人盲抽预留的牌 %s"
						% [seat, reserved.get("id")])
	if legal.is_empty():
		_fail(where, "座位 %d 收到了空的合法动作列表" % seat)
	for action: Action in legal:
		if not Rules.is_action_legal(view, _catalog, _config, action):
			_fail(where, "座位 %d 收到了非法动作：%s" % [seat, action.describe()])

# ---------------------------------------------------------------- 非法动作

func _check_illegal_rejection() -> void:
	var where: String = "非法动作拒绝"
	var game := GameController.new()
	add_child(game)
	_reject_messages.clear()
	game.action_rejected.connect(func(message: String) -> void: _reject_messages.append(message))
	var controllers: Array[PlayerController] = [
		IllegalOnceController.new(),
		RandomController.new(1234),
	]
	if not game.start_with_controllers(2, 777, controllers):
		_fail(where, "开局失败")
		game.queue_free()
		return
	_checks += 1
	if _reject_messages.size() != 1:
		_fail(where, "应该只被拒绝 1 次，实际 %d 次：%s"
				% [_reject_messages.size(), str(_reject_messages)])
	elif not _reject_messages[0].contains("非法动作"):
		_fail(where, "拒绝原因里没有「非法动作」：%s" % _reject_messages[0])
	if not game.is_running() or String(game.current_view().get("phase", "")) != "finished":
		_fail(where, "拒绝非法动作后对局没有继续到结束")
	game.queue_free()
	print("  非法动作被拒绝后可继续 ✓")

# ---------------------------------------------------------------- 重放 / 快照

func _check_replay(game: GameController, where: String) -> void:
	var data: Dictionary = game.build_replay_data()
	if data.is_empty():
		_fail(where, "build_replay_data 返回空")
		return
	var replayed := GameController.new()
	add_child(replayed)
	var errors: Array[String] = []
	replayed.load_replay(data, false, errors)
	_checks += 1
	if not errors.is_empty():
		_fail(where, "重放失败：" + "；".join(errors))
	elif replayed.fingerprint() != game.fingerprint():
		_fail(where, "重放后指纹不一致")
	elif not replayed.can_save_replay():
		_fail(where, "重放载入后应该还能再次存档")
	replayed.queue_free()

func _check_snapshot_loading() -> void:
	for scenario: String in SCENARIOS:
		var path: String = "res://tests/scenarios/%s.json" % scenario
		var where: String = "预设局面 %s" % scenario
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
			_fail(where, "JSON 解析失败")
			continue
		var data: Dictionary = json.data
		if SaveFile.kind_of(data) != SaveFile.KIND_SNAPSHOT:
			_fail(where, "不是快照文件")
			continue
		var game := GameController.new()
		add_child(game)
		var errors: Array[String] = []
		if not game.load_snapshot(SaveFile.unwrap_snapshot(data), errors):
			_fail(where, "载入失败：" + "；".join(errors))
			game.queue_free()
			continue
		_checks += 1
		var view: Dictionary = game.current_view()
		if int(view.get("viewer_seat", -99)) != int(view.get("current_seat", -100)):
			_fail(where, "快照视图不是当前玩家的")
		if game.can_save_replay():
			_fail(where, "快照载入后不应该能存成重放文件")
		if Rules.get_legal_actions(view, _catalog, _config).is_empty():
			_fail(where, "快照的当前玩家没有合法动作")
		game.queue_free()
	print("  六个预设快照都能载入 ✓")

# ---------------------------------------------------------------- 工具

func _check_turn_counts_equal(view: Dictionary, where: String) -> void:
	var counts: Array = view.get("turn_counts", [])
	if counts.is_empty():
		_fail(where, "turn_counts 为空")
		return
	for count: Variant in counts:
		if int(count) != int(counts[0]):
			_fail(where, "终局时回合数不相同：%s" % str(counts))
			return

func _fail(where: String, message: String) -> void:
	_failures += 1
	if _failures <= MAX_PRINTED_FAILURES:
		print("✗ %s：%s" % [where, message])
	elif _failures == MAX_PRINTED_FAILURES + 1:
		print("…… 后面的失败不再逐条打印")
