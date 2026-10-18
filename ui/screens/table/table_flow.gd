## 牌桌交互：把 UiTableSession 的视图 / 事件与 UiTableScreen 的点击接起来。
## 所有“能不能点”都从 session.legal_actions() 推出；本地只保存已选宝石和选中卡。
## 弃宝石 / 选贵族 / 结算弹窗由视图的 phase 决定（INTERACTION.md 第 4 节）。
class_name UiTableFlow
extends Node

signal leave_requested

const FLASH_SECONDS := 1.5
const FAILURE_SECONDS := 3.0

var _screen: UiTableScreen = null
var _session: UiTableSession = null
var _view: Dictionary = {}
var _me_seat: int = -1
var _legal: Array[Action] = []

var _selection: Dictionary[int, int] = {}
var _selected_kind: String = ""
var _selected_id: String = ""
var _selected_level: int = 0

var _last_event: Dictionary = {}
var _flash_cards: Array[String] = []
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


func setup(screen: UiTableScreen, session: UiTableSession) -> void:
	_screen = screen
	_session = session
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

	_session.view_updated.connect(_on_view_updated)
	_session.events_arrived.connect(_on_events)
	_session.game_ended.connect(_on_game_ended)
	_session.action_failed.connect(_on_action_failed)

	_screen.gem_chip_clicked.connect(click_color)
	_screen.confirm_pressed.connect(confirm)
	_screen.cancel_pressed.connect(cancel)
	_screen.card_clicked.connect(click_card)
	_screen.blank_clicked.connect(click_blank)
	_screen.purchase_pressed.connect(purchase_selected)
	_screen.reserve_pressed.connect(reserve_selected)
	_screen.menu_requested.connect(func() -> void: leave_requested.emit())

	if not session.view().is_empty():
		_on_view_updated(session.view(), session.me_seat())


# ---------------------------------------------------------------- 视图 / 事件

func _on_view_updated(view: Dictionary, me_seat: int) -> void:
	_view = view
	_me_seat = me_seat
	_legal = _session.legal_actions()
	var current: int = int(view.get("current_seat", -1))
	var phase: String = String(view.get("phase", ""))
	if current != _last_current or phase != _last_phase:
		_clear_selection()
		_last_current = current
		_last_phase = phase
	if phase != "finished":
		_result = {}
		_result_dismissed = false
	if not _session.is_my_turn():
		_clear_selection()
	_validate_selection()
	_sync_modal()
	_render()


func _on_events(events: Array[Dictionary]) -> void:
	var added_flash: bool = false
	for event: Dictionary in events:
		var type: String = String(event.get("type", ""))
		if type == "card_reserved" and not bool(event.get("blind", false)):
			var card_id: String = String(event.get("card_id", ""))
			if not card_id.is_empty() and not _flash_cards.has(card_id):
				_flash_cards.append(card_id)
				added_flash = true
		elif type == "card_purchased":
			var card_id: String = String(event.get("card_id", ""))
			if not card_id.is_empty() and not _flash_cards.has(card_id):
				_flash_cards.append(card_id)
				added_flash = true
		var text: String = UiEventText.text_for(event, _session.catalog(), _session.names())
		if not text.is_empty():
			_last_event = {
				"seat": int(event.get("seat", -1)),
				"text": text,
			}
	if added_flash:
		_flash_timer.start(FLASH_SECONDS)


func _on_flash_timeout() -> void:
	_flash_cards.clear()
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
	if String(_view.get("phase", "")) == "discard" and _session.is_my_turn():
		_build_discard_modal()


func _on_game_ended(result: Dictionary) -> void:
	_result = result
	_result_dismissed = false
	_sync_modal()
	_render()


# ---------------------------------------------------------------- 渲染

func _render() -> void:
	if _screen == null or _session == null or _view.is_empty():
		return
	var phase: String = String(_view.get("phase", ""))
	var interactive: bool = _session.is_my_turn()
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
	if not _is_playing_mine():
		return
	if kind == "market" and card_id.is_empty():
		return
	if kind == _selected_kind and card_id == _selected_id and level == _selected_level:
		_clear_selected_card()
		_render()
		return
	_selection.clear()
	_selected_kind = kind
	_selected_id = card_id
	_selected_level = level
	_render()


func click_blank() -> void:
	if _modal_kind == "discard" or _modal_kind == "noble" or _modal_kind == "result":
		return
	if not _is_playing_mine():
		return
	_clear_selection()
	_render()


func purchase_selected() -> void:
	if not _is_playing_mine() or _selected_kind == "deck":
		return
	if not _can_purchase(_selected_id):
		return
	var card_id: String = _selected_id
	_clear_selection()
	_submit(Action.purchase(card_id))


func reserve_selected() -> void:
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
		"leave": func() -> void: leave_requested.emit(),
	}
	var modal := UiModalFrame.new()
	modal.name = "ResultModal"
	_screen.show_modal(modal)
	UiTableModals.populate_result(modal, _result, _view, _session.rules(),
			_session.names(), _session.seat_types(), callbacks)
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
	if String(_view.get("phase", "")) == "discard" and _session.is_my_turn():
		_build_discard_modal()
	else:
		_close_modal()
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


func dismiss_result() -> void:
	_result_dismissed = true
	_close_modal()


# ---------------------------------------------------------------- 输入

func _unhandled_input(event: InputEvent) -> void:
	if _session == null or _view.is_empty():
		return
	if event.is_action_pressed("spl_confirm"):
		confirm()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("spl_cancel"):
		cancel()
		get_viewport().set_input_as_handled()
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
