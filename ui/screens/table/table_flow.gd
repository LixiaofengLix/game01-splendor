## 牌桌交互：把 UiTableSession 的视图 / 事件与 UiTableScreen 的点击接起来。
## 所有“能不能点”都从 session.legal_actions() 推出；本地只保存已选宝石和选中卡。
## 弃宝石 / 选贵族 / 结算弹窗由视图的 phase 决定（INTERACTION.md 第 4 节）。
class_name UiTableFlow
extends Node

signal leave_requested
signal load_requested
signal rematch_requested(setup: Dictionary)
## 结算弹窗的【看回放】（U6）。
signal replay_requested
## 暂停菜单的【设置】（U7）：应用入口把设置屏压在牌桌之上。
signal settings_requested

const FLASH_SECONDS := 1.5
const FAILURE_SECONDS := 3.0
const RESUME_NOTICE_SECONDS := 8.0
## 大模型兜底说明在顶条停留的时间。
const LLM_FALLBACK_SECONDS := 8.0
## 等待计时刷新间隔（只改胶囊和等待块，不整桌重画）。
const LLM_TICK_SECONDS := 0.1

var _screen: UiTableScreen = null
var _session: UiTableSession = null
var _store: UiSaveStore = null
var _anim: UiTableAnim = null
var _view: Dictionary = {}
var _me_seat: int = -1
var _legal: Array[Action] = []
## 同一视图的事件先到、视图后到：暂存到视图到达后作为一批交给动效队列。
var _pending_events: Array[Dictionary] = []
## 结束信号可能先于最后一帧落地：它到了以后不要再被中间视图清掉。
var _ended: bool = false

var _selection: Dictionary[int, int] = {}
var _selected_kind: String = ""
var _selected_id: String = ""
var _selected_level: int = 0

var _last_event: Dictionary = {}
var _flash_cards: Array[String] = []
## 市场卡位变化：{level, slot}；购买 / 预留后补上新牌的位置也要亮一下。
var _flash_slots: Array[Vector2i] = []
var _failure_text: String = ""

var _modal_kind: String = ""
var _discard_selection: Dictionary[int, int] = {}
## 按点击顺序记下要弃的颜色，提交时逐个发牌。
var _discard_order: Array[int] = []
var _discard_submitting: bool = false
var _noble_selected: String = ""
var _result: Dictionary = {}
var _result_dismissed: bool = false

var _last_current: int = -1
var _last_phase: String = ""

var _flash_timer: Timer
var _failure_timer: Timer

## 暂停菜单 / 规则速查。
var _pause: UiPauseMenu = null
var _rules_overlay: Control = null

## 同屏换人遮挡（INTERACTION.md 第 5 节）。
var _hotseat_cover_enabled: bool = false
var _approved_seat: int = -1
var _cover: UiHotseatCover = null
var _cover_pending_view: Dictionary = {}
var _cover_pending_me: int = -1
var _cover_pending_events: Array[Dictionary] = []
var _cover_events: Array[Dictionary] = []

## 回合结束时写自动存档；对局结束时转存 finished。
var _autosave_pending: bool = false
var _result_saved: bool = false

## 大模型等待 / 兜底（U7）。等的是 current_seat 的那位；视图一换人就清掉。
var _llm_waiting: Dictionary = {}
var _llm_attempts: Dictionary[int, int] = {}
var _llm_fallback: Dictionary = {}
var _llm_fallback_at_ms: int = 0
var _llm_tick_accum: float = 0.0


func setup(screen: UiTableScreen, session: UiTableSession,
		save_store: UiSaveStore = null, options: Dictionary = {}) -> void:
	_screen = screen
	_session = session
	_store = save_store
	_hotseat_cover_enabled = bool(options.get("hotseat_cover", false))
	_flash_timer = Timer.new()
	_flash_timer.one_shot = true
	_flash_timer.wait_time = FLASH_SECONDS
	_flash_timer.timeout.connect(_on_flash_timeout)
	add_child(_flash_timer)
	_failure_timer = Timer.new()
	_failure_timer.one_shot = true
	_failure_timer.wait_time = FAILURE_SECONDS
	_failure_timer.timeout.connect(_on_failure_timeout)
	add_child(_failure_timer)
	_anim = UiTableAnim.new()
	_anim.name = "TableAnim"
	add_child(_anim)
	_anim.setup(screen, _apply_view_animated)
	_anim.queue_drained.connect(_on_animation_drained)

	_session.view_updated.connect(_on_view_updated)
	_session.events_arrived.connect(_on_events)
	_session.game_ended.connect(_on_game_ended)
	_session.action_failed.connect(_on_action_failed)
	_session.seat_status_changed.connect(_on_seat_status)

	_screen.gem_chip_clicked.connect(click_color)
	_screen.confirm_pressed.connect(confirm)
	_screen.cancel_pressed.connect(cancel)
	_screen.card_clicked.connect(click_card)
	_screen.blank_clicked.connect(click_blank)
	_screen.purchase_pressed.connect(purchase_selected)
	_screen.reserve_pressed.connect(reserve_selected)
	_screen.menu_requested.connect(open_pause)
	_screen.rules_requested.connect(open_rules)

	if not session.view().is_empty():
		_on_view_updated(session.view(), session.me_seat())


# ---------------------------------------------------------------- 视图 / 事件

func _on_view_updated(view: Dictionary, me_seat: int) -> void:
	var events: Array[Dictionary] = _pending_events.duplicate()
	_pending_events.clear()
	var phase: String = String(view.get("phase", ""))
	var need_cover: bool = _hotseat_cover_enabled \
			and _session.local_seats().size() >= 2 \
			and phase != "finished" \
			and _session.is_my_turn() \
			and me_seat >= 0 \
			and me_seat != _approved_seat
	if need_cover:
		# 遮挡前把积压的动效直接落完；盖屏期间不播任何东西。
		_anim.finish_now()
		_cover_pending_view = view
		_cover_pending_me = me_seat
		_cover_pending_events = events
		_write_autosave(view)
		_show_hotseat_cover(me_seat)
		return
	_anim.enqueue(events, view, me_seat)


