## 阶段 5 的大模型自检（无界面，不依赖外网）：
## 1) LlmProfile / 示例配置校验；
## 2) AppConfig 读写、增删改、坏配置；
## 3) StateDescriber 的局面文本、动作编号、隐藏信息断言；
## 4) 提示词模板与性格；
## 5) LlmClient：正常回复、结构化输出不支持的回退、HTTP 错误、断网、超时、测试连接；
## 6) LlmController：JSON / 代码块 / 越界 / 网络 / 超时 / 取消 的重试与兜底；
## 7) 全流程：LLM vs 程序 AI 完整对局、start_new_game 的 llm 座位与坏配置档；
## 8) 调试界面的配置面板能加载。
## 本地模拟服务器见 tests/mock_llm_server.gd。任何一处违反都会打印原因并以退出码 1 结束。
## 用法：godot --headless --path . tests/llm_selfcheck.tscn
extends Node

const MAX_PRINTED_FAILURES: int = 30
const WATCHDOG_SECONDS: float = 180.0
const TEST_CONFIG_PATH: String = "user://llm_selfcheck_config.json"

var _config: RulesConfig = null
var _catalog: CardCatalog = null
var _server: MockLlmServer = null
var _failures: int = 0
var _checks: int = 0
var _watchdog_fired: bool = false

func _ready() -> void:
	var watchdog := get_tree().create_timer(WATCHDOG_SECONDS)
	watchdog.timeout.connect(_on_watchdog)
	if not DataRegistry.is_valid():
		print("数据校验失败，先跑 tests/data_report.tscn：")
		for message: String in DataRegistry.get_errors():
			print("  x %s" % message)
		get_tree().quit(1)
		return
	_config = DataRegistry.rules()
	_catalog = DataRegistry.card_catalog()
	_server = MockLlmServer.new()
	add_child(_server)
	if not _server.start():
		_fail("模拟服务器启动失败")
		_finish(0)
		return

	var started: int = Time.get_ticks_msec()
	print("=== 大模型自检（本地模拟服务器）===")
	_check_profiles()
	_check_app_config()
	_check_describer()
	_check_prompts()
	await _check_client()
	await _check_controller()
	await _check_integration()
	await _check_start_new_game_llm()
	_check_settings_panel()
	_server.stop()
	_finish(started)

func _on_watchdog() -> void:
	if _watchdog_fired:
		return
	_watchdog_fired = true
	print("✗ 自检超时（%.0f 秒），可能有请求没有返回" % WATCHDOG_SECONDS)
	get_tree().quit(1)

func _finish(started: int) -> void:
	var elapsed: float = float(Time.get_ticks_msec() - started) / 1000.0
	print("")
	if _failures == 0:
		print("OK —— 共 %d 项检查全部通过，用时 %.1f 秒。" % [_checks, elapsed])
		get_tree().quit(0)
		return
	print("失败：%d 处（共 %d 项检查，用时 %.1f 秒）" % [_failures, _checks, elapsed])
	get_tree().quit(1)

# ---------------------------------------------------------------- 配置校验

func _check_profiles() -> void:
	var data: Dictionary = _read_json("res://data/llm/llm_config.example.json")
	var raw_llm: Variant = data.get("llm", {})
	_check(raw_llm is Dictionary, "示例配置应有 llm 对象")
	if not raw_llm is Dictionary:
		return
	var raw_profiles: Variant = (raw_llm as Dictionary).get("profiles", {})
	_check(raw_profiles is Dictionary, "示例配置应有 llm.profiles")
	if not raw_profiles is Dictionary:
		return
	var profiles: Dictionary = raw_profiles
	_check(profiles.size() == 2, "示例配置应有 2 个配置档（实际 %d）" % profiles.size())
	for profile_id: String in ["deepseek", "ollama"]:
		_check(profiles.has(profile_id), "示例配置应有 %s" % profile_id)
		if not profiles.has(profile_id):
			continue
		var errors: Array[String] = []
		var profile: LlmProfile = LlmProfile.from_dict(profiles[profile_id], profile_id, errors)
		_check(profile != null, "%s 配置应能解析：%s" % [profile_id, "；".join(errors)])
		if profile == null:
			continue
		_check(not profile.base_url.is_empty() and not profile.model.is_empty(),
				"%s 的 base_url / model 不应为空" % profile_id)
		_check(profile.endpoint_url().ends_with("/chat/completions"),
				"%s 的 endpoint_url 应以 /chat/completions 结尾" % profile_id)

	var base: Dictionary = _mock_profile_data("http://127.0.0.1:1/v1")
	_check(_rejects_profile(base, "temperature", 3.0), "temperature 超范围应被拒绝")
	_check(_rejects_profile(base, "base_url", "ftp://example.com"), "非 http(s) 的 base_url 应被拒绝")
	_check(_rejects_profile(base, "model", ""), "空 model 应被拒绝")
	_check(_rejects_profile(base, "structured_output", "no_such_mode"), "非法 structured_output 应被拒绝")
	_check(_rejects_profile(base, "fallback_difficulty", "nightmare"), "非法兜底难度应被拒绝")
	_check(_rejects_profile(base, "personality", "angry"), "非法性格应被拒绝")
	_check(_rejects_profile(base, "think_budget_ms", 500), "过小的思考预算应被拒绝")
	_check(_rejects_profile(base, "thinking_effort", "extreme"), "非法思考强度应被拒绝")

	var legacy: Dictionary = base.duplicate(true)
	legacy.erase("thinking_effort")
	var legacy_errors: Array[String] = []
	var legacy_profile: LlmProfile = LlmProfile.from_dict(legacy, "mock", legacy_errors)
	_check(legacy_profile != null and legacy_profile.thinking_effort == LlmProfile.THINKING_DEFAULT,
			"旧配置没有 thinking_effort 时应默认 default")

	var errors: Array[String] = []
	var profile: LlmProfile = LlmProfile.from_dict(base, "mock", errors)
	_check(profile != null, "合法配置应能解析")
	if profile != null:
		var copied: LlmProfile = profile.copy()
		copied.model = "changed"
		_check(profile.model == "mock-model" and copied.model == "changed",
				"LlmProfile.copy() 应互不影响")
		_check(profile.endpoint_url() == "http://127.0.0.1:1/v1/chat/completions",
				"endpoint_url 应拼上 /chat/completions")
	print("  配置解析与校验 ✓")

