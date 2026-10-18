## 牌桌会话：屏幕与逻辑层之间的唯一入口。
## 负责开局 / 读快照、隐私过滤（别人的盲抽一律隐藏；我自己的盲抽在别人回合用缓存补上）、
## 日志整理和结算数据；屏幕只认它的信号和 legal_actions()。
class_name UiTableSession
extends Node

signal view_updated(view: Dictionary, me_seat: int)
signal events_arrived(events: Array[Dictionary])
signal game_ended(result: Dictionary)
signal action_failed(message: String)
signal seat_status_changed(seat: int, status: Dictionary)

const DEFAULT_NAMES: Array[String] = ["小明", "薄荷", "紫晶", "橘子"]

var _backend: UiLiveBackend = null
var _catalog: CardCatalog = null
var _rules: RulesConfig = null
var _names: Array[String] = []
var _types: Array[String] = []
## 与座位一一对应的选项；大模型座位用 {"llm_profile": id}（IR-08）。
var _seat_options: Array[Dictionary] = []
var _local_seats: Array[int] = []
var _me_seat: int = -1
## 当前行动者的原始视图（只有桥接层内部使用，用于算合法动作）。
var _raw_view: Dictionary = {}
## 过滤后的视图（viewer 是“我”）。
var _display_view: Dictionary = {}
## 座位 -> 该座位预留卡 id（按出现顺序）；只记自己在场时看到过的。
var _blind_cache: Dictionary = {}
## 从新到旧；条目额外带 _at_ms / _merge 字段，输出时去掉。
var _log: Array[Dictionary] = []
## 大模型理由 / 兜底先于对应动作的事件到达，暂存到该座位下一条日志上。
var _pending_llm_reason: Dictionary = {}
var _pending_llm_fallback: Dictionary = {}
var _ended: bool = false
var _result: Dictionary = {}
var _started_ms: int = 0
## 读档继续的局：界面计时要接上存档里的 elapsed_sec。
var _elapsed_offset_sec: int = 0
## 开局设置（重开一局用）；读档继续的局由存档的 ui_meta 重建。
var _setup: Dictionary = {}
## 读档继续前的座位类型（IR-04 落地前实际控制器全是人类，重开一局时仍沿用原类型）。
var _original_types: Array[String] = []
var _hotseat_cover: bool = true
var _resume_note: String = ""


func _exit_tree() -> void:
	close()


# ---------------------------------------------------------------- 开局 / 载入

## setup = {count, seed (-1 = 随机), seats: [{name, type}], hotseat_cover}。
func start_local(setup: Dictionary) -> bool:
	close()
	var count: int = int(setup.get("count", 2))
	var seats: Array = setup.get("seats", [])
	if seats.size() != count or count <= 0:
		action_failed.emit("开局参数不正确：座位数 %d，人数 %d" % [seats.size(), count])
		return false
	var raw_options: Variant = setup.get("seat_options", [])
	var setup_options: Array = raw_options if raw_options is Array else []
	for seat: int in count:
		var entry: Dictionary = seats[seat] if seats[seat] is Dictionary else {}
		_names.append(String(entry.get("name", "")))
		var seat_type: String = String(entry.get("type", "human"))
		_types.append(seat_type)
		_seat_options.append(_option_for(entry, setup_options, seat))
		if seat_type == "human":
			_local_seats.append(seat)
	_original_types = _types.duplicate()
	_hotseat_cover = bool(setup.get("hotseat_cover", true))
	_setup = {
		"count": count,
		"seed": int(setup.get("seed", -1)),
		"seats": seats.duplicate(true),
		"seat_options": _seat_options.duplicate(true),
		"hotseat_cover": _hotseat_cover,
	}
	_prepare()
	_backend = UiLiveBackend.new()
	_backend.attach(self)
	_connect_backend()
	var ok: bool = _backend.start_local(count, int(setup.get("seed", -1)), _types,
			_seat_options)
	if not ok:
		close()
		return false
	return true


