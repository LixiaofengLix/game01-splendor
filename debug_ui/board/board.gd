## 最小可视化桌面（调试用）：只靠 GameController 的信号和过滤视图驱动，不访问 GameState。
## 所有可点按钮都由 Rules.get_legal_actions(view) 启用 / 禁用；弃宝石、选贵族用弹出选择框。
## 正式 UI 可以整体替换本目录，对接约定见 docs/UI_INTEGRATION.md。
class_name BoardScreen
extends Control

signal back_to_setup

const SAVE_PATH: String = "user://saves/board_quick.json"
const SCENARIO_DIR: String = "res://tests/scenarios"
## 目录扫描在导出包里可能拿不到 res:// 的文件列表，这里兜底。
const KNOWN_SCENARIOS: Array[String] = [
	"token_limit", "two_nobles", "endgame", "bank_edges", "colors_short", "deck_empty",
]
const CARD_MIN_SIZE: Vector2 = Vector2(150, 136)
const DIM_COLOR: Color = Color(0, 0, 0, 0.6)

var _game: GameController
var _view: Dictionary = {}
var _legal: Array[Action] = []
var _scenario_names: Array[String] = []
## 当前座位是人类时才接受点击；电脑 / 大模型回合所有动作按钮禁用。
var _accepts_input: bool = false
## 大模型等待计时：收到 waiting_started 后每 0.2 秒刷新顶栏的“已等 N 秒”。
var _llm_waiting_since_ms: int = -1
var _llm_waiting_limit_sec: float = 0.0
var _status_timer: Timer = null

var _status_label: Label
var _bank_box: HBoxContainer
var _nobles_box: HFlowContainer
var _levels_box: VBoxContainer
var _actions_label: Label
var _actions_box: HFlowContainer
var _players_box: VBoxContainer
var _log: RichTextLabel
var _overlay: Control
var _overlay_title: Label
var _overlay_buttons: VBoxContainer
var _scenario_menu: PopupMenu

func _ready() -> void:
	_build_ui()
	_game = GameController.new()
	_game.name = "GameController"
	add_child(_game)
	_game.state_changed.connect(_on_state_changed)
	_game.events_emitted.connect(_on_events_emitted)
	_game.game_finished.connect(_on_game_finished)
	_game.action_rejected.connect(_on_action_rejected)
	_game.waiting_started.connect(_on_llm_waiting_started)
	_game.reason_emitted.connect(_on_llm_reason)
	_game.fallback_used.connect(_on_llm_fallback)
	_status_timer = Timer.new()
	_status_timer.wait_time = 0.2
	_status_timer.timeout.connect(_on_status_tick)
	add_child(_status_timer)
	_fill_scenarios()

# ---------------------------------------------------------------- 对外接口

## 由主界面调用。成功后界面会通过 state_changed 自动刷新。
## seat_options 与座位一一对应，大模型座位用它指定配置档。
func start_new_game(player_count: int, seed: int, seat_types: Array[String],
		seat_options: Array[Dictionary] = []) -> bool:
	_log.clear()
	_overlay.visible = false
	_log_line("新对局：%d 人局，种子 %d" % [player_count, seed])
	var ok: bool = _game.start_new_game(player_count, seed, seat_types, seat_options)
	if not ok:
		_log_line("✗ 开局失败（数据问题见 output 面板）")
		return false
	_log_line("对局开始，轮到座位 %d。" % int(_view.get("current_seat", 0)))
	return true

## 载入 tests/scenarios/ 下的预设局面（调试与冒烟测试用）。
func load_scenario(name: String) -> bool:
	return _load_path("%s/%s.json" % [SCENARIO_DIR, name], false)

## 当前座位自己的视图（界面渲染的唯一数据来源）。
func current_view() -> Dictionary:
	return _view

## 调试 / 冒烟测试用：当前是否弹出了弃宝石或选贵族的选择框。
func has_choice_overlay() -> bool:
	return _overlay.visible