func _rejects_profile(base: Dictionary, key: String, value: Variant) -> bool:
	var data: Dictionary = base.duplicate(true)
	data[key] = value
	var errors: Array[String] = []
	var profile: LlmProfile = LlmProfile.from_dict(data, "mock", errors)
	return profile == null and not errors.is_empty()

# ---------------------------------------------------------------- AppConfig

func _check_app_config() -> void:
	_delete_file(TEST_CONFIG_PATH)
	var cfg: Variant = load("res://autoload/app_config.gd").new()
	cfg.config_path = TEST_CONFIG_PATH
	cfg.load_config()
	_check(cfg.is_valid(), "首次加载应自动复制示例配置：%s" % "；".join(cfg.get_errors()))
	_check(FileAccess.file_exists(TEST_CONFIG_PATH), "首次加载后应生成配置文件")
	_check(cfg.llm_profile_ids().size() == 2, "示例配置应加载 2 个配置档")

	var profile: LlmProfile = cfg.llm_profile("deepseek").copy()
	profile.model = "saved-model"
	_check(cfg.save_llm_profile(profile), "保存配置档应成功：%s" % cfg.last_operation_error())
	cfg.load_config()
	_check(cfg.llm_profile("deepseek") != null
			and cfg.llm_profile("deepseek").model == "saved-model", "保存后的 model 应能读回")

	var new_id: String = cfg.new_profile_id()
	var new_data: Dictionary = cfg.example_profile_data()
	new_data["display_name"] = "Test"
	new_data["api_key"] = ""
	var errors: Array[String] = []
	var new_profile: LlmProfile = LlmProfile.from_dict(new_data, new_id, errors)
	_check(new_profile != null, "示例字段应能构成新配置档：%s" % "；".join(errors))
	if new_profile != null:
		_check(cfg.save_llm_profile(new_profile), "新建配置档应成功")
		_check(cfg.llm_profile_ids().has(new_id), "新配置档应出现在列表里")
		_check(cfg.set_active_llm_profile(new_id), "切换激活配置档应成功")
		_check(cfg.active_llm_profile_id() == new_id, "激活配置档应更新")
		_check(cfg.delete_llm_profile(new_id), "删除配置档应成功")
		_check(not cfg.llm_profile_ids().has(new_id), "删除后配置档不应再出现")

	var bad: LlmProfile = cfg.llm_profile(cfg.llm_profile_ids()[0]).copy()
	bad.temperature = 3.0
	_check(not cfg.save_llm_profile(bad), "非法配置档不应保存")
	_check(not cfg.last_operation_error().is_empty(), "保存失败应给出原因")

	# 不能删掉最后一个配置档。
	while cfg.llm_profile_ids().size() > 1:
		cfg.delete_llm_profile(cfg.llm_profile_ids()[0])
	_check(not cfg.delete_llm_profile(cfg.llm_profile_ids()[0]), "最后一个配置档不应被删除")

	_write_text(TEST_CONFIG_PATH, "{ 这不是 JSON")
	cfg.load_config()
	_check(not cfg.is_valid() and not cfg.get_errors().is_empty(), "坏 JSON 应被报出来")

	cfg.free()
	_delete_file(TEST_CONFIG_PATH)
	print("  AppConfig 读写与校验 ✓")

# ---------------------------------------------------------------- 局面描述

