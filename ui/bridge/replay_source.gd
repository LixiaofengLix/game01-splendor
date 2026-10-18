## 回放数据源：把一份回放存档（人数 + 种子 + 动作序列）变成任意一步的视图与步骤说明。
## IR-03 落地前的临时实现：内部用 GameController.load_replay 载入截断到第 N 步的动作序列，
## 因此只有“当前行动者视角”；要别的视角时把所有人的盲抽预留 id 置空（不会泄露）。
## 回放屏只读这里的结果，不直接碰 GameController / GameState。
class_name UiReplaySource
extends Node

const DEFAULT_NAMES: Array[String] = ["小明", "薄荷", "紫晶", "橘子"]
## 日志只保留最近这么多步（牌桌最多显示 7 条，留一点余量；避免一次载入全部前缀）。
const LOG_WINDOW: int = 8

var _controller: GameController = null
var _catalog: CardCatalog = null
var _data: Dictionary = {}
var _actions: Array[Action] = []
var _names: Array[String] = []
var _types: Array[String] = []
var _player_count: int = 0
var _seed: int = 0
var _opened: bool = false
var _final_fingerprint: String = ""
## 步骤 -> 该步之后、当前行动者的原始视图；按需载入。
var _view_cache: Dictionary = {}
## 步骤 -> 步骤说明（含 {card:id} / {gem:color} 标记）。
var _text_cache: Dictionary = {}
## 步骤 -> 动效事件（由动作 + 前后视图合成，IR-03 前没有真实事件）。
var _event_cache: Dictionary = {}


func _exit_tree() -> void:
	close()


## 打开一份回放存档。失败原因写进 errors，成功后可反复 step 查询。
func open(entry: UiSaveEntry, errors: Array[String]) -> bool:
	if entry == null:
		errors.append("没有选中存档")
		return false
	if entry.kind != "replay":
		errors.append("只有回放存档可以看回放（快照没有动作序列）")
		return false
	return open_data(entry.data, entry.ui_meta, entry.player_count, errors)


## 直接用存档字典打开（结算弹窗的“看回放”没有落盘文件，也走这里）。
func open_data(data: Dictionary, ui_meta: Dictionary, player_count: int,
		errors: Array[String]) -> bool:
	close()
	if SaveFile.kind_of(data) != SaveFile.KIND_REPLAY:
		errors.append("这不是回放存档（需要种子和动作序列）")
		return false
	var parsed: Dictionary = SaveFile.parse_replay(data)
	if parsed.is_empty():
		errors.append("回放文件解析失败（详见 output 面板）")
		return false
	_data = data.duplicate(true)
	_actions.assign(parsed.get("actions", []))
	_player_count = int(parsed.get("player_count", player_count))
	_seed = int(parsed.get("seed", 0))
	if _player_count <= 0:
		errors.append("回放里没有有效的人数")
		return false
	_catalog = DataRegistry.card_catalog()
	_build_names(ui_meta)
	_controller = GameController.new()
	_controller.name = "ReplayController"
	add_child(_controller)
	# 先载入最后一步：验证整份动作序列，并拿到最终指纹。
	if _load_view(step_count(), errors).is_empty():
		close()
		return false
	_final_fingerprint = _controller.fingerprint()
	# 截断载入时清空了指纹，所以在这里补上存档指纹的比对（和 load_replay 一致）。
	var expected: String = String(_data.get("fingerprint", ""))
	if not expected.is_empty() and expected != _final_fingerprint:
		errors.append("重放后状态不一致：存档指纹 %s，现在 %s（改过规则或数据？）"
				% [expected, _final_fingerprint])
		close()
		return false
	_opened = true
	return true


func close() -> void:
	if _controller != null:
		_controller.reset()
		if is_instance_valid(_controller):
			_controller.queue_free()
		_controller = null
	_data = {}
	_actions.clear()
	_names.clear()
	_types.clear()
	_player_count = 0
	_seed = 0
	_view_cache.clear()
	_text_cache.clear()
	_event_cache.clear()
	_final_fingerprint = ""
	_opened = false


func is_open() -> bool:
	return _opened


func step_count() -> int:
	return _actions.size()


func action_count() -> int:
	return _actions.size()


func player_count() -> int:
	return _player_count


