## 真实后端：包装 GameController，把它的信号转成桥接层统一的形态。
## 只调用 docs/UI_INTEGRATION.md 里的公开接口；UI 的其他部分不直接碰控制器。
class_name UiLiveBackend
extends RefCounted

signal view_received(view: Dictionary)
signal events_received(events: Array)
signal finished(winners: Array, scores: Dictionary)
signal rejected(message: String)
signal llm_waiting(seat: int, profile: String, attempt: int, limit_sec: float)
signal llm_reason(seat: int, text: String)
signal llm_fallback(seat: int, reason: String, bot_type: String)

var _controller: GameController = null


## 把 GameController 挂到 host 下面并连接信号。重复调用无副作用。
func attach(host: Node) -> void:
	if _controller != null:
		return
	_controller = GameController.new()
	_controller.name = "GameController"
	host.add_child(_controller)
	_controller.state_changed.connect(func(view: Dictionary) -> void: view_received.emit(view))
	_controller.events_emitted.connect(func(events: Array[GameEvent]) -> void: events_received.emit(events))
	_controller.game_finished.connect(func(winners: Array[int], scores: Dictionary) -> void:
		finished.emit(winners, scores))
	_controller.action_rejected.connect(func(message: String) -> void: rejected.emit(message))
	_controller.waiting_started.connect(
			func(seat: int, profile: String, attempt: int, limit_sec: float) -> void:
				llm_waiting.emit(seat, profile, attempt, limit_sec))
	_controller.reason_emitted.connect(func(seat: int, text: String) -> void: llm_reason.emit(seat, text))
	_controller.fallback_used.connect(func(seat: int, reason: String, bot_type: String) -> void:
		llm_fallback.emit(seat, reason, bot_type))


func start_local(player_count: int, seed_value: int, seat_types: Array[String]) -> bool:
	if _controller == null:
		push_error("UiLiveBackend：还没有 attach")
		return false
	var actual_seed: int = seed_value
	if actual_seed < 0:
		actual_seed = randi() & 0x7fffffff
	return _controller.start_new_game(player_count, actual_seed, seat_types)


func load_snapshot(state_data: Dictionary, errors: Array[String]) -> bool:
	if _controller == null:
		errors.append("桥接层还没有连接控制器")
		return false
	return _controller.load_snapshot(state_data, errors)


func submit(action: Action) -> bool:
	if _controller == null:
		return false
	return _controller.submit_action(action)


func is_current_human() -> bool:
	return _controller != null and _controller.is_current_human()


func current_view() -> Dictionary:
	return _controller.current_view() if _controller != null else {}


func can_save_replay() -> bool:
	return _controller != null and _controller.can_save_replay()


func build_replay_data() -> Dictionary:
	return _controller.build_replay_data() if _controller != null else {}


func reset() -> void:
	if _controller != null:
		_controller.reset()


## 释放控制器节点（换局 / 回到主菜单时调用）。
func release() -> void:
	if _controller == null:
		return
	_controller.reset()
	if is_instance_valid(_controller):
		_controller.queue_free()
	_controller = null
