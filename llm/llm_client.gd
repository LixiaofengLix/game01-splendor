## OpenAI 兼容的 /chat/completions 客户端（HTTPRequest）。
## 构造请求、解析响应、错误归类都集中在这里；以后接 Anthropic 等非 OpenAI 格式只改这一处。
## 支持结构化输出（response_format / format），服务不支持时自动退回纯文本，由上层解析 JSON。
## 超时、HTTP 错误、网络错误都通过 chat_completed / test_finished 返回，不抛异常。
class_name LlmClient
extends Node

## 一次聊天请求的结果：
##   成功 {ok: true, content, usage, elapsed_ms, http_status, structured_fallback}
##   失败 {ok: false, error, error_kind, elapsed_ms, http_status}
## error_kind: network / timeout / http / bad_response / empty / config
signal chat_completed(result: Dictionary)
signal test_finished(ok: bool, message: String, elapsed_ms: int)

var profile: LlmProfile = null

var request_count: int = 0
var success_count: int = 0
var error_count: int = 0
var structured_fallbacks: int = 0
var thinking_fallbacks: int = 0
var prompt_tokens: int = 0
var completion_tokens: int = 0
var total_tokens: int = 0
var last_error_kind: String = ""
var last_error_message: String = ""
var last_http_status: int = 0

var _http: HTTPRequest = null
var _busy: bool = false
var _test_mode: bool = false
var _generation: int = 0
var _started_ms: int = 0
var _messages: Array[Dictionary] = []
var _timeout_override_ms: int = -1
var _structured_fallback_used: bool = false
var _thinking_fallback_used: bool = false

func configure(p_profile: LlmProfile) -> void:
	profile = p_profile

## 发起一次聊天请求。timeout_override_ms > 0 时覆盖配置里的单次请求超时。
func chat(messages: Array[Dictionary], timeout_override_ms: int = -1) -> void:
	if _busy:
		push_error("LlmClient：上一个请求还没结束")
		return
	if profile == null:
		_emit_error("config", "没有配置大模型配置档", Time.get_ticks_msec())
		return
	_busy = true
	_test_mode = false
	_messages = messages
	_timeout_override_ms = timeout_override_ms
	_structured_fallback_used = false
	_thinking_fallback_used = false
	last_http_status = 0
	_started_ms = Time.get_ticks_msec()
	_generation += 1
	request_count += 1
	_send(_generation, profile.structured_output != LlmProfile.STRUCTURED_NONE,
			profile.thinking_effort != LlmProfile.THINKING_DEFAULT)

## 测试连接：发一个极短的请求，只关心能否拿到非空回复。
func test_connection(p_profile: LlmProfile = null, timeout_override_ms: int = -1) -> void:
	if _busy:
		push_error("LlmClient：上一个请求还没结束")
		return
	if p_profile != null:
		configure(p_profile)
	if profile == null:
		test_finished.emit(false, "没有配置大模型配置档", 0)
		return
	_busy = true
	_test_mode = true
	# 提示词里要出现 "JSON"，否则 OpenAI 的 json_object 模式会直接 400。
	_messages = [{"role": "user", "content": "请只回复一个 JSON 对象：{\"ok\": true}"}]
	_timeout_override_ms = timeout_override_ms
	_structured_fallback_used = false
	_thinking_fallback_used = false
	last_http_status = 0
	_started_ms = Time.get_ticks_msec()
	_generation += 1
	request_count += 1
	_send(_generation, profile.structured_output != LlmProfile.STRUCTURED_NONE,
			profile.thinking_effort != LlmProfile.THINKING_DEFAULT)

## 取消尚未结束的请求。取消后不会发出 chat_completed / test_finished。
func cancel() -> void:
	_generation += 1
	_busy = false
	_test_mode = false
	_discard_http()

func is_busy() -> bool:
	return _busy

func usage_total() -> Dictionary:
	return {
		"prompt_tokens": prompt_tokens,
		"completion_tokens": completion_tokens,
		"total_tokens": total_tokens,
	}

# ---------------------------------------------------------------- 请求

func _send(generation: int, use_structured: bool, use_thinking: bool) -> void:
	if generation != _generation or not _busy:
		return
	_discard_http()
	var http := HTTPRequest.new()
	http.timeout = _request_timeout_seconds()
	http.request_completed.connect(
			_on_request_completed.bind(generation, use_structured, use_thinking))
	add_child(http)
	_http = http

	var body: Dictionary = _build_body(use_structured, use_thinking)
	var error: Error = http.request(profile.endpoint_url(), _headers(),
			HTTPClient.METHOD_POST, JSON.stringify(body))
	if error != OK:
		_discard_http()
		_emit_error("network", "HTTPRequest 启动失败：%s" % error_string(error),
				Time.get_ticks_msec())