## 返回设置界面时调用，释放对局与控制器。
func reset() -> void:
	_game.reset()
	_view = {}
	_legal.clear()
	_accepts_input = false
	_llm_waiting_since_ms = -1
	_llm_waiting_limit_sec = 0.0
	if _status_timer != null:
		_status_timer.stop()
	_log.clear()
	_clear(_overlay_buttons)
	_overlay.visible = false

# ---------------------------------------------------------------- 界面搭建

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 8)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)

	var top := HBoxContainer.new()
	root.add_child(top)
	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_status_label)
	top.add_child(_toolbar_button("存档", _on_save_pressed))
	top.add_child(_toolbar_button("读档", _on_load_pressed))
	top.add_child(_toolbar_button("重放", _on_replay_pressed))
	var scenario_button := MenuButton.new()
	scenario_button.text = "预设局面"
	_scenario_menu = scenario_button.get_popup()
	_scenario_menu.id_pressed.connect(_on_scenario_selected)
	top.add_child(scenario_button)
	top.add_child(_toolbar_button("返回设置", _on_back_pressed))

	var main_row := HBoxContainer.new()
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_row.add_theme_constant_override("separation", 8)
	root.add_child(main_row)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 4)
	main_row.add_child(left)

	left.add_child(_section_label("贵族"))
	_nobles_box = HFlowContainer.new()
	left.add_child(_nobles_box)
	left.add_child(_section_label("银行"))
	_bank_box = HBoxContainer.new()
	_bank_box.add_theme_constant_override("separation", 6)
	left.add_child(_bank_box)
	_levels_box = VBoxContainer.new()
	_levels_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_levels_box.add_theme_constant_override("separation", 6)
	left.add_child(_levels_box)
	_actions_label = _section_label("拿宝石")
	left.add_child(_actions_label)
	_actions_box = HFlowContainer.new()
	_actions_box.add_theme_constant_override("h_separation", 6)
	_actions_box.add_theme_constant_override("v_separation", 4)
	left.add_child(_actions_box)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(350, 0)
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 4)
	main_row.add_child(right)
	right.add_child(_section_label("玩家"))
	var players_scroll := ScrollContainer.new()
	players_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	players_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(players_scroll)
	_players_box = VBoxContainer.new()
	_players_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_players_box.add_theme_constant_override("separation", 4)
	players_scroll.add_child(_players_box)
	right.add_child(_section_label("事件日志"))
	_log = RichTextLabel.new()
	_log.custom_minimum_size = Vector2(0, 170)
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.scroll_following = true
	_log.selection_enabled = true
	right.add_child(_log)

	_build_overlay()

func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	add_child(_overlay)
	var dim := ColorRect.new()
	dim.color = DIM_COLOR
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	panel.add_theme_stylebox_override("panel",
			_panel_style(Color(0.14, 0.15, 0.19), Color(0.85, 0.7, 0.3), 2))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 16)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	_overlay_title = Label.new()
	_overlay_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_title.add_theme_font_size_override("font_size", 18)
	column.add_child(_overlay_title)
	_overlay_buttons = VBoxContainer.new()
	_overlay_buttons.add_theme_constant_override("separation", 6)
	column.add_child(_overlay_buttons)

# ---------------------------------------------------------------- 信号处理

func _on_state_changed(view: Dictionary) -> void:
	_view = view
	_legal = Rules.get_legal_actions(view, DataRegistry.card_catalog(), DataRegistry.rules())
	_accepts_input = _game.is_current_human()
	_llm_waiting_since_ms = -1
	_llm_waiting_limit_sec = 0.0
	if _status_timer != null:
		_status_timer.stop()
	_refresh()

func _on_events_emitted(events: Array[GameEvent]) -> void:
	for event: GameEvent in events:
		_log_line(event.describe())

func _on_game_finished(winners: Array[int], _scores: Dictionary) -> void:
	_llm_waiting_since_ms = -1
	if _status_timer != null:
		_status_timer.stop()
	var seats: Array[String] = []
	for seat: int in winners:
		seats.append("座位 %d" % seat)
	_log_line("★ 对局结束：%s 获胜" % ("、".join(seats) if not seats.is_empty() else "无"))

