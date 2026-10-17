## 存档 / 重放 / 快照文件的格式（纯数据处理，不碰文件系统：读写由调用方负责）。
## 两种文件：
##   重放文件（kind = "replay"）：人数 + 种子 + 动作序列 + 末尾指纹。
##     文件很小，可完整重放复现（存档 = 种子 + 动作序列），用来复现 bug。
##   快照文件（kind = "snapshot"）：GameState.to_dict(VIEW_ALL) 的完整状态。
##     用来直接进入任意局面（tests/scenarios/ 的预设局面就是这种）。
class_name SaveFile
extends RefCounted

const SCHEMA_VERSION: int = 1
const KIND_REPLAY: String = "replay"
const KIND_SNAPSHOT: String = "snapshot"

## 组一个重放文件。actions 可以是 Action 对象或已经转好的字典。
static func build_replay(player_count: int, seed: int, actions: Array,
		fingerprint: String = "") -> Dictionary:
	var action_dicts: Array = []
	for item: Variant in actions:
		if item is Action:
			action_dicts.append((item as Action).to_dict())
		else:
			action_dicts.append(item)
	return {
		"schema_version": SCHEMA_VERSION,
		"kind": KIND_REPLAY,
		"player_count": player_count,
		"seed": seed,
		"actions": action_dicts,
		"fingerprint": fingerprint,
	}

static func wrap_snapshot(state: GameState) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"kind": KIND_SNAPSHOT,
		"state": state.to_dict(GameState.VIEW_ALL),
	}

## 文件类型："replay" / "snapshot"；不认识（含 schema_version 不符）时返回空字符串。
static func kind_of(data: Dictionary) -> String:
	if int(data.get("schema_version", 0)) != SCHEMA_VERSION:
		return ""
	var kind: String = String(data.get("kind", ""))
	if kind == KIND_REPLAY or kind == KIND_SNAPSHOT:
		return kind
	return ""

## 解析重放文件：{player_count, seed, actions: Array[Action], fingerprint}；失败返回 {} 并报错。
static func parse_replay(data: Dictionary) -> Dictionary:
	if kind_of(data) != KIND_REPLAY:
		push_error("SaveFile：不是重放文件（kind 应为 \"replay\"，schema_version 应为 %d）" % SCHEMA_VERSION)
		return {}
	var raw_actions: Variant = data.get("actions", [])
	if not raw_actions is Array:
		push_error("SaveFile：actions 必须是数组")
		return {}
	var actions: Array[Action] = []
	for index: int in (raw_actions as Array).size():
		var item: Variant = (raw_actions as Array)[index]
		if not item is Dictionary:
			push_error("SaveFile：actions[%d] 必须是对象" % index)
			return {}
		var action: Action = Action.from_dict(item)
		if action == null:
			push_error("SaveFile：actions[%d] 解析失败" % index)
			return {}
		actions.append(action)
	return {
		"player_count": int(data.get("player_count", 0)),
		"seed": int(data.get("seed", 0)),
		"actions": actions,
		"fingerprint": String(data.get("fingerprint", "")),
	}

## 取出快照内层的状态字典；失败返回 {} 并报错。
static func unwrap_snapshot(data: Dictionary) -> Dictionary:
	if kind_of(data) != KIND_SNAPSHOT:
		push_error("SaveFile：不是快照文件（kind 应为 \"snapshot\"，schema_version 应为 %d）" % SCHEMA_VERSION)
		return {}
	var state: Variant = data.get("state")
	if not state is Dictionary:
		push_error("SaveFile：快照文件缺少 state 对象")
		return {}
	return state