func _build_body(use_structured: bool, use_thinking: bool) -> Dictionary:
	var body: Dictionary = {
		"model": profile.model,
		"messages": _messages,
		"stream": false,
		"temperature": profile.temperature,
		"max_tokens": profile.max_tokens,
	}
	if use_structured:
		match profile.structured_output:
			LlmProfile.STRUCTURED_JSON_OBJECT, LlmProfile.STRUCTURED_AUTO:
				body["response_format"] = {"type": "json_object"}
			LlmProfile.STRUCTURED_OLLAMA_FORMAT:
				body["format"] = "json"
	if use_thinking and profile.thinking_effort != LlmProfile.THINKING_DEFAULT:
		body["reasoning_effort"] = profile.thinking_effort
	return body

func _headers() -> PackedStringArray:
	var headers := PackedStringArray(["Content-Type: application/json", "Accept: application/json"])
	if not profile.api_key.is_empty():
		headers.append("Authorization: Bearer " + profile.api_key)
	return headers

func _request_timeout_seconds() -> float:
	var timeout_ms: int = profile.request_timeout_ms
	if _timeout_override_ms > 0:
		timeout_ms = _timeout_override_ms
	return float(timeout_ms) / 1000.0

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray,
		body: PackedByteArray, generation: int, use_structured: bool,
		use_thinking: bool) -> void:
	_discard_http()
	if generation != _generation or not _busy:
		return
	var elapsed: int = Time.get_ticks_msec() - _started_ms
	last_http_status = response_code

	if result == HTTPRequest.RESULT_TIMEOUT:
		_emit_error("timeout", "请求超时（%d ms）" % int(_request_timeout_seconds() * 1000.0), elapsed)
		return
	if result != HTTPRequest.RESULT_SUCCESS:
		_emit_error("network", "网络错误（%s）" % _result_name(result), elapsed)
		return

	var body_text: String = body.get_string_from_utf8()
	if response_code == 400 or response_code == 422:
		# 服务不支持 response_format / format 或 reasoning_effort：
		# 去掉对应参数重试一次，不消耗上层重试次数。
		var drop_structured: bool = use_structured \
				and _looks_like_unsupported_structured_output(body_text)
		var drop_thinking: bool = use_thinking and _looks_like_unsupported_thinking(body_text)
		if drop_structured or drop_thinking:
			if drop_structured:
				_structured_fallback_used = true
				structured_fallbacks += 1
			if drop_thinking:
				_thinking_fallback_used = true
				thinking_fallbacks += 1
			_send(generation, use_structured and not drop_structured,
					use_thinking and not drop_thinking)
			return
	if response_code != 200:
		_emit_error("http", "HTTP %d：%s" % [response_code, _extract_error(body_text)], elapsed)
		return

	var parsed: Variant = _parse_json(body_text)
	if not parsed is Dictionary:
		_emit_error("bad_response", "响应不是 JSON 对象：%s" % _short(body_text),
				elapsed, {"raw": _short(body_text, 500)})
		return
	# 有些代理 / 网关会在 HTTP 200 的响应体里放 error 对象。
	if (parsed as Dictionary).has("error"):
		_emit_error("http", "HTTP %d：%s" % [response_code, _extract_error(body_text)],
				elapsed, {"raw": _short(body_text, 500)})
		return
	var content: String = _extract_content(parsed)
	if content.strip_edges().is_empty():
		var finish_reason: String = _extract_finish_reason(parsed)
		var reasoning_len: int = _extract_reasoning_length(parsed)
		var hint: String = ""
		if finish_reason == "length":
			hint = "（finish_reason=length，可能是 max_tokens 太小）"
		elif reasoning_len > 0:
			hint = "（只有 reasoning_content，没有最终文本）"
		_emit_error("empty", "响应里没有文本内容%s" % hint, elapsed, {
			"raw": _short(body_text, 500),
			"usage": _extract_usage(parsed),
			"finish_reason": finish_reason,
			"reasoning_len": reasoning_len,
		})
		return
	var usage: Dictionary = _extract_usage(parsed)
	_accumulate_usage(usage)
	success_count += 1
	_busy = false
	if _test_mode:
		_test_mode = false
		var notes: Array[String] = []
		if _structured_fallback_used:
			notes.append("结构化输出不支持，已自动关闭")
		if _thinking_fallback_used:
			notes.append("思考强度参数不支持，已自动关闭")
		var suffix: String = "" if notes.is_empty() else "；" + "；".join(notes)
		test_finished.emit(true, "连接成功（模型 %s，HTTP %d）%s"
				% [profile.model, response_code, suffix], elapsed)
		return
	chat_completed.emit({
		"ok": true,
		"content": content,
		"usage": usage,
		"elapsed_ms": elapsed,
		"http_status": response_code,
		"structured_fallback": _structured_fallback_used,
		"thinking_fallback": _thinking_fallback_used,
	})

# ---------------------------------------------------------------- 解析