func _on_action_rejected(message: String) -> void:
	_log_line("✗ %s" % message)

func _on_llm_waiting_started(seat: int, profile: String, attempt: int, limit_sec: float) -> void:
	_llm_waiting_since_ms = Time.get_ticks_msec()
	_llm_waiting_limit_sec = limit_sec
	if _status_timer != null:
		_status_timer.start()
	_log_line("… 座位 %d 的大模型（%s）第 %d 次请求" % [seat, profile, attempt])
	_refresh_status()

func _on_llm_reason(seat: int, text: String) -> void:
	_log_line("◇ 座位 %d 的大模型理由：%s" % [seat, text])

func _on_llm_fallback(seat: int, reason: String, bot_type: String) -> void:
	var reason_text: String = reason
	match reason:
		LlmController.FALLBACK_PARSE:
			reason_text = "回复无法解析"
		LlmController.FALLBACK_TIMEOUT:
			reason_text = "超时"
		LlmController.FALLBACK_NETWORK:
			reason_text = "网络 / 接口错误"
	var bot_text: String = bot_type
	match bot_type:
		"bot_easy":
			bot_text = "简单电脑"
		"bot_normal":
			bot_text = "普通电脑"
		"bot_hard":
			bot_text = "困难电脑"
	_log_line("⚠ 座位 %d 的大模型%s，这一步由%s代打。" % [seat, reason_text, bot_text])

func _on_status_tick() -> void:
	if _llm_waiting_since_ms < 0:
		if _status_timer != null:
			_status_timer.stop()
		return
	_refresh_status()

# ---------------------------------------------------------------- 刷新

func _refresh() -> void:
	if _view.is_empty():
		return
	_refresh_status()
	_refresh_bank()
	_refresh_nobles()
	_refresh_levels()
	_refresh_actions()
	_refresh_players()
	_refresh_overlay()

func _refresh_status() -> void:
	var phase: String = String(_view.get("phase", ""))
	var text: String = "%d 人局 · %s" % [int(_view.get("player_count", 0)), _phase_zh(phase)]
	if phase != "finished":
		var round_number: int = 1
		var counts: Array = _view.get("turn_counts", [])
		if not counts.is_empty():
			round_number = int(counts[0]) + 1
			for count: Variant in counts:
				round_number = mini(round_number, int(count) + 1)
		text = "%d 人局 · 第 %d 回合 · %s · 轮到座位 %d" % [
			int(_view.get("player_count", 0)), round_number, _phase_zh(phase),
			int(_view.get("current_seat", 0))]
	if bool(_view.get("endgame_triggered", false)) and phase != "finished":
		text += " · 终局已触发（本轮打完结算）"
	if phase != "finished" and not _accepts_input:
		if _game.is_current_llm():
			var elapsed: float = 0.0
			if _llm_waiting_since_ms >= 0:
				elapsed = float(Time.get_ticks_msec() - _llm_waiting_since_ms) / 1000.0
			if _llm_waiting_limit_sec > 0.0:
				text += " · 大模型思考中… 已等 %.1f / %.0f 秒" % [elapsed, _llm_waiting_limit_sec]
			else:
				text += " · 大模型思考中… 已等 %.1f 秒" % elapsed
		else:
			text += " · 电脑思考中…"
	_status_label.text = text

func _refresh_bank() -> void:
	_clear(_bank_box)
	var bank: Dictionary = _view.get("bank", {})
	for color: Enums.GemColor in Enums.ALL_COLORS:
		var amount: int = int(bank.get(Enums.color_to_string(color), 0))
		_bank_box.add_child(_gem_chip(color, amount))