## 座位的附加选项：setup.seat_options 优先，否则从座位条目的 llm_profile 推。
static func _option_for(entry: Dictionary, setup_options: Array, seat: int) -> Dictionary:
	if seat < setup_options.size() and setup_options[seat] is Dictionary:
		var explicit: Dictionary = setup_options[seat]
		if not explicit.is_empty():
			return explicit.duplicate(true)
	var option: Dictionary = {}
	var profile_id: String = String(entry.get("llm_profile", "")).strip_edges()
	if not profile_id.is_empty():
		option["llm_profile"] = profile_id
	return option


## 从快照载入（预设局面 / 继续存档的雏形）。所有座位都恢复为人类控制器。
func load_snapshot(state_data: Dictionary, errors: Array[String] = []) -> bool:
	close()
	var count: int = int(state_data.get("player_count", 0))
	if count <= 0:
		errors.append("快照里没有有效的人数")
		return false
	for seat: int in count:
		_names.append(DEFAULT_NAMES[seat] if seat < DEFAULT_NAMES.size() else "座位 %d" % (seat + 1))
		_types.append("human")
		_local_seats.append(seat)
	_original_types = _types.duplicate()
	_hotseat_cover = false
	_prepare()
	_backend = UiLiveBackend.new()
	_backend.attach(self)
	_connect_backend()
	if not _backend.load_snapshot(state_data, errors):
		close()
		return false
	return true


## 从存档继续：回放存档走 load_replay（种子 + 动作），快照走 load_snapshot。
## IR-04 落地前，所有座位都恢复为人类控制器；原座位类型保留在 ui_meta 里供界面提示和重开一局。
func resume(entry: UiSaveEntry, errors: Array[String]) -> bool:
	if entry == null:
		close()
		errors.append("没有选中存档")
		return false
	if not entry.readable():
		close()
		errors.append(entry.reason_label())
		return false
	return _resume_payload(entry.kind, entry.data, entry.ui_meta, entry.player_count, errors)


## 回放到第 step 步为止（U6 的“从这里接着玩”会用到）。
func resume_until(entry: UiSaveEntry, step: int, errors: Array[String]) -> bool:
	if entry == null or entry.kind != "replay":
		errors.append("只有回放存档可以读到指定步")
		return false
	var data: Dictionary = entry.data.duplicate(true)
	var actions: Variant = data.get("actions", [])
	if not actions is Array:
		errors.append("存档里没有动作序列")
		return false
	var action_list: Array = actions
	var count: int = clampi(step, 0, action_list.size())
	action_list.resize(count)
	data["actions"] = action_list
	data["fingerprint"] = ""
	return _resume_payload("replay", data, entry.ui_meta, entry.player_count, errors)


func _resume_payload(kind: String, data: Dictionary, ui_meta: Dictionary,
		count: int, errors: Array[String]) -> bool:
	close()
	if count <= 0:
		errors.append("存档里没有有效的人数")
		return false
	var meta_names: Array[String] = []
	var raw_names: Variant = ui_meta.get("names", [])
	if raw_names is Array:
		for item: Variant in raw_names:
			meta_names.append(String(item))
	var original_types: Array[String] = []
	var raw_types: Variant = ui_meta.get("seat_types", [])
	if raw_types is Array:
		for item: Variant in raw_types:
			original_types.append(String(item))
	if original_types.size() != count:
		original_types.clear()
		for seat: int in count:
			original_types.append("human")
	for seat: int in count:
		_names.append(meta_names[seat] if seat < meta_names.size() and not meta_names[seat].is_empty()
				else (DEFAULT_NAMES[seat] if seat < DEFAULT_NAMES.size() else "座位 %d" % (seat + 1)))
		_types.append("human")
		_local_seats.append(seat)
	_original_types = original_types
	_hotseat_cover = bool(ui_meta.get("hotseat_cover", true))
	_elapsed_offset_sec = maxi(int(ui_meta.get("elapsed_sec", 0)), 0)
	_setup = _build_rematch_setup(count)
	_prepare()
	_backend = UiLiveBackend.new()
	_backend.attach(self)
	_connect_backend()
	var ok: bool = false
	if kind == "replay":
		ok = _backend.load_replay(data, errors)
	else:
		ok = _backend.load_snapshot(SaveFile.unwrap_snapshot(data), errors)
	if not ok:
		close()
		return false
	for seat_type: String in _original_types:
		if seat_type != "human":
			_resume_note = "这局里的电脑座位暂时以人类身份恢复；轮到它们时请替它们操作。"
			break
	return true


