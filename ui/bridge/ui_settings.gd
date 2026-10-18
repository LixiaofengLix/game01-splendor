## UI 自有设置：内存状态 + user://ui_settings.json 持久化（U7）。
## 只保存界面偏好（昵称 / 动效 / 音效 / 显示 / 存档）；大模型配置档在 AppConfig（user://config.json）。
## 每个 setter 立即生效并在已载入设置后自动写盘；设置页因此不需要额外的“应用”按钮。
class_name UiSettings
extends RefCounted

const SCHEMA_VERSION: int = 1
const DEFAULT_PATH: String = "user://ui_settings.json"
const DEFAULT_NAME: String = "小明"

const SPEED_SLOW: String = "slow"
const SPEED_NORMAL: String = "normal"
const SPEED_FAST: String = "fast"
const SPEEDS: Array[String] = [SPEED_SLOW, SPEED_NORMAL, SPEED_FAST]
## 动画时长倍率：慢 ×1.5 / 标准 ×1 / 快 ×0.5（INTERACTION.md 第 7 节）。
const SPEED_MULTIPLIERS: Dictionary[String, float] = {
	SPEED_SLOW: 1.5,
	SPEED_NORMAL: 1.0,
	SPEED_FAST: 0.5,
}

## 测试钩子：非空时读写这个路径，避免动到真实用户设置。
static var path_override: String = ""

static var _auto_save: bool = false
static var _last_error: String = ""
static var _default_name: String = DEFAULT_NAME
static var _anim_speed: String = SPEED_NORMAL
static var _animations_enabled: bool = true
static var _sfx_enabled: bool = true
static var _confirm_before_buy: bool = true
static var _hotseat_cover_default: bool = true
static var _fullscreen: bool = false
static var _show_card_ids: bool = false
static var _autosave: bool = true


# ---------------------------------------------------------------- 读取 / 写入

static func path() -> String:
	return path_override if not path_override.is_empty() else DEFAULT_PATH


## 从磁盘载入；文件不存在或读不了时保留默认值，并记录原因。
## 载入成功后 setter 会自动写盘（设置页“改动立即保存”）。
static func load_from_disk() -> void:
	reset_defaults()
	_auto_save = false
	var file_path: String = path()
	if not FileAccess.file_exists(file_path):
		_auto_save = true
		apply_display()
		return
	var text: String = FileAccess.get_file_as_string(file_path)
	var json := JSON.new()
	if json.parse(text) != OK:
		_last_error = "ui_settings.json：第 %d 行 JSON 语法错误：%s" % [
			json.get_error_line(), json.get_error_message(),
		]
		_auto_save = true
		apply_display()
		return
	if not json.data is Dictionary:
		_last_error = "ui_settings.json：顶层必须是一个对象"
		_auto_save = true
		apply_display()
		return
	var data: Dictionary = json.data
	var version: int = int(data.get("schema_version", 0))
	if version != SCHEMA_VERSION:
		_last_error = "ui_settings.json：schema_version 应为 %d，实际为 %d" % [
			SCHEMA_VERSION, version,
		]
		_auto_save = true
		apply_display()
		return

	var raw_name: Variant = data.get("default_name", DEFAULT_NAME)
	if raw_name is String:
		var trimmed: String = String(raw_name).strip_edges()
		if not trimmed.is_empty():
			_default_name = trimmed.substr(0, 8)
	var raw_speed: Variant = data.get("anim_speed", SPEED_NORMAL)
	if raw_speed is String and SPEEDS.has(String(raw_speed)):
		_anim_speed = String(raw_speed)
	_animations_enabled = _bool_value(data, "animations_enabled", _animations_enabled)
	_sfx_enabled = _bool_value(data, "sfx", _sfx_enabled)
	_confirm_before_buy = _bool_value(data, "confirm_before_buy", _confirm_before_buy)
	_hotseat_cover_default = _bool_value(data, "hotseat_cover_default", _hotseat_cover_default)
	_fullscreen = _bool_value(data, "fullscreen", _fullscreen)
	_show_card_ids = _bool_value(data, "show_card_ids", _show_card_ids)
	_autosave = _bool_value(data, "autosave", _autosave)
	_auto_save = true
	apply_display()