func seed_value() -> int:
	return _seed


func names() -> Array[String]:
	return _names.duplicate()


func seat_types() -> Array[String]:
	return _types.duplicate()


## 最后一步的状态指纹（与存档里的指纹一致时可用于校验）。
func fingerprint() -> String:
	return _final_fingerprint


# ---------------------------------------------------------------- 视图

## 第 step 步（0 = 开局）的视图。viewer_seat = -1 表示“全部公开”（所有盲抽都画牌背）；
## 指定座位时，只有该座位正好是这一步的当前行动者，才能看到自己的盲抽正面。
func view(step: int, viewer_seat: int = -1) -> Dictionary:
	var base: Dictionary = _load_view(clampi(step, 0, step_count()), [])
	if base.is_empty():
		return {}
	var copy: Dictionary = base.duplicate(true)
	if viewer_seat >= 0 and int(base.get("viewer_seat", -1)) == viewer_seat:
		copy["viewer_seat"] = viewer_seat
		return copy
	return _hide_all_blind(copy)


func public_view(step: int) -> Dictionary:
	return view(step, -1)


## 第 step 步（1 起）是谁在行动；0 / 越界返回 -1。
func actor_at(step: int) -> int:
	if step <= 0 or step > step_count():
		return -1
	var before: Dictionary = _load_view(step - 1, [])
	return int(before.get("current_seat", -1)) if not before.is_empty() else -1


## 第 step 步（1 起）行动者当时所处的轮次。
func round_at(step: int) -> int:
	if step <= 0 or step > step_count():
		return 1
	var before: Dictionary = _load_view(step - 1, [])
	return UiViewMath.round_number(before) if not before.is_empty() else 1


func action_at(step: int) -> Action:
	if step <= 0 or step > _actions.size():
		return null
	return _actions[step - 1]


## 某一步的视图里，viewer 自己的盲抽预留是否可见（测试隐私用）。
func blind_visible(step: int, seat: int) -> bool:
	var raw: Dictionary = _load_view(clampi(step, 0, step_count()), [])
	var players: Array = raw.get("players", [])
	if seat < 0 or seat >= players.size():
		return false
	var player: Dictionary = players[seat] if players[seat] is Dictionary else {}
	for entry: Variant in player.get("reserved", []):
		if entry is Dictionary and bool((entry as Dictionary).get("blind", false)) \
				and (entry as Dictionary).get("id") != null:
			return true
	return false


# ---------------------------------------------------------------- 步骤说明 / 日志

## 第 step 步（1 起）的中文说明，形如“薄荷 盲抽预留了三级牌堆顶”。
func step_text(step: int) -> String:
	if step <= 0 or step > step_count():
		return ""
	if _text_cache.has(step):
		return String(_text_cache[step])
	var action: Action = _actions[step - 1]
	var actor: int = actor_at(step)
	var who: String = UiEventText.name_of(actor, _names)
	var before: Dictionary = _load_view(step - 1, [])
	var after: Dictionary = _load_view(step, [])
	var text: String = ""
	match action.type:
		Enums.ActionType.TAKE_THREE:
			text = "%s 拿了 %s" % [who, _taken_text(action.colors)]
		Enums.ActionType.TAKE_TWO:
			text = "%s 拿了 2 枚 {gem:%s}" % [who, Enums.color_to_string(action.colors[0])]
		Enums.ActionType.RESERVE:
			var gold: int = maxi(
					UiViewMath.token_count(before, actor, Enums.GemColor.GOLD)
					- UiViewMath.token_count(after, actor, Enums.GemColor.GOLD), 0)
			var gold_text: String = "，拿到 1 枚 {gem:gold}" if gold > 0 else ""
			if not action.card_id.is_empty():
				text = "%s 预留了 %s%s" % [who, _card_token(action.card_id), gold_text]
			else:
				text = "%s 盲抽预留了%s牌堆顶%s" % [
					who, UiEventText.level_zh(action.level), gold_text,
				]
		Enums.ActionType.PURCHASE:
			var paid: String = _paid_text(before, after, actor)
			var suffix: String = "，付 %s" % paid if not paid.is_empty() else ""
			text = "%s 购买 %s%s" % [who, _card_token(action.card_id), suffix]
		Enums.ActionType.DISCARD:
			text = "%s 弃回 {gem:%s}" % [who, Enums.color_to_string(action.color)]
		Enums.ActionType.CHOOSE_NOBLE:
			var noble: NobleData = _catalog.noble(action.noble_id) if _catalog != null else null
			if noble != null:
				text = "贵族（%s）来拜访%s（+%d 分）" % [
					UiEventText.noble_requirement_text(noble), who, noble.points,
				]
			else:
				text = "%s 请来一位贵族（+3 分）" % who
		_:
			text = "%s 执行了一个动作" % who
	_text_cache[step] = text
	return text