func _refresh_nobles() -> void:
	_clear(_nobles_box)
	var noble_ids: Array = _view.get("nobles", [])
	if noble_ids.is_empty():
		_nobles_box.add_child(_muted_label("（没有贵族了）"))
	for noble_id: Variant in noble_ids:
		var noble: NobleData = DataRegistry.card_catalog().noble(String(noble_id))
		if noble != null:
			_nobles_box.add_child(_noble_panel(noble))

func _refresh_levels() -> void:
	_clear(_levels_box)
	for level: int in [3, 2, 1]:
		_levels_box.add_child(_level_row(level))

func _refresh_actions() -> void:
	_clear(_actions_box)
	match String(_view.get("phase", "")):
		"discard":
			if _accepts_input:
				_actions_label.text = "弃宝石（也可以在上方选择框里操作）"
			elif _game.is_current_llm():
				_actions_label.text = "大模型正在弃宝石…"
			else:
				_actions_label.text = "电脑正在弃宝石…"
		"choose_noble":
			if _accepts_input:
				_actions_label.text = "选贵族（也可以在上方选择框里操作）"
			elif _game.is_current_llm():
				_actions_label.text = "大模型正在选贵族…"
			else:
				_actions_label.text = "电脑正在选贵族…"
		"finished":
			_actions_label.text = "对局已结束"
		_:
			_actions_label.text = "拿宝石"
	var shown: int = 0
	for action: Action in _legal:
		if action.type != Enums.ActionType.TAKE_THREE \
				and action.type != Enums.ActionType.TAKE_TWO:
			continue
		_actions_box.add_child(_action_button(_take_text(action), action))
		shown += 1
	if shown == 0:
		_actions_box.add_child(_muted_label("（当前没有拿宝石的动作）"
				if String(_view.get("phase", "")) == "playing" else "（见弹出的选择框）"))

func _refresh_players() -> void:
	_clear(_players_box)
	var players: Array = _view.get("players", [])
	var current_seat: int = int(_view.get("current_seat", -1))
	var finished: bool = String(_view.get("phase", "")) == "finished"
	for index: int in players.size():
		# 画面显示的是当前玩家的视图；轮到电脑时，它的盲抽预留牌对同屏人类应保持隐藏。
		var mask_blind: bool = index == current_seat and not _accepts_input
		_players_box.add_child(_player_panel(players[index],
				index == current_seat and not finished, mask_blind))

func _refresh_overlay() -> void:
	_clear(_overlay_buttons)
	_overlay.visible = false
	match String(_view.get("phase", "")):
		"discard":
			if _accepts_input:
				_show_choice_overlay(_discard_title(), _filter_actions(Enums.ActionType.DISCARD))
		"choose_noble":
			if _accepts_input:
				_show_choice_overlay("同时满足多位贵族，请选择一位（一回合最多一位）",
						_filter_actions(Enums.ActionType.CHOOSE_NOBLE))
		"finished":
			_show_result_overlay()

# ---------------------------------------------------------------- 面板构建

func _level_row(level: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var deck_panel := PanelContainer.new()
	deck_panel.custom_minimum_size = Vector2(112, CARD_MIN_SIZE.y)
	deck_panel.add_theme_stylebox_override("panel", _panel_style())
	var deck_column := VBoxContainer.new()
	deck_panel.add_child(deck_column)
	deck_column.add_child(_label("%d 级牌堆" % level))
	var decks: Dictionary = _view.get("decks", {})
	var deck_entry: Dictionary = decks.get(str(level), {})
	deck_column.add_child(_label("剩 %d 张" % int(deck_entry.get("count", 0))))
	var blind_action := Action.reserve_blind(level)
	var blind_button := _action_button("盲抽预留", blind_action)
	_enable_action_button(blind_button, blind_action)
	deck_column.add_child(blind_button)
	row.add_child(deck_panel)
	var board: Array = (_view.get("boards", {}) as Dictionary).get(str(level), [])
	for slot: Variant in board:
		row.add_child(_card_panel(slot))
	return row

func _card_panel(slot: Variant) -> Control:
	if slot == null or String(slot).is_empty():
		return _empty_slot("空位")
	var card: CardData = DataRegistry.card_catalog().card(String(slot))
	if card == null:
		return _empty_slot("未知牌")
	var panel := PanelContainer.new()
	panel.custom_minimum_size = CARD_MIN_SIZE
	panel.add_theme_stylebox_override("panel", _card_style(card.bonus))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)
	column.add_child(_label("%s · %d 分" % [card.id, card.points], 14))
	column.add_child(_label("加成 %s" % Enums.color_to_zh(card.bonus)))
	column.add_child(_label("花费 %s" % _cost_text(card)))
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	var buy_action := Action.purchase(card.id)
	var buy_button := _action_button("购买", buy_action)
	_enable_action_button(buy_button, buy_action)
	buttons.add_child(buy_button)
	var reserve_action := Action.reserve_card(card.id)
	var reserve_button := _action_button("预留", reserve_action)
	_enable_action_button(reserve_button, reserve_action)
	buttons.add_child(reserve_button)
	return panel