## 写入 user://ui_settings.json。返回是否成功；原因从 last_error() 取。
static func save() -> bool:
	if path().begins_with("user://"):
		var directory: String = path().get_base_dir()
		if not DirAccess.dir_exists_absolute(directory):
			var make_error: Error = DirAccess.make_dir_recursive_absolute(directory)
			if make_error != OK:
				_last_error = "建不了目录 %s：%s" % [directory, error_string(make_error)]
				return false
	var file: FileAccess = FileAccess.open(path(), FileAccess.WRITE)
	if file == null:
		_last_error = "写不了 %s：%s" % [path(), error_string(FileAccess.get_open_error())]
		return false
	file.store_string(JSON.stringify(to_dict(), "  "))
	file.close()
	_last_error = ""
	return true


static func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"default_name": _default_name,
		"anim_speed": _anim_speed,
		"animations_enabled": _animations_enabled,
		"confirm_before_buy": _confirm_before_buy,
		"hotseat_cover_default": _hotseat_cover_default,
		"sfx": _sfx_enabled,
		"fullscreen": _fullscreen,
		"show_card_ids": _show_card_ids,
		"autosave": _autosave,
	}


static func last_error() -> String:
	return _last_error


static func _bool_value(data: Dictionary, key: String, fallback: bool) -> bool:
	var value: Variant = data.get(key)
	return bool(value) if value is bool else fallback


static func _write_if_auto() -> void:
	if _auto_save:
		save()


# ---------------------------------------------------------------- 对局偏好

static func default_name() -> String:
	return _default_name


static func set_default_name(value: String) -> void:
	var trimmed: String = value.strip_edges()
	_default_name = trimmed.substr(0, 8) if not trimmed.is_empty() else DEFAULT_NAME
	_write_if_auto()


static func anim_speed() -> String:
	return _anim_speed


## 传入未知值时回退到 normal，避免设置文件写坏后整个界面变慢 / 变快。
static func set_anim_speed(value: String) -> void:
	_anim_speed = value if SPEEDS.has(value) else SPEED_NORMAL
	_write_if_auto()


static func speed_multiplier() -> float:
	return float(SPEED_MULTIPLIERS.get(_anim_speed, 1.0))


static func animations_enabled() -> bool:
	return _animations_enabled


static func set_animations_enabled(enabled: bool) -> void:
	_animations_enabled = enabled
	_write_if_auto()


static func confirm_before_buy() -> bool:
	return _confirm_before_buy


static func set_confirm_before_buy(enabled: bool) -> void:
	_confirm_before_buy = enabled
	_write_if_auto()


static func hotseat_cover_default() -> bool:
	return _hotseat_cover_default


static func set_hotseat_cover_default(enabled: bool) -> void:
	_hotseat_cover_default = enabled
	_write_if_auto()


# ---------------------------------------------------------------- 声音与显示

static func sfx_enabled() -> bool:
	return _sfx_enabled


static func set_sfx_enabled(enabled: bool) -> void:
	_sfx_enabled = enabled
	_write_if_auto()


static func fullscreen() -> bool:
	return _fullscreen


static func set_fullscreen(enabled: bool) -> void:
	_fullscreen = enabled
	apply_display()
	_write_if_auto()


## 全屏开关落到窗口；headless 下没有窗口，直接跳过。
static func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN if _fullscreen
			else DisplayServer.WINDOW_MODE_WINDOWED)


static func show_card_ids() -> bool:
	return _show_card_ids


static func set_show_card_ids(enabled: bool) -> void:
	_show_card_ids = enabled
	_write_if_auto()


# ---------------------------------------------------------------- 存档

static func autosave() -> bool:
	return _autosave


static func set_autosave(enabled: bool) -> void:
	_autosave = enabled
	_write_if_auto()


## 测试用：恢复默认并停止自动写盘（U5 起的测试都从这里开始）。
static func reset_defaults() -> void:
	_auto_save = false
	_last_error = ""
	_default_name = DEFAULT_NAME
	_anim_speed = SPEED_NORMAL
	_animations_enabled = true
	_sfx_enabled = true
	_confirm_before_buy = true
	_hotseat_cover_default = true
	_fullscreen = false
	_show_card_ids = false
	_autosave = true
