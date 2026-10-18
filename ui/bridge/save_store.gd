## 存档库：扫描 / 读写 user://saves/，维护自动存档、快速存档和对局结束记录。
## 只在桥接层使用：屏幕拿 UiSaveEntry，不自己解析 JSON，也不直接调用 GameController。
class_name UiSaveStore
extends Node

const DEFAULT_ROOT: String = "user://saves"
const AUTOSAVE_NAME: String = "autosave.json"
const QUICK_NAME: String = "quick.json"
const FINISHED_DIR: String = "finished"

## 测试可以指向临时目录，避免碰真实存档。
static var root_override: String = ""

var root_dir: String = DEFAULT_ROOT


func _init() -> void:
	if not root_override.is_empty():
		root_dir = root_override


func configure(path: String) -> void:
	root_dir = path


# ---------------------------------------------------------------- 写入

func ensure_dirs() -> bool:
	var ok: bool = true
	if not DirAccess.dir_exists_absolute(root_dir):
		ok = DirAccess.make_dir_recursive_absolute(root_dir) == OK and ok
	var finished_dir: String = root_dir.path_join(FINISHED_DIR)
	if not DirAccess.dir_exists_absolute(finished_dir):
		ok = DirAccess.make_dir_recursive_absolute(finished_dir) == OK and ok
	return ok


func save_autosave(data: Dictionary, meta: Dictionary) -> bool:
	return _write(root_dir.path_join(AUTOSAVE_NAME), data, meta)


func save_quick(data: Dictionary, meta: Dictionary) -> bool:
	return _write(root_dir.path_join(QUICK_NAME), data, meta)


## 对局结束：写一份 finished/<yyyyMMdd-HHmmss>.json，然后删掉自动存档。
## 返回写入的路径；失败返回空字符串。
func transfer_finished(data: Dictionary, meta: Dictionary) -> String:
	if not ensure_dirs():
		return ""
	var saved_at: int = int(meta.get("saved_at", Time.get_unix_time_from_system()))
	var datetime: Dictionary = UiSaveEntry.local_datetime(saved_at)
	var stamp: String = "%04d%02d%02d-%02d%02d%02d" % [
		int(datetime["year"]), int(datetime["month"]), int(datetime["day"]),
		int(datetime["hour"]), int(datetime["minute"]), int(datetime["second"]),
	]
	var path: String = root_dir.path_join(FINISHED_DIR).path_join(stamp + ".json")
	var index: int = 2
	while FileAccess.file_exists(path):
		path = root_dir.path_join(FINISHED_DIR).path_join("%s-%d.json" % [stamp, index])
		index += 1
	if not _write(path, data, meta):
		return ""
	var autosave_path: String = root_dir.path_join(AUTOSAVE_NAME)
	if FileAccess.file_exists(autosave_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(autosave_path))
	return path


