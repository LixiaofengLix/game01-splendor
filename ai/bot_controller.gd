## 电脑座位控制器：用 AIEvaluator 从过滤视图决定动作，再通过 action_decided 交给 GameController。
## 主行动阶段可以配置思考延迟（方便观察）；弃宝石 / 选贵族不等待。
## 异步等待用子 Timer + 请求代数实现：取消 / 重置后旧的超时不会把动作注入新局。
class_name BotController
extends PlayerController

var profile: AIProfile = null
var thinking_delay: float = 0.0
var last_think_ms: int = 0
var max_think_ms: int = 0
## 每次决策的耗时（不含界面延迟），供自检 / 批量模拟统计。
var think_times: Array[int] = []
## AI 返回的动作不在合法列表里、被迫回退到第一个合法动作的次数（正常应为 0）。
var fallback_count: int = 0
## 困难搜索因为超时 / 节点预算没有完整展开的次数（正常应为 0）。
var timeout_fallbacks: int = 0
var node_limit_fallbacks: int = 0

var _evaluator: AIEvaluator = null
var _timer: Timer = null
var _pending_action: Action = null
var _generation: int = 0

## 由 GameController 在开局时调用。rng_seed 必须由 derive_seed() 派生，保证可复现。
func configure(p_profile: AIProfile, p_catalog: CardCatalog, p_config: RulesConfig,
		rng_seed: int, delay_override: float = -1.0) -> void:
	profile = p_profile
	_evaluator = AIEvaluator.new(p_profile, p_catalog, p_config, rng_seed)
	thinking_delay = float(p_profile.thinking_delay_ms) / 1000.0
	if delay_override >= 0.0:
		thinking_delay = delay_override

func request_action(view: Dictionary, legal_actions: Array[Action]) -> void:
	if _evaluator == null:
		push_error("BotController：没有 configure 就收到了动作请求（座位 %d）" % seat)
		return
	if legal_actions.is_empty():
		push_error("BotController：合法动作列表为空（座位 %d）" % seat)
		return
	if _pending_action != null:
		push_error("BotController：上一个动作还没发出，又收到了请求（座位 %d）" % seat)
		return

	var action: Action = _evaluator.choose_action(view, legal_actions, seat)
	last_think_ms = _evaluator.last_think_ms
	max_think_ms = maxi(max_think_ms, last_think_ms)
	think_times.append(last_think_ms)
	timeout_fallbacks = _evaluator.timeout_fallbacks
	node_limit_fallbacks = _evaluator.node_limit_fallbacks
	if action == null or not _is_in_legal(action, legal_actions):
		fallback_count += 1
		push_error("BotController：AI 的动作不在合法列表里，回退到第一个动作（座位 %d）" % seat)
		action = legal_actions[0]

	# 只有正常回合需要“思考一下”给用户看；弃宝石 / 选贵族快速处理。
	var delay: float = thinking_delay
	if String(view.get("phase", "")) != "playing":
		delay = 0.0
	if delay <= 0.0:
		action_decided.emit(action)
		return
	_pending_action = action
	_generation += 1
	_start_timer(delay, _generation)

## GameController 在重置 / 换局 / 释放控制器前调用：作废尚未发出的动作。
func cancel_pending() -> void:
	_generation += 1
	_pending_action = null
	_stop_timer()

func _start_timer(delay: float, generation: int) -> void:
	_stop_timer()
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer_timeout.bind(generation))
	add_child(_timer)
	_timer.start(delay)

func _stop_timer() -> void:
	if _timer == null:
		return
	_timer.stop()
	if _timer.get_parent() == self:
		remove_child(_timer)
	_timer.queue_free()
	_timer = null

func _on_timer_timeout(generation: int) -> void:
	_stop_timer()
	if generation != _generation or _pending_action == null or not is_inside_tree():
		return
	var action: Action = _pending_action
	_pending_action = null
	action_decided.emit(action)

## 用整数运算派生随机种子（不用 String.hash()，跨会话 / 平台保持一致）。
static func derive_seed(game_seed: int, seat: int, salt: int) -> int:
	return game_seed * 131 + seat * 7919 + salt

func _is_in_legal(action: Action, legal_actions: Array[Action]) -> bool:
	for legal: Action in legal_actions:
		if legal.equals(action):
			return true
	return false