func _check_describer() -> void:
	# 用真实开局造一个"对手盲抽预留"的局面，确保视图隐藏它。
	var state: GameState = Rules.setup(_config, _catalog, 2, 777)
	var legal0: Array[Action] = Rules.get_legal_actions(state.to_dict(0), _catalog, _config)
	var reserve: Action = null
	for action: Action in legal0:
		if action.type == Enums.ActionType.RESERVE and action.card_id.is_empty():
			reserve = action
			break
	_check(reserve != null, "开局应有盲抽预留动作")
	if reserve != null:
		Rules.apply(state, reserve)

	var viewer: int = state.current_seat
	var view: Dictionary = state.to_dict(viewer)
	var legal: Array[Action] = Rules.get_legal_actions(view, _catalog, _config)
	var state_text: String = StateDescriber.describe(view, _catalog, _config)
	var actions_text: String = StateDescriber.describe_actions(view, legal, _catalog)
	var combined: String = state_text + "\n" + actions_text
	var full: Dictionary = state.to_dict(GameState.VIEW_ALL)

	_check(state_text.contains("【局面】") and state_text.contains("【银行】")
			and state_text.contains("【玩家】"), "局面文本应包含主要区块")
	_check(state_text.contains("座位 %d（你）" % viewer), "局面文本应标出当前玩家")
	_check(not combined.contains("{{"), "局面文本不应残留占位符")
	_check(actions_text.split("\n").size() == legal.size(), "合法动作编号数量应与合法动作一致")
	if not legal.is_empty():
		_check(actions_text.begins_with("1. "), "合法动作编号应从 1 开始")

	# 盲抽预留对对手隐藏。
	var hidden_reserved: bool = false
	for player: Variant in view.get("players", []):
		var data: Dictionary = player
		if int(data.get("seat", -1)) == viewer:
			continue
		for entry: Variant in data.get("reserved", []):
			if bool((entry as Dictionary).get("blind", false)):
				hidden_reserved = hidden_reserved or (entry as Dictionary).get("id") == null
	_check(hidden_reserved, "对手盲抽预留的 id 在视图里应为 null")
	_check(state_text.contains("（盲抽，未知）"), "局面文本应把对手盲抽表示为未知")

	var problems: Array[String] = StateDescriber.privacy_problems(view, combined, full)
	_check(problems.is_empty(), "局面文本不应泄露隐藏信息：%s" % "；".join(problems))

	var leak_view: Dictionary = view.duplicate(true)
	leak_view["seed"] = 1
	_check(not StateDescriber.privacy_problems(leak_view, "", full).is_empty(),
			"视图带种子时应被检查出来")

	var full_decks: Dictionary = full.get("decks", {})
	var level_one: Dictionary = full_decks.get("1", {})
	var deck_ids: Array = level_one.get("cards", [])
	var hidden_id: String = ""
	for item: Variant in deck_ids:
		if item != null:
			hidden_id = String(item)
			break
	if not hidden_id.is_empty():
		_check(not StateDescriber.privacy_problems(view, combined + " " + hidden_id, full).is_empty(),
				"文本里出现牌堆卡牌 id 时应被检查出来")
		_check(not combined.contains(hidden_id), "局面文本不应包含牌堆里的卡牌 id")

	# 购买动作的说明应提示支付自动完成（不要求这个动作当前合法）。
	var board: Dictionary = view.get("boards", {})
	var any_card_id: String = ""
	for level: int in [3, 2, 1]:
		for item: Variant in board.get(str(level), []):
			if item != null:
				any_card_id = String(item)
				break
		if not any_card_id.is_empty():
			break
	if not any_card_id.is_empty():
		var detail: String = StateDescriber.action_detail(Action.purchase(any_card_id), view, _catalog)
		_check(detail.contains("支付自动完成"), "购买动作说明应提示支付自动完成")
	print("  局面描述与隐藏信息断言 ✓")

# ---------------------------------------------------------------- 提示词

func _check_prompts() -> void:
	PromptLibrary.clear_cache()
	var system: String = PromptLibrary.system_prompt("balanced", _config)
	_check(system.contains(str(_config.win_points)), "系统提示应替换胜利分占位符")
	_check(not system.contains("{{"), "系统提示不应残留占位符")
	var aggressive: String = PromptLibrary.system_prompt("aggressive", _config)
	_check(aggressive != system and aggressive.contains("激进"), "性格模板应追加到系统提示后面")
	for personality: String in LlmProfile.PERSONALITIES:
		var path: String = "%s/personalities/%s.txt" % [PromptLibrary.PROMPT_DIR, personality]
		_check(FileAccess.file_exists(path), "缺少性格模板 %s" % path)

	var state: GameState = Rules.setup(_config, _catalog, 2, 90210)
	var view: Dictionary = state.to_dict(0)
	var legal: Array[Action] = Rules.get_legal_actions(view, _catalog, _config)
	var profile_data: Dictionary = _mock_profile_data(_server.base_url())
	var errors: Array[String] = []
	var profile: LlmProfile = LlmProfile.from_dict(profile_data, "mock", errors)
	var turn: String = PromptLibrary.turn_prompt(view, legal, _catalog, _config)
	_check(turn.contains("【局面】") and turn.contains("1. "), "回合提示应包含局面和编号动作")
	var messages: Array[Dictionary] = PromptLibrary.build_messages(view, legal, _catalog, _config, profile)
	_check(messages.size() == 2 and String(messages[0]["role"]) == "system"
			and String(messages[1]["role"]) == "user", "messages 应为 system + user")
	print("  提示词模板与性格 ✓")

