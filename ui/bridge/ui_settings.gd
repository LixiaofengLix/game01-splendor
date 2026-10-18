## UI 自有设置的运行时状态：动画速度 / 动效开关 / 音效开关。
## U5 只提供内存中的一项和测试钩子；JSON 持久化按计划在 U7 做（user://ui_settings.json）。
class_name UiSettings
extends RefCounted

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

static var _anim_speed: String = SPEED_NORMAL
static var _animations_enabled: bool = true
static var _sfx_enabled: bool = true
static var _confirm_before_buy: bool = true


static func anim_speed() -> String:
	return _anim_speed


## 传入未知值时回退到 standard，避免设置文件写坏后整个界面变慢 / 变快。
static func set_anim_speed(value: String) -> void:
	_anim_speed = value if SPEEDS.has(value) else SPEED_NORMAL


static func speed_multiplier() -> float:
	return float(SPEED_MULTIPLIERS.get(_anim_speed, 1.0))


static func animations_enabled() -> bool:
	return _animations_enabled


static func set_animations_enabled(enabled: bool) -> void:
	_animations_enabled = enabled


static func sfx_enabled() -> bool:
	return _sfx_enabled


static func set_sfx_enabled(enabled: bool) -> void:
	_sfx_enabled = enabled


static func confirm_before_buy() -> bool:
	return _confirm_before_buy


static func set_confirm_before_buy(enabled: bool) -> void:
	_confirm_before_buy = enabled


## 测试用：恢复默认（动效开、标准速度、音效开、购买前确认开）。
static func reset_defaults() -> void:
	_anim_speed = SPEED_NORMAL
	_animations_enabled = true
	_sfx_enabled = true
	_confirm_before_buy = true
