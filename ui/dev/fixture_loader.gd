## 读取 ui/dev/fixtures/ 下的夹具：视图 + 座位信息 + 日志 + 顶条覆盖。
## 夹具格式与 BRIDGE_AND_REQUESTS.md 第 2 节的假后端一致：seats / me_seat / steps[0].view。
## U2 的牌桌预览、截图与冒烟测试都用它；U3 的 FakeBackend 可以继续复用。
class_name UiFixtureLoader
extends RefCounted

const DIR := "res://ui/dev/fixtures/"


static func names() -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(DIR)
	if dir == null:
		return result
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".json"):
			result.append(entry.trim_suffix(".json"))
		entry = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result


## 返回 {name, view, me_seat, session_info}；失败返回空字典并报错。
static func load_fixture(fixture_name: String) -> Dictionary:
	var path := DIR + fixture_name + ".json"
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("UiFixtureLoader：读不到夹具 %s" % path)
		return {}
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary:
		push_error("UiFixtureLoader：夹具 %s 不是 JSON 对象" % path)
		return {}
	var fixture: Dictionary = data
	var steps: Array = fixture.get("steps", [])
	if steps.is_empty() or not steps[0] is Dictionary:
		push_error("UiFixtureLoader：夹具 %s 没有 steps[0]" % path)
		return {}
	var view_rel: String = String((steps[0] as Dictionary).get("view", ""))
	var view_text := FileAccess.get_file_as_string(DIR + view_rel)
	if view_text.is_empty():
		push_error("UiFixtureLoader：读不到视图 %s%s" % [DIR, view_rel])
		return {}
	var view: Variant = JSON.parse_string(view_text)
	if not view is Dictionary:
		push_error("UiFixtureLoader：视图 %s%s 不是 JSON 对象" % [DIR, view_rel])
		return {}
	return {
		"name": fixture_name,
		"view": view,
		"me_seat": int(fixture.get("me_seat", -1)),
		"session_info": _session_info(fixture),
	}


static func _session_info(fixture: Dictionary) -> Dictionary:
	var names: Array[String] = []
	var seat_types: Array[String] = []
	var seats: Array = fixture.get("seats", [])
	for item: Variant in seats:
		var seat: Dictionary = item if item is Dictionary else {}
		names.append(String(seat.get("name", "")))
		seat_types.append(String(seat.get("type", "human")))
	return {
		"names": names,
		"seat_types": seat_types,
		"log": fixture.get("log", []),
		"strip": fixture.get("strip", {}),
		"pill_text": String(fixture.get("pill_text", "")),
		"mode": String(fixture.get("mode", "")),
		"replay_label": String(fixture.get("replay_label", "")),
		"flash_cards": fixture.get("flash_cards", []),
		"log_limit": int(fixture.get("log_limit", 0)),
		"llm_waiting": fixture.get("llm_waiting", {}),
	}
