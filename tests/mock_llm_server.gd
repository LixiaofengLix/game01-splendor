## 测试用的最小 HTTP 服务器（无界面）：模拟 OpenAI 兼容的 /chat/completions。
## 支持正常回复、指定动作、乱回复、越界编号、HTTP 401/500、结构化输出不支持、超时。
## 只用于 tests/llm_selfcheck.gd；不进入正式代码。
class_name MockLlmServer
extends Node

## action：从提示词的合法动作里挑最后一个（通常是购买）；
## fixed_action：固定返回 response_action；
## garbage / out_of_range / http_401 / http_500 / unsupported_format / timeout / ok。
var mode: String = "action"
var response_action: int = -1
## mode = "raw" 时原样返回这段文本（用来测试代码块 / 夹带解释的回复）。
var raw_content: String = ""

## 收到的请求体原文（测试用来检查提示词内容）。
var requests: Array[String] = []

var _server: TCPServer = null
var _connections: Array[Dictionary] = []

func start(bind_port: int = 0) -> bool:
	_server = TCPServer.new()
	var error: Error = _server.listen(bind_port, "127.0.0.1")
	if error != OK:
		push_error("MockLlmServer：监听失败：%s" % error_string(error))
		return false
	set_process(true)
	return true

func stop() -> void:
	set_process(false)
	for entry: Dictionary in _connections:
		var peer: StreamPeerTCP = entry["peer"]
		peer.disconnect_from_host()
	_connections.clear()
	if _server != null:
		_server.stop()
		_server = null

func port() -> int:
	return _server.get_local_port() if _server != null else 0

func base_url() -> String:
	return "http://127.0.0.1:%d/v1" % port()

func request_count() -> int:
	return requests.size()

func last_request() -> String:
	return "" if requests.is_empty() else requests[requests.size() - 1]

# ---------------------------------------------------------------- HTTP

func _process(_delta: float) -> void:
	if _server == null:
		return
	while _server.is_connection_available():
		var peer: StreamPeerTCP = _server.take_connection()
		if peer != null:
			_connections.append({"peer": peer, "buffer": PackedByteArray(),
					"responded": false, "close_at": 0})
	var index: int = _connections.size() - 1
	while index >= 0:
		var entry: Dictionary = _connections[index]
		var peer: StreamPeerTCP = entry["peer"]
		peer.poll()
		var status: int = peer.get_status()
		if status == StreamPeerTCP.STATUS_ERROR or status == StreamPeerTCP.STATUS_NONE:
			_connections.remove_at(index)
			index -= 1
			continue
		var close_at: int = int(entry.get("close_at", 0))
		if close_at > 0 and Time.get_ticks_msec() >= close_at:
			peer.disconnect_from_host()
			_connections.remove_at(index)
			index -= 1
			continue
		var available: int = peer.get_available_bytes()
		if available > 0:
			var chunk: Array = peer.get_data(available)
			if int(chunk[0]) == OK:
				var buffer: PackedByteArray = entry["buffer"]
				buffer.append_array(chunk[1] as PackedByteArray)
				entry["buffer"] = buffer
		var data: PackedByteArray = entry["buffer"]
		var header_end: int = _find_header_end(data)
		if header_end >= 0 and not bool(entry["responded"]):
			var content_length: int = _content_length(
					data.slice(0, header_end).get_string_from_utf8())
			if data.size() >= header_end + 4 + content_length:
				entry["responded"] = true
				var body: String = data.slice(header_end + 4,
						header_end + 4 + content_length).get_string_from_utf8()
				requests.append(body)
				_handle(entry, body)
		index -= 1

func _find_header_end(data: PackedByteArray) -> int:
	for index: int in range(0, data.size() - 3):
		if data[index] == 13 and data[index + 1] == 10 \
				and data[index + 2] == 13 and data[index + 3] == 10:
			return index
	return -1