# ---------------------------------------------------------------- LlmClient

func _check_client() -> void:
	var profile: LlmProfile = _profile_from_data(_mock_profile_data(_server.base_url()))
	var client := LlmClient.new()
	client.configure(profile)
	add_child(client)

	_server.mode = "ok"
	_server.requests.clear()
	var result: Dictionary = await _chat(client, 3000)
	_check(bool(result.get("ok", false)), "正常回复应成功")
	_check(String(result.get("content", "")) == "OK", "正常回复内容应为 OK")
	var usage: Dictionary = result.get("usage", {})
	_check(int(usage.get("total_tokens", 0)) == 120, "应记录 token 用量")
	_check(client.total_tokens == 120, "客户端应累计 token")
	_check(_server.request_count() == 1, "正常回复应只请求一次")
	_check(not _server.requests[0].contains("reasoning_effort"),
			"thinking_effort=default 时不应发送 reasoning_effort")

	# 思考强度：非 default 时作为 reasoning_effort 发送。
	_server.mode = "ok"
	_server.requests.clear()
	var thinking_data: Dictionary = _mock_profile_data(_server.base_url())
	thinking_data["thinking_effort"] = "low"
	var thinking_client := LlmClient.new()
	thinking_client.configure(_profile_from_data(thinking_data))
	add_child(thinking_client)
	var thinking_result: Dictionary = await _chat(thinking_client, 3000)
	_check(bool(thinking_result.get("ok", false)), "带思考强度的请求应成功")
	_check(_server.request_count() == 1
			and _server.requests[0].contains("\"reasoning_effort\":\"low\""),
			"thinking_effort=low 应发送 reasoning_effort")
	thinking_client.queue_free()

	# 服务不支持 reasoning_effort 时，自动去掉参数重试一次。
	_server.mode = "unsupported_thinking"
	_server.requests.clear()
	var unsupported_thinking_data: Dictionary = _mock_profile_data(_server.base_url())
	unsupported_thinking_data["thinking_effort"] = "high"
	var unsupported_thinking_client := LlmClient.new()
	unsupported_thinking_client.configure(_profile_from_data(unsupported_thinking_data))
	add_child(unsupported_thinking_client)
	var unsupported_thinking_result: Dictionary = await _chat(unsupported_thinking_client, 3000)
	_check(bool(unsupported_thinking_result.get("ok", false)),
			"思考参数不支持时应去掉参数重试成功")
	_check(unsupported_thinking_client.thinking_fallbacks == 1,
			"应记录一次思考参数回退")
	_check(_server.request_count() == 2
			and _server.requests[0].contains("reasoning_effort")
			and not _server.requests[1].contains("reasoning_effort"),
			"第一次带 reasoning_effort，第二次不带")
	unsupported_thinking_client.queue_free()

	_server.mode = "unsupported_format"
	_server.requests.clear()
	var fallback_result: Dictionary = await _chat(client, 3000)
	_check(bool(fallback_result.get("ok", false)), "结构化输出不支持时应退回纯文本")
	_check(client.structured_fallbacks == 1, "应记录一次结构化输出回退")
	_check(_server.request_count() == 2, "结构化输出回退应请求两次")
	_check(_server.requests.size() == 2 and _server.requests[0].contains("response_format")
			and not _server.requests[1].contains("response_format"),
			"第一次请求应带 response_format，第二次不带")

	_server.mode = "http_401"
	var http_result: Dictionary = await _chat(client, 3000)
	_check(not bool(http_result.get("ok", true)), "HTTP 401 应失败")
	_check(String(http_result.get("error_kind", "")) == "http", "HTTP 401 应归类为 http 错误")
	_check(client.last_http_status == 401, "应记录 HTTP 状态码")

	_server.mode = "empty"
	var empty_result: Dictionary = await _chat(client, 3000)
	_check(not bool(empty_result.get("ok", true)), "空 content 应失败")
	_check(String(empty_result.get("error_kind", "")) == "empty", "空 content 应归类为 empty")
	_check(String(empty_result.get("finish_reason", "")) == "length",
			"应记录 finish_reason=length")
	_check(int(empty_result.get("reasoning_len", 0)) > 0, "应记录 reasoning_content 长度")
	_check(String(empty_result.get("raw", "")).contains("finish_reason"),
			"empty 失败时应返回原始响应，便于排查")

	# 断网：连接一个刚释放、没有监听的端口。
	var closed_port: int = _unused_port()
	var offline_data: Dictionary = _mock_profile_data("http://127.0.0.1:%d/v1" % closed_port)
	offline_data["request_timeout_ms"] = 1500
	var offline_client := LlmClient.new()
	offline_client.configure(_profile_from_data(offline_data))
	add_child(offline_client)
	var offline_result: Dictionary = await _chat(offline_client, 1500)
	_check(not bool(offline_result.get("ok", true)), "断网应失败")
	_check(String(offline_result.get("error_kind", "")) == "network", "断网应归类为 network")
	offline_client.queue_free()

	_server.mode = "timeout"
	var timeout_data: Dictionary = _mock_profile_data(_server.base_url())
	timeout_data["request_timeout_ms"] = 500
	var timeout_client := LlmClient.new()
	timeout_client.configure(_profile_from_data(timeout_data))
	add_child(timeout_client)
	var timeout_result: Dictionary = await _chat(timeout_client, 400)
	_check(not bool(timeout_result.get("ok", true)), "超时应失败")
	_check(String(timeout_result.get("error_kind", "")) == "timeout", "超时应归类为 timeout")
	timeout_client.queue_free()

	_server.mode = "ok"
	var test_client := LlmClient.new()
	test_client.configure(profile)
	add_child(test_client)
	test_client.test_connection(profile, 3000)
	var test_result: Array = await test_client.test_finished
	_check(bool(test_result[0]), "测试连接应成功：%s" % String(test_result[1]))
	_check(String(test_result[1]).contains("连接成功"), "测试连接应给出成功信息")
	test_client.queue_free()

	client.cancel()
	client.queue_free()
	_server.mode = "action"
	print("  LlmClient：正常 / 结构化回退 / HTTP / 断网 / 超时 / 测试连接 ✓")