## 动效队列的落地回调：from_view 是这一批动效的起点（用于光晕和补牌比对）。
func _apply_view_animated(view: Dictionary, me_seat: int,
		from_view: Dictionary, events: Array) -> void:
	_apply_view(view, me_seat, from_view, events)


func _on_animation_drained() -> void:
	# 最后一帧落地时 is_playing() 已经是 false；这里补一次渲染，保证输入锁状态正确。
	_render()


func _apply_view(view: Dictionary, me_seat: int, from_view: Dictionary = {},
		events: Array = []) -> void:
	var previous: Dictionary = from_view if not from_view.is_empty() else _view
	_update_flash(previous, view, events)
	_view = view
	_me_seat = me_seat
	_legal = _session.legal_actions()
	var current: int = int(view.get("current_seat", -1))
	var phase: String = String(view.get("phase", ""))
	if current != _last_current or phase != _last_phase:
		_clear_selection()
		_last_current = current
		_last_phase = phase
	if phase != "finished" and not _ended:
		_result = {}
		_result_dismissed = false
	if not _session.is_my_turn():
		_clear_selection()
	elif me_seat >= 0:
		_approved_seat = me_seat
	if not _llm_waiting.is_empty() and current != int(_llm_waiting.get("seat", -1)):
		_clear_llm_waiting()
	_validate_selection()
	_sync_modal()
	_render()
	_write_autosave(view)


## 光晕目标：事件里的卡 id（已离开场面也没关系）+ 卡位差异（补上来的新卡也要亮）。
func _update_flash(previous: Dictionary, view: Dictionary, events: Array) -> void:
	var cards: Array[String] = []
	for item: Variant in events:
		if not item is Dictionary:
			continue
		var event: Dictionary = item
		var type: String = String(event.get("type", ""))
		if type == "card_reserved" and bool(event.get("blind", false)):
			continue
		if type != "card_reserved" and type != "card_purchased":
			continue
		var card_id: String = String(event.get("card_id", ""))
		if not card_id.is_empty() and not cards.has(card_id):
			cards.append(card_id)
	var slots: Array[Vector2i] = _changed_slots(previous, view)
	if cards.is_empty() and slots.is_empty():
		return
	_flash_cards = cards
	_flash_slots = slots
	_flash_timer.start(FLASH_SECONDS)