func _content_length(header: String) -> int:
	for line: String in header.split("\r\n"):
		var lower: String = line.to_lower()
		if lower.begins_with("content-length:"):
			return int(line.split(":", true, 1)[1].strip_edges())
	return 0

func _handle(entry: Dictionary, body: String) -> void:
	if mode == "timeout":
		return  # 保持连接不响应，让 HTTPRequest 自己超时
	if mode == "http_401":
		_send(entry, 401, "Unauthorized",
				"{\"error\":{\"message\":\"invalid api key\"}}")
		return
	if mode == "http_500":
		_send(entry, 500, "Internal Server Error",
				"{\"error\":{\"message\":\"mock server error\"}}")
		return
	if mode == "unsupported_format" and _mentions_structured(body):
		_send(entry, 400, "Bad Request",
				"{\"error\":{\"message\":\"response_format is not supported\"}}")
		return
	if mode == "unsupported_thinking" and body.contains("reasoning_effort"):
		_send(entry, 400, "Bad Request",
				"{\"error\":{\"message\":\"reasoning_effort is not supported\"}}")
		return
	var content: String = "OK"
	match mode:
		"garbage":
			content = "我觉得应该先拿蓝宝石，然后再看看。"
		"out_of_range":
			content = "{\"action\": 999, \"reason\": \"越界测试\"}"
		"raw":
			content = raw_content
		"empty":
			# 推理模型常见形态：内容为空、finish_reason=length、思考过程在 reasoning_content。
			_send(entry, 200, "OK",
					_chat_response("", "length", 300, "这里是模型的思考过程，占满了 max_tokens。"))
			return
		"ok":
			content = "OK"
		_:
			var action_index: int = response_action
			if action_index < 0:
				action_index = _last_action_number(body)
			content = "{\"action\": %d, \"reason\": \"模拟回复\"}" % action_index
	_send(entry, 200, "OK", _chat_response(content))

func _mentions_structured(body: String) -> bool:
	return body.contains("response_format") or body.contains("\"format\"")

## 从最后一条 user 消息里找 "N. " 形式的动作编号，返回最大的一个。
func _last_action_number(body: String) -> int:
	var parsed: Variant = JSON.parse_string(body)
	if not parsed is Dictionary:
		return 1
	var messages: Variant = (parsed as Dictionary).get("messages")
	if not messages is Array or (messages as Array).is_empty():
		return 1
	var content: String = ""
	for item: Variant in messages:
		if item is Dictionary and String((item as Dictionary).get("role", "")) == "user":
			content = String((item as Dictionary).get("content", ""))
	var best: int = 1
	for line: String in content.split("\n"):
		var stripped: String = line.strip_edges()
		var dot: int = stripped.find(". ")
		if dot <= 0:
			continue
		var prefix: String = stripped.substr(0, dot)
		if prefix.is_valid_int():
			best = maxi(best, int(prefix))
	return best

func _chat_response(content: String, finish_reason: String = "stop",
		completion_tokens: int = 20, reasoning: String = "") -> String:
	var message: Dictionary = {"role": "assistant", "content": content}
	if not reasoning.is_empty():
		message["reasoning_content"] = reasoning
	var data: Dictionary = {
		"id": "mock",
		"object": "chat.completion",
		"choices": [{
			"index": 0,
			"message": message,
			"finish_reason": finish_reason,
		}],
		"usage": {
			"prompt_tokens": 100,
			"completion_tokens": completion_tokens,
			"total_tokens": 100 + completion_tokens,
		},
	}
	return JSON.stringify(data)

func _send(entry: Dictionary, status_code: int, reason: String, body: String) -> void:
	var peer: StreamPeerTCP = entry["peer"]
	var body_bytes: PackedByteArray = body.to_utf8_buffer()
	var response: String = "HTTP/1.1 %d %s\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % [
		status_code, reason, body_bytes.size(),
	]
	peer.put_data(response.to_utf8_buffer())
	peer.put_data(body_bytes)
	entry["close_at"] = Time.get_ticks_msec() + 60