func close() -> void:
	if _backend != null:
		_backend.release()
		_backend = null
	_names.clear()
	_types.clear()
	_seat_options.clear()
	_local_seats.clear()
	_me_seat = -1
	_raw_view = {}
	_display_view = {}
	_blind_cache.clear()
	_log.clear()
	_pending_llm_reason.clear()
	_pending_llm_fallback.clear()
	_ended = false
	_result = {}
	_elapsed_offset_sec = 0
	_setup = {}
	_original_types.clear()
	_hotseat_cover = true
	_resume_note = ""


func _prepare() -> void:
	_catalog = DataRegistry.card_catalog()
	_rules = DataRegistry.rules()
	_started_ms = Time.get_ticks_msec()
	_ended = false
	_result = {}


func _connect_backend() -> void:
	_backend.view_received.connect(_on_backend_view)
	_backend.events_received.connect(_on_backend_events)
	_backend.finished.connect(_on_backend_finished)
	_backend.rejected.connect(func(message: String) -> void: action_failed.emit(message))
	_backend.llm_waiting.connect(func(seat: int, profile: String, attempt: int, limit_sec: float) -> void:
		seat_status_changed.emit(seat, {
			"kind": "llm_waiting", "profile": profile, "attempt": attempt,
			"started_ms": Time.get_ticks_msec(), "limit_sec": limit_sec,
		}))
	_backend.llm_reason.connect(func(seat: int, text: String) -> void:
		_pending_llm_reason[seat] = text
		seat_status_changed.emit(seat, {"kind": "llm_reason", "text": text}))
	_backend.llm_fallback.connect(func(seat: int, reason: String, bot_type: String) -> void:
		_pending_llm_fallback[seat] = {"reason": reason, "bot": bot_type}
		seat_status_changed.emit(seat, {"kind": "llm_fallback", "reason": reason, "bot": bot_type}))


# ---------------------------------------------------------------- 视图 / 隐私

func _on_backend_view(view: Dictionary) -> void:
	_raw_view = view
	var viewer: int = int(view.get("viewer_seat", -1))
	if viewer >= 0 and _local_seats.has(viewer):
		_me_seat = viewer
		_remember_reserved(view, viewer)
	elif _me_seat < 0 or not _local_seats.has(_me_seat):
		_me_seat = _local_seats.min() if not _local_seats.is_empty() else -1
	_display_view = sanitize_view(view, _me_seat, _blind_cache)
	view_updated.emit(_display_view, _me_seat)
	if String(_display_view.get("phase", "")) == "finished":
		_emit_result()


## 过滤视图：viewer 不是“我”时，viewer 自己的盲抽也画牌背；
## “我”的盲抽在别人回合用缓存补上（IR-01 落地前的临时方案）。
static func sanitize_view(view: Dictionary, me_seat: int, blind_cache: Dictionary) -> Dictionary:
	var clean: Dictionary = view.duplicate(true)
	clean["viewer_seat"] = me_seat
	var players: Array = clean.get("players", [])
	for seat: int in players.size():
		var player: Dictionary = players[seat] if players[seat] is Dictionary else {}
		var reserved: Array = player.get("reserved", [])
		for index: int in reserved.size():
			var entry: Dictionary = reserved[index] if reserved[index] is Dictionary else {}
			if not bool(entry.get("blind", false)):
				continue
			if seat == me_seat:
				if entry.get("id") == null:
					var cache: Array = blind_cache.get(seat, [])
					if index < cache.size() and not String(cache[index]).is_empty():
						entry["id"] = String(cache[index])
			else:
				entry["id"] = null
	return clean