func _write(path: String, data: Dictionary, meta: Dictionary) -> bool:
	if not ensure_dirs():
		return false
	var payload: Dictionary = data.duplicate(true)
	payload["ui_meta"] = meta.duplicate(true)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("UiSaveStore：无法写入 %s（错误 %d）" % [path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(payload, "  "))
	file.close()
	return true


func delete_entry(entry: UiSaveEntry) -> bool:
	if entry == null or entry.read_only:
		return false
	var dir := DirAccess.open(entry.path.get_base_dir())
	if dir == null:
		return false
	return dir.remove(entry.path.get_file()) == OK


# ---------------------------------------------------------------- 扫描

## 全部存档，自动存档在前，其余按保存时间从新到旧。读不了的文件也保留。
func list() -> Array[UiSaveEntry]:
	var entries: Array[UiSaveEntry] = []
	if not ensure_dirs():
		return entries
	for file_name: String in DirAccess.get_files_at(root_dir):
		if not file_name.ends_with(".json"):
			continue
		var entry: UiSaveEntry = _load_entry(root_dir.path_join(file_name), false)
		if entry != null:
			entries.append(entry)
	var finished_dir: String = root_dir.path_join(FINISHED_DIR)
	for file_name: String in DirAccess.get_files_at(finished_dir):
		if not file_name.ends_with(".json"):
			continue
		var entry: UiSaveEntry = _load_entry(finished_dir.path_join(file_name), true)
		if entry != null:
			entries.append(entry)
	entries.sort_custom(_sort_entries)
	return entries


func autosave_entry() -> UiSaveEntry:
	var path: String = root_dir.path_join(AUTOSAVE_NAME)
	if not FileAccess.file_exists(path):
		return null
	var entry: UiSaveEntry = _load_entry(path, false)
	if entry == null or not entry.readable():
		return null
	if entry.status() != UiSaveEntry.STATUS_IN_PROGRESS:
		return null
	return entry


## 主菜单“继续上一局”的副标题数据；没有进行中的自动存档时返回空字典。
func autosave_summary() -> Dictionary:
	var entry: UiSaveEntry = autosave_entry()
	if entry == null:
		return {}
	var round_number: int = int(entry.summary().get("round", 0))
	var parts: Array[String] = ["%d 人" % entry.player_count]
	if round_number > 0:
		parts.append("第 %d 轮" % round_number)
	parts.append(entry.saved_text())
	return {
		"entry": entry,
		"text": " · ".join(parts),
		"player_count": entry.player_count,
		"round": round_number,
		"saved_text": entry.saved_text(),
	}


func _load_entry(path: String, in_finished_dir: bool) -> UiSaveEntry:
	var entry := UiSaveEntry.new()
	entry.path = path
	entry.file_name = path.get_file()
	entry.is_autosave = not in_finished_dir and entry.file_name == AUTOSAVE_NAME
	entry.is_quick = not in_finished_dir and entry.file_name == QUICK_NAME
	entry.is_finished = in_finished_dir
	entry.read_only = not (entry.is_autosave or entry.is_quick or in_finished_dir)

	var text: String = FileAccess.get_file_as_string(path)
	var json := JSON.new()
	var parse_error: Error = json.parse(text)
	if parse_error != OK:
		entry.reason = UiSaveEntry.REASON_CORRUPT
		entry.reason_detail = "第 %d 行：%s" % [json.get_error_line(), json.get_error_message()]
		entry.display_name = entry.file_name.get_basename()
		entry.saved_at = FileAccess.get_modified_time(path)
		return entry
	if not json.data is Dictionary:
		entry.reason = UiSaveEntry.REASON_CORRUPT
		entry.reason_detail = "顶层不是对象"
		entry.display_name = entry.file_name.get_basename()
		entry.saved_at = FileAccess.get_modified_time(path)
		return entry

	var data: Dictionary = json.data
	entry.data = data
	var version: int = int(data.get("schema_version", 0))
	if version > SaveFile.SCHEMA_VERSION:
		entry.reason = UiSaveEntry.REASON_VERSION_TOO_NEW
		entry.reason_detail = "存档版本 %d，当前支持到 %d" % [version, SaveFile.SCHEMA_VERSION]
	elif version != SaveFile.SCHEMA_VERSION or SaveFile.kind_of(data).is_empty():
		entry.reason = UiSaveEntry.REASON_UNKNOWN_KIND
		entry.reason_detail = "schema_version=%d，kind=%s" % [
			version, String(data.get("kind", "(缺失)")),
		]
	if not entry.reason.is_empty():
		entry.display_name = entry.file_name.get_basename()
		entry.saved_at = FileAccess.get_modified_time(path)
		return entry

	entry.kind = SaveFile.kind_of(data)
	var meta: Variant = data.get("ui_meta", {})
	if meta is Dictionary:
		entry.ui_meta = meta
	entry.player_count = int(data.get("player_count", 0))
	if entry.kind == "snapshot":
		var state: Variant = data.get("state", {})
		if state is Dictionary:
			entry.player_count = int((state as Dictionary).get("player_count", 0))
	else:
		entry.seed = int(data.get("seed", 0))
		var actions: Variant = data.get("actions", [])
		if actions is Array:
			entry.action_count = (actions as Array).size()
	entry.saved_at = int(entry.ui_meta.get("saved_at", 0))
	if entry.saved_at <= 0:
		entry.saved_at = FileAccess.get_modified_time(path)
	entry.display_name = _display_name(entry, in_finished_dir)
	return entry


func _display_name(entry: UiSaveEntry, in_finished_dir: bool) -> String:
	if entry.is_autosave:
		return "自动存档"
	if entry.is_quick:
		return "快速存档"
	var names: Array[String] = entry.names()
	if in_finished_dir or entry.status() == UiSaveEntry.STATUS_FINISHED:
		var date_text: String = UiSaveEntry.relative_time(entry.saved_at)
		if date_text.contains("前") or date_text == "刚刚" or date_text == "昨天":
			date_text = entry.saved_datetime_text().substr(0, 5)
		var winner_names: Array[String] = []
		for seat: int in entry.winners():
			if seat >= 0 and seat < names.size():
				winner_names.append(names[seat])
		if not winner_names.is_empty():
			return "%s · %s获胜" % [date_text, "、".join(winner_names)]
		return "%s · 对局记录" % date_text
	if entry.kind == "snapshot":
		return "预设局面 · %s" % entry.file_name.get_basename()
	return entry.file_name.get_basename()


static func _sort_entries(a: UiSaveEntry, b: UiSaveEntry) -> bool:
	var rank_a: int = 0 if a.is_autosave else (1 if a.is_quick else (2 if a.is_finished else 3))
	var rank_b: int = 0 if b.is_autosave else (1 if b.is_quick else (2 if b.is_finished else 3))
	if rank_a != rank_b:
		return rank_a < rank_b
	if a.saved_at != b.saved_at:
		return a.saved_at > b.saved_at
	return a.file_name < b.file_name


# ---------------------------------------------------------------- 校验

## 选中时校验能否完整载入。回放走 GameController.load_replay（会比对指纹），
## 快照走 load_snapshot；失败原因写入 entry.verify_*，同一项不重复校验。
func validate(entry: UiSaveEntry) -> Dictionary:
	if entry == null:
		return {"ok": false, "reason": UiSaveEntry.REASON_CORRUPT, "detail": "", "step": 0}
	if not entry.readable():
		return {"ok": false, "reason": entry.reason, "detail": entry.reason_detail, "step": 0}
	if entry.verify_checked:
		return {
			"ok": entry.verify_ok, "reason": "" if entry.verify_ok else UiSaveEntry.REASON_VERIFY_FAILED,
			"detail": entry.verify_detail, "step": entry.verify_step,
		}
	var controller := GameController.new()
	controller.name = "SaveValidateController"
	add_child(controller)
	var errors: Array[String] = []
	var ok: bool = false
	if entry.kind == "replay":
		controller.load_replay(entry.data, false, errors)
		ok = errors.is_empty()
	else:
		ok = controller.load_snapshot(SaveFile.unwrap_snapshot(entry.data), errors)
	controller.queue_free()

	entry.verify_checked = true
	entry.verify_ok = ok
	entry.verify_detail = "\n".join(errors)
	entry.verify_step = _first_failed_step(errors)
	return {
		"ok": ok,
		"reason": "" if ok else UiSaveEntry.REASON_VERIFY_FAILED,
		"detail": entry.verify_detail,
		"step": entry.verify_step,
	}


static func _first_failed_step(errors: Array[String]) -> int:
	for message: String in errors:
		var marker: int = message.find("第 ")
		if marker < 0:
			continue
		var rest: String = message.substr(marker + 2)
		var end: int = rest.find(" 步")
		if end > 0:
			var number_text: String = rest.substr(0, end)
			if number_text.is_valid_int():
				return int(number_text)
	return 0


# ---------------------------------------------------------------- ui_meta

static func make_meta(status: String, names: Array, seat_types: Array,
		hotseat_cover: bool, elapsed_sec: int, summary: Dictionary) -> Dictionary:
	return {
		"version": 1,
		"saved_at": int(Time.get_unix_time_from_system()),
		"status": status,
		"names": names.duplicate(),
		"seat_types": seat_types.duplicate(),
		"hotseat_cover": bool(hotseat_cover),
		"elapsed_sec": int(elapsed_sec),
		"summary": summary.duplicate(true),
	}


static func make_summary(round_number: int, current_seat: int,
		scores: Array, winners: Array = []) -> Dictionary:
	return {
		"round": round_number,
		"current_seat": current_seat,
		"scores": scores.duplicate(),
		"winners": winners.duplicate(),
	}
