## 大模型座位控制器：把过滤视图和合法动作发给模型，要求返回 {"action": 编号, "reason": "..."}。
## 解析失败、编号非法、网络错误、超时都会重试；最终失败时交给指定难度的程序 AI 兜底。
## IR-08 的三个信号（waiting_started / reason_emitted / fallback_used）由 GameController 转发给界面。
## 异步等待用代数 + 请求取消实现：重开 / 返回设置后，旧 HTTP 响应不会注入新局。
class_name LlmController
extends PlayerController

signal waiting_started(profile: String, attempt: int, limit_sec: float)
signal reason_emitted(text: String)
signal fallback_used(reason: String, bot_type: String)

const FALLBACK_PARSE: String = "parse_failed"
const FALLBACK_TIMEOUT: String = "timeout"
const FALLBACK_NETWORK: String = "network"
const REASON_MAX_LENGTH: int = 200

var profile: LlmProfile = null
var fallback_bot_type: String = "bot_hard"

# 统计（自检 / 界面显示用）。
var requests_made: int = 0
var success_count: int = 0
var parse_failures: int = 0
var network_errors: int = 0
var timeouts: int = 0
var fallback_count: int = 0
var fallback_first_action_count: int = 0
var last_reason: String = ""
var last_error_kind: String = ""
var last_error: String = ""
var last_think_ms: int = 0

var _catalog: CardCatalog = null
var _config: RulesConfig = null
var _fallback_profile: AIProfile = null
var _evaluator: AIEvaluator = null
var _client: LlmClient = null
var _budget_timer: Timer = null

var _view: Dictionary = {}
var _legal: Array[Action] = []
var _pending: bool = false
var _generation: int = 0
var _attempt: int = 0
var _started_ms: int = 0

## 由 GameController 在开局时调用。fallback_profile 是失败时接管这一步的程序 AI 配置。
func configure(p_profile: LlmProfile, p_catalog: CardCatalog, p_config: RulesConfig,
		rng_seed: int, p_fallback_profile: AIProfile) -> void:
	profile = p_profile
	_catalog = p_catalog
	_config = p_config
	_fallback_profile = p_fallback_profile
	if profile != null:
		fallback_bot_type = "bot_" + profile.fallback_difficulty
	if _fallback_profile != null:
		_evaluator = AIEvaluator.new(_fallback_profile, p_catalog, p_config, rng_seed)
	if _client != null and profile != null:
		_client.configure(profile)

func _ready() -> void:
	_client = LlmClient.new()
	_client.name = "LlmClient"
	add_child(_client)
	_client.chat_completed.connect(_on_chat_completed)
	if profile != null:
		_client.configure(profile)

	_budget_timer = Timer.new()
	_budget_timer.one_shot = true
	_budget_timer.timeout.connect(_on_budget_timeout)
	add_child(_budget_timer)

func request_action(view: Dictionary, legal_actions: Array[Action]) -> void:
	if _pending:
		push_error("LlmController：上一个动作还没发出，又收到了请求（座位 %d）" % seat)
		return
	if legal_actions.is_empty():
		push_error("LlmController：合法动作列表为空（座位 %d）" % seat)
		return
	if profile == null or _client == null or _evaluator == null:
		push_error("LlmController：没有 configure 就收到了动作请求（座位 %d）" % seat)
		if not legal_actions.is_empty():
			action_decided.emit(legal_actions[0])
		return

	_view = view
	_legal = legal_actions.duplicate()
	_pending = true
	_generation += 1
	_attempt = 0
	_started_ms = Time.get_ticks_msec()
	last_error_kind = ""
	last_error = ""
	last_reason = ""
	if profile.think_budget_ms > 0 and _budget_timer != null:
		_budget_timer.start(float(profile.think_budget_ms) / 1000.0)
	_start_attempt()

func cancel_pending() -> void:
	_generation += 1
	_pending = false
	_stop_budget_timer()
	if _client != null:
		_client.cancel()