func _noble_panel(noble: NobleData) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(145, 0)
	panel.add_theme_stylebox_override("panel", _panel_style())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)
	column.add_child(_label("%s · %d 分" % [noble.id, noble.points], 14))
	column.add_child(_label("要求 %s" % _requirement_text(noble)))
	var choose_action := Action.choose_noble(noble.id)
	if _has_action(choose_action):
		column.add_child(_action_button("选择", choose_action))
	return panel

func _player_panel(player: Dictionary, is_current: bool, mask_blind: bool) -> Control:
	var seat: int = int(player.get("seat", 0))
	var tokens: Dictionary = player.get("tokens", {})
	var purchased: Array = player.get("purchased", [])
	var nobles: Array = player.get("nobles", [])
	var discounts: Dictionary[int, int] = {}
	var card_points: int = 0
	var catalog: CardCatalog = DataRegistry.card_catalog()
	for card_id: Variant in purchased:
		var card: CardData = catalog.card(String(card_id))
		if card == null:
			continue
		card_points += card.points
		discounts[card.bonus] = discounts.get(card.bonus, 0) + 1
	var noble_points: int = 0
	for noble_id: Variant in nobles:
		var noble: NobleData = catalog.noble(String(noble_id))
		if noble != null:
			noble_points += noble.points

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",
			_panel_style(Color(0.13, 0.14, 0.18),
					Color(0.95, 0.76, 0.25) if is_current else Color(0.3, 0.31, 0.36),
					2 if is_current else 1))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)
	column.add_child(_label("座位 %d%s" % [seat, " ★ 当前" if is_current else ""], 15))
	column.add_child(_label("分数 %d（卡牌 %d + 贵族 %d） · 已购 %d 张"
			% [card_points + noble_points, card_points, noble_points, purchased.size()]))
	column.add_child(_label("宝石：%s" % _tokens_text(tokens)))
	column.add_child(_label("折扣：%s" % _discount_text(discounts)))
	var noble_names: Array[String] = []
	for noble_id: Variant in nobles:
		noble_names.append(String(noble_id))
	column.add_child(_label("贵族：%s" % (" ".join(noble_names) if not noble_names.is_empty() else "无")))
	var reserved: Array = player.get("reserved", [])
	if reserved.is_empty():
		column.add_child(_label("预留：无"))
	else:
		column.add_child(_label("预留："))
		for entry: Variant in reserved:
			column.add_child(_reserved_row(entry, is_current, mask_blind))
	return panel

