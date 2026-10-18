## 界面冒烟测试（无界面）：直接实例化设置界面和棋盘，按按钮走关键流程。
## 覆盖：启动新局、合法 / 非法按钮的启用状态、拿宝石、预留、弃宝石弹窗、选贵族弹窗、
##       终局结算弹窗、存档 / 读档 / 重放、设置界面的默认参数、人类 vs 电脑的回合切换。
## 用法：godot --headless --path . tests/board_smoke.tscn
extends Node

const MAX_PRINTED_FAILURES: int = 30

var _failures: int = 0
var _checks: int = 0
var _setup_player_count: int = -1
var _setup_seed: int = -1
var _setup_types: Array[String] = []

func _ready() -> void:
	if not DataRegistry.is_valid():
		print("数据校验失败，先跑 tests/data_report.tscn")
		get_tree().quit(1)
		return
	var started: int = Time.get_ticks_msec()
	print("=== 界面冒烟测试 ===")
	_check_new_game_buttons()
	_check_discard_overlay()
	_check_noble_overlay()
	_check_endgame_overlay()
	_check_save_load_replay()
	_check_setup_screen()
	await _check_human_vs_bot()
	var elapsed: float = float(Time.get_ticks_msec() - started) / 1000.0
	print("")
	if _failures == 0:
		print("OK —— 共 %d 项检查全部通过，用时 %.1f 秒。" % [_checks, elapsed])
		get_tree().quit(0)
		return
	print("失败：%d 处（共 %d 项检查，用时 %.1f 秒）" % [_failures, _checks, elapsed])
	get_tree().quit(1)

# ---------------------------------------------------------------- 新局 / 按钮状态

func _check_new_game_buttons() -> void:
	var board := _make_board()
	_check(board.start_new_game(2, 12345, ["human", "human"]), "新对局能启动")
	var view: Dictionary = board.current_view()
	_check(int(view.get("current_seat", -1)) == 0, "新局轮到座位 0")

	var buttons: Array[Button] = []
	_collect_action_buttons(board, buttons)
	_check(not buttons.is_empty(), "棋盘生成了操作按钮")
	var enabled_take: Button = null
	var disabled_purchase: Button = null
	for button: Button in buttons:
		if not button.is_visible_in_tree():
			continue
		var action: Action = button.get_meta("action")
		if _is_legal(view, action):
			_check(not button.disabled, "合法动作的按钮应可用：%s" % action.describe())
		else:
			_check(button.disabled, "非法动作的按钮应禁用：%s" % action.describe())
		if not button.disabled and (action.type == Enums.ActionType.TAKE_THREE
				or action.type == Enums.ActionType.TAKE_TWO):
			enabled_take = button
		if button.disabled and action.type == Enums.ActionType.PURCHASE:
			disabled_purchase = button
	_check(enabled_take != null, "开局应该能拿宝石")
	_check(disabled_purchase != null, "开局时买不起的卡，购买按钮应禁用")

	# 拿一次宝石 → 回合结束，轮到座位 1。
	var turns_before: int = int((view["turn_counts"] as Array)[0])
	enabled_take.pressed.emit()
	view = board.current_view()
	_checks += 1
	if int((view["turn_counts"] as Array)[0]) != turns_before + 1:
		_fail("拿宝石后座位 0 的回合数没有 +1")
	_check(int(view.get("current_seat", -1)) == 1, "拿宝石后轮到座位 1")

	# 座位 1 预留一张场面卡 → 拿 1 枚金币，回合结束。
	var reserve_button: Button = _find_enabled(board, [Enums.ActionType.RESERVE])
	_check(reserve_button != null, "座位 1 应该能预留")
	if reserve_button != null:
		reserve_button.pressed.emit()
		view = board.current_view()
		var seat1: Dictionary = (view["players"] as Array)[1]
		_check((seat1["reserved"] as Array).size() == 1, "预留后座位 1 应有 1 张预留卡")
		_check(int((seat1["tokens"] as Dictionary).get("gold", 0)) == 1,
				"预留应该附带 1 枚金币")
		_check(int(view.get("current_seat", -1)) == 0, "预留后轮到座位 0")

	# 按住一个禁用的"购买"按钮（模拟界面被强行触发）也不能改变局面。
	var before: String = JSON.stringify(board.current_view())
	if disabled_purchase != null:
		disabled_purchase.pressed.emit()
	_check(JSON.stringify(board.current_view()) == before, "非法点击不会改变局面")
	board.queue_free()

