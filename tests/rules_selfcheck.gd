## 阶段 2 的规则自检（无界面，改完 core/ 就跑一次）：
## 1) 用随机的合法动作跑 N 局（默认 2000），每一步检查不变量：
##    宝石守恒、不为负、持币 / 预留上限、卡牌守恒、视图里不含隐藏信息、往返序列化一致等；
## 2) 同一种子开局可复现、存档（种子 + 动作序列）重放后状态一致、duplicate_state 互不影响；
## 3) tests/scenarios/ 下的预设局面逐个载入、校验，再用随机动作走几步。
## 用法：godot --headless --path . tests/rules_selfcheck.tscn -- 2000
## 任何一处违反都会打印"局面 + 步数 + 哪条不变量"，并以退出码 1 结束。
extends Node

const DEFAULT_GAMES: int = 2000
const MAX_STEPS_PER_GAME: int = 3000
## 每走几步做一次"重"检查（卡牌守恒 / 往返序列化 / 隐藏信息），轻检查每步都做。
const HEAVY_INTERVAL: int = 5
const SCENARIO_STEPS: int = 20
const RNG_SEED: int = 20261016
const MAX_PRINTED_FAILURES: int = 40

var _config: RulesConfig
var _catalog: CardCatalog
var _rng := RandomNumberGenerator.new()
var _failures: int = 0
var _checks: int = 0
var _total_steps: int = 0
var _longest_game: int = 0

func _ready() -> void:
	_rng.seed = RNG_SEED
	if not DataRegistry.is_valid():
		print("数据校验失败，先跑 tests/data_report.tscn：")
		for message: String in DataRegistry.get_errors():
			print("  x %s" % message)
		get_tree().quit(1)
		return
	_config = DataRegistry.rules()
	_catalog = DataRegistry.card_catalog()
	var games: int = DEFAULT_GAMES
	for argument: String in OS.get_cmdline_user_args():
		if argument.is_valid_int():
			games = int(argument)
	var started: int = Time.get_ticks_msec()
	print("=== 规则自检：%d 局（人数 2/3/4 轮换，随机合法动作） ===" % games)
	_check_setup_determinism()
	_check_payment_rules()
	_check_illegal_actions()
	_check_skip_and_stall()
	for index: int in games:
		_play_random_game(index)
		if (index + 1) % 200 == 0:
			print("  已跑 %d/%d 局（失败 %d 处，最长一局 %d 步）"
					% [index + 1, games, _failures, _longest_game])
	print("随机对局：%d 局，共 %d 步，最长 %d 步，平均 %.1f 步"
			% [games, _total_steps, _longest_game,
			float(_total_steps) / maxf(games, 1)])
	_check_scenarios()
	var elapsed: float = float(Time.get_ticks_msec() - started) / 1000.0
	print("")
	if _failures == 0:
		print("OK —— 共 %d 项检查全部通过，用时 %.1f 秒。" % [_checks, elapsed])
		get_tree().quit(0)
		return
	print("失败：%d 处（共 %d 项检查，用时 %.1f 秒）" % [_failures, _checks, elapsed])
	get_tree().quit(1)

# ---------------------------------------------------------------- 随机对局

func _play_random_game(index: int) -> void:
	var player_count: int = 2 + (index % 3)
	var seed_value: int = 1000000 + index
	var where: String = "%d 人局 种子 %d" % [player_count, seed_value]
	var state: GameState = Rules.setup(_config, _catalog, player_count, seed_value)
	if state == null:
		_fail(where, 0, "开局失败")
		return
	var actions: Array[Action] = []
	var step: int = 0
	while not state.is_finished() and step < MAX_STEPS_PER_GAME:
		var legal: Array[Action] = _legal(state)
		if legal.is_empty():
			_fail(where, step, "当前玩家没有合法动作（应该自动跳过或结束）")
			return
		var action: Action = legal[_rng.randi_range(0, legal.size() - 1)]
		var events: Array[GameEvent] = Rules.apply(state, action)
		if events.is_empty():
			_fail(where, step, "合法动作执行失败：%s" % action.describe())
			return
		actions.append(action)
		step += 1
		_check_light(state, where, step)
		if step % HEAVY_INTERVAL == 0:
			_check_heavy(state, where, step)
		if step % 100 == 0:
			_check_duplicate(state, where, step)
	_check_light(state, where, step)
	_check_heavy(state, where, step)
	if not state.is_finished():
		_fail(where, step, "超过 %d 步还没结束" % MAX_STEPS_PER_GAME)
		return
	_check_winners(state, where, step)
	if index % 100 == 0:
		_check_replay(where, player_count, seed_value, actions, state.fingerprint())
	_total_steps += step
	_longest_game = maxi(_longest_game, step)

