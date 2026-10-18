## 对局流程控制器（Node）：持有完整 GameState，按座位向 PlayerController 要动作，
## 用 Rules 校验并执行，然后把过滤后的视图和事件发给界面。
## 界面只监听 state_changed / events_emitted / game_finished / action_rejected，不直接访问 GameState。
class_name GameController
extends Node

signal state_changed(view: Dictionary)
signal events_emitted(events: Array[GameEvent])
signal game_finished(winners: Array[int], scores: Dictionary)
## 控制器交来非法动作 / 不在自己回合的动作时发出（界面用来提示，不改动对局）。
signal action_rejected(message: String)

const ORIGIN_NEW: String = "replay"
const ORIGIN_SNAPSHOT: String = "snapshot"
## 座位类型。阶段 4 增加三档电脑；阶段 5 / 6 再增加大模型与远程。
const SEAT_TYPE_HUMAN: String = "human"
const SEAT_TYPE_BOT_EASY: String = "bot_easy"
const SEAT_TYPE_BOT_NORMAL: String = "bot_normal"
const SEAT_TYPE_BOT_HARD: String = "bot_hard"
## 同步控制器连续提交非法动作时，最多重试这么多次就停下（防止死循环）。
const MAX_REJECT_STREAK: int = 8

var _state: GameState = null
var _controllers: Array[PlayerController] = []
var _origin: String = ""
var _origin_seed: int = 0
var _origin_player_count: int = 0
var _action_log: Array[Action] = []
var _finished_emitted: bool = false

# 动作泵：控制器可以同步决定（AI / 测试），也可以异步决定（人类点击、大模型 HTTP）。
var _pending_action: Action = null
var _pumping: bool = false
var _reject_streak: int = 0

# ---------------------------------------------------------------- 开局 / 载入

## 按座位类型开局。seat_types 的元素见 SEAT_TYPE_* 常量。
func start_new_game(player_count: int, seed: int, seat_types: Array[String]) -> bool:
	if seat_types.size() != player_count:
		_fail_start("座位类型数量 %d 与人数 %d 不一致" % [seat_types.size(), player_count])
		return false
	# 先整体校验，避免创建到一半失败留下半套控制器。
	for seat: int in seat_types.size():
		if not _is_supported_seat_type(seat_types[seat]):
			_fail_start("座位 %d 的类型 \"%s\" 在本阶段不可用" % [seat, seat_types[seat]])
			return false
	var controllers: Array[PlayerController] = []
	for seat: int in player_count:
		var controller: PlayerController = _create_controller(seat, seat_types[seat], seed)
		if controller == null:
			return false
		controllers.append(controller)
	return start_with_controllers(player_count, seed, controllers)

## 用外部提供的控制器开局（阶段 4 的 AI、阶段 6 的远程、测试都走这里）。
func start_with_controllers(player_count: int, seed: int,
		controllers: Array[PlayerController]) -> bool:
	if controllers.size() != player_count:
		_fail_start("控制器数量 %d 与人数 %d 不一致" % [controllers.size(), player_count])
		return false
	if not _data_ready():
		return false
	var state: GameState = Rules.setup(DataRegistry.rules(), DataRegistry.card_catalog(),
			player_count, seed)
	if state == null:
		_fail_start("开局失败：人数 %d 或数据不正确" % player_count)
		return false
	_reset_controllers()
	for seat: int in controllers.size():
		_add_controller(seat, controllers[seat])
	_adopt(state, ORIGIN_NEW, seed, player_count)
	return true

## 载入快照（SaveFile.unwrap_snapshot 的内层状态）。座位全部重置为人类控制器。
func load_snapshot(state_data: Dictionary, errors: Array[String]) -> bool:
	if not _data_ready():
		errors.append("数据校验失败")
		return false
	var state: GameState = GameState.from_dict(state_data, DataRegistry.rules(),
			DataRegistry.card_catalog(), errors)
	if state == null:
		return false
	_ensure_human_controllers(state.player_count)
	_adopt(state, ORIGIN_SNAPSHOT, 0, state.player_count)
	return true