func _remember_reserved(view: Dictionary, seat: int) -> void:
	var players: Array = view.get("players", [])
	if seat < 0 or seat >= players.size():
		return
	var player: Dictionary = players[seat] if players[seat] is Dictionary else {}
	var ids: Array[String] = []
	for entry: Variant in player.get("reserved", []):
		var item: Dictionary = entry if entry is Dictionary else {}
		var raw: Variant = item.get("id")
		ids.append(String(raw) if raw != null else "")
	_blind_cache[seat] = ids


# ---------------------------------------------------------------- 事件 / 日志

func _on_backend_events(events: Array) -> void:
	var dicts: Array[Dictionary] = []
	for item: Variant in events:
		if not item is GameEvent:
			continue
		var data: Dictionary = (item as GameEvent).to_dict()
		dicts.append(data)
		if _local_seats.has(int(data.get("seat", -1))):
			update_blind_cache(_blind_cache, int(data.get("seat", -1)), data)
		_append_log(data)
	events_arrived.emit(dicts)


## 用公开事件维护盲抽缓存的位置：预留追加、从预留区购买则移除。
## 盲抽预留没有卡牌 id，先放一个空位；这张牌要等本人下一个视图才能知道是哪张（IR-01 前）。
static func update_blind_cache(cache: Dictionary, seat: int, event: Dictionary) -> void:
	var ids: Array = cache.get(seat, [])
	var type: String = String(event.get("type", ""))
	if type == "card_reserved":
		if bool(event.get("blind", false)):
			ids.append("")
		else:
			ids.append(String(event.get("card_id", "")))
		cache[seat] = ids
		return
	if type == "card_purchased" and bool(event.get("from_reserved", false)):
		var card_id: String = String(event.get("card_id", ""))
		var index: int = ids.find(card_id)
		if index >= 0:
			ids.remove_at(index)
		else:
			# 买掉的可能是一张还没见过正面的盲抽牌：移掉一个空位。
			var unknown: int = ids.find("")
			if unknown >= 0:
				ids.remove_at(unknown)
		cache[seat] = ids


func _append_log(event: Dictionary) -> void:
	var type: String = String(event.get("type", ""))
	var seat: int = int(event.get("seat", -1))
	if type in ["turn_started", "turn_ended", "discard_required", "noble_choice_required"]:
		# 回合边界之后不应再有上一条动作的理由 / 兜底残留。
		if type == "turn_ended":
			_pending_llm_reason.erase(seat)
			_pending_llm_fallback.erase(seat)
		return
	if type == "gems_discarded":
		var merge_key: String = "discard:%d" % seat
		if not _log.is_empty() and String(_log[0].get("_merge", "")) == merge_key:
			var colors: Array = _log[0].get("_colors", [])
			colors.append(String(event.get("color", "")))
			_log[0]["_colors"] = colors
			_log[0]["seat"] = seat
			_log[0]["text"] = "%s 弃回 %s" % [
				UiEventText.name_of(seat, _names), UiEventText.discard_colors_text(colors),
			]
			_log[0]["_at_ms"] = Time.get_ticks_msec()
			_attach_llm_note(seat, _log[0])
			return
	var text: String = UiEventText.text_for(event, _catalog, _names)
	if text.is_empty():
		return
	var entry: Dictionary = {
		"seat": seat, "text": text, "time": "刚刚", "_at_ms": Time.get_ticks_msec(),
	}
	if type == "gems_discarded":
		entry["_merge"] = "discard:%d" % seat
		entry["_colors"] = [String(event.get("color", ""))]
	_attach_llm_note(seat, entry)
	_log.push_front(entry)