func _legal(state: GameState) -> Array[Action]:
	# 合法动作只从"当前玩家自己的视图"算，和 AI / 客户端将来的用法一致
	return Rules.get_legal_actions(state.to_dict(state.current_seat), _catalog, _config)

## 每步都做的轻检查：宝石守恒 / 不为负 / 上限。
func _check_light(state: GameState, where: String, step: int) -> void:
	_checks += 1
	var total_per_color: Dictionary[int, int] = {}
	for color: Enums.GemColor in Enums.ALL_COLORS:
		total_per_color[color] = state.bank_count(color)
		if state.bank_count(color) < 0:
			_fail(where, step, "银行%s为负数：%d" % [Enums.color_to_zh(color), state.bank_count(color)])
	for player: PlayerState in state.players:
		if player.token_count() > _config.max_tokens \
				and not (state.phase == Enums.GamePhase.DISCARD and player.seat == state.current_seat):
			_fail(where, step, "座位 %d 持币 %d 枚，超过上限（阶段 %s）"
					% [player.seat, player.token_count(), Enums.phase_to_string(state.phase)])
		if player.reserved_count() > _config.max_reserved:
			_fail(where, step, "座位 %d 预留 %d 张，超过上限" % [player.seat, player.reserved_count()])
		for color: Enums.GemColor in Enums.ALL_COLORS:
			if player.token_count_of(color) < 0:
				_fail(where, step, "座位 %d 的%s为负数" % [player.seat, Enums.color_to_zh(color)])
			total_per_color[color] += player.token_count_of(color)
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		var expected: int = _config.gems_per_color_for(state.player_count)
		if total_per_color[color] != expected:
			_fail(where, step, "%s宝石总数应为 %d，实际 %d"
					% [Enums.color_to_zh(color), expected, total_per_color[color]])
	if total_per_color[Enums.GemColor.GOLD] != _config.gold_count:
		_fail(where, step, "金币总数应为 %d，实际 %d"
				% [_config.gold_count, total_per_color[Enums.GemColor.GOLD]])

## 每隔几步做的重检查：完整不变量（含卡牌守恒）、往返序列化、隐藏信息。
func _check_heavy(state: GameState, where: String, step: int) -> void:
	_check_light(state, where, step)
	_checks += 1
	var problems: Array[String] = state.validate()
	if not problems.is_empty():
		_fail(where, step, "不变量：" + "；".join(problems))
	_check_roundtrip(state, where, step)
	_check_hidden(state, where, step)

## 完整状态与过滤视图都要能重建出一模一样的信息。
func _check_roundtrip(state: GameState, where: String, step: int) -> void:
	_checks += 1
	var full: Dictionary = state.to_dict(GameState.VIEW_ALL)
	var rebuilt: GameState = GameState.from_dict(full, _config, _catalog, [])
	if rebuilt == null:
		_fail(where, step, "完整状态重建失败")
	elif rebuilt.fingerprint() != state.fingerprint():
		_fail(where, step, "完整状态往返后指纹不一致")
	for seat: int in state.player_count:
		var view: Dictionary = state.to_dict(seat)
		var from_view: GameState = GameState.from_dict(view, _config, _catalog, [])
		if from_view == null:
			_fail(where, step, "座位 %d 的视图重建失败" % seat)
			continue
		if JSON.stringify(from_view.to_dict(seat)) != JSON.stringify(view):
			_fail(where, step, "座位 %d 的视图往返后信息变了" % seat)