## 市场卡位差异：购买 / 预留后新补上的牌（或空位）在动效里闪 1.5 秒。
func _changed_slots(previous: Dictionary, view: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if previous.is_empty():
		return result
	var old_boards: Dictionary = previous.get("boards", {})
	var new_boards: Dictionary = view.get("boards", {})
	for level: int in [1, 2, 3]:
		var old_slots: Array = old_boards.get(str(level), [])
		var new_slots: Array = new_boards.get(str(level), [])
		var count: int = mini(old_slots.size(), new_slots.size())
		for index: int in count:
			var old_id: String = String(old_slots[index]) if old_slots[index] != null else ""
			var new_id: String = String(new_slots[index]) if new_slots[index] != null else ""
			if old_id != new_id:
				result.append(Vector2i(level, index))
	return result


func _on_events(events: Array[Dictionary]) -> void:
	for event: Dictionary in events:
		_pending_events.append(event)
		var type: String = String(event.get("type", ""))
		if type == "turn_ended":
			_autosave_pending = true
		# 这位大模型的请求已经有结果（动作 / 弃宝石 / 回合结束），计时停下。
		if not _llm_waiting.is_empty() and type != "turn_started" \
				and int(event.get("seat", -1)) == int(_llm_waiting.get("seat", -1)):
			_clear_llm_waiting()
		if _hotseat_cover_enabled and _session.local_seats().size() >= 2:
			_cover_events.append(event)
		var text: String = UiEventText.text_for(event, _session.catalog(), _session.names())
		if not text.is_empty():
			_last_event = {
				"seat": int(event.get("seat", -1)),
				"text": text,
			}


func _on_flash_timeout() -> void:
	_flash_cards.clear()
	_flash_slots.clear()
	_render()


func _on_failure_timeout() -> void:
	_failure_text = ""
	_render()


func _on_action_failed(message: String) -> void:
	_discard_submitting = false
	_clear_selection()
	if _modal_kind == "discard":
		_discard_selection.clear()
		_discard_order.clear()
	_failure_text = "这一步没成功：%s，请重新选择" % message
	_failure_timer.start(FAILURE_SECONDS)
	_render()
	if String(_view.get("phase", "")) == "discard" and _session.is_my_turn() \
			and not is_animating():
		_build_discard_modal()


func _on_game_ended(result: Dictionary) -> void:
	_ended = true
	_result = result
	_result_dismissed = false
	_clear_llm_waiting()
	_llm_fallback.clear()
	_save_finished_record()
	_sync_modal()
	_render()


# ---------------------------------------------------------------- 大模型状态（17）

func _on_seat_status(seat: int, status: Dictionary) -> void:
	match String(status.get("kind", "")):
		"llm_waiting":
			var attempts: int = int(status.get("attempt", 1))
			_llm_attempts[seat] = attempts
			_llm_waiting = {
				"seat": seat,
				"profile": String(status.get("profile", "大模型")),
				"attempt": attempts,
				"limit_sec": float(status.get("limit_sec", 0.0)),
				"started_ms": int(status.get("started_ms", Time.get_ticks_msec())),
			}
			# 新的等待开始：上一位的兜底说明已经过时。
			_llm_fallback.clear()
			_llm_tick_accum = LLM_TICK_SECONDS
			_render()
		"llm_fallback":
			_llm_fallback = {
				"seat": seat,
				"reason": String(status.get("reason", "")),
				"bot": String(status.get("bot", "")),
				"attempts": int(_llm_attempts.get(seat, 0)),
			}
			_llm_fallback_at_ms = Time.get_ticks_msec()
			_clear_llm_waiting()
			_render()


func _process(delta: float) -> void:
	if not _llm_fallback.is_empty():
		var age: float = float(Time.get_ticks_msec() - _llm_fallback_at_ms) / 1000.0
		if age >= LLM_FALLBACK_SECONDS:
			_llm_fallback.clear()
			_render()
	if _llm_waiting.is_empty():
		return
	if _screen == null or not _screen.is_visible_in_tree() or _session == null:
		return
	if int(_view.get("current_seat", -1)) != int(_llm_waiting.get("seat", -1)):
		return
	_llm_tick_accum += delta
	if _llm_tick_accum < LLM_TICK_SECONDS:
		return
	_llm_tick_accum = 0.0
	_screen.update_llm_waiting(int(_llm_waiting["seat"]), llm_elapsed_seconds(),
			float(_llm_waiting.get("limit_sec", 0.0)))


func llm_elapsed_seconds() -> float:
	if _llm_waiting.is_empty():
		return 0.0
	return maxf(float(Time.get_ticks_msec() - int(_llm_waiting.get("started_ms", 0))) / 1000.0,
			0.0)


## 等待信息（测试 / 顶条用）：seat / profile / attempt / elapsed_sec / limit_sec。
func llm_waiting_info() -> Dictionary:
	if _llm_waiting.is_empty():
		return {}
	var info: Dictionary = _llm_waiting.duplicate(true)
	info["elapsed_sec"] = llm_elapsed_seconds()
	return info


func llm_fallback_strip() -> String:
	if _llm_fallback.is_empty():
		return ""
	return UiLlmText.fallback_strip(_name(int(_llm_fallback.get("seat", -1))),
			String(_llm_fallback.get("reason", "")),
			String(_llm_fallback.get("bot", "")), int(_llm_fallback.get("attempts", 0)))


func _clear_llm_waiting() -> void:
	_llm_waiting.clear()
	_llm_tick_accum = 0.0


# ---------------------------------------------------------------- 渲染

## 设置页返回牌桌时调用：显示卡牌 id 这类设置要立即反映到当前画面。
func refresh() -> void:
	_render()


func _render() -> void:
	if _screen == null or _session == null or _view.is_empty():
		return
	if _cover != null:
		return
	var phase: String = String(_view.get("phase", ""))
	# 动效播放期间锁住所有动作入口；最后一帧落地时 is_playing() 已经为 false。
	var interactive: bool = _session.is_my_turn() and not is_animating()
	var playing: bool = interactive and phase == "playing"
	var info: Dictionary = {
		"names": _session.names(),
		"seat_types": _session.seat_types(),
		"log": _session.log_entries(),
		"catalog": _session.catalog(),
		"rules": _session.rules(),
		"interactive": interactive,
		"selection": _selection.duplicate(),
		"clickable_colors": _clickable_colors() if playing else [],
		"selected_kind": _selected_kind if playing else "",
		"selected_id": _selected_id if playing else "",
		"selected_level": _selected_level if playing else 0,
		"popover": _popover_data() if playing else {},
		"take_confirm_enabled": playing and _candidate_take() != null,
		"strip": _strip_data(),
		"pill_text": _pill_text(),
		"flash_cards": _flash_cards,
		"flash_slots": _flash_slots,
		"llm_waiting": llm_waiting_info() if not _llm_waiting.is_empty()
				and int(_view.get("current_seat", -1)) == int(_llm_waiting.get("seat", -1)) else {},
		"show_card_ids": UiSettings.show_card_ids(),
	}
	_screen.render(_view, _me_seat, info)


func _pill_text() -> String:
	var phase: String = String(_view.get("phase", ""))
	var current: int = int(_view.get("current_seat", -1))
	if phase == "discard":
		return "%s · 弃宝石" % _name(current)
	if phase == "choose_noble":
		return "%s · 选贵族" % _name(current)
	return ""


func _strip_data() -> Dictionary:
	var phase: String = String(_view.get("phase", ""))
	var current: int = int(_view.get("current_seat", -1))
	if not _failure_text.is_empty():
		return {"kind": "note", "text": _failure_text}
	if not _llm_fallback.is_empty() and not _session.is_my_turn():
		return {
			"kind": "event",
			"seat": int(_llm_fallback.get("seat", -1)),
			"text": "%s　现在轮到 %s" % [llm_fallback_strip(), _name(current)],
			"right": "电脑代打",
		}
	if not _session.is_my_turn():
		if phase == "discard":
			return {"kind": "note", "text": "%s 正在弃宝石" % _name(current)}
		if phase == "choose_noble":
			return {"kind": "note", "text": "%s 正在选贵族" % _name(current)}
		if phase == "finished":
			return {"kind": "note", "text": "对局结束"}
		if bool(_view.get("endgame_triggered", false)):
			return _endgame_strip()
		if not _last_event.is_empty() and int(_last_event.get("seat", -1)) != _me_seat:
			return {
				"kind": "event",
				"seat": int(_last_event.get("seat", -1)),
				"text": "%s · 现在轮到 %s" % [String(_last_event.get("text", "")), _name(current)],
				"right": "刚刚",
			}
		return {"kind": "note", "text": "等 %s 出手…你可以先看看场面" % _name(current)}

	if phase == "discard":
		return {"kind": "note", "text": "持币超过上限，先弃回银行"}
	if phase == "choose_noble":
		return {"kind": "note", "text": "回合末：贵族来访"}
	if not _selected_kind.is_empty():
		return {
			"kind": "note",
			"text": "已选中 %s —— 在浮层里购买或预留，点空白处取消" % _selected_title(),
		}
	return {
		"kind": "note",
		"text": _selection_hint(),
		"tray_text": _tray_text(),
		"tray_colors": _tray_colors(),
		"confirm_label": "确认拿取",
		"confirm_enabled": _candidate_take() != null,
		"cancel_enabled": not _selection.is_empty(),
	}


## 托盘里逐枚筹码：选 2 枚同色就放两个同色筹码。
func _tray_colors() -> Array[int]:
	var result: Array[int] = []
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		for index: int in int(_selection.get(color, 0)):
			result.append(color)
	return result


func _endgame_strip() -> Dictionary:
	var trigger: int = int(_view.get("trigger_seat", -1))
	var remaining: Array[int] = UiViewMath.endgame_remaining(_view)
	var names: Array[String] = []
	for seat: int in remaining:
		names.append(_name(seat))
	var suffix: String = "终局轮：这一轮打完结算"
	if not names.is_empty():
		suffix = "终局轮：%s各还有一回合，之后结算" % "、".join(names)
	return {
		"kind": "event",
		"seat": trigger,
		"text": "%s 到 %d 分了！%s" % [
			_name(trigger), UiViewMath.score(_view, trigger, _session.catalog()), suffix,
		],
		"right": "终局轮",
	}


# ---------------------------------------------------------------- 拿宝石

func click_color(color: int) -> void:
	if _maybe_skip_animation():
		return
	if not _is_playing_mine():
		return
	if not _clickable_colors().has(color):
		return
	var amount: int = int(_selection.get(color, 0))
	if amount == 2:
		_selection.erase(color)
	elif amount == 1:
		if _selection.size() == 1 and _can_take_two(color):
			_selection[color] = 2
		else:
			_selection.erase(color)
	else:
		if _selection.values().has(2):
			_selection.clear()
		if _selection.size() < 3:
			_selection[color] = 1
	_clear_selected_card()
	_render()


func confirm() -> void:
	if _maybe_skip_animation():
		return
	if _modal_kind == "discard":
		confirm_discard()
		return
	if _modal_kind == "noble":
		confirm_noble()
		return
	if not _is_playing_mine():
		return
	var candidate: Action = _candidate_take()
	if candidate != null:
		_submit(candidate)
		return
	if not _selected_kind.is_empty() and _can_purchase(_selected_id):
		purchase_selected()


func cancel() -> void:
	if _maybe_skip_animation():
		return
	if _modal_kind == "discard" or _modal_kind == "noble" or _modal_kind == "result":
		return
	_clear_selection()
	_render()


func _candidate_take() -> Action:
	if _selection.is_empty():
		return null
	var colors: Array[Enums.GemColor] = []
	var double_color: int = -1
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		var amount: int = int(_selection.get(color, 0))
		if amount > 0:
			colors.append(color)
		if amount >= 2:
			double_color = color
	var action: Action
	if colors.size() == 1 and double_color >= 0:
		action = Action.take_two(colors[0])
	else:
		action = Action.take_three(colors)
	return _find_legal(action)


func _clickable_colors() -> Array[int]:
	var result: Array[int] = []
	for action: Action in _legal:
		if action.type != Enums.ActionType.TAKE_THREE and action.type != Enums.ActionType.TAKE_TWO:
			continue
		for color: Enums.GemColor in action.colors:
			if not result.has(color):
				result.append(color)
	return result


func _can_take_two(color: int) -> bool:
	return _find_legal(Action.take_two(color)) != null


func _selection_hint() -> String:
	if _selection.is_empty():
		return "轮到你：点银行拿宝石，或点一张卡购买 / 预留"
	var selected_total: int = _sum(_selection)
	var after: int = UiViewMath.token_total(_view, _me_seat) + selected_total
	var max_tokens: int = int(_session.rules().max_tokens)
	if after > max_tokens:
		return "拿后 %d 枚，确认后需要弃 %d 枚" % [after, after - max_tokens]
	if _selection.size() == 1:
		var color: int = _selected_color()
		var amount: int = int(_selection.get(color, 0))
		if amount == 2:
			return "同色 2 枚（%s银行剩 %d 枚）" % [
				Enums.color_to_zh(color), _bank_count(color),
			]
	if _available_color_count() < 3:
		return "银行只剩 %d 种颜色，可以少拿" % _available_color_count()
	match _selection.size():
		1:
			return "再选 2 种不同颜色；同一颜色再点一次 = 拿 2 枚"
		2:
			return "再选 1 种不同颜色；同一颜色再点一次 = 拿 2 枚"
	return "三种不同颜色各 1 枚"


func _tray_text() -> String:
	if _selection.is_empty():
		return "还没选宝石"
	var parts: Array[String] = []
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		var amount: int = int(_selection.get(color, 0))
		if amount <= 0:
			continue
		if amount == 2:
			parts.append("2 枚%s" % Enums.color_to_zh(color))
		else:
			parts.append(Enums.color_to_zh(color))
	var after: int = UiViewMath.token_total(_view, _me_seat) + _sum(_selection)
	return "拿 %s · %d / %d" % [" ".join(parts), after, int(_session.rules().max_tokens)]


func _selected_color() -> int:
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		if int(_selection.get(color, 0)) > 0:
			return color
	return -1


func _available_color_count() -> int:
	var count: int = 0
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		if _bank_count(color) > 0:
			count += 1
	return count


func _bank_count(color: int) -> int:
	var bank: Dictionary = _view.get("bank", {})
	return int(bank.get(Enums.color_to_string(color), 0))


# ---------------------------------------------------------------- 选卡 / 浮层

func click_card(kind: String, card_id: String, level: int) -> void:
	if _maybe_skip_animation():
		return
	if not _is_playing_mine():
		return
	if kind == "market" and card_id.is_empty():
		return
	if kind == _selected_kind and card_id == _selected_id and level == _selected_level:
		_clear_selected_card()
		_render()
		return
	# 关掉“购买前确认”后，点一张买得起的卡直接购买（设置 15）。
	if kind != "deck" and not UiSettings.confirm_before_buy() and _can_purchase(card_id):
		_clear_selection()
		_submit(Action.purchase(card_id))
		return
	_selection.clear()
	_selected_kind = kind
	_selected_id = card_id
	_selected_level = level
	_render()


func click_blank() -> void:
	if _maybe_skip_animation():
		return
	if _modal_kind == "discard" or _modal_kind == "noble" or _modal_kind == "result":
		return
	if not _is_playing_mine():
		return
	_clear_selection()
	_render()


func purchase_selected() -> void:
	if _maybe_skip_animation():
		return
	if not _is_playing_mine() or _selected_kind == "deck":
		return
	if not _can_purchase(_selected_id):
		return
	var card_id: String = _selected_id
	_clear_selection()
	_submit(Action.purchase(card_id))


func reserve_selected() -> void:
	if _maybe_skip_animation():
		return
	if not _is_playing_mine():
		return
	if _selected_kind == "market":
		var card_id: String = _selected_id
		if not _can_reserve_card(card_id):
			return
		_clear_selection()
		_submit(Action.reserve_card(card_id))
	elif _selected_kind == "deck":
		var level: int = _selected_level
		if not _can_reserve_blind(level):
			return
		_clear_selection()
		_submit(Action.reserve_blind(level))


func _popover_data() -> Dictionary:
	if _selected_kind.is_empty():
		return {}
	if _selected_kind == "deck":
		return {
			"mode": "deck",
			"title": "%s牌堆 · 盲抽" % UiEventText.level_zh(_selected_level),
			"tag_text": "",
			"note": "看不到是哪张，抽到后只有你自己能看见。",
			"can_buy": false,
			"can_reserve": _can_reserve_blind(_selected_level),
			"reserve_label": _reserve_label(true),
			"reserve_note": _reserve_note(),
			"hint": "Enter 预留 · Esc 取消",
		}
	var catalog: CardCatalog = _session.catalog()
	var card: CardData = catalog.card(_selected_id) if catalog != null else null
	if card == null:
		return {}
	var affordable: bool = UiViewMath.can_afford(_view, _me_seat, _selected_id, catalog)
	var shortfall: int = UiViewMath.shortfall(_view, _me_seat, _selected_id, catalog)
	var preview: Dictionary = UiViewMath.payment_preview(_view, _me_seat, _selected_id, catalog)
	var can_reserve: bool = _selected_kind == "market" and _can_reserve_card(_selected_id)
	var missing: Array[Dictionary] = []
	if not affordable:
		missing = UiViewMath.missing_by_color(_view, _me_seat, _selected_id, catalog)
	return {
		"mode": "reserved" if _selected_kind == "reserved" else "market",
		"title": _card_title(card),
		"tag_text": "可买" if affordable else "还差 %d" % shortfall,
		"tag_variant": "mint" if affordable else "red",
		"payment": preview,
		"affordable": affordable,
		"shortfall": shortfall,
		"missing": missing,
		"gold_can_pay": UiViewMath.gold_can_pay(_view, _me_seat, _selected_id, catalog),
		"bonuses": UiViewMath.bonuses(_view, _me_seat, catalog),
		"tokens": UiViewMath.tokens(_view, _me_seat),
		"change_text": _change_text(card, preview) if affordable else "",
		"can_buy": _can_purchase(_selected_id),
		"buy_label": "购买",
		"can_reserve": can_reserve,
		"reserve_label": _reserve_label(false),
		"reserve_note": _reserve_note() if _selected_kind == "market" else "",
		"note": "",
	}


func _change_text(card: CardData, preview: Dictionary) -> String:
	var before: int = UiViewMath.token_total(_view, _me_seat)
	var used: int = int(preview.get("gold", 0))
	for value: Variant in (preview.get("gems", {}) as Dictionary).values():
		used += int(value)
	var bonuses: Dictionary[int, int] = UiViewMath.bonuses(_view, _me_seat, _session.catalog())
	var bonus_before: int = int(bonuses.get(card.bonus, 0))
	var parts: Array[String] = [
		"宝石 %d → %d" % [before, before - used],
		"%s折扣 %d → %d" % [Enums.color_to_zh(card.bonus), bonus_before, bonus_before + 1],
	]
	if card.points > 0:
		var score_before: int = UiViewMath.score(_view, _me_seat, _session.catalog())
		parts.append("分数 %d → %d" % [score_before, score_before + card.points])
	return "买后：" + "，".join(parts)


func _card_title(card: CardData) -> String:
	var text: String = "%s · %s" % [
		UiEventText.level_zh(card.level), Enums.color_to_zh(card.bonus),
	]
	if card.points > 0:
		text += " · %d 分" % card.points
	return text


func _selected_title() -> String:
	if _selected_kind == "deck":
		return "%s牌堆" % UiEventText.level_zh(_selected_level)
	var card: CardData = null
	if _session.catalog() != null:
		card = _session.catalog().card(_selected_id)
	return _card_title(card) if card != null else "这张卡"


func _reserve_label(blind: bool) -> String:
	var base: String = "盲抽预留" if blind else "预留"
	if not _session.rules().is_enabled("reserve_takes_gold"):
		return base
	var bank: Dictionary = _view.get("bank", {})
	var gold: int = int(bank.get(Enums.color_to_string(Enums.GemColor.GOLD), 0))
	if gold > 0:
		return base + " · +1 金"
	return base + "（金币已空）"


func _reserve_note() -> String:
	var max_reserved: int = int(_session.rules().max_reserved)
	if _reserved_count() >= max_reserved:
		return "预留已满 %d 张" % max_reserved
	return ""


func _reserved_count() -> int:
	var raw: Variant = UiViewMath.player(_view, _me_seat).get("reserved", [])
	return (raw as Array).size() if raw is Array else 0


# ---------------------------------------------------------------- 合法动作

func _find_legal(action: Action) -> Action:
	if action == null:
		return null
	for legal: Action in _legal:
		if legal.equals(action):
			return legal
	return null


func _can_purchase(card_id: String) -> bool:
	if not _is_playing_mine() or card_id.is_empty():
		return false
	return _find_legal(Action.purchase(card_id)) != null


func _can_reserve_card(card_id: String) -> bool:
	if not _is_playing_mine() or card_id.is_empty():
		return false
	return _find_legal(Action.reserve_card(card_id)) != null


func _can_reserve_blind(level: int) -> bool:
	if not _is_playing_mine() or level <= 0:
		return false
	return _find_legal(Action.reserve_blind(level)) != null


func _submit(action: Action) -> void:
	if action == null:
		return
	if _find_legal(action) == null:
		_show_failure("这个操作已经过期，请重新选择")
		_clear_selection()
		_render()
		return
	if not _session.submit(action):
		if _failure_text.is_empty():
			_show_failure("这个点击已经过期，请重新选择")
		_render()


func _show_failure(message: String) -> void:
	_failure_text = "这一步没成功：%s，请重新选择" % message
	_failure_timer.start(FAILURE_SECONDS)


func _is_playing_mine() -> bool:
	return _session != null and _session.is_my_turn() \
			and String(_view.get("phase", "")) == "playing"


# ---------------------------------------------------------------- 弹窗

func _sync_modal() -> void:
	# 动效播放期间画面还停在起点，不能按中间视图开 / 关弃宝石、选贵族弹窗；
	# 否则飞行会被弹窗遮住，或旧回合的弹窗被重新打开。
	if is_animating():
		if _modal_kind == "result":
			return
		if not _modal_kind.is_empty():
			_close_modal()
		return
	var phase: String = String(_view.get("phase", ""))
	if phase == "finished" and not _result.is_empty() and not _result_dismissed:
		_show_result_modal()
		return
	if not _session.is_my_turn():
		_close_modal()
		return
	match phase:
		"discard":
			if _discard_submitting:
				return
			if _modal_kind != "discard":
				_discard_selection.clear()
				_discard_order.clear()
			_build_discard_modal()
		"choose_noble":
			if _modal_kind != "noble":
				_noble_selected = ""
			_build_noble_modal()
		"finished":
			_close_modal()
		_:
			_close_modal()


func _build_discard_modal() -> void:
	if not _session.is_my_turn() or String(_view.get("phase", "")) != "discard":
		return
	var callbacks: Dictionary = {
		"color": func(color: int) -> void: choose_discard_color(color),
		"reset": func() -> void: reset_discard_selection(),
		"confirm": func() -> void: confirm_discard(),
	}
	var modal := UiModalFrame.new()
	modal.name = "DiscardModal"
	_screen.show_modal(modal)
	UiTableModals.populate_discard(modal, _view, _me_seat, _discard_selection,
			_session.rules(), callbacks)
	_modal_kind = "discard"


func _build_noble_modal() -> void:
	if not _session.is_my_turn() or String(_view.get("phase", "")) != "choose_noble":
		return
	var callbacks: Dictionary = {
		"select": func(noble_id: String) -> void: choose_noble(noble_id),
		"confirm": func() -> void: confirm_noble(),
	}
	var modal := UiModalFrame.new()
	modal.name = "NobleModal"
	_screen.show_modal(modal)
	UiTableModals.populate_noble(modal, _view, _me_seat, _noble_selected,
			_session.catalog(), callbacks)
	_modal_kind = "noble"


func _show_result_modal() -> void:
	var callbacks: Dictionary = {
		"close": func() -> void: dismiss_result(),
		"main_menu": func() -> void: leave_requested.emit(),
		"replay": func() -> void: replay_requested.emit(),
		"save_replay": func() -> void: save_result_replay(),
		"rematch": func() -> void: rematch_requested.emit(_session.rematch_setup()),
	}
	var modal := UiModalFrame.new()
	modal.name = "ResultModal"
	_screen.show_modal(modal)
	UiTableModals.populate_result(modal, _result, _view, _session.rules(),
			_session.names(), _session.original_seat_types(), callbacks,
			_session.can_save(), _result_saved)
	_modal_kind = "result"


func _close_modal() -> void:
	if _modal_kind.is_empty():
		return
	_screen.hide_modal()
	_modal_kind = ""


func choose_discard_color(color: int) -> void:
	if _modal_kind != "discard":
		return
	var held: int = UiViewMath.token_count(_view, _me_seat, color)
	var selected: int = int(_discard_selection.get(color, 0))
	var max_tokens: int = int(_session.rules().max_tokens)
	var need: int = maxi(UiViewMath.token_total(_view, _me_seat) - max_tokens, 0)
	if held - selected <= 0 or _sum(_discard_selection) >= need:
		return
	_discard_selection[color] = selected + 1
	_discard_order.append(color)
	_build_discard_modal()


func reset_discard_selection() -> void:
	_discard_selection.clear()
	_discard_order.clear()
	_build_discard_modal()


func confirm_discard() -> void:
	if _modal_kind != "discard" or _discard_submitting:
		return
	var max_tokens: int = int(_session.rules().max_tokens)
	var need: int = maxi(UiViewMath.token_total(_view, _me_seat) - max_tokens, 0)
	if _sum(_discard_selection) != need:
		return
	var actions: Array[Action] = []
	if _discard_order.size() == need:
		for color: int in _discard_order:
			actions.append(Action.discard(color))
	else:
		for color: Enums.GemColor in Enums.ALL_COLORS:
			for index: int in int(_discard_selection.get(color, 0)):
				actions.append(Action.discard(color))
	_discard_submitting = true
	_session.submit_sequence(actions)
	_discard_submitting = false
	_discard_selection.clear()
	_discard_order.clear()
	# 先关掉弹窗让弃宝石的飞行动效可见；如果仍然需要弃（被拒 / 还没弃够），
	# _sync_modal 会按最新落地视图重新打开。
	_close_modal()
	_sync_modal()
	_render()


func choose_noble(noble_id: String) -> void:
	if _modal_kind != "noble":
		return
	_noble_selected = noble_id
	_build_noble_modal()


func confirm_noble() -> void:
	if _modal_kind != "noble" or _noble_selected.is_empty():
		return
	var noble_id: String = _noble_selected
	_noble_selected = ""
	_submit(Action.choose_noble(noble_id))
	# 关掉弹窗让贵族飞向玩家面板；失败时 _sync_modal 会按仍为 choose_noble 的视图重开。
	_close_modal()
	_sync_modal()
	_render()


func dismiss_result() -> void:
	_result_dismissed = true
	_close_modal()


# ---------------------------------------------------------------- 暂停菜单 / 规则

func open_pause() -> void:
	if _screen == null or _session == null or _pause != null:
		return
	_pause = UiPauseMenu.new()
	_pause.name = "PauseMenu"
	_pause.configure(_session.can_save(), _save_note(), _exit_note())
	_screen.push_overlay(_pause)
	_pause.setup_rules(_session.rules())
	_pause.continue_pressed.connect(close_pause)
	_pause.save_pressed.connect(quick_save)
	_pause.load_pressed.connect(func() -> void:
		close_pause()
		load_requested.emit())
	_pause.settings_pressed.connect(func() -> void:
		close_pause()
		settings_requested.emit())
	_pause.exit_pressed.connect(func() -> void:
		close_pause()
		leave_requested.emit())
	_pause.closed.connect(close_pause)
	_session.set_paused(true)


func close_pause() -> void:
	if _pause == null:
		return
	_screen.pop_overlay(_pause)
	_pause = null
	_session.set_paused(false)


func open_rules() -> void:
	if _screen == null or _rules_overlay != null:
		return
	var overlay := UiModalFrame.new()
	overlay.name = "RulesOverlay"
	overlay.preferred_width = 560
	overlay.title = "规则速查"
	var scrim_host := Control.new()
	scrim_host.name = "RulesOverlayHost"
	scrim_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim_host.mouse_filter = Control.MOUSE_FILTER_STOP
	var scrim := ColorRect.new()
	scrim.color = UiPalette.SCRIM
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim_host.add_child(scrim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim_host.add_child(center)
	center.add_child(overlay)

	_screen.push_overlay(scrim_host)
	var rules_panel := UiRulesPanel.new()
	rules_panel.name = "RulesContent"
	overlay.body().add_child(rules_panel)
	rules_panel.setup(_session.rules())
	var close := UiButton.new()
	close.variant = &"ghost"
	close.text = "关闭"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(close_rules)
	overlay.add_action(close)
	_rules_overlay = scrim_host


func close_rules() -> void:
	if _rules_overlay == null:
		return
	_screen.pop_overlay(_rules_overlay)
	_rules_overlay = null


func _save_note() -> String:
	if not _session.can_save():
		return "这局来自预设局面，不能保存回放。"
	return ""


func _exit_note() -> String:
	if _session.can_save():
		return "退出后可从「继续上一局」或「读取存档」回来。"
	return "这局不能存档，退出会丢掉当前进度。"


# ---------------------------------------------------------------- 同屏换人遮挡

func _show_hotseat_cover(next_seat: int) -> void:
	if _screen == null:
		return
	if _cover == null:
		_cover = UiHotseatCover.new()
		_cover.name = "HotseatCover"
		_cover.next_seat = next_seat
		_cover.next_name = _name(next_seat)
		_cover.previous_seat = _approved_seat
		_cover.previous_name = _name(_approved_seat) if _approved_seat >= 0 else ""
		_cover.summary = _cover_summary_text(next_seat)
		_screen.push_overlay(_cover)
		_cover.start_pressed.connect(dismiss_cover)


func dismiss_cover() -> void:
	if _cover == null:
		return
	var pending_view: Dictionary = _cover_pending_view
	var pending_me: int = _cover_pending_me
	var pending_events: Array[Dictionary] = _cover_pending_events.duplicate()
	_screen.pop_overlay(_cover)
	_cover = null
	_cover_events.clear()
	_cover_pending_view = {}
	_cover_pending_me = -1
	_cover_pending_events.clear()
	_approved_seat = pending_me
	if not pending_view.is_empty():
		_apply_view(pending_view, pending_me, {}, pending_events)


## 上一位本机座位之后、别人做的最后一件事；多件时写动作数。
func _cover_summary_text(next_seat: int) -> String:
	var texts: Array[String] = []
	var last_text: String = ""
	for event: Dictionary in _cover_events:
		var type: String = String(event.get("type", ""))
		if type in ["turn_started", "turn_ended", "discard_required", "noble_choice_required"]:
			continue
		var text: String = UiEventText.text_for(event, _session.catalog(), _session.names())
		if text.is_empty():
			continue
		texts.append(text)
		if int(event.get("seat", -1)) != next_seat:
			last_text = text
	if last_text.is_empty():
		return "刚才没有其他动作。"
	if texts.size() <= 1:
		return last_text
	return "刚才发生了 %d 个动作 · 最后：%s" % [texts.size(), last_text]


# ---------------------------------------------------------------- 存档

func quick_save() -> void:
	if _store == null or not _session.can_save():
		_screen.show_toast(_me_seat, "保存失败", "这局不能保存回放。", 3.0)
		return
	var data: Dictionary = _session.build_save_data()
	if data.is_empty() or not _store.save_quick(data,
			_make_meta(UiSaveEntry.STATUS_IN_PROGRESS, _latest_view(), [])):
		_screen.show_toast(_me_seat, "保存失败", "无法写入存档目录。", 3.0)
		return
	_screen.show_toast(_me_seat, "已保存到「快速存档」", "可从主菜单 → 读取存档 继续")


func _write_autosave(view: Dictionary) -> void:
	if not _autosave_pending:
		return
	_autosave_pending = false
	if _store == null or not _session.can_save():
		return
	# 设置 15 的“每回合自动存档”关掉后不写自动存档；快速存档和结束转存不受影响。
	if not UiSettings.autosave():
		return
	if String(view.get("phase", "")) == "finished":
		return
	var data: Dictionary = _session.build_save_data()
	if not data.is_empty():
		_store.save_autosave(data,
				_make_meta(UiSaveEntry.STATUS_IN_PROGRESS, _latest_view(), []))


func _save_finished_record() -> void:
	_result_saved = false
	if _store == null or not _session.can_save() or _view.is_empty():
		return
	var data: Dictionary = _session.build_save_data()
	if data.is_empty():
		return
	var winners: Array = _result.get("winners", [])
	var path: String = _store.transfer_finished(data,
			_make_meta(UiSaveEntry.STATUS_FINISHED, _latest_view(), winners))
	_result_saved = not path.is_empty()


func save_result_replay() -> void:
	if _result_saved or not _session.can_save():
		return
	_save_finished_record()
	if _result_saved:
		_screen.show_toast(_me_seat, "已保存回放", "可从主菜单 → 读取存档 查看")
	else:
		_screen.show_toast(_me_seat, "保存失败", "无法写入存档目录。", 3.0)
	_show_result_modal()


## 存档的摘要取会话最新视图：动效可能还没播完，不能写落后一拍的画面。
func _latest_view() -> Dictionary:
	var view: Dictionary = _session.view() if _session != null else {}
	return view if not view.is_empty() else _view


func _make_meta(status: String, view: Dictionary, winners: Array) -> Dictionary:
	var scores: Array[int] = []
	var count: int = int(view.get("player_count", 0))
	for seat: int in count:
		scores.append(UiViewMath.score(view, seat, _session.catalog()))
	var round_number: int = UiViewMath.round_number(view)
	var current_seat: int = int(view.get("current_seat", -1))
	var summary: Dictionary = UiSaveStore.make_summary(round_number, current_seat, scores, winners)
	return UiSaveStore.make_meta(status, _session.names(), _session.original_seat_types(),
			_session.hotseat_cover(), _session.elapsed_seconds(), summary)


func show_resume_notice(text: String) -> void:
	if text.is_empty() or _screen == null:
		return
	_screen.show_toast(_me_seat, text, "等逻辑层支持后会恢复电脑座位。", RESUME_NOTICE_SECONDS)


# ---------------------------------------------------------------- 输入

func _unhandled_input(event: InputEvent) -> void:
	if _session == null or _view.is_empty():
		return
	# 牌桌被别的屏幕盖住（读档列表、回放）时不再响应快捷键。
	if _screen == null or not _screen.is_visible_in_tree():
		return
	if _anim != null and _anim.is_playing() and _is_action_key(event) \
			and _pause == null and _rules_overlay == null and _cover == null:
		_anim.skip_all()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("spl_cancel"):
		if _pause != null:
			close_pause()
		elif _rules_overlay != null:
			close_rules()
		elif _cover != null:
			return
		elif _modal_kind in ["discard", "noble", "result"]:
			# 回合内弹窗不能取消，但可以叠开暂停菜单。
			open_pause()
		elif not _selection.is_empty() or not _selected_kind.is_empty() or not _failure_text.is_empty():
			cancel()
		else:
			open_pause()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("spl_confirm"):
		if _pause != null or _rules_overlay != null or _cover != null:
			return
		confirm()
		get_viewport().set_input_as_handled()
		return
	if _pause != null or _rules_overlay != null or _cover != null:
		return
	if not _is_playing_mine():
		return
	if event.is_action_pressed("spl_reserve"):
		reserve_selected()
		get_viewport().set_input_as_handled()
		return
	for index: int in 5:
		if event.is_action_pressed("spl_color_%d" % (index + 1)):
			click_color(Enums.PURCHASABLE_COLORS[index])
			get_viewport().set_input_as_handled()
			return


## 动效播放时，任意牌桌操作 / 方向键都先跳过动效；这一下点击不再执行原动作。
func _maybe_skip_animation() -> bool:
	if _anim == null or not _anim.is_playing():
		return false
	_anim.skip_all()
	return true


func _is_action_key(event: InputEvent) -> bool:
	if event.is_action_pressed("spl_cancel") or event.is_action_pressed("spl_confirm") \
			or event.is_action_pressed("spl_reserve"):
		return true
	for index: int in 5:
		if event.is_action_pressed("spl_color_%d" % (index + 1)):
			return true
	return false


# ---------------------------------------------------------------- 本地状态辅助

func _validate_selection() -> void:
	if not _is_playing_mine():
		_clear_selection()
		return
	if not _selection.is_empty() and _candidate_take() == null:
		_selection.clear()
	match _selected_kind:
		"market":
			if not _market_has(_selected_id):
				_clear_selected_card()
		"reserved":
			if not _reserved_has(_selected_id):
				_clear_selected_card()
		"deck":
			var decks: Dictionary = _view.get("decks", {})
			var entry: Dictionary = decks.get(str(_selected_level), {})
			if int(entry.get("count", 0)) <= 0:
				_clear_selected_card()


func _market_has(card_id: String) -> bool:
	var boards: Dictionary = _view.get("boards", {})
	for level: int in [1, 2, 3]:
		for item: Variant in boards.get(str(level), []):
			if item != null and String(item) == card_id:
				return true
	return false


func _reserved_has(card_id: String) -> bool:
	var player: Dictionary = UiViewMath.player(_view, _me_seat)
	for item: Variant in player.get("reserved", []):
		if item is Dictionary and UiViewMath.reserved_card_id(item) == card_id:
			return true
	return false


func _clear_selection() -> void:
	_selection.clear()
	_clear_selected_card()


func _clear_selected_card() -> void:
	_selected_kind = ""
	_selected_id = ""
	_selected_level = 0


func _name(seat: int) -> String:
	var info: Dictionary = _session.seat_info(seat) if _session != null else {}
	return String(info.get("name", "座位 %d" % (seat + 1)))


func _sum(values: Dictionary) -> int:
	var total: int = 0
	for value: Variant in values.values():
		total += int(value)
	return total


# ---------------------------------------------------------------- 测试 / 调试用

func selection() -> Dictionary[int, int]:
	return _selection.duplicate()


func selected_kind() -> String:
	return _selected_kind


func selected_card_id() -> String:
	return _selected_id


func selected_level() -> int:
	return _selected_level


func modal_kind() -> String:
	return _modal_kind


func discard_selection() -> Dictionary[int, int]:
	return _discard_selection.duplicate()


func noble_selected() -> String:
	return _noble_selected


func popover_data() -> Dictionary:
	return _popover_data()


func last_failure() -> String:
	return _failure_text


func result() -> Dictionary:
	return _result


func is_interactive() -> bool:
	return _session != null and _session.is_my_turn()


func is_color_clickable(color: int) -> bool:
	return _is_playing_mine() and _clickable_colors().has(color)


func can_purchase(card_id: String) -> bool:
	return _can_purchase(card_id)


func can_reserve(card_id: String) -> bool:
	return _can_reserve_card(card_id)


func can_reserve_blind(level: int) -> bool:
	return _can_reserve_blind(level)


func clickable_colors() -> Array[int]:
	return _clickable_colors()


func flash_cards() -> Array[String]:
	return _flash_cards.duplicate()


func flash_slots() -> Array[Vector2i]:
	return _flash_slots.duplicate()


## 当前是否还有事件动效在播 / 排队。
func is_animating() -> bool:
	return _anim != null and _anim.is_playing()


func pending_animation_batches() -> int:
	return _anim.pending_count() if _anim != null else 0


func last_animation_duration() -> float:
	return _anim.last_duration() if _anim != null else 0.0


func last_animation_visuals() -> int:
	return _anim.last_visual_count() if _anim != null else 0


## 牌桌当前实际显示的视图（动效没播完时会落后于会话）。
func displayed_view() -> Dictionary:
	return _view.duplicate(true)


func skip_animation() -> void:
	if _anim != null:
		_anim.skip_all()


func pause_menu() -> UiPauseMenu:
	return _pause


func is_paused() -> bool:
	return _pause != null


func rules_visible() -> bool:
	return _rules_overlay != null


func cover_visible() -> bool:
	return _cover != null


func cover_seat() -> int:
	return _cover.next_seat if _cover != null else -1


func cover_summary() -> String:
	return _cover.summary if _cover != null else ""


func set_hotseat_cover_enabled(on: bool) -> void:
	_hotseat_cover_enabled = on


func result_saved() -> bool:
	return _result_saved