## 把暂存的大模型理由 / 兜底信息挂到这条日志上（只挂一次）。
func _attach_llm_note(seat: int, entry: Dictionary) -> void:
	if _pending_llm_reason.has(seat):
		entry["reason"] = String(_pending_llm_reason[seat])
		_pending_llm_reason.erase(seat)
	if _pending_llm_fallback.has(seat):
		var fallback: Dictionary = _pending_llm_fallback[seat]
		entry["fallback_reason"] = String(fallback.get("reason", ""))
		entry["fallback_bot"] = String(fallback.get("bot", ""))
		_pending_llm_fallback.erase(seat)


## 从新到旧的日志条目：{seat, text, time}。相对时间在读取时计算。
func log_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var now: int = Time.get_ticks_msec()
	for entry: Dictionary in _log:
		var copy: Dictionary = entry.duplicate()
		copy["time"] = _relative_time(now - int(entry.get("_at_ms", now)))
		copy.erase("_at_ms")
		copy.erase("_merge")
		copy.erase("_colors")
		result.append(copy)
	return result


func _relative_time(age_ms: int) -> String:
	var seconds: int = int(maxi(age_ms, 0) / 1000)
	if seconds < 10:
		return "刚刚"
	if seconds < 60:
		return "%d 秒" % seconds
	if seconds < 3600:
		return "%d 分钟" % int(seconds / 60)
	return "%d 小时" % int(seconds / 3600)


# ---------------------------------------------------------------- 动作

func legal_actions() -> Array[Action]:
	if not is_my_turn():
		return []
	return Rules.get_legal_actions(_raw_view, _catalog, _rules)


func submit(action: Action) -> bool:
	if not is_my_turn():
		return false
	return _backend.submit(action)


## 逐个提交（弃宝石用）；任一失败就停。
func submit_sequence(actions: Array[Action]) -> bool:
	for action: Action in actions:
		if not submit(action):
			return false
	return true


func is_my_turn() -> bool:
	if _raw_view.is_empty() or _local_seats.is_empty():
		return false
	if String(_raw_view.get("phase", "")) == "finished":
		return false
	var current: int = int(_raw_view.get("current_seat", -1))
	return _local_seats.has(current)


# ---------------------------------------------------------------- 查询

func me_seat() -> int:
	return _me_seat


func local_seats() -> Array[int]:
	return _local_seats.duplicate()


func names() -> Array[String]:
	return _names.duplicate()


func seat_types() -> Array[String]:
	return _types.duplicate()


func seat_info(seat: int) -> Dictionary:
	var name: String = ""
	if seat >= 0 and seat < _names.size():
		name = _names[seat]
	if name.is_empty():
		name = "座位 %d" % (seat + 1)
	return {
		"name": name,
		"type": _types[seat] if seat >= 0 and seat < _types.size() else "human",
		"mascot": seat,
	}


func rules() -> RulesConfig:
	return _rules


func catalog() -> CardCatalog:
	return _catalog


func elapsed_seconds() -> int:
	return _elapsed_offset_sec + maxi(int((Time.get_ticks_msec() - _started_ms) / 1000), 0)


## 重开一局用的设置：同样的名字 / 座位类型 / 同屏开关，新种子（-1 = 随机）。
func rematch_setup() -> Dictionary:
	if not _setup.is_empty():
		var setup: Dictionary = _setup.duplicate(true)
		setup["seed"] = -1
		return setup
	return _build_rematch_setup(_names.size())