## 视图里不能出现隐藏信息：牌堆顺序、别人盲抽预留的牌、种子与随机数状态。
func _check_hidden(state: GameState, where: String, step: int) -> void:
	_checks += 1
	var deck_ids: Dictionary = {}
	for level: int in [1, 2, 3]:
		for card: CardData in state.decks[level]:
			if not card.is_unknown():
				deck_ids[card.id] = true
	for seat: int in state.player_count:
		var hidden: Dictionary = deck_ids.duplicate()
		for other: PlayerState in state.players:
			if other.seat == seat:
				continue
			for entry: ReservedCard in other.reserved:
				if entry.blind and not entry.card.is_unknown():
					hidden[entry.card.id] = true
		var view: Dictionary = state.to_dict(seat)
		if view.has("seed") or view.has("rng_state"):
			_fail(where, step, "座位 %d 的视图里有种子 / 随机数状态" % seat)
		for level: int in [1, 2, 3]:
			if ((view["decks"] as Dictionary)[str(level)] as Dictionary).has("cards"):
				_fail(where, step, "座位 %d 的视图里有牌堆顺序" % seat)
		for text: String in _all_strings(view):
			if hidden.has(text):
				_fail(where, step, "座位 %d 的视图里泄露了看不到的牌 %s" % [seat, text])