func _chat(client: LlmClient, timeout_ms: int) -> Dictionary:
	client.chat([{"role": "user", "content": "测试"}], timeout_ms)
	return await client.chat_completed

# ---------------------------------------------------------------- LlmController

func _check_controller() -> void:
	var state: GameState = Rules.setup(_config, _catalog, 2, 4242)
	var view: Dictionary = state.to_dict(0)
	var legal: Array[Action] = Rules.get_legal_actions(view, _catalog, _config)
	_check(legal.size() >= 2, "控制器测试需要至少 2 个合法动作")

	# 正常 JSON 回复。
	_server.mode = "fixed_action"
	_server.response_action = 2
	var controller := _new_llm_controller(_mock_profile_data(_server.base_url()))
	var reasons: Array[String] = []
	var waiting: Array[int] = []
	var fallbacks: Array[String] = []
	controller.reason_emitted.connect(func(text: String) -> void: reasons.append(text))
	controller.waiting_started.connect(func(_p: String, attempt: int, _l: float) -> void:
		waiting.append(attempt))
	controller.fallback_used.connect(func(reason: String, _bot: String) -> void: fallbacks.append(reason))
	var outcome: Dictionary = await _request_action(controller, view, legal)
	var action: Action = outcome.get("action") as Action
	_check(action != null and legal[1].equals(action), "应执行模型返回的第 2 个动作")
	_check(reasons.size() == 1 and reasons[0] == "模拟回复", "应发出模型理由")
	_check(waiting.size() == 1 and waiting[0] == 1, "应发出第 1 次等待")
	_check(fallbacks.is_empty() and controller.fallback_count == 0, "成功时不应兜底")
	_free_controller(controller)

	# 代码块 + 前后解释也能解析。
	_server.mode = "raw"
	_server.raw_content = "好的，我选择：\n```json\n{\"action\": 1, \"reason\": \"先拿宝石\"}\n```"
	var raw_controller := _new_llm_controller(_mock_profile_data(_server.base_url()))
	outcome = await _request_action(raw_controller, view, legal)
	action = outcome.get("action") as Action
	_check(action != null and legal[0].equals(action), "代码块里的 JSON 应能解析")
	_check(raw_controller.last_reason == "先拿宝石", "代码块回复的理由应被保留")
	_free_controller(raw_controller)

	# 越界编号：重试一次后兜底到程序 AI。
	_server.mode = "out_of_range"
	var parse_data: Dictionary = _mock_profile_data(_server.base_url())
	parse_data["max_retries"] = 1
	var parse_controller := _new_llm_controller(parse_data)
	var parse_fallbacks: Array[String] = []
	parse_controller.fallback_used.connect(func(reason: String, _bot: String) -> void:
		parse_fallbacks.append(reason))
	outcome = await _request_action(parse_controller, view, legal)
	action = outcome.get("action") as Action
	_check(action != null and _is_legal(action, legal), "解析失败后应兜底到合法动作")
	_check(parse_fallbacks.size() == 1 and parse_fallbacks[0] == LlmController.FALLBACK_PARSE,
			"解析失败应报告 parse_failed")
	_check(parse_controller.requests_made == 2, "max_retries=1 应请求 2 次")
	_check(parse_controller.fallback_count == 1, "应记录一次兜底")
	_free_controller(parse_controller)

	# HTTP 500：重试后兜底到程序 AI。
	_server.mode = "http_500"
	var http_controller := _new_llm_controller(parse_data)
	var http_fallbacks: Array[String] = []
	http_controller.fallback_used.connect(func(reason: String, _bot: String) -> void:
		http_fallbacks.append(reason))
	outcome = await _request_action(http_controller, view, legal)
	action = outcome.get("action") as Action
	_check(action != null and _is_legal(action, legal), "HTTP 错误后应兜底到合法动作")
	_check(http_fallbacks.size() == 1 and http_fallbacks[0] == LlmController.FALLBACK_NETWORK,
			"HTTP 错误应报告 network")
	_free_controller(http_controller)

	# HTTP 200 但 content 为空：应归为解析失败（模型输出问题），不是 network。
	_server.mode = "empty"
	var empty_controller := _new_llm_controller(parse_data)
	var empty_fallbacks: Array[String] = []
	empty_controller.fallback_used.connect(func(reason: String, _bot: String) -> void:
		empty_fallbacks.append(reason))
	outcome = await _request_action(empty_controller, view, legal)
	action = outcome.get("action") as Action
	_check(action != null and _is_legal(action, legal), "空回复后应兜底到合法动作")
	_check(empty_fallbacks.size() == 1 and empty_fallbacks[0] == LlmController.FALLBACK_PARSE,
			"空回复应报告 parse_failed（不是 network）")
	_check(empty_controller.last_error.contains("max_tokens")
			or empty_controller.last_error.contains("文本内容"),
			"空回复的错误信息应能提示原因")
	_free_controller(empty_controller)

	# 超时：思考预算内反复超时，最终兜底。
	_server.mode = "timeout"
	var timeout_data: Dictionary = _mock_profile_data(_server.base_url())
	timeout_data["request_timeout_ms"] = 500
	timeout_data["think_budget_ms"] = 2000
	timeout_data["max_retries"] = 3
	var timeout_controller := _new_llm_controller(timeout_data)
	var timeout_fallbacks: Array[String] = []
	timeout_controller.fallback_used.connect(func(reason: String, _bot: String) -> void:
		timeout_fallbacks.append(reason))
	var timeout_started: int = Time.get_ticks_msec()
	outcome = await _request_action(timeout_controller, view, legal, 10.0)
	var timeout_elapsed: int = Time.get_ticks_msec() - timeout_started
	action = outcome.get("action") as Action
	_check(action != null and _is_legal(action, legal), "超时后应兜底到合法动作")
	_check(timeout_fallbacks.size() == 1 and timeout_fallbacks[0] == LlmController.FALLBACK_TIMEOUT,
			"超时应报告 timeout")
	_check(timeout_elapsed < 5000, "思考预算应限制总耗时（实际 %dms）" % timeout_elapsed)
	_free_controller(timeout_controller)

	# cancel_pending 之后旧请求不应再注入动作。
	_server.mode = "timeout"
	var cancel_controller := _new_llm_controller(timeout_data)
	var decided: Array[Action] = []
	cancel_controller.action_decided.connect(func(value: Action) -> void: decided.append(value))
	cancel_controller.request_action(view, legal)
	await get_tree().create_timer(0.1).timeout
	cancel_controller.cancel_pending()
	await get_tree().create_timer(0.8).timeout
	_check(decided.is_empty(), "cancel_pending 后不应再发出动作")
	_check(not cancel_controller.is_waiting(), "cancel_pending 后不应处于等待状态")
	_free_controller(cancel_controller)
	_server.mode = "action"
	print("  LlmController：正常 / 代码块 / 解析失败 / HTTP / 超时 / 取消 ✓")