# ---------------------------------------------------------------- 弃宝石弹窗

func _check_discard_overlay() -> void:
	var board := _make_board()
	_check(board.load_scenario("token_limit"), "载入 token_limit")
	var take_button: Button = _find_enabled(board, [Enums.ActionType.TAKE_THREE,
			Enums.ActionType.TAKE_TWO])
	_check(take_button != null, "token_limit：应该有拿宝石动作")
	if take_button == null:
		board.queue_free()
		return
	take_button.pressed.emit()
	var view: Dictionary = board.current_view()
	_check(String(view.get("phase", "")) == "discard", "持币超限后进入弃宝石阶段")
	_check(board.has_choice_overlay(), "弃宝石阶段应弹出选择框")
	var discard_button: Button = _find_enabled(board, [Enums.ActionType.DISCARD])
	_check(discard_button != null, "弃宝石选择框里应有弃宝石按钮")
	if discard_button != null:
		var seat: int = int(view.get("current_seat", 0))
		var before: int = _token_total(view, seat)
		discard_button.pressed.emit()
		view = board.current_view()
		_check(_token_total(view, seat) == before - 1, "弃宝石后该座位宝石数应 -1")
	board.queue_free()

# ---------------------------------------------------------------- 选贵族弹窗

func _check_noble_overlay() -> void:
	var board := _make_board()
	_check(board.load_scenario("two_nobles"), "载入 two_nobles")
	var nobles_before: int = _noble_count(board.current_view(), 0)
	var take_button: Button = _find_enabled(board, [Enums.ActionType.TAKE_THREE,
			Enums.ActionType.TAKE_TWO])
	_check(take_button != null, "two_nobles：应该有拿宝石动作")
	if take_button == null:
		board.queue_free()
		return
	take_button.pressed.emit()
	var view: Dictionary = board.current_view()
	_check(String(view.get("phase", "")) == "choose_noble", "同时满足两位贵族时进入选贵族阶段")
	_check(board.has_choice_overlay(), "选贵族阶段应弹出选择框")
	var noble_button: Button = _find_enabled(board, [Enums.ActionType.CHOOSE_NOBLE])
	_check(noble_button != null, "选贵族选择框里应有贵族按钮")
	if noble_button != null:
		noble_button.pressed.emit()
		view = board.current_view()
		_check(_noble_count(view, 0) == nobles_before + 1, "选择后座位 0 的贵族数应 +1")
		_check(String(view.get("phase", "")) != "choose_noble", "选完贵族后应结束选择阶段")
	board.queue_free()

# ---------------------------------------------------------------- 终局弹窗

func _check_endgame_overlay() -> void:
	var board := _make_board()
	_check(board.load_scenario("endgame"), "载入 endgame")
	var view: Dictionary = board.current_view()
	var points_before: int = _points(view, 0)
	var purchase_button: Button = _find_winning_purchase(board, points_before)
	_check(purchase_button != null, "endgame：应有一张买到就能到 15 分的卡")
	if purchase_button == null:
		board.queue_free()
		return
	purchase_button.pressed.emit()
	view = board.current_view()
	_check(String(view.get("phase", "")) == "playing", "触发终局后本轮还没打完")
	_check(int(view.get("current_seat", -1)) == 1, "触发终局后轮到座位 1")
	var take_button: Button = _find_enabled(board, [Enums.ActionType.TAKE_THREE,
			Enums.ActionType.TAKE_TWO])
	_check(take_button != null, "endgame：座位 1 应该有拿宝石动作")
	if take_button != null:
		take_button.pressed.emit()
		view = board.current_view()
		_check(String(view.get("phase", "")) == "finished", "本轮打完后对局结束")
		_check((view.get("winners", []) as Array).has(0), "终局胜者应为座位 0")
		_check(board.has_choice_overlay(), "对局结束应弹出结算框")
	board.queue_free()