## 载入重放文件（SaveFile kind = replay）：重新开局、逐步校验并重放，最后比对指纹。
## 返回给日志面板看的记录行（verbose 时逐条动作 / 事件）；失败原因写进 errors，当前对局保持不变。
func load_replay(data: Dictionary, verbose: bool, errors: Array[String]) -> Array[String]:
	var lines: Array[String] = []
	if not _data_ready():
		errors.append("数据校验失败")
		return lines
	var parsed: Dictionary = SaveFile.parse_replay(data)
	if parsed.is_empty():
		errors.append("重放文件解析失败（详见 output 面板）")
		return lines
	var player_count: int = int(parsed["player_count"])
	var seed: int = int(parsed["seed"])
	var state: GameState = Rules.setup(DataRegistry.rules(), DataRegistry.card_catalog(),
			player_count, seed)
	if state == null:
		errors.append("重放开局失败：人数 %d 不支持" % player_count)
		return lines
	var actions: Array[Action] = parsed["actions"]
	for index: int in actions.size():
		var action: Action = actions[index]
		if verbose:
			lines.append("%3d/%d  %s" % [index + 1, actions.size(), action.describe()])
		var events: Array[GameEvent] = Rules.apply(state, action)
		if events.is_empty():
			errors.append("第 %d 步重放失败：%s（存档与当前规则 / 数据不一致）"
					% [index + 1, action.describe()])
			return lines
		if verbose:
			for event: GameEvent in events:
				lines.append("  · %s" % event.describe())
	var expected: String = String(parsed["fingerprint"])
	var actual: String = state.fingerprint()
	if not expected.is_empty() and expected != actual:
		errors.append("重放后状态不一致：存档指纹 %s，现在 %s（改过规则或数据？）" % [expected, actual])
		return lines
	_ensure_human_controllers(state.player_count)
	_adopt(state, ORIGIN_NEW, seed, player_count, actions)
	if expected.is_empty():
		lines.append("重放完成：%d 步（存档里没有记录指纹，无法比对）" % actions.size())
	else:
		lines.append("重放完成：%d 步，指纹一致 ✓（%s）" % [actions.size(), expected])
	return lines

## 结束当前对局并释放控制器（返回设置界面时调用）。
func reset() -> void:
	_reset_controllers()
	_state = null
	_origin = ""
	_origin_seed = 0
	_origin_player_count = 0
	_action_log.clear()
	_pending_action = null
	_finished_emitted = false
	_reject_streak = 0

# ---------------------------------------------------------------- 界面接口

## 界面提交玩家选中的动作。只有当前座位是人类控制器时接受。
func submit_action(action: Action) -> bool:
	if _state == null or _state.is_finished():
		action_rejected.emit("对局未开始或已结束")
		return false
	var controller: PlayerController = _controllers[_state.current_seat]
	if not controller is HumanController:
		action_rejected.emit("当前座位不是人类控制器")
		return false
	var accepted: bool = (controller as HumanController).submit(action)
	if not accepted:
		action_rejected.emit("这个点击已经过期，请重新选择")
	return accepted

## 当前玩家自己的视图（界面只读它，不访问 GameState）。
func current_view() -> Dictionary:
	if _state == null:
		return {}
	return _state.to_dict(_state.current_seat)

func is_running() -> bool:
	return _state != null

## 当前行动座位是否由人类控制。界面用它决定动作按钮能否点击；
## 对局未开始 / 已结束 / 座位越界时一律返回 false。
func is_current_human() -> bool:
	if _state == null or _state.is_finished():
		return false
	var seat: int = _state.current_seat
	if seat < 0 or seat >= _controllers.size():
		return false
	return _controllers[seat] is HumanController

## 这局是否来自"种子 + 动作序列"（新开局或重放存档），可以再存成重放文件。
func can_save_replay() -> bool:
	return _state != null and _origin == ORIGIN_NEW

func build_replay_data() -> Dictionary:
	if not can_save_replay():
		return {}
	return SaveFile.build_replay(_origin_player_count, _origin_seed, _action_log, fingerprint())

func fingerprint() -> String:
	return "" if _state == null else _state.fingerprint()

func action_count() -> int:
	return _action_log.size()

# ---------------------------------------------------------------- 动作泵

## 动作泵：反复"请求当前玩家 → 执行同步给出的动作"，直到某个控制器异步等待（人类点击 / 大模型）
## 或对局结束。同步 AI 不会因为递归调用爆栈，异步控制器也不需要特殊处理。
func _pump() -> void:
	if _pumping:
		return
	_pumping = true
	while true:
		if _state == null or _state.is_finished():
			break
		if _pending_action == null:
			_request_current_action()
			if _pending_action == null:
				break  # 等控制器异步给出动作
		var action: Action = _pending_action
		_pending_action = null
		if _apply_action(action):
			_reject_streak = 0
		else:
			_reject_streak += 1
			if _reject_streak >= MAX_REJECT_STREAK:
				push_error("GameController：当前控制器连续提交 %d 个非法动作，停止推进"
						% _reject_streak)
				break
	_pumping = false

func _request_current_action() -> void:
	var seat: int = _state.current_seat
	var view: Dictionary = _state.to_dict(seat)
	var legal: Array[Action] = Rules.get_legal_actions(view, _state.catalog, _state.config)
	if legal.is_empty():
		push_error("GameController：座位 %d 没有合法动作（规则引擎本应自动跳过）" % seat)
		return
	_controllers[seat].request_action(view, legal)