func token_usage() -> Dictionary:
	return _client.usage_total() if _client != null else {}

func is_waiting() -> bool:
	return _pending

# ---------------------------------------------------------------- 请求 / 重试

func _start_attempt() -> void:
	if not _pending:
		return
	if _budget_expired():
		last_error_kind = FALLBACK_TIMEOUT
		last_error = "思考预算用完"
		_fallback(FALLBACK_TIMEOUT)
		return
	_attempt += 1
	requests_made += 1
	waiting_started.emit(profile.display_name, _attempt,
			float(profile.think_budget_ms) / 1000.0 if profile.think_budget_ms > 0 else 0.0)

	var retry_note: String = "" if _attempt == 1 else last_error
	var messages: Array[Dictionary] = PromptLibrary.build_messages(
			_view, _legal, _catalog, _config, profile, retry_note)
	_assert_privacy(messages)
	_client.chat(messages, _remaining_timeout_ms())

func _on_chat_completed(result: Dictionary) -> void:
	if not _pending:
		return
	if not bool(result.get("ok", false)):
		var kind: String = String(result.get("error_kind", "network"))
		last_error = String(result.get("error", "请求失败"))
		if kind == "timeout":
			timeouts += 1
			last_error_kind = FALLBACK_TIMEOUT
		else:
			network_errors += 1
			last_error_kind = FALLBACK_NETWORK
		_retry_or_fallback()
		return

	var parsed: Dictionary = _parse_reply(String(result.get("content", "")))
	if parsed.has("error"):
		parse_failures += 1
		last_error_kind = FALLBACK_PARSE
		last_error = String(parsed["error"])
		_retry_or_fallback()
		return

	var index: int = int(parsed.get("action", 0))
	if index < 1 or index > _legal.size():
		parse_failures += 1
		last_error_kind = FALLBACK_PARSE
		last_error = "动作编号 %d 不在 1..%d 之间" % [index, _legal.size()]
		_retry_or_fallback()
		return
	_finish_success(_legal[index - 1], String(parsed.get("reason", "")))

func _retry_or_fallback() -> void:
	if _pending and _attempt <= profile.max_retries and not _budget_expired():
		_start_attempt()
		return
	_fallback(last_error_kind if not last_error_kind.is_empty() else FALLBACK_PARSE)

func _finish_success(action: Action, reason: String) -> void:
	_stop_budget_timer()
	_pending = false
	_generation += 1
	success_count += 1
	last_think_ms = Time.get_ticks_msec() - _started_ms
	last_reason = _clean_reason(reason)
	if not last_reason.is_empty():
		reason_emitted.emit(last_reason)
	action_decided.emit(action)

func _fallback(reason: String) -> void:
	if not _pending:
		return
	_stop_budget_timer()
	if _client != null:
		_client.cancel()
	_pending = false
	_generation += 1
	fallback_count += 1
	last_think_ms = Time.get_ticks_msec() - _started_ms
	last_error_kind = reason
	var action: Action = null
	if _evaluator != null:
		action = _evaluator.choose_action(_view, _legal, seat)
	if action == null or not _is_in_legal(action):
		fallback_first_action_count += 1
		if not _legal.is_empty():
			action = _legal[0]
	if action == null:
		push_error("LlmController：兜底也找不到合法动作（座位 %d）" % seat)
		return
	fallback_used.emit(reason, fallback_bot_type)
	action_decided.emit(action)

func _on_budget_timeout() -> void:
	if not _pending:
		return
	last_error_kind = FALLBACK_TIMEOUT
	last_error = "思考预算用完"
	timeouts += 1
	_fallback(FALLBACK_TIMEOUT)

func _stop_budget_timer() -> void:
	if _budget_timer != null:
		_budget_timer.stop()

func _budget_expired() -> bool:
	if profile == null or profile.think_budget_ms <= 0:
		return false
	return Time.get_ticks_msec() - _started_ms >= profile.think_budget_ms