func _new_llm_controller(data: Dictionary) -> LlmController:
	var profile: LlmProfile = _profile_from_data(data)
	var fallback: AIProfile = DataRegistry.ai_profile(profile.fallback_difficulty)
	var controller := LlmController.new()
	controller.seat = 0
	controller.configure(profile, _catalog, _config, 12345, fallback)
	add_child(controller)
	return controller

func _request_action(controller: LlmController, view: Dictionary,
		legal: Array[Action], timeout_sec: float = 10.0) -> Dictionary:
	var result: Dictionary = {"action": null, "elapsed_ms": 0}
	var done: Array[bool] = [false]
	var on_action := func(action: Action) -> void:
		result["action"] = action
		done[0] = true
	controller.action_decided.connect(on_action)
	var started: int = Time.get_ticks_msec()
	controller.request_action(view, legal)
	while not done[0] and Time.get_ticks_msec() - started < int(timeout_sec * 1000.0):
		await get_tree().process_frame
	result["elapsed_ms"] = Time.get_ticks_msec() - started
	controller.action_decided.disconnect(on_action)
	return result

func _free_controller(controller: LlmController) -> void:
	controller.cancel_pending()
	remove_child(controller)
	controller.queue_free()

# ---------------------------------------------------------------- 全流程

func _check_integration() -> void:
	_server.mode = "action"
	_server.response_action = -1
	_server.requests.clear()

	var game := GameController.new()
	add_child(game)
	var rejected: Array[int] = [0]
	var finished: Array[bool] = [false]
	var winners: Array = []
	var waiting: Array[int] = [0]
	var reasons: Array[int] = [0]
	var fallbacks: Array[int] = [0]
	game.action_rejected.connect(func(_message: String) -> void: rejected[0] += 1)
	game.game_finished.connect(func(result_winners: Array[int], _scores: Dictionary) -> void:
		finished[0] = true
		winners.assign(result_winners))
	game.waiting_started.connect(func(_seat: int, _profile: String, _attempt: int, _limit: float) -> void:
		waiting[0] += 1)
	game.reason_emitted.connect(func(_seat: int, _text: String) -> void: reasons[0] += 1)
	game.fallback_used.connect(func(_seat: int, _reason: String, _bot: String) -> void:
		fallbacks[0] += 1)

	var llm_profile: LlmProfile = _profile_from_data(_mock_profile_data(_server.base_url()))
	var llm := LlmController.new()
	llm.configure(llm_profile, _catalog, _config, 111,
			DataRegistry.ai_profile(llm_profile.fallback_difficulty))
	var bot_profile: AIProfile = DataRegistry.ai_profile("easy")
	var bot := BotController.new()
	bot.configure(bot_profile, _catalog, _config,
			BotController.derive_seed(222, 1, bot_profile.seed_salt), 0.0)
	var controllers: Array[PlayerController] = [llm, bot]
	_check(game.start_with_controllers(2, 222, controllers), "LLM vs 程序 AI 应能开局")

	var started: int = Time.get_ticks_msec()
	while not finished[0] and Time.get_ticks_msec() - started < 120000:
		await get_tree().process_frame
	_check(finished[0], "LLM vs 程序 AI 应能正常结束")
	_check(rejected[0] == 0, "LLM 对局不应有非法动作（%d 次）" % rejected[0])
	_check(fallbacks[0] == 0, "模拟服务器正常时不应兜底（%d 次）" % fallbacks[0])
	_check(waiting[0] > 0, "应发出大模型等待信号")
	_check(reasons[0] > 0, "应发出大模型理由")
	_check(_server.request_count() > 0, "应实际发出大模型请求")
	_check(not winners.is_empty(), "对局应有胜者")
	_check(String(game.current_view().get("finished_reason", "")) == "win_points",
			"对局应以 win_points 结束（实际 %s）" % game.current_view().get("finished_reason", "?"))
	var counts: Array = game.current_view().get("turn_counts", [])
	if counts.is_empty():
		_fail("终局 turn_counts 为空")
	else:
		for count: Variant in counts:
			if int(count) != int(counts[0]):
				_fail("终局时回合数应相同：%s" % str(counts))
				break
	var usage: Dictionary = llm.token_usage()
	_check(int(usage.get("total_tokens", 0)) > 0, "应累计 token 用量")
	_check(not game.current_view().has("seed"), "LLM 视图不应有种子")
	print("  全流程：LLM vs 程序 AI（%d 次请求，%d tokens）✓"
			% [_server.request_count(), int(usage.get("total_tokens", 0))])

	game.reset()
	remove_child(game)
	game.queue_free()