func _on_action_decided(action: Action, seat: int) -> void:
	if _state == null or _state.is_finished():
		return
	if seat != _state.current_seat:
		action_rejected.emit("座位 %d 不在他的回合" % seat)
		return
	if _pending_action != null:
		action_rejected.emit("收到了重复的动作")
		return
	_pending_action = action
	if not _pumping:
		_pump()

func _apply_action(action: Action) -> bool:
	if action == null:
		action_rejected.emit("空动作")
		return false
	var seat: int = _state.current_seat
	var view: Dictionary = _state.to_dict(seat)
	if not Rules.is_action_legal(view, _state.catalog, _state.config, action):
		action_rejected.emit("座位 %d 的非法动作：%s" % [seat, action.describe()])
		return false
	var events: Array[GameEvent] = Rules.apply(_state, action)
	if events.is_empty():
		action_rejected.emit("动作执行失败：%s" % action.describe())
		return false
	_action_log.append(action)
	events_emitted.emit(events)
	_emit_state()
	if _state.is_finished():
		_emit_finished()
	return true

# ---------------------------------------------------------------- 内部

func _adopt(state: GameState, origin: String, seed: int, player_count: int,
		actions: Array[Action] = []) -> void:
	_state = state
	_origin = origin
	_origin_seed = seed
	_origin_player_count = player_count
	_action_log.clear()
	_action_log.assign(actions)
	_pending_action = null
	_finished_emitted = false
	_reject_streak = 0
	_emit_state()
	if _state.is_finished():
		_emit_finished()
		return
	_pump()

func _emit_state() -> void:
	state_changed.emit(_state.to_dict(_state.current_seat))

func _emit_finished() -> void:
	if _finished_emitted:
		return
	_finished_emitted = true
	var scores: Dictionary = {}
	for player: PlayerState in _state.players:
		scores[str(player.seat)] = player.total_points()
	var winners: Array[int] = []
	winners.assign(_state.winners)
	game_finished.emit(winners, scores)

func _create_controller(seat: int, seat_type: String, seed: int) -> PlayerController:
	match seat_type:
		SEAT_TYPE_HUMAN:
			return HumanController.new()
	var profile_id: String = _bot_profile_id(seat_type)
	if profile_id.is_empty():
		push_error("GameController：座位 %d 的类型 \"%s\" 在本阶段不可用" % [seat, seat_type])
		action_rejected.emit("座位 %d 的类型 %s 尚未支持" % [seat, seat_type])
		return null
	var profile: AIProfile = DataRegistry.ai_profile(profile_id)
	if profile == null:
		push_error("GameController：找不到 AI 配置 \"%s\"（data/ai 校验失败？）" % profile_id)
		action_rejected.emit("座位 %d 的 AI 配置 %s 不可用" % [seat, profile_id])
		return null
	var bot := BotController.new()
	bot.configure(profile, DataRegistry.card_catalog(), DataRegistry.rules(),
			BotController.derive_seed(seed, seat, profile.seed_salt))
	return bot

func _is_supported_seat_type(seat_type: String) -> bool:
	if seat_type == SEAT_TYPE_HUMAN:
		return true
	var profile_id: String = _bot_profile_id(seat_type)
	return not profile_id.is_empty() and DataRegistry.ai_profile(profile_id) != null

func _bot_profile_id(seat_type: String) -> String:
	match seat_type:
		SEAT_TYPE_BOT_EASY:
			return "easy"
		SEAT_TYPE_BOT_NORMAL:
			return "normal"
		SEAT_TYPE_BOT_HARD:
			return "hard"
	return ""

func _add_controller(seat: int, controller: PlayerController) -> void:
	controller.seat = seat
	controller.name = "Seat%dController" % seat
	add_child(controller)
	controller.action_decided.connect(_on_action_decided.bind(seat))
	_controllers.append(controller)

func _ensure_human_controllers(count: int) -> void:
	_reset_controllers()
	for seat: int in count:
		_add_controller(seat, HumanController.new())

func _reset_controllers() -> void:
	for controller: PlayerController in _controllers:
		if not is_instance_valid(controller):
			continue
		controller.cancel_pending()
		if controller.get_parent() == self:
			remove_child(controller)
		controller.queue_free()
	_controllers.clear()

func _data_ready() -> bool:
	if DataRegistry.is_valid():
		return true
	push_error("GameController：data/ 校验失败，先跑 tests/data_report.tscn")
	return false

func _fail_start(message: String) -> void:
	push_error("GameController：" + message)
	action_rejected.emit(message)