func _remaining_timeout_ms() -> int:
	if profile.think_budget_ms <= 0:
		return profile.request_timeout_ms
	var remaining: int = profile.think_budget_ms - (Time.get_ticks_msec() - _started_ms)
	if remaining <= 0:
		return 1
	return maxi(100, mini(profile.request_timeout_ms, remaining))

## 从模型回复里提取 {"action": 编号, "reason": "..."}。
## 支持 markdown 代码块和 JSON 前后夹带解释文字；失败返回 {"error": "..."}。
func _parse_reply(content: String) -> Dictionary:
	var json_text: String = _find_json_object(content)
	var parsed: Variant = _parse_json(json_text)
	if not parsed is Dictionary:
		return {"error": "回复不是 JSON 对象：%s" % _shorten(content, 80)}
	var data: Dictionary = parsed
	var raw_action: Variant = data.get("action")
	var index: int = -1
	if raw_action is int:
		index = int(raw_action)
	elif raw_action is float:
		if float(raw_action) != floor(float(raw_action)):
			return {"error": "action 必须是整数"}
		index = int(raw_action)
	elif raw_action is String and String(raw_action).strip_edges().is_valid_int():
		index = int(String(raw_action).strip_edges())
	else:
		return {"error": "缺少合法的 action 字段"}
	if index < 1 or index > _legal.size():
		return {"error": "action 编号 %d 不在 1..%d 之间" % [index, _legal.size()]}
	return {"action": index, "reason": String(data.get("reason", ""))}

## 先试整段文本；失败则从第一个 { 开始做括号匹配（忽略字符串里的括号与转义）。
func _find_json_object(content: String) -> String:
	var text: String = content.strip_edges()
	if text.begins_with("```"):
		var first_newline: int = text.find("\n")
		if first_newline >= 0:
			text = text.substr(first_newline + 1).strip_edges()
		if text.ends_with("```"):
			text = text.substr(0, text.length() - 3).strip_edges()
	if _parse_json(text) is Dictionary:
		return text
	var start: int = text.find("{")
	if start < 0:
		return text
	var depth: int = 0
	var in_string: bool = false
	var escaped: bool = false
	for index: int in range(start, text.length()):
		var character: String = text[index]
		if in_string:
			if escaped:
				escaped = false
			elif character == "\\":
				escaped = true
			elif character == "\"":
				in_string = false
			continue
		if character == "\"":
			in_string = true
		elif character == "{":
			depth += 1
		elif character == "}":
			depth -= 1
			if depth == 0:
				return text.substr(start, index - start + 1)
	return text

## 静默解析：JSON.parse_string 会把解析失败打到 stderr，模型乱回复时太吵。
func _parse_json(text: String) -> Variant:
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data

func _is_in_legal(action: Action) -> bool:
	for legal: Action in _legal:
		if legal.equals(action):
			return true
	return false

func _clean_reason(reason: String) -> String:
	var cleaned: String = reason.strip_edges().replace("\n", " ").replace("\r", " ")
	if cleaned.length() > REASON_MAX_LENGTH:
		cleaned = cleaned.substr(0, REASON_MAX_LENGTH)
	return cleaned

func _shorten(text: String, limit: int) -> String:
	var cleaned: String = text.strip_edges().replace("\n", " ")
	return cleaned.substr(0, limit)

## 调试模式下自动断言：发出去的文本没有种子、牌堆顺序或对手盲抽预留的牌。
func _assert_privacy(messages: Array[Dictionary]) -> void:
	if not OS.is_debug_build():
		return
	var text: String = ""
	for message: Dictionary in messages:
		text += String(message.get("content", "")) + "\n"
	var problems: Array[String] = StateDescriber.privacy_problems(_view, text)
	if problems.is_empty():
		return
	push_error("LlmController：发给大模型的文本泄露了隐藏信息：%s" % "；".join(problems))
	assert(false, "大模型提示词泄露隐藏信息")