## 第 step 步（1 起）的动效事件（和 GameEvent.to_dict() 同形态，供 UiTableAnim 使用）。
## IR-03 前没有真实事件，这里按动作类型 + 前后视图的差值合成：拿 / 预留 / 购买 / 弃 / 选贵族，
## 以及“这一步触发了终局”。买牌的 paid 和预留拿的金币都来自前后筹码差。
func events_at(step: int) -> Array[Dictionary]:
	if step <= 0 or step > step_count():
		return []
	if _event_cache.has(step):
		return _event_cache[step] as Array[Dictionary]
	var action: Action = _actions[step - 1]
	var actor: int = actor_at(step)
	var before: Dictionary = _load_view(step - 1, [])
	var after: Dictionary = _load_view(step, [])
	var events: Array[Dictionary] = []
	match action.type:
		Enums.ActionType.TAKE_THREE:
			var gems: Dictionary = {}
			for color: Enums.GemColor in action.colors:
				var key: String = Enums.color_to_string(color)
				gems[key] = int(gems.get(key, 0)) + 1
			events.append({"type": "gems_taken", "seat": actor, "gems": gems})
		Enums.ActionType.TAKE_TWO:
			events.append({
				"type": "gems_taken", "seat": actor,
				"gems": {Enums.color_to_string(action.colors[0]): 2},
			})
		Enums.ActionType.RESERVE:
			var blind: bool = action.card_id.is_empty()
			var event: Dictionary = {
				"type": "card_reserved", "seat": actor, "blind": blind,
				"gold": _color_gain(before, after, actor, Enums.GemColor.GOLD),
			}
			if blind:
				event["level"] = action.level
			else:
				event["card_id"] = action.card_id
				var card: CardData = _catalog.card(action.card_id) if _catalog != null else null
				event["level"] = card.level if card != null else 1
			events.append(event)
		Enums.ActionType.PURCHASE:
			var card: CardData = _catalog.card(action.card_id) if _catalog != null else null
			events.append({
				"type": "card_purchased", "seat": actor, "card_id": action.card_id,
				"paid": _paid_dict(before, after, actor),
				"from_reserved": _was_reserved(before, actor, action.card_id),
				"level": card.level if card != null else 1,
			})
		Enums.ActionType.DISCARD:
			events.append({
				"type": "gems_discarded", "seat": actor,
				"color": Enums.color_to_string(action.color),
			})
		Enums.ActionType.CHOOSE_NOBLE:
			events.append({
				"type": "noble_visited", "seat": actor, "noble_id": action.noble_id,
			})
	if not bool(before.get("endgame_triggered", false)) \
			and bool(after.get("endgame_triggered", false)):
		events.append({
			"type": "endgame_triggered", "seat": actor,
			"points": UiViewMath.score(after, actor, _catalog),
		})
	_event_cache[step] = events
	return events