# ---------------------------------------------------------------- 开局装配

func _check_start_new_game_llm() -> void:
	var original_path: String = AppConfig.config_path
	var temp_path: String = "user://llm_selfcheck_start_config.json"
	_delete_file(temp_path)
	var profile_a: Dictionary = _mock_profile_data(_server.base_url())
	var profile_b: Dictionary = _mock_profile_data(_server.base_url())
	profile_b["model"] = "mock-model-b"
	var data: Dictionary = {
		"schema_version": 1,
		"llm": {
			"active_profile": "mock",
			"profiles": {"mock": profile_a, "mock_b": profile_b},
		},
	}
	_write_json(temp_path, data)
	AppConfig.config_path = temp_path
	AppConfig.load_config()
	_check(AppConfig.is_valid() and AppConfig.llm_profile("mock") != null,
			"临时配置应能加载 mock 配置档")

	_server.mode = "action"
	_server.response_action = -1
	var game := GameController.new()
	add_child(game)
	var waiting: Array[int] = [0]
	game.waiting_started.connect(func(_seat: int, _profile: String, _attempt: int, _limit: float) -> void:
		waiting[0] += 1)
	var started: int = Time.get_ticks_msec()
	var ok: bool = game.start_new_game(2, 333, ["llm", "bot_easy"],
			[{"llm_profile": "mock"}, {}])
	_check(ok, "start_new_game 应支持 llm 座位")
	while ok and game.action_count() < 3 and Time.get_ticks_msec() - started < 20000:
		await get_tree().process_frame
	_check(waiting[0] > 0, "start_new_game 的 llm 座位应发出等待信号")
	_check(game.action_count() >= 1, "llm 座位应实际推进对局")

	var bad_game := GameController.new()
	add_child(bad_game)
	var bad_ok: bool = bad_game.start_new_game(2, 333, ["llm", "bot_easy"],
			[{"llm_profile": "missing"}, {}])
	_check(not bad_ok, "不存在的配置档应拒绝开局")
	remove_child(bad_game)
	bad_game.queue_free()

	# 两个座位用不同配置档：请求里的 model 应该分别是两个配置档的模型名。
	_server.requests.clear()
	var duel := GameController.new()
	add_child(duel)
	var duel_ok: bool = duel.start_new_game(2, 335, ["llm", "llm"],
			[{"llm_profile": "mock"}, {"llm_profile": "mock_b"}])
	_check(duel_ok, "两个大模型座位应能使用不同配置档")
	var duel_started: int = Time.get_ticks_msec()
	while duel_ok and duel.action_count() < 2 and Time.get_ticks_msec() - duel_started < 20000:
		await get_tree().process_frame
	var models: Dictionary = {}
	for body: String in _server.requests:
		var parsed: Variant = JSON.parse_string(body)
		if parsed is Dictionary:
			models[String((parsed as Dictionary).get("model", ""))] = true
	_check(models.has("mock-model") and models.has("mock-model-b"),
			"两个座位应分别使用自己的模型（实际 %s）" % str(models.keys()))
	duel.reset()
	remove_child(duel)
	duel.queue_free()

	# 调试棋盘也应该能接上大模型：日志里出现等待与理由。
	var board := preload("res://debug_ui/board/board.tscn").instantiate() as BoardScreen
	add_child(board)
	var board_ok: bool = board.start_new_game(2, 444, ["llm", "bot_easy"],
			[{"llm_profile": "mock"}, {}])
	_check(board_ok, "棋盘应能开大模型座位")
	var board_started: int = Time.get_ticks_msec()
	while board_ok and board._game.action_count() < 1 and Time.get_ticks_msec() - board_started < 20000:
		await get_tree().process_frame
	var log_text: String = board._log.get_parsed_text()
	_check(log_text.contains("大模型"), "棋盘日志应出现大模型等待 / 理由")
	_check(log_text.contains("理由"), "棋盘日志应显示模型给出的理由")
	board.reset()
	remove_child(board)
	board.queue_free()

	game.reset()
	remove_child(game)
	game.queue_free()
	AppConfig.config_path = original_path
	AppConfig.load_config()
	_delete_file(temp_path)
	print("  start_new_game 的 llm 座位与坏配置档 ✓")

