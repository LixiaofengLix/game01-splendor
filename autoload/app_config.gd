## 全局单例（autoload 名 AppConfig）：用户设置的读写，目前只包含大模型配置档。
## 配置文件在 user://config.json，首次运行从 data/llm/llm_config.example.json 复制；
## API Key 只存在用户目录，不进仓库、不进存档、不写日志。
## 注意：autoload 脚本不能写 class_name；测试可以直接 new() 这个脚本并改 config_path。
extends Node

const DEFAULT_CONFIG_PATH: String = "user://config.json"
const EXAMPLE_PATH: String = "res://data/llm/llm_config.example.json"
const SCHEMA_VERSION: int = 1

## 测试可以改成临时路径，避免动到真实用户配置。
var config_path: String = DEFAULT_CONFIG_PATH

var _raw: Dictionary = {}
var _profiles: Dictionary[String, LlmProfile] = {}
var _active_profile_id: String = ""
var _errors: Array[String] = []
var _last_operation_error: String = ""

func _ready() -> void:
	load_config()

# ---------------------------------------------------------------- 读取

## 重新加载配置文件。文件不存在时先复制示例；坏配置只记录错误，不崩溃。
func load_config() -> void:
	_errors.clear()
	_profiles.clear()
	_raw.clear()
	_active_profile_id = ""

	if not FileAccess.file_exists(config_path):
		var copy_error: String = _copy_example()
		if not copy_error.is_empty():
			_errors.append(copy_error)
			return

	var json := JSON.new()
	var parse_error: Error = json.parse(FileAccess.get_file_as_string(config_path))
	if parse_error != OK:
		_errors.append("config.json：第 %d 行 JSON 语法错误：%s"
				% [json.get_error_line(), json.get_error_message()])
		return
	if not json.data is Dictionary:
		_errors.append("config.json：顶层必须是一个对象")
		return
	_raw = json.data

	var version: int = int(_raw.get("schema_version", 0))
	if version != SCHEMA_VERSION:
		_errors.append("config.json：schema_version 应为 %d，实际为 %d"
				% [SCHEMA_VERSION, version])

	var raw_llm: Variant = _raw.get("llm", {})
	if not raw_llm is Dictionary:
		_errors.append("config.json：llm 必须是一个对象")
		return
	var llm: Dictionary = raw_llm
	var raw_profiles: Variant = llm.get("profiles", {})
	if not raw_profiles is Dictionary:
		_errors.append("config.json：llm.profiles 必须是一个对象")
		return

	var profiles: Dictionary = raw_profiles
	for key: Variant in profiles:
		var entry: Variant = profiles[key]
		if not entry is Dictionary:
			_errors.append("config.json：llm.profiles.%s 必须是一个对象" % key)
			continue
		var profile: LlmProfile = LlmProfile.from_dict(entry, String(key), _errors)
		if profile != null:
			_profiles[profile.id] = profile

	_active_profile_id = String(llm.get("active_profile", "")).strip_edges()
	if not _profiles.is_empty() and not _profiles.has(_active_profile_id):
		_active_profile_id = llm_profile_ids()[0]

# ---------------------------------------------------------------- 大模型配置档

func llm_profile_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in _profiles:
		ids.append(id)
	ids.sort()
	return ids

func llm_profile(profile_id: String) -> LlmProfile:
	return _profiles.get(profile_id)

func active_llm_profile_id() -> String:
	return _active_profile_id

func active_llm_profile() -> LlmProfile:
	return llm_profile(_active_profile_id)

func has_llm_profiles() -> bool:
	return not _profiles.is_empty()

## 新建 / 更新一个配置档并写回文件。校验失败返回 false，原因从 last_operation_error() 取。
func save_llm_profile(profile: LlmProfile) -> bool:
	if profile == null:
		_last_operation_error = "配置档为空"
		return false
	var errors: Array[String] = []
	var validated: LlmProfile = LlmProfile.from_dict(profile.to_dict(), profile.id, errors)
	if validated == null:
		_last_operation_error = "；".join(errors)
		return false
	_profiles[validated.id] = validated
	if _active_profile_id.is_empty():
		_active_profile_id = validated.id
	var save_error: String = save()
	if not save_error.is_empty():
		_last_operation_error = save_error
		return false
	_last_operation_error = ""
	return true