## 回放日志：从第 step 步往前，最多 LOG_WINDOW 条，带“#37”步号；最新一条在前。
func log_entries(step: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var first: int = maxi(step - LOG_WINDOW + 1, 1)
	for number: int in range(step, first - 1, -1):
		result.append({
			"seat": actor_at(number),
			"text": step_text(number),
			"time": "#%d" % number,
		})
	return result


# ---------------------------------------------------------------- 内部

func _build_names(ui_meta: Dictionary) -> void:
	_names.clear()
	_types.clear()
	var meta_names: Array = []
	var raw_names: Variant = ui_meta.get("names", [])
	if raw_names is Array:
		meta_names = raw_names
	var meta_types: Array = []
	var raw_types: Variant = ui_meta.get("seat_types", [])
	if raw_types is Array:
		meta_types = raw_types
	for seat: int in _player_count:
		var name: String = String(meta_names[seat]) \
				if seat < meta_names.size() and not String(meta_names[seat]).is_empty() \
				else (DEFAULT_NAMES[seat] if seat < DEFAULT_NAMES.size() else "座位 %d" % (seat + 1))
		_names.append(name)
		_types.append(String(meta_types[seat]) if seat < meta_types.size() else "human")


## 载入截断到 step 步的存档；结果按步缓存。失败时返回空字典并写 errors。
func _load_view(step: int, errors: Array[String]) -> Dictionary:
	step = clampi(step, 0, step_count())
	if _view_cache.has(step):
		return _view_cache[step] as Dictionary
	if _controller == null:
		return {}
	var data: Dictionary = _data.duplicate(true)
	var raw_actions: Variant = data.get("actions", [])
	var action_dicts: Array = (raw_actions as Array).duplicate(true) if raw_actions is Array else []
	action_dicts.resize(step)
	data["actions"] = action_dicts
	data["fingerprint"] = ""
	var local_errors: Array[String] = []
	_controller.load_replay(data, false, local_errors)
	if not local_errors.is_empty():
		for message: String in local_errors:
			errors.append(message)
		return {}
	var result: Dictionary = _controller.current_view()
	_view_cache[step] = result
	return result


## “全部公开”视图：所有人的盲抽预留 id 都置空；牌堆本来就只有张数。
func _hide_all_blind(view: Dictionary) -> Dictionary:
	view["viewer_seat"] = -1
	var players: Array = view.get("players", [])
	for player_item: Variant in players:
		if not player_item is Dictionary:
			continue
		var player: Dictionary = player_item
		var reserved: Array = player.get("reserved", [])
		for entry_item: Variant in reserved:
			if entry_item is Dictionary and bool((entry_item as Dictionary).get("blind", false)):
				(entry_item as Dictionary)["id"] = null
	return view


func _taken_text(colors: Array[Enums.GemColor]) -> String:
	if colors.size() == 1:
		return "1 枚 {gem:%s}" % Enums.color_to_string(colors[0])
	var tokens: Array[String] = []
	for color: Enums.GemColor in colors:
		tokens.append("{gem:%s}" % Enums.color_to_string(color))
	return "%s 各 1 枚" % "".join(tokens)


func _card_token(card_id: String) -> String:
	if card_id.is_empty():
		return "一张卡"
	if _catalog != null and _catalog.card(card_id) != null:
		return "{card:%s}" % card_id
	return "一张卡"


func _paid_text(before: Dictionary, after: Dictionary, actor: int) -> String:
	var parts: Array[String] = []
	var paid: Dictionary = _paid_dict(before, after, actor)
	for color_name: String in Enums.COLOR_NAMES:
		var amount: int = int(paid.get(color_name, 0))
		if amount > 0:
			parts.append("{gem:%s}×%d" % [color_name, amount])
	return " ".join(parts)


## 这一步实际付掉的筹码（钱包减少量），key 是颜色字符串。
func _paid_dict(before: Dictionary, after: Dictionary, actor: int) -> Dictionary:
	var result: Dictionary = {}
	for color: Enums.GemColor in Enums.ALL_COLORS:
		var amount: int = UiViewMath.token_count(before, actor, color) \
				- UiViewMath.token_count(after, actor, color)
		if amount > 0:
			result[Enums.color_to_string(color)] = amount
	return result


## before → after 某座位某颜色的筹码增加量（预留拿金用）。
func _color_gain(before: Dictionary, after: Dictionary, actor: int,
		color: Enums.GemColor) -> int:
	return UiViewMath.token_count(after, actor, color) \
			- UiViewMath.token_count(before, actor, color)


## 购买前这张牌是否在购买者的预留区（盲抽预留的 id 在行动者自己的视图里是可见的）。
func _was_reserved(before: Dictionary, actor: int, card_id: String) -> bool:
	var player: Dictionary = UiViewMath.player(before, actor)
	for item: Variant in player.get("reserved", []):
		if item is Dictionary and UiViewMath.reserved_card_id(item) == card_id:
			return true
	return false