func _extract_content(parsed: Dictionary) -> String:
	var choices: Variant = parsed.get("choices")
	if not choices is Array or (choices as Array).is_empty():
		return ""
	var first: Variant = (choices as Array)[0]
	if not first is Dictionary:
		return ""
	var message: Variant = (first as Dictionary).get("message")
	if not message is Dictionary:
		return ""
	var content: Variant = (message as Dictionary).get("content")
	if content is String:
		return content
	if content is Array:
		var parts: Array[String] = []
		for part: Variant in content:
			if part is String:
				parts.append(part)
			elif part is Dictionary and (part as Dictionary).get("text") is String:
				parts.append(String((part as Dictionary)["text"]))
		return "".join(parts)
	return ""

func _extract_finish_reason(parsed: Dictionary) -> String:
	var choices: Variant = parsed.get("choices")
	if not choices is Array or (choices as Array).is_empty():
		return ""
	var first: Variant = (choices as Array)[0]
	if not first is Dictionary:
		return ""
	return String((first as Dictionary).get("finish_reason", ""))


## 一些推理模型把思考过程放在 message.reasoning_content 里；记录长度用于判断
## 是不是 max_tokens 被思考过程吃光了（content 为空、finish_reason=length）。
func _extract_reasoning_length(parsed: Dictionary) -> int:
	var choices: Variant = parsed.get("choices")
	if not choices is Array or (choices as Array).is_empty():
		return 0
	var first: Variant = (choices as Array)[0]
	if not first is Dictionary:
		return 0
	var message: Variant = (first as Dictionary).get("message")
	if not message is Dictionary:
		return 0
	var reasoning: Variant = (message as Dictionary).get("reasoning_content")
	return String(reasoning).length() if reasoning is String else 0


func _extract_usage(parsed: Dictionary) -> Dictionary:
	var raw: Variant = parsed.get("usage")
	if not raw is Dictionary:
		return {}
	var usage: Dictionary = raw
	var prompt: int = int(usage.get("prompt_tokens", 0))
	var completion: int = int(usage.get("completion_tokens", 0))
	var total: int = int(usage.get("total_tokens", prompt + completion))
	if total == 0:
		total = prompt + completion
	return {
		"prompt_tokens": prompt,
		"completion_tokens": completion,
		"total_tokens": total,
	}

func _extract_error(body_text: String) -> String:
	var parsed: Variant = _parse_json(body_text)
	if parsed is Dictionary:
		var error: Variant = (parsed as Dictionary).get("error")
		if error is Dictionary:
			var message: Variant = (error as Dictionary).get("message")
			if message != null:
				return _short(String(message))
		if error is String:
			return _short(error)
	return _short(body_text)

func _looks_like_unsupported_structured_output(body_text: String) -> bool:
	var lower: String = body_text.to_lower()
	var mentions: bool = lower.contains("response_format") or lower.contains("\"format\"")
	return mentions and _looks_unsupported(lower)

func _looks_like_unsupported_thinking(body_text: String) -> bool:
	var lower: String = body_text.to_lower()
	var mentions: bool = lower.contains("reasoning_effort") \
			or lower.contains("\"thinking\"") or lower.contains("thinking")
	return mentions and _looks_unsupported(lower)

func _looks_unsupported(lower: String) -> bool:
	return lower.contains("unsupported") or lower.contains("not support") \
			or lower.contains("not supported") or lower.contains("unknown") \
			or lower.contains("unrecognized") or lower.contains("invalid") \
			or lower.contains("extra")

func _accumulate_usage(usage: Dictionary) -> void:
	prompt_tokens += int(usage.get("prompt_tokens", 0))
	completion_tokens += int(usage.get("completion_tokens", 0))
	total_tokens += int(usage.get("total_tokens", 0))

func _result_name(result: int) -> String:
	match result:
		HTTPRequest.RESULT_CANT_CONNECT:
			return "连接失败"
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "域名解析失败"
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "连接中断"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "TLS 握手失败"
		HTTPRequest.RESULT_NO_RESPONSE:
			return "服务端没有响应"
		HTTPRequest.RESULT_REQUEST_FAILED:
			return "请求失败"
	return "错误码 %d" % result

func _parse_json(text: String) -> Variant:
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data

func _short(text: String, limit: int = 200) -> String:
	var cleaned: String = text.strip_edges().replace("\n", " ")
	return cleaned.substr(0, limit)

func _emit_error(kind: String, message: String, elapsed: int,
		extra: Dictionary = {}) -> void:
	_busy = false
	error_count += 1
	last_error_kind = kind
	last_error_message = message
	if _test_mode:
		_test_mode = false
		test_finished.emit(false, message, elapsed)
		return
	var result: Dictionary = {
		"ok": false,
		"error": message,
		"error_kind": kind,
		"elapsed_ms": elapsed,
		"http_status": last_http_status,
	}
	for key: String in extra:
		result[key] = extra[key]
	chat_completed.emit(result)

func _discard_http() -> void:
	if _http == null:
		return
	if _http.get_parent() == self:
		remove_child(_http)
	_http.queue_free()
	_http = null
