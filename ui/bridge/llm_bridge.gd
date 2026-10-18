## 大模型配置档的桥接层：包住 AppConfig 与 LlmClient，屏幕不直接碰逻辑层。
## 配置档走 user://config.json（AppConfig）；测试连接用 LlmClient，结果通过信号返回。
class_name UiLlmBridge
extends Node

signal test_finished(ok: bool, message: String, elapsed_ms: int)

const TEST_TIMEOUT_MS: int = 15000

var _client: LlmClient = null
var _last_error: String = ""


func _ready() -> void:
	if _client == null:
		_client = LlmClient.new()
		_client.name = "LlmClient"
		add_child(_client)
		_client.test_finished.connect(_on_test_finished)


## 配置档列表（已保存的）。
static func profile_ids() -> Array[String]:
	return AppConfig.llm_profile_ids()


static func has_profiles() -> bool:
	return AppConfig.has_llm_profiles()


static func profile(profile_id: String) -> LlmProfile:
	return AppConfig.llm_profile(profile_id)


static func active_profile_id() -> String:
	return AppConfig.active_llm_profile_id()


## 新建配置档时的默认值（示例配置的副本）。
static func example_profile_data() -> Dictionary:
	return AppConfig.example_profile_data()


static func new_profile_id() -> String:
	return AppConfig.new_profile_id()


# ---------------------------------------------------------------- 编辑 / 保存

## 从表单字典构造配置档；校验失败返回 null，原因写进 errors。
func build_profile(profile_id: String, fields: Dictionary,
		errors: Array[String]) -> LlmProfile:
	return LlmProfile.from_dict(fields, profile_id, errors)


func save_profile(profile: LlmProfile) -> bool:
	if AppConfig.save_llm_profile(profile):
		_last_error = ""
		return true
	_last_error = AppConfig.last_operation_error()
	return false


func delete_profile(profile_id: String) -> bool:
	if AppConfig.delete_llm_profile(profile_id):
		_last_error = ""
		return true
	_last_error = AppConfig.last_operation_error()
	return false


func last_error() -> String:
	return _last_error


# ---------------------------------------------------------------- 测试连接

func is_testing() -> bool:
	return _client != null and _client.is_busy()


## 用当前表单值测试（不要求先保存）。返回是否真的发出了请求。
func test_connection(profile: LlmProfile) -> bool:
	if profile == null or _client == null or _client.is_busy():
		return false
	_client.test_connection(profile, TEST_TIMEOUT_MS)
	return true


func cancel_test() -> void:
	if _client != null:
		_client.cancel()


func _on_test_finished(ok: bool, message: String, elapsed_ms: int) -> void:
	test_finished.emit(ok, message, elapsed_ms)