# ---------------------------------------------------------------- 存档 / 读档 / 重放

func _check_save_load_replay() -> void:
	var board := _make_board()
	_check(board.start_new_game(2, 2468, ["human", "human"]), "存读档：新对局能启动")
	for step: int in 3:
		var take_button: Button = _find_enabled(board, [Enums.ActionType.TAKE_THREE,
				Enums.ActionType.TAKE_TWO])
		if take_button == null:
			break
		take_button.pressed.emit()
	var saved: String = JSON.stringify(board.current_view())
	board._on_save_pressed()
	_check(board.load_scenario("token_limit"), "存读档：先载入别的局面")
	board._on_load_pressed()
	_check(JSON.stringify(board.current_view()) == saved, "读档后局面与存档时一致")
	board._on_replay_pressed()
	_check(JSON.stringify(board.current_view()) == saved, "重放后局面与存档时一致")
	board.queue_free()

# ---------------------------------------------------------------- 设置界面

func _check_setup_screen() -> void:
	var setup := preload("res://debug_ui/setup/setup.tscn").instantiate() as SetupScreen
	add_child(setup)
	setup.start_requested.connect(_on_setup_start)
	var start_button: Button = _find_button_by_text(setup, "开始游戏")
	_check(start_button != null, "设置界面有开始按钮")
	var bot_enabled: bool = false
	var llm_disabled: bool = false
	for node: Node in _all_nodes(setup):
		if node is OptionButton and (node as OptionButton).item_count == 6:
			bot_enabled = not (node as OptionButton).is_item_disabled(1)
			llm_disabled = (node as OptionButton).is_item_disabled(4)
			break
	_check(bot_enabled, "电脑座位选项应启用（阶段 4）")
	_check(llm_disabled, "大模型座位选项应继续置灰")
	if start_button != null:
		start_button.pressed.emit()
		_check(_setup_player_count == 2, "默认人数应为 2")
		_check(_setup_types.size() == 2 and _setup_types[0] == "human"
				and _setup_types[1] == "bot_normal", "默认座位 0 人类、座位 1 普通电脑")
		_check(_setup_seed >= 0, "默认种子应为整数")
	setup.queue_free()

func _on_setup_start(player_count: int, seed: int, seat_types: Array[String]) -> void:
	_setup_player_count = player_count
	_setup_seed = seed
	_setup_types = seat_types

# ---------------------------------------------------------------- 人类 vs 电脑

## 人类走一步后，电脑自动思考并行动；电脑回合界面不能替它点击。
func _check_human_vs_bot() -> void:
	var board := _make_board()
	_check(board.start_new_game(2, 13579, ["human", "bot_normal"]), "人机局能启动")
	_check(int(board.current_view().get("current_seat", -1)) == 0, "人机局从人类座位 0 开始")
	_check(board._game.is_current_human(), "座位 0 是人类，界面应接受输入")
	var take_button: Button = _find_enabled(board, [Enums.ActionType.TAKE_THREE,
			Enums.ActionType.TAKE_TWO])
	_check(take_button != null, "人机局人类回合有拿宝石按钮")
	if take_button == null:
		board.queue_free()
		return
	take_button.pressed.emit()
	_check(not board._game.is_current_human(), "人类行动后轮到电脑")
	var any_enabled: bool = _find_enabled(board, [Enums.ActionType.PURCHASE,
			Enums.ActionType.RESERVE, Enums.ActionType.TAKE_THREE,
			Enums.ActionType.TAKE_TWO]) != null
	_check(not any_enabled, "电脑回合所有动作按钮应禁用")
	var waited: int = 0
	while waited < 40 and not board._game.is_current_human():
		await get_tree().create_timer(0.1).timeout
		waited += 1
	_check(board._game.is_current_human(), "电脑行动结束后回到人类回合")
	_check(int((board.current_view()["turn_counts"] as Array)[1]) >= 1, "电脑座位已完成至少一个回合")
	board.queue_free()