## 删除配置档；不允许删掉最后一个（否则所有大模型座位都没配置可用）。
func delete_llm_profile(profile_id: String) -> bool:
	if not _profiles.has(profile_id):
		_last_operation_error = "配置档 %s 不存在" % profile_id
		return false
	if _profiles.size() <= 1:
		_last_operation_error = "至少要保留一个配置档"
		return false
	_profiles.erase(profile_id)
	if _active_profile_id == profile_id:
		_active_profile_id = llm_profile_ids()[0]
	var save_error: String = save()
	if not save_error.is_empty():
		_last_operation_error = save_error
		return false
	_last_operation_error = ""
	return true

func set_active_llm_profile(profile_id: String) -> bool:
	if not _profiles.has(profile_id):
		_last_operation_error = "配置档 %s 不存在" % profile_id
		return false
	_active_profile_id = profile_id
	var save_error: String = save()
	if not save_error.is_empty():
		_last_operation_error = save_error
		return false
	_last_operation_error = ""
	return true

## 示例文件里第一个配置档的副本（新建配置档时用作默认值）。读不到时返回空字典。
func example_profile_data() -> Dictionary:
	if not FileAccess.file_exists(EXAMPLE_PATH):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(EXAMPLE_PATH)) != OK:
		return {}
	if not json.data is Dictionary:
		return {}
	var raw_llm: Variant = (json.data as Dictionary).get("llm", {})
	if not raw_llm is Dictionary:
		return {}
	var raw_profiles: Variant = (raw_llm as Dictionary).get("profiles", {})
	if not raw_profiles is Dictionary:
		return {}
	var profiles: Dictionary = raw_profiles
	var keys: Array = profiles.keys()
	keys.sort()
	if keys.is_empty():
		return {}
	var first: Variant = profiles[keys[0]]
	return (first as Dictionary).duplicate(true) if first is Dictionary else {}

## 生成一个不与现有 id 冲突的新 id。
func new_profile_id(prefix: String = "profile") -> String:
	var index: int = 1
	while _profiles.has("%s_%d" % [prefix, index]):
		index += 1
	return "%s_%d" % [prefix, index]

func save() -> String:
	_raw["schema_version"] = SCHEMA_VERSION
	var llm: Dictionary = {}
	var raw_llm: Variant = _raw.get("llm")
	if raw_llm is Dictionary:
		llm = raw_llm
	llm["active_profile"] = _active_profile_id
	var profiles: Dictionary = {}
	for id: String in llm_profile_ids():
		profiles[id] = _profiles[id].to_dict()
	llm["profiles"] = profiles
	_raw["llm"] = llm
	return _write_json(config_path, _raw)

func last_operation_error() -> String:
	return _last_operation_error

func is_valid() -> bool:
	return _errors.is_empty()

func get_errors() -> Array[String]:
	return _errors.duplicate()

# ---------------------------------------------------------------- 内部

func _copy_example() -> String:
	if not FileAccess.file_exists(EXAMPLE_PATH):
		return "找不到示例配置 %s" % EXAMPLE_PATH
	var text: String = FileAccess.get_file_as_string(EXAMPLE_PATH)
	if text.is_empty():
		return "示例配置 %s 是空文件" % EXAMPLE_PATH
	var directory: String = config_path.get_base_dir()
	if config_path.begins_with("user://") and not DirAccess.dir_exists_absolute(directory):
		var make_error: Error = DirAccess.make_dir_recursive_absolute(directory)
		if make_error != OK:
			return "建不了目录 %s：%s" % [directory, error_string(make_error)]
	var file: FileAccess = FileAccess.open(config_path, FileAccess.WRITE)
	if file == null:
		return "写不了 %s：%s" % [config_path, error_string(FileAccess.get_open_error())]
	file.store_string(text)
	file.close()
	return ""

func _write_json(path: String, data: Dictionary) -> String:
	var directory: String = path.get_base_dir()
	if path.begins_with("user://") and not DirAccess.dir_exists_absolute(directory):
		var make_error: Error = DirAccess.make_dir_recursive_absolute(directory)
		if make_error != OK:
			return "建不了目录 %s：%s" % [directory, error_string(make_error)]
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "写不了 %s：%s" % [path, error_string(FileAccess.get_open_error())]
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	return ""