# ---------------------------------------------------------------- 调试界面

func _check_settings_panel() -> void:
	var panel := preload("res://debug_ui/llm_settings/llm_settings.tscn").instantiate() as LlmSettings
	add_child(panel)
	var ids: Array[String] = AppConfig.llm_profile_ids()
	_check(panel._profile_option.item_count == ids.size(),
			"配置面板应列出全部配置档（%d / %d）" % [panel._profile_option.item_count, ids.size()])
	if not ids.is_empty():
		var profile: LlmProfile = AppConfig.llm_profile(ids[0])
		_check(panel._base_url_edit.text == profile.base_url, "配置面板应加载 BASE URL")
		_check(panel._model_edit.text == profile.model, "配置面板应加载模型名")
	_check(panel._test_button.text == "测试连接", "配置面板应有测试连接按钮")
	panel.queue_free()
	print("  调试界面配置面板 ✓")

# ---------------------------------------------------------------- 工具

func _mock_profile_data(base_url: String) -> Dictionary:
	return {
		"display_name": "Mock",
		"base_url": base_url,
		"api_key": "",
		"model": "mock-model",
		"temperature": 0.0,
		"max_tokens": 200,
		"request_timeout_ms": 3000,
		"think_budget_ms": 5000,
		"max_retries": 1,
		"structured_output": "json_object",
		"thinking_effort": "default",
		"fallback_difficulty": "normal",
		"personality": "balanced",
	}

func _profile_from_data(data: Dictionary) -> LlmProfile:
	var errors: Array[String] = []
	var profile: LlmProfile = LlmProfile.from_dict(data, "mock", errors)
	if profile == null:
		_fail("测试配置档解析失败：%s" % "；".join(errors))
	return profile

func _is_legal(action: Action, legal: Array[Action]) -> bool:
	for candidate: Action in legal:
		if candidate.equals(action):
			return true
	return false

func _unused_port() -> int:
	var server := TCPServer.new()
	server.listen(0, "127.0.0.1")
	var port: int = server.get_local_port()
	server.stop()
	return port

func _read_json(path: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		_fail("读不了 %s" % path)
		return {}
	return json.data

func _write_json(path: String, data: Dictionary) -> void:
	_write_text(path, JSON.stringify(data, "  "))

func _write_text(path: String, text: String) -> void:
	var directory: String = path.get_base_dir()
	if path.begins_with("user://") and not DirAccess.dir_exists_absolute(directory):
		DirAccess.make_dir_recursive_absolute(directory)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("写不了 %s" % path)
		return
	file.store_string(text)
	file.close()

func _delete_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

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
