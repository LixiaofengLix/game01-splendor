## 一条存档的元信息（`UiSaveStore.list()` 的返回项）。
## 屏幕只读这些字段，不解析存档 JSON；无法读取的存档也保留在列表里，并带上原因。
class_name UiSaveEntry
extends RefCounted

const STATUS_IN_PROGRESS: String = "in_progress"
const STATUS_FINISHED: String = "finished"

const REASON_VERSION_TOO_NEW: String = "version_too_new"
const REASON_CORRUPT: String = "corrupt"
const REASON_UNKNOWN_KIND: String = "unknown_kind"
const REASON_VERIFY_FAILED: String = "verify_failed"

var path: String = ""
var file_name: String = ""
## replay / snapshot / unreadable
var kind: String = "unreadable"
## 读不了的原因；可读时为空。
var reason: String = ""
var reason_detail: String = ""
var data: Dictionary = {}
var ui_meta: Dictionary = {}
var player_count: int = 0
var seed: int = 0
var action_count: int = 0
var saved_at: int = 0
var display_name: String = ""
## 调试界面等其他工具写的文件：只读，不能删除。
var read_only: bool = false
var is_autosave: bool = false
var is_quick: bool = false
var is_finished: bool = false

## 选中后由 UiSaveStore.validate() 填写，避免重复校验。
var verify_checked: bool = false
var verify_ok: bool = false
var verify_detail: String = ""
var verify_step: int = 0


func readable() -> bool:
	return kind == "replay" or kind == "snapshot"


func status() -> String:
	if not readable():
		return "unreadable"
	return String(ui_meta.get("status", STATUS_IN_PROGRESS))


func names() -> Array[String]:
	var result: Array[String] = []
	var raw: Variant = ui_meta.get("names", [])
	if raw is Array:
		for item: Variant in raw:
			result.append(String(item))
	return result


func seat_types() -> Array[String]:
	var result: Array[String] = []
	var raw: Variant = ui_meta.get("seat_types", [])
	if raw is Array:
		for item: Variant in raw:
			result.append(String(item))
	return result


func summary() -> Dictionary:
	var raw: Variant = ui_meta.get("summary", {})
	return raw if raw is Dictionary else {}


func winners() -> Array[int]:
	var result: Array[int] = []
	var raw: Variant = summary().get("winners", [])
	if raw is Array:
		for item: Variant in raw:
			result.append(int(item))
	return result


## 分数按座位顺序；没有 ui_meta 时为空。
func scores() -> Array[int]:
	var result: Array[int] = []
	var raw: Variant = summary().get("scores", [])
	if raw is Array:
		for item: Variant in raw:
			result.append(int(item))
	return result


func status_label() -> String:
	match status():
		STATUS_IN_PROGRESS:
			return "进行中"
		STATUS_FINISHED:
			return "已结束"
		_:
			return "无法读取"


func status_variant() -> StringName:
	match status():
		STATUS_IN_PROGRESS:
			return &"orange"
		STATUS_FINISHED:
			return &"mint"
		_:
			return &"red"


func kind_label() -> String:
	match kind:
		"replay":
			return "回放"
		"snapshot":
			return "快照"
		_:
			return "无法读取"


func kind_variant() -> StringName:
	return &"purple" if kind == "replay" else &"orange"


func reason_label() -> String:
	match reason:
		REASON_VERSION_TOO_NEW:
			return "版本太新"
		REASON_CORRUPT:
			return "文件损坏"
		REASON_UNKNOWN_KIND:
			return "不认识的类型"
		REASON_VERIFY_FAILED:
			return "重放校验失败"
		_:
			return "无法读取"


## 列表里的一行摘要。
func summary_line() -> String:
	if not readable():
		return reason_label()
	var parts: Array[String] = ["%d 人" % player_count]
	if kind == "replay":
		parts.append("%d 步" % action_count)
	var round_number: int = int(summary().get("round", 0))
	if round_number > 0:
		parts.append("第 %d 轮" % round_number)
	if kind == "snapshot":
		parts.append("预设局面")
	return " · ".join(parts)


## 头像座位：已结束的局用胜者，其余用座位 1。
func mascot_seat() -> int:
	var winners_list: Array[int] = winners()
	return winners_list[0] if not winners_list.is_empty() else 0


func saved_text() -> String:
	return relative_time(saved_at)


func saved_datetime_text() -> String:
	if saved_at <= 0:
		return "时间未知"
	var datetime: Dictionary = local_datetime(saved_at)
	return "%02d-%02d %02d:%02d" % [
		int(datetime["month"]), int(datetime["day"]),
		int(datetime["hour"]), int(datetime["minute"]),
	]


## Unix 时间 → 本地时区的日期字典（Time 的默认接口按 UTC）。
static func local_datetime(unix: int) -> Dictionary:
	var bias_minutes: int = int(Time.get_time_zone_from_system().get("bias", 0))
	return Time.get_datetime_dict_from_unix_time(unix + bias_minutes * 60)


static func relative_time(unix: int) -> String:
	if unix <= 0:
		return "时间未知"
	var seconds: int = int(Time.get_unix_time_from_system()) - unix
	if seconds < 60:
		return "刚刚"
	if seconds < 3600:
		return "%d 分钟前" % int(seconds / 60)
	if seconds < 86400:
		return "%d 小时前" % int(seconds / 3600)
	if seconds < 172800:
		return "昨天"
	var datetime: Dictionary = local_datetime(unix)
	return "%02d-%02d" % [int(datetime["month"]), int(datetime["day"])]