func _all_strings(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is String:
		result.append(value)
	elif value is Array:
		for item: Variant in value:
			result.append_array(_all_strings(item))
	elif value is Dictionary:
		for key: Variant in value:
			result.append_array(_all_strings(key))
			result.append_array(_all_strings(value[key]))
	return result

## 深拷贝的副本必须和原状态互不影响。
func _check_duplicate(state: GameState, where: String, step: int) -> void:
	_checks += 1
	var before: String = state.fingerprint()
	var copy: GameState = state.duplicate_state()
	if copy.fingerprint() != before:
		_fail(where, step, "duplicate_state 的副本和原状态不一致")
		return
	copy.bank[Enums.GemColor.WHITE] = copy.bank_count(Enums.GemColor.WHITE) + 1
	copy.players[0].add_tokens(Enums.GemColor.GOLD, 1)
	copy.players[0].purchased.clear()
	if state.fingerprint() != before:
		_fail(where, step, "改副本影响到了原状态（共享了容器）")

## 终局判定：分数最高，平分时已购卡牌少者胜，再相同并列。
func _check_winners(state: GameState, where: String, step: int) -> void:
	_checks += 1
	var best_points: int = -1
	var best_cards: int = 0
	var expected: Array[int] = []
	for player: PlayerState in state.players:
		var points: int = player.total_points()
		var cards: int = player.purchased.size()
		if points > best_points or (points == best_points and cards < best_cards):
			best_points = points
			best_cards = cards
			expected = [player.seat]
		elif points == best_points and cards == best_cards:
			expected.append(player.seat)
	if expected != state.winners:
		_fail(where, step, "胜者应为 %s，实际 %s" % [str(expected), str(state.winners)])
	if state.winners.is_empty():
		_fail(where, step, "对局结束但没有胜者")
	if best_points < _config.win_points and state.finished_reason != "stalled":
		_fail(where, step, "没到胜利分就结束了（最高分 %d），原因 %s" % [best_points, state.finished_reason])

# ---------------------------------------------------------------- 可复现性

func _check_setup_determinism() -> void:
	_checks += 1
	for player_count: int in [2, 3, 4]:
		var seed_value: int = 4242 + player_count
		var first: GameState = Rules.setup(_config, _catalog, player_count, seed_value)
		var second: GameState = Rules.setup(_config, _catalog, player_count, seed_value)
		if first.fingerprint() != second.fingerprint():
			_fail("同种子开局", 0, "%d 人局种子 %d 两次开局不一致" % [player_count, seed_value])
		var other: GameState = Rules.setup(_config, _catalog, player_count, seed_value + 1)
		if other.fingerprint() == first.fingerprint():
			_fail("同种子开局", 0, "%d 人局不同种子开局却一样（洗牌没生效？）" % player_count)
	print("  同一种子开局可复现 ✓")

## 支付规则：先用折扣，再用同色宝石，差额用金币补（不让玩家手动选）。
func _check_payment_rules() -> void:
	_checks += 1
	var where: String = "支付规则"
	var template: GameState = Rules.setup(_config, _catalog, 2, 77)
	var card: CardData = _find_single_color_board_card(template)
	if card == null:
		_fail(where, 0, "种子 77 的场面上没有单色花费的卡")
		return
	var cost_color: Enums.GemColor = Enums.PURCHASABLE_COLORS[0]
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		if card.cost_of(color) > 0:
			cost_color = color
	var cost: int = card.cost_of(cost_color)
	# 三种摆法：(折扣数, 同色宝石数, 金币数) -> 期望支付
	var cases: Array = [
		[cost - 1, 1, 0],   # 折扣后还差 1，用同色宝石
		[cost - 1, 0, 2],   # 折扣后还差 1，同色宝石没有，用金币
		[maxi(cost - 2, 0), 1, 2],  # 折扣后还差 2：1 枚同色 + 1 枚金币
	]
	for setup_case: Array in cases:
		var state: GameState = Rules.setup(_config, _catalog, 2, 77)
		var discounts: int = setup_case[0]
		var tokens: int = setup_case[1]
		var gold: int = setup_case[2]
		for index: int in discounts:
			var bonus_card: CardData = _take_from_deck(state, 1, cost_color)
			if bonus_card == null:
				_fail(where, 0, "牌堆里没有 %s 加成的牌" % Enums.color_to_zh(cost_color))
				return
			state.players[0].purchased.append(bonus_card)
		if tokens > 0:
			_move_tokens(state, 0, cost_color, tokens)
		if gold > 0:
			_move_tokens(state, 0, Enums.GemColor.GOLD, gold)
		var need: int = cost - discounts
		var expect_tokens: int = mini(tokens, need)
		var expect_gold: int = need - expect_tokens
		var bank_before: int = state.bank_count(cost_color)
		var gold_before: int = state.bank_count(Enums.GemColor.GOLD)
		var events: Array[GameEvent] = Rules.apply(state, Action.purchase(card.id))
		if events.is_empty():
			_fail(where, 0, "折扣 %d / 同色 %d / 金币 %d 时买 %s 失败"
					% [discounts, tokens, gold, card.id])
			continue
		if state.bank_count(cost_color) != bank_before + expect_tokens:
			_fail(where, 0, "花费[%s%d]（折扣 %d）应该回到银行 %d 枚同色宝石，实际少了 %d 枚"
					% [Enums.color_to_zh(cost_color), cost, discounts, expect_tokens,
					bank_before + expect_tokens - state.bank_count(cost_color)])
		if state.bank_count(Enums.GemColor.GOLD) != gold_before + expect_gold:
			_fail(where, 0, "花费[%s%d]（折扣 %d）应该付 %d 枚金币，实际少了 %d 枚"
					% [Enums.color_to_zh(cost_color), cost, discounts, expect_gold,
					gold_before + expect_gold - state.bank_count(Enums.GemColor.GOLD)])
	print("  支付顺序（折扣 → 同色 → 金币）✓")

## 非法动作必须被拒绝，而且不能改动状态（联网时主机就靠这一层）。
func _check_illegal_actions() -> void:
	_checks += 1
	var where: String = "非法动作"
	var state: GameState = Rules.setup(_config, _catalog, 2, 4711)
	var before: String = state.fingerprint()
	var illegal: Array[Action] = []
	illegal.append(Action.purchase(_first_board_card(state).id))  # 买不起
	illegal.append(Action.take_three([Enums.GemColor.WHITE, Enums.GemColor.WHITE,
			Enums.GemColor.BLUE]))  # 同色重复
	illegal.append(Action.take_three([Enums.GemColor.WHITE, Enums.GemColor.BLUE,
			Enums.GemColor.GREEN, Enums.GemColor.RED]))  # 四种颜色
	illegal.append(Action.discard(Enums.GemColor.WHITE))  # 不在弃宝石阶段
	illegal.append(Action.choose_noble(state.nobles[0].id))  # 不在选贵族阶段
	illegal.append(Action.reserve_blind(4))  # 没有 4 级
	_move_tokens(state, 1, Enums.GemColor.WHITE, 2)  # 银行剩 2 枚白，不能拿两枚
	illegal.append(Action.take_two(Enums.GemColor.WHITE))
	var after_setup: String = state.fingerprint()
	for action: Action in illegal:
		if Rules.apply(state, action).size() > 0:
			_fail(where, 0, "非法动作居然执行了：%s" % action.describe())
		if state.fingerprint() != after_setup:
			_fail(where, 0, "非法动作改动了状态：%s" % action.describe())
			return
	if after_setup == before:
		_fail(where, 0, "测试用的摆法没有生效")
	print("  非法动作被拒绝且状态不变 ✓")

## 没有合法动作的玩家要自动跳过（跳过也算一个回合）；一整圈都没人能动作时提前结束（保险丝）。
## 这种局面正常对局里几乎不会出现，所以这里手工构造一个：银行搬空、场面清空、预留占满、
## 手里只剩买不起的三级牌——座位 0 还能盲抽预留一步，走完之后另外两家和座位 0 自己都没动作了。
func _check_skip_and_stall() -> void:
	_checks += 1
	var where: String = "跳过与保险丝"
	var state: GameState = Rules.setup(_config, _catalog, 3, 321)
	# 银行搬空（3 人局 30 枚刚好每人 10 枚），每人只拿两种颜色
	var colors: Array[Enums.GemColor] = [Enums.GemColor.WHITE, Enums.GemColor.RED,
			Enums.GemColor.BLUE, Enums.GemColor.BLACK, Enums.GemColor.GREEN, Enums.GemColor.GOLD]
	for index: int in colors.size():
		_move_tokens(state, index / 2, colors[index], state.bank_count(colors[index]))
	# 场面清空（牌放回同级牌堆），谁都买不到、也没场面卡可预留
	for level: int in [1, 2, 3]:
		var slots: Array = state.boards[level]
		var deck: Array = state.decks[level]
		for slot: int in slots.size():
			if slots[slot] != null:
				deck.append(slots[slot])
				slots[slot] = null
	# 预留占满：每人留几张自己买不起的三级牌（逐张用规则算过）
	for seat: int in state.player_count:
		var target: int = 2 if seat == 0 else 3
		var deck: Array = state.decks[3]
		var affordable: Array[CardData] = []
		var picks: Array[CardData] = []
		for card: CardData in deck:
			if _can_afford(state, seat, card):
				affordable.append(card)
			elif picks.size() < target:
				picks.append(card)
			else:
				affordable.append(card)
		if picks.size() < target:
			_fail(where, 0, "3 级牌堆里凑不出 %d 张座位 %d 买不起的牌" % [target, seat])
			return
		var leftover: Array[CardData] = affordable
		state.decks[3] = leftover
		for card: CardData in picks:
			state.players[seat].reserved.append(ReservedCard.new(card, false))
	# 座位 1、2 必须真的动不了；座位 0 只剩盲抽预留
	for seat: int in state.player_count:
		state.current_seat = seat
		if seat == 0:
			continue
		if not _legal(state).is_empty():
			_fail(where, 0, "构造的局面里座位 %d 还有合法动作" % seat)
			return
	state.current_seat = 0
	var legal: Array[Action] = _legal(state)
	if legal.size() != 3:
		_fail(where, 0, "构造的局面里座位 0 应该只剩 3 个盲抽预留动作，实际 %d 个" % legal.size())
		return
	for action: Action in legal:
		if action.type != Enums.ActionType.RESERVE or not action.card_id.is_empty():
			_fail(where, 0, "座位 0 剩下的动作应该都是盲抽预留：%s" % action.describe())
			return
	var events: Array[GameEvent] = Rules.apply(state, legal[0])
	var skipped: int = 0
	for event: GameEvent in events:
		if event.type == Enums.EventType.PLAYER_SKIPPED:
			skipped += 1
	if skipped != 3:
		_fail(where, 0, "座位 1、2 和座位 0 都该被跳过，实际跳过 %d 个" % skipped)
	if state.phase != Enums.GamePhase.FINISHED or state.finished_reason != "stalled":
		_fail(where, 0, "一圈都没人能动作时应该以 stalled 结束，实际 %s / \"%s\""
				% [Enums.phase_to_string(state.phase), state.finished_reason])
		return
	if str(state.turn_counts) != "[2, 1, 1]":
		_fail(where, 0, "被跳过也要记一个回合，实际 %s" % str(state.turn_counts))
	_check_roundtrip(state, where, 0)
	print("  没有合法动作时跳过、一圈都动不了时提前结束 ✓")

# ---------------------------------------------------------------- 自检用的小工具

func _first_board_card(state: GameState) -> CardData:
	for level: int in [1, 2, 3]:
		for slot: Variant in state.boards[level]:
			if slot != null:
				return slot
	return null

## 场面上第一张"只花一种颜色、2~4 枚"的卡（验证支付顺序用，这种卡最容易摆局面）。
func _find_single_color_board_card(state: GameState) -> CardData:
	for level: int in [3, 2, 1]:
		for slot: Variant in state.boards[level]:
			if slot == null:
				continue
			var card: CardData = slot
			var colors: int = 0
			var amount: int = 0
			for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
				if card.cost_of(color) > 0:
					colors += 1
					amount = card.cost_of(color)
			if colors == 1 and amount >= 2 and amount <= 4:
				return card
	return null

func _take_from_deck(state: GameState, level: int, bonus: Enums.GemColor) -> CardData:
	var deck: Array = state.decks[level]
	for index: int in deck.size():
		var card: CardData = deck[index]
		if card.bonus == bonus and card.points == 0:
			deck.remove_at(index)
			return card
	return null

func _move_tokens(state: GameState, seat: int, color: Enums.GemColor, amount: int) -> void:
	state.bank[color] = state.bank_count(color) - amount
	state.players[seat].add_tokens(color, amount)

## 这张牌对这名玩家是不是买得起（规则与 Rules 里的支付顺序一致，摆局面用）。
func _can_afford(state: GameState, seat: int, card: CardData) -> bool:
	var player: PlayerState = state.players[seat]
	var needed: int = 0
	var available: int = player.token_count_of(Enums.GemColor.GOLD)
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		var need: int = card.cost_of(color) - mini(player.discount_count(color), card.cost_of(color))
		if need > 0:
			needed += need
			available += mini(player.token_count_of(color), need)
	return available >= needed

## 用记录下来的动作序列重放，末状态必须和原局一致（就是调试台 save / replay 的机制）。
func _check_replay(where: String, player_count: int, seed_value: int, actions: Array[Action],
		expected_fingerprint: String) -> void:
	_checks += 1
	var replayed: GameState = Rules.setup(_config, _catalog, player_count, seed_value)
	if replayed == null:
		_fail(where, 0, "重放开局失败")
		return
	for index: int in actions.size():
		var events: Array[GameEvent] = Rules.apply(replayed, actions[index])
		if events.is_empty():
			_fail(where, index, "重放到第 %d 步失败：%s" % [index + 1, actions[index].describe()])
			return
	if replayed.fingerprint() != expected_fingerprint:
		_fail(where, actions.size(), "重放后的状态和原局不一致")

# ---------------------------------------------------------------- 预设局面

func _check_scenarios() -> void:
	var directory: DirAccess = DirAccess.open("res://tests/scenarios")
	if directory == null:
		_fail("预设局面", 0, "打不开 res://tests/scenarios")
		return
	var files: PackedStringArray = directory.get_files()
	files.sort()
	var checked: int = 0
	for file_name: String in files:
		if not file_name.ends_with(".json"):
			continue
		checked += 1
		_check_scenario("res://tests/scenarios/%s" % file_name)
	print("  预设局面：检查了 %d 个 ✓" % checked)

func _check_scenario(path: String) -> void:
	_checks += 1
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		_fail(path, 0, "JSON 解析失败")
		return
	var data: Dictionary = json.data
	if SaveFile.kind_of(data) != SaveFile.KIND_SNAPSHOT:
		_fail(path, 0, "不是快照文件（kind / schema_version 不对）")
		return
	var errors: Array[String] = []
	var state: GameState = GameState.from_dict(SaveFile.unwrap_snapshot(data), _config, _catalog, errors)
	if state == null:
		_fail(path, 0, "快照载入失败：" + "；".join(errors))
		return
	var where: String = path.get_file()
	_check_heavy(state, where, 0)
	if _legal(state).is_empty():
		_fail(where, 0, "当前玩家没有合法动作（载入后会卡住）")
		return
	for step: int in SCENARIO_STEPS:
		var legal: Array[Action] = _legal(state)
		if legal.is_empty():
			break  # 走完了 / 结束了
		var action: Action = legal[_rng.randi_range(0, legal.size() - 1)]
		if Rules.apply(state, action).is_empty():
			_fail(where, step, "合法动作执行失败：%s" % action.describe())
			return
		_check_light(state, where, step)

# ---------------------------------------------------------------- 报告

func _fail(where: String, step: int, message: String) -> void:
	_failures += 1
	if _failures <= MAX_PRINTED_FAILURES:
		print("✗ %s 第 %d 步：%s" % [where, step, message])
	elif _failures == MAX_PRINTED_FAILURES + 1:
		print("…… 后面的失败不再逐条打印")