func _build_rematch_setup(count: int) -> Dictionary:
	var seats: Array[Dictionary] = []
	var options: Array[Dictionary] = []
	for seat: int in count:
		var seat_type: String = _original_types[seat] \
				if seat < _original_types.size() else "human"
		var seat_name: String = _names[seat] \
				if seat < _names.size() else "座位 %d" % (seat + 1)
		var entry: Dictionary = {"name": seat_name, "type": seat_type}
		var option: Dictionary = {}
		if seat_type == "llm":
			var profile_id: String = ""
			if seat < _seat_options.size():
				profile_id = String(_seat_options[seat].get("llm_profile", ""))
			if profile_id.is_empty():
				profile_id = UiLlmBridge.active_profile_id()
			if not profile_id.is_empty():
				entry["llm_profile"] = profile_id
				option["llm_profile"] = profile_id
		seats.append(entry)
		options.append(option)
	return {
		"count": count, "seed": -1, "seats": seats,
		"seat_options": options, "hotseat_cover": _hotseat_cover,
	}


## 大模型配置档被多少个座位使用（设置页 16 的“几个座位在用”）。
func llm_profile_usage() -> Dictionary:
	var usage: Dictionary = {}
	for seat: int in _types.size():
		if _types[seat] != "llm" or seat >= _seat_options.size():
			continue
		var profile_id: String = String(_seat_options[seat].get("llm_profile", ""))
		if profile_id.is_empty():
			profile_id = UiLlmBridge.active_profile_id()
		if profile_id.is_empty():
			continue
		usage[profile_id] = int(usage.get(profile_id, 0)) + 1
	return usage


func seat_options() -> Array[Dictionary]:
	return _seat_options.duplicate(true)


## 读档继续前的座位类型（界面显示 / 存档 ui_meta 用）；新开局等于实际座位类型。
func original_seat_types() -> Array[String]:
	return _original_types.duplicate()


func hotseat_cover() -> bool:
	return _hotseat_cover


## 读档继续时给界面的提示（电脑座位暂时以人类身份恢复）；没有提示时为空。
func resume_note() -> String:
	return _resume_note


func can_save() -> bool:
	return _backend != null and _backend.can_save_replay()


## 存档内容：GameController.build_replay_data()；这局来自预设局面时为 {}。
func build_save_data() -> Dictionary:
	if _backend == null:
		return {}
	return _backend.build_replay_data()


func fingerprint() -> String:
	return _backend.fingerprint() if _backend != null else ""


## 暂停菜单：IR-12 落地前只记录状态，电脑在后台照常行动。
func set_paused(_paused: bool) -> void:
	pass


func view() -> Dictionary:
	return _display_view


func result() -> Dictionary:
	return _result


# ---------------------------------------------------------------- 结算

func _on_backend_finished(_winners: Array, _scores: Dictionary) -> void:
	_emit_result()


func _emit_result() -> void:
	if _ended:
		return
	var view: Dictionary = _raw_view
	if view.is_empty():
		return
	var scores: Dictionary = {}
	var cards: Dictionary = {}
	var nobles: Dictionary = {}
	var top_score: int = -1
	for seat: int in int(view.get("player_count", 0)):
		var score: int = UiViewMath.score(view, seat, _catalog)
		scores[str(seat)] = score
		cards[str(seat)] = UiViewMath.card_count(view, seat)
		nobles[str(seat)] = UiViewMath.noble_count(view, seat)
		top_score = maxi(top_score, score)
	var tied: Array[int] = []
	for seat: int in int(view.get("player_count", 0)):
		if int(scores[str(seat)]) == top_score:
			tied.append(seat)
	var tiebreak: String = ""
	if tied.size() > 1:
		tiebreak = "tie"
		var first_cards: int = int(cards[str(tied[0])])
		for seat: int in tied:
			if int(cards[str(seat)]) != first_cards:
				tiebreak = "cards"
				break
	var winners: Array[int] = []
	for item: Variant in view.get("winners", []):
		winners.append(int(item))
	_result = {
		"winners": winners,
		"scores": scores,
		"reason": String(view.get("finished_reason", "")),
		"cards": cards,
		"nobles": nobles,
		"tiebreak": tiebreak,
		"round": UiViewMath.round_number(view),
		"elapsed_sec": elapsed_seconds(),
	}
	_ended = true
	game_ended.emit(_result)