# ---------------------------------------------------------------- 工具

func _make_board() -> BoardScreen:
	var board := preload("res://debug_ui/board/board.tscn").instantiate() as BoardScreen
	add_child(board)
	return board

func _collect_action_buttons(node: Node, result: Array[Button]) -> void:
	if node is Button and node.has_meta("action"):
		result.append(node)
	for child: Node in node.get_children():
		_collect_action_buttons(child, result)

func _find_enabled(node: Node, types: Array) -> Button:
	var buttons: Array[Button] = []
	_collect_action_buttons(node, buttons)
	for button: Button in buttons:
		if button.disabled or not button.is_visible_in_tree():
			continue
		var action: Action = button.get_meta("action")
		if types.has(action.type):
			return button
	return null

## 找一张"买下后座位 points_before 的分数能到胜利分"的购买按钮。
func _find_winning_purchase(node: Node, points_before: int) -> Button:
	var buttons: Array[Button] = []
	_collect_action_buttons(node, buttons)
	var catalog: CardCatalog = DataRegistry.card_catalog()
	for button: Button in buttons:
		if button.disabled or not button.is_visible_in_tree():
			continue
		var action: Action = button.get_meta("action")
		if action.type != Enums.ActionType.PURCHASE:
			continue
		var card: CardData = catalog.card(action.card_id)
		if card != null and points_before + card.points >= DataRegistry.rules().win_points:
			return button
	return null

func _find_button_by_text(node: Node, text: String) -> Button:
	for child: Node in _all_nodes(node):
		if child is Button and (child as Button).text == text:
			return child
	return null

func _all_nodes(node: Node) -> Array[Node]:
	var result: Array[Node] = [node]
	for child: Node in node.get_children():
		result.append_array(_all_nodes(child))
	return result

func _is_legal(view: Dictionary, action: Action) -> bool:
	return Rules.is_action_legal(view, DataRegistry.card_catalog(), DataRegistry.rules(), action)

func _token_total(view: Dictionary, seat: int) -> int:
	var players: Array = view.get("players", [])
	if seat < 0 or seat >= players.size():
		return -1
	var total: int = 0
	for amount: Variant in ((players[seat] as Dictionary).get("tokens", {}) as Dictionary).values():
		total += int(amount)
	return total

func _noble_count(view: Dictionary, seat: int) -> int:
	var players: Array = view.get("players", [])
	if seat < 0 or seat >= players.size():
		return -1
	return ((players[seat] as Dictionary).get("nobles", []) as Array).size()

func _points(view: Dictionary, seat: int) -> int:
	var players: Array = view.get("players", [])
	if seat < 0 or seat >= players.size():
		return -1
	var data: Dictionary = players[seat]
	var points: int = 0
	for card_id: Variant in data.get("purchased", []):
		var card: CardData = DataRegistry.card_catalog().card(String(card_id))
		if card != null:
			points += card.points
	for noble_id: Variant in data.get("nobles", []):
		var noble: NobleData = DataRegistry.card_catalog().noble(String(noble_id))
		if noble != null:
			points += noble.points
	return points

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	_failures += 1
	if _failures <= MAX_PRINTED_FAILURES:
		print("✗ %s" % message)
	elif _failures == MAX_PRINTED_FAILURES + 1:
		print("…… 后面的失败不再逐条打印")