func _reserved_row(entry: Variant, is_current: bool, mask_blind: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var data: Dictionary = entry
	var card_id: Variant = data.get("id")
	var level: int = int(data.get("level", 0))
	var text: String = "?%d 级（盲抽）" % level
	if card_id != null and not mask_blind:
		var card: CardData = DataRegistry.card_catalog().card(String(card_id))
		if card == null:
			text = String(card_id)
		else:
			text = "%s · %s · %d 分" % [card.id, Enums.color_to_zh(card.bonus), card.points]
	var label := _label(text)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	if is_current and card_id != null and _accepts_input and not mask_blind:
		var action := Action.purchase(String(card_id))
		var button := _action_button("购买", action)
		_enable_action_button(button, action)
		row.add_child(button)
	return row

# ---------------------------------------------------------------- 选择框

func _show_choice_overlay(title: String, actions: Array[Action]) -> void:
	if actions.is_empty():
		return
	_overlay.visible = true
	_overlay_title.text = title
	for action: Action in actions:
		var button := _action_button(_choice_text(action), action, 16)
		_overlay_buttons.add_child(button)

func _show_result_overlay() -> void:
	_overlay.visible = true
	var winners: Array = _view.get("winners", [])
	var seats: Array[String] = []
	for seat: Variant in winners:
		seats.append("座位 %d" % int(seat))
	var scores: Dictionary = _scores_from_view()
	_overlay_title.text = "对局结束：%s 获胜\n比分：%s" % [
		"、".join(seats) if not seats.is_empty() else "无胜者", _scores_text(scores)]
	_overlay_buttons.add_child(_plain_button("返回设置", _on_back_pressed))
	_overlay_buttons.add_child(_plain_button("查看桌面", _hide_overlay))

func _discard_title() -> String:
	var seats: Array = _view.get("players", [])
	var current: int = int(_view.get("current_seat", 0))
	if current < 0 or current >= seats.size():
		return "持币超过上限，请弃掉宝石"
	var tokens: Dictionary = (seats[current] as Dictionary).get("tokens", {})
	var total: int = 0
	for amount: Variant in tokens.values():
		total += int(amount)
	var need: int = total - DataRegistry.rules().max_tokens
	return "持币超过上限：请弃掉 %d 枚宝石" % maxi(need, 1)

func _choice_text(action: Action) -> String:
	if action.type == Enums.ActionType.CHOOSE_NOBLE:
		var noble: NobleData = DataRegistry.card_catalog().noble(action.noble_id)
		if noble != null:
			return "选择 %s（%d 分，要求 %s）" % [noble.id, noble.points, _requirement_text(noble)]
	return action.describe()

# ---------------------------------------------------------------- 工具

func _submit(action: Action) -> void:
	_game.submit_action(action)  # 被拒绝时由 action_rejected 写日志

func _on_save_pressed() -> void:
	_log_line("—— 存档 ——")
	if not _game.can_save_replay():
		_log_line("✗ 当前对局来自快照，没有种子 + 动作序列；请从新对局存档")
		return
	var error: String = _write_json(SAVE_PATH, _game.build_replay_data())
	if error.is_empty():
		_log_line("已存档：%s（%d 步动作）" % [SAVE_PATH, _game.action_count()])
	else:
		_log_line("✗ 存档失败：%s" % error)

func _on_load_pressed() -> void:
	_load_path(SAVE_PATH, false)

func _on_replay_pressed() -> void:
	_load_path(SAVE_PATH, true)

func _on_scenario_selected(id: int) -> void:
	if id < 0 or id >= _scenario_names.size():
		return
	load_scenario(_scenario_names[id])

func _on_back_pressed() -> void:
	reset()
	back_to_setup.emit()

func _hide_overlay() -> void:
	_overlay.visible = false

## replay_only = true 时只接受重放文件（逐条打印动作与事件）。
func _load_path(path: String, replay_only: bool) -> bool:
	_log_line("—— 读取 %s ——" % path)
	var data: Dictionary = _read_json(path)
	if data.is_empty():
		return false
	match SaveFile.kind_of(data):
		SaveFile.KIND_SNAPSHOT:
			if replay_only:
				_log_line("✗ 重放只接受重放存档（种子 + 动作序列）")
				return false
			var state_data: Dictionary = SaveFile.unwrap_snapshot(data)
			if state_data.is_empty():
				_log_line("✗ 快照文件格式不对")
				return false
			var errors: Array[String] = []
			if not _game.load_snapshot(state_data, errors):
				for message: String in errors:
					_log_line("✗ %s" % message)
				return false
			_log_line("已载入快照（%d 人局）" % int(_view.get("player_count", 0)))
			return true
		SaveFile.KIND_REPLAY:
			var errors: Array[String] = []
			var lines: Array[String] = _game.load_replay(data, replay_only, errors)
			for line: String in lines:
				_log_line(line)
			if not errors.is_empty():
				for message: String in errors:
					_log_line("✗ %s" % message)
				return false
			_log_line("已载入重放存档（%d 步动作）" % _game.action_count())
			return true
	_log_line("✗ 无法识别的文件（kind / schema_version 不对）")
	return false

func _fill_scenarios() -> void:
	_scenario_names.clear()
	var directory: DirAccess = DirAccess.open(SCENARIO_DIR)
	if directory != null:
		for file_name: String in directory.get_files():
			if not file_name.ends_with(".json"):
				continue
			var scenario_name: String = file_name.get_basename()
			if not _scenario_names.has(scenario_name):
				_scenario_names.append(scenario_name)
	for known: String in KNOWN_SCENARIOS:
		if not _scenario_names.has(known):
			_scenario_names.append(known)
	_scenario_names.sort()
	for index: int in _scenario_names.size():
		_scenario_menu.add_item(_scenario_names[index], index)

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_log_line("✗ 找不到文件：%s" % path)
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		_log_line("✗ %s：第 %d 行 JSON 语法错误：%s"
				% [path, json.get_error_line(), json.get_error_message()])
		return {}
	if not json.data is Dictionary:
		_log_line("✗ %s：顶层必须是对象" % path)
		return {}
	return json.data

func _write_json(path: String, data: Dictionary) -> String:
	var directory: String = path.get_base_dir()
	if path.begins_with("user://") and not DirAccess.dir_exists_absolute(directory):
		var error: Error = DirAccess.make_dir_recursive_absolute(directory)
		if error != OK:
			return "建不了目录 %s：%s" % [directory, error_string(error)]
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "写不了 %s：%s" % [path, error_string(FileAccess.get_open_error())]
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	return ""

func _log_line(text: String) -> void:
	_log.append_text(text + "\n")

# ---------------------------------------------------------------- 渲染小工具

## 立即从树里移除再排队释放：重建面板时旧按钮不会和新按钮同时存在。
func _clear(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _has_action(action: Action) -> bool:
	for legal: Action in _legal:
		if legal.equals(action):
			return true
	return false

func _enable_action_button(button: Button, action: Action) -> void:
	button.disabled = not _accepts_input or not _has_action(action)

func _filter_actions(type: Enums.ActionType) -> Array[Action]:
	var result: Array[Action] = []
	for action: Action in _legal:
		if action.type == type:
			result.append(action)
	return result

func _action_button(text: String, action: Action, font_size: int = 13) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", font_size)
	button.set_meta("action", action)
	button.disabled = not _accepts_input
	button.pressed.connect(_submit.bind(action))
	return button

func _plain_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	return button

func _toolbar_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	return button

func _label(text: String, font_size: int = 13) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _muted_label(text: String) -> Label:
	var label := _label(text)
	label.modulate = Color(1, 1, 1, 0.55)
	return label

func _section_label(text: String) -> Label:
	var label := _label(text, 16)
	label.add_theme_color_override("font_color", Color(0.85, 0.78, 0.55))
	return label

func _empty_slot(text: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = CARD_MIN_SIZE
	panel.add_theme_stylebox_override("panel",
			_panel_style(Color(0.1, 0.1, 0.12), Color(0.22, 0.22, 0.26), 1))
	panel.add_child(_muted_label(text))
	return panel

func _gem_chip(color: Enums.GemColor, amount: int) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(64, 34)
	panel.add_theme_stylebox_override("panel", _gem_style(color))
	var label := _label("%s %d" % [Enums.color_to_zh(color), amount], 15)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", _gem_text_color(color))
	panel.add_child(label)
	return panel

func _panel_style(background: Color = Color(0.15, 0.16, 0.2),
		border: Color = Color(0.3, 0.31, 0.36), width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	return style

func _card_style(bonus: Enums.GemColor) -> StyleBoxFlat:
	return _panel_style(Color(0.16, 0.17, 0.21), _color_value(bonus), 3)

func _gem_style(color: Enums.GemColor) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _color_value(color)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(4)
	return style

func _color_value(color: Enums.GemColor) -> Color:
	match color:
		Enums.GemColor.WHITE:
			return Color(0.92, 0.92, 0.88)
		Enums.GemColor.BLUE:
			return Color(0.22, 0.5, 0.85)
		Enums.GemColor.GREEN:
			return Color(0.25, 0.65, 0.35)
		Enums.GemColor.RED:
			return Color(0.82, 0.25, 0.25)
		Enums.GemColor.BLACK:
			return Color(0.17, 0.17, 0.2)
		Enums.GemColor.GOLD:
			return Color(0.95, 0.76, 0.25)
	return Color.WHITE

func _gem_text_color(color: Enums.GemColor) -> Color:
	if color == Enums.GemColor.WHITE or color == Enums.GemColor.GOLD:
		return Color(0.1, 0.1, 0.1)
	return Color.WHITE

func _tokens_text(tokens: Dictionary) -> String:
	var parts: Array[String] = []
	for color: Enums.GemColor in Enums.ALL_COLORS:
		var amount: int = int(tokens.get(Enums.color_to_string(color), 0))
		if amount > 0:
			parts.append("%s%d" % [Enums.color_to_zh(color), amount])
	return " ".join(parts) if not parts.is_empty() else "无"

func _discount_text(discounts: Dictionary[int, int]) -> String:
	var parts: Array[String] = []
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		var amount: int = discounts.get(color, 0)
		if amount > 0:
			parts.append("%s%d" % [Enums.color_to_zh(color), amount])
	return " ".join(parts) if not parts.is_empty() else "无"

func _cost_text(card: CardData) -> String:
	var parts: Array[String] = []
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		if card.cost_of(color) > 0:
			parts.append("%s%d" % [Enums.color_to_zh(color), card.cost_of(color)])
	return " ".join(parts)

func _requirement_text(noble: NobleData) -> String:
	var parts: Array[String] = []
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		if noble.requirement_of(color) > 0:
			parts.append("%s%d" % [Enums.color_to_zh(color), noble.requirement_of(color)])
	return " ".join(parts)

func _take_text(action: Action) -> String:
	var names: Array[String] = []
	for color: Enums.GemColor in action.colors:
		names.append(Enums.color_to_zh(color))
	if action.type == Enums.ActionType.TAKE_TWO:
		return "拿 %s ×2" % names[0]
	if names.size() < 3:
		return "拿 %s（不足 3 种）" % " ".join(names)
	return "拿 %s" % " ".join(names)

func _phase_zh(phase: String) -> String:
	match phase:
		"playing":
			return "进行中"
		"discard":
			return "弃宝石"
		"choose_noble":
			return "选贵族"
		"finished":
			return "已结束"
	return phase

func _scores_from_view() -> Dictionary:
	var scores: Dictionary = {}
	for player: Variant in _view.get("players", []):
		var data: Dictionary = player
		var points: int = 0
		for card_id: Variant in data.get("purchased", []):
			var card: CardData = DataRegistry.card_catalog().card(String(card_id))
			if card != null:
				points += card.points
		for noble_id: Variant in data.get("nobles", []):
			var noble: NobleData = DataRegistry.card_catalog().noble(String(noble_id))
			if noble != null:
				points += noble.points
		scores[str(int(data.get("seat", 0)))] = points
	return scores

func _scores_text(scores: Dictionary) -> String:
	var parts: Array[String] = []
	for seat: Variant in scores:
		parts.append("座位 %s %d 分" % [seat, int(scores[seat])])
	return "，".join(parts)
