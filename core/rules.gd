## 规则引擎：开局、合法动作、执行动作，全部为静态函数。
## 合法性只看"视图"（GameState.to_dict 的输出）+ 静态数据（CardCatalog / RulesConfig），
## 所以 AI、大模型、客户端、界面都能从自己拿到的视图算出合法动作，和主机算的完全一样。
## 规则参数一律来自 RulesConfig（不写魔法数字），数值来源是 data/rules.json。
class_name Rules
extends RefCounted

# ---------------------------------------------------------------- 开局

## 按种子洗牌、发牌、布置贵族。同一种子开局完全一致（随机只用带种子的 RandomNumberGenerator）。
static func setup(config: RulesConfig, catalog: CardCatalog, player_count: int, seed: int) -> GameState:
	if config == null or catalog == null:
		push_error("Rules.setup：缺少 RulesConfig / CardCatalog")
		return null
	if not config.supported_player_counts().has(player_count):
		push_error("Rules.setup：不支持 %d 人局" % player_count)
		return null
	var state := GameState.new()
	state.config = config
	state.catalog = catalog
	state.player_count = player_count
	state.seed = seed
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for level: int in [1, 2, 3]:
		var deck: Array[CardData] = catalog.cards_in_level(level)
		_shuffle(deck, rng)
		state.decks[level] = deck
		var board: Array = []
		for slot: int in config.board_slots_per_level:
			board.append(_draw(state, level))
		state.boards[level] = board
	var nobles: Array[NobleData] = catalog.all_nobles()
	_shuffle(nobles, rng)
	for index: int in config.nobles_for(player_count):
		state.nobles.append(nobles[index])
	state.rng_state = rng.state
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		state.bank[color] = config.gems_per_color_for(player_count)
	state.bank[Enums.GemColor.GOLD] = config.gold_count
	for seat: int in player_count:
		state.players.append(PlayerState.new(seat))
	state.turn_counts.resize(player_count)
	state.current_seat = 0
	state.phase = Enums.GamePhase.PLAYING
	return state

## 用带种子的随机数洗牌（不用 Array.shuffle，它用的是全局随机源，不可复现）。
static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for index: int in range(items.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var swap: Variant = items[index]
		items[index] = items[other]
		items[other] = swap

# ---------------------------------------------------------------- 合法动作

## 列出当前玩家的合法动作。view 必须是"当前玩家自己的视图"（viewer_seat = current_seat）或完整视图（-1）。
## 返回值顺序固定（拿三枚 → 拿两枚 → 预留 → 购买），同一局面每次得到的编号一致。
static func get_legal_actions(view: Dictionary, catalog: CardCatalog, config: RulesConfig) -> Array[Action]:
	var actions: Array[Action] = []
	if catalog == null or config == null:
		push_error("Rules.get_legal_actions：缺少 CardCatalog / RulesConfig")
		return actions
	var current: int = int(view.get("current_seat", -1))
	var viewer: int = int(view.get("viewer_seat", GameState.VIEW_ALL))
	if viewer != GameState.VIEW_ALL and viewer != current:
		push_error("Rules.get_legal_actions：这个视图属于座位 %d，当前玩家是座位 %d（合法动作要用自己的视图算）"
				% [viewer, current])
		return actions
	match Enums.phase_from_string(String(view.get("phase", ""))):
		Enums.GamePhase.FINISHED:
			return actions
		Enums.GamePhase.DISCARD:
			return _discard_actions(view, current)
		Enums.GamePhase.CHOOSE_NOBLE:
			return _noble_choice_actions(view)
		Enums.GamePhase.PLAYING:
			return _playing_actions(view, current, catalog, config)
	push_error("Rules.get_legal_actions：phase 不合法：\"%s\"" % view.get("phase"))
	return actions

static func is_action_legal(view: Dictionary, catalog: CardCatalog, config: RulesConfig,
		action: Action) -> bool:
	if action == null:
		return false
	for legal: Action in get_legal_actions(view, catalog, config):
		if legal.equals(action):
			return true
	return false

## 弃宝石阶段：每种持有量 > 0 的颜色都可以弃 1 枚（含金币）。
static func _discard_actions(view: Dictionary, seat: int) -> Array[Action]:
	var actions: Array[Action] = []
	var tokens: Dictionary[int, int] = _tokens_from_view(_player_dict(view, seat).get("tokens", {}))
	for color: Enums.GemColor in Enums.ALL_COLORS:
		if tokens.get(color, 0) > 0:
			actions.append(Action.discard(color))
	return actions

static func _noble_choice_actions(view: Dictionary) -> Array[Action]:
	var actions: Array[Action] = []
	for noble_id: Variant in view.get("pending_nobles", []):
		actions.append(Action.choose_noble(String(noble_id)))
	return actions

## 正常回合的动作：拿三枚不同色、拿两枚同色、预留（场面卡 / 盲抽）、购买（场面卡 / 自己预留的卡）。
static func _playing_actions(view: Dictionary, seat: int, catalog: CardCatalog,
		config: RulesConfig) -> Array[Action]:
	var actions: Array[Action] = []
	var player: Dictionary = _player_dict(view, seat)
	var bank: Dictionary = view.get("bank", {})
	var boards: Dictionary = view.get("boards", {})
	var decks: Dictionary = view.get("decks", {})
	var tokens: Dictionary[int, int] = _tokens_from_view(player.get("tokens", {}))
	var bonuses: Dictionary[int, int] = _bonuses_of_ids(player.get("purchased", []), catalog)
	var reserved: Array = player.get("reserved", [])

	var available: Array[Enums.GemColor] = []
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		if _color_count(bank, color) > 0:
			available.append(color)
	if available.size() >= 3:
		for combo: Variant in _combinations(available, 3):
			actions.append(Action.take_three(combo))
	elif config.is_enabled("allow_take_fewer_when_colors_short"):
		# 官方规则：一次拿不足 3 种不同颜色时，可以拿 2 种，甚至 1 种（拿几种由玩家决定）
		for size: int in range(1, available.size() + 1):
			for combo: Variant in _combinations(available, size):
				actions.append(Action.take_three(combo))
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		if _color_count(bank, color) >= config.take_two_min_remaining:
			actions.append(Action.take_two(color))

	if reserved.size() < config.max_reserved:
		for level: int in [1, 2, 3]:
			for card_id: Variant in boards.get(str(level), []):
				if card_id is String and not String(card_id).is_empty():
					actions.append(Action.reserve_card(String(card_id)))
		for level: int in [1, 2, 3]:
			# 牌堆空了就不能盲抽预留
			if _deck_count(decks, level) > 0:
				actions.append(Action.reserve_blind(level))

	for level: int in [1, 2, 3]:
		for card_id: Variant in boards.get(str(level), []):
			if card_id is String and _can_afford_card(bonuses, tokens, catalog, String(card_id)):
				actions.append(Action.purchase(String(card_id)))
	for entry: Variant in reserved:
		if not entry is Dictionary:
			continue
		var card_id: Variant = (entry as Dictionary).get("id")
		if card_id is String and _can_afford_card(bonuses, tokens, catalog, String(card_id)):
			actions.append(Action.purchase(String(card_id)))
	return actions

## 从 items 里取 size 个的组合（顺序按 items 的顺序，结果可复现）。
static func _combinations(items: Array[Enums.GemColor], size: int) -> Array:
	var result: Array = []
	if size <= 0 or size > items.size():
		return result
	var indices: Array[int] = []
	for index: int in size:
		indices.append(index)
	while true:
		var combo: Array[Enums.GemColor] = []
		for index: int in indices:
			combo.append(items[index])
		result.append(combo)
		var position: int = size - 1
		while position >= 0 and indices[position] == items.size() - size + position:
			position -= 1
		if position < 0:
			break
		indices[position] += 1
		for next_position: int in range(position + 1, size):
			indices[next_position] = indices[next_position - 1] + 1
	return result

# ---------------------------------------------------------------- 执行动作

## 执行一个动作。内部先按当前玩家的视图再校验一次合法性（非法就报错并原样返回，不改状态）；
## 执行完自动推进回合末流程（弃宝石 → 贵族 → 终局 → 换人 → 跳过没有合法动作的玩家），
## 返回这一串流程产生的全部事件。调用方不需要再手动推进回合。
static func apply(state: GameState, action: Action) -> Array[GameEvent]:
	var events: Array[GameEvent] = []
	if state == null or action == null:
		push_error("Rules.apply：state / action 不能为空")
		return events
	if state.phase == Enums.GamePhase.FINISHED:
		push_error("Rules.apply：对局已结束，不能再执行动作")
		return events
	var view: Dictionary = state.to_dict(state.current_seat)
	if not is_action_legal(view, state.catalog, state.config, action):
		push_error("Rules.apply：座位 %d 的非法动作：%s" % [state.current_seat, action.describe()])
		return events
	var player: PlayerState = state.current_player()
	match action.type:
		Enums.ActionType.TAKE_THREE, Enums.ActionType.TAKE_TWO:
			_take_gems(state, player, action, events)
		Enums.ActionType.RESERVE:
			_reserve(state, player, action, events)
		Enums.ActionType.PURCHASE:
			_purchase(state, player, action, events)
			if not state.config.is_enabled("noble_visit_at_turn_end"):
				_check_nobles(state, events)  # "贵族立即来访"的变体开关
		Enums.ActionType.DISCARD:
			_discard(state, player, action, events)
		Enums.ActionType.CHOOSE_NOBLE:
			_choose_noble(state, player, action, events)
		_:
			push_error("Rules.apply：未知动作类型")
			return events
	_settle(state, events)
	return events

static func _take_gems(state: GameState, player: PlayerState, action: Action,
		events: Array[GameEvent]) -> void:
	var amount: int = 2 if action.type == Enums.ActionType.TAKE_TWO else 1
	var gems: Dictionary = {}
	for color: Enums.GemColor in action.colors:
		state.bank[color] = state.bank_count(color) - amount
		player.add_tokens(color, amount)
		gems[Enums.color_to_string(color)] = amount
	events.append(GameEvent.new(Enums.EventType.GEMS_TAKEN, player.seat, {"gems": gems}))

static func _reserve(state: GameState, player: PlayerState, action: Action,
		events: Array[GameEvent]) -> void:
	var blind: bool = action.card_id.is_empty()
	var card: CardData = _draw(state, action.level) if blind else _take_from_board(state, action.card_id)
	player.reserved.append(ReservedCard.new(card, blind))
	var gold: int = 0
	if state.config.is_enabled("reserve_takes_gold") and state.bank_count(Enums.GemColor.GOLD) > 0:
		state.bank[Enums.GemColor.GOLD] = state.bank_count(Enums.GemColor.GOLD) - 1
		player.add_tokens(Enums.GemColor.GOLD, 1)
		gold = 1
	# 盲抽的牌不给 card_id（事件要能原样发给所有人，不能泄露别人看不到的牌）
	events.append(GameEvent.new(Enums.EventType.CARD_RESERVED, player.seat, {
		"card_id": "" if blind else card.id,
		"level": card.level,
		"blind": blind,
		"gold": gold,
	}))

static func _purchase(state: GameState, player: PlayerState, action: Action,
		events: Array[GameEvent]) -> void:
	var card: CardData = null
	var from_reserved: bool = false
	for index: int in player.reserved.size():
		if player.reserved[index].card.id == action.card_id:
			card = player.reserved[index].card
			player.reserved.remove_at(index)
			from_reserved = true
			break
	if card == null:
		card = _take_from_board(state, action.card_id)
	var payment: Dictionary[int, int] = _payment(_bonuses_of_cards(player.purchased),
			player.tokens, card.cost)
	var paid: Dictionary = {}
	for color: Enums.GemColor in payment:
		var amount: int = payment[color]
		state.bank[color] = state.bank_count(color) + amount
		player.add_tokens(color, -amount)
		paid[Enums.color_to_string(color)] = amount
	player.purchased.append(card)
	events.append(GameEvent.new(Enums.EventType.CARD_PURCHASED, player.seat, {
		"card_id": card.id,
		"level": card.level,
		"points": card.points,
		"paid": paid,
		"from_reserved": from_reserved,
	}))

static func _discard(state: GameState, player: PlayerState, action: Action,
		events: Array[GameEvent]) -> void:
	player.add_tokens(action.color, -1)
	state.bank[action.color] = state.bank_count(action.color) + 1
	events.append(GameEvent.new(Enums.EventType.GEMS_DISCARDED, player.seat,
			{"color": Enums.color_to_string(action.color)}))

static func _choose_noble(state: GameState, player: PlayerState, action: Action,
		events: Array[GameEvent]) -> void:
	for index: int in state.pending_nobles.size():
		if state.pending_nobles[index].id == action.noble_id:
			_take_noble(state, player, state.pending_nobles[index], events)
			state.pending_nobles.clear()  # 剩下的贵族留在场面，以后还可以再拿
			return
	push_error("Rules：待选贵族里没有 %s" % action.noble_id)

# ---------------------------------------------------------------- 回合末流程

## 动作执行后的收尾：需要玩家继续做选择（弃宝石 / 选贵族）时挂起，选完再从 apply → 这里进来。
static func _settle(state: GameState, events: Array[GameEvent]) -> void:
	if state.phase == Enums.GamePhase.DISCARD:
		if state.current_player().token_count() > state.config.max_tokens:
			return  # 还没弃够
		state.phase = Enums.GamePhase.PLAYING
		_end_of_turn(state, events, false)
		return
	if state.phase == Enums.GamePhase.CHOOSE_NOBLE:
		if not state.pending_nobles.is_empty():
			return  # 等玩家选
		state.phase = Enums.GamePhase.PLAYING
		_end_of_turn(state, events, true)  # 贵族这一步已经做完，不重复检查
		return
	_end_of_turn(state, events, false)

## 回合末：弃宝石（超上限时）→ 贵族来访 → 终局触发 → 换人。
static func _end_of_turn(state: GameState, events: Array[GameEvent], noble_step_done: bool) -> void:
	var player: PlayerState = state.current_player()
	if player.token_count() > state.config.max_tokens:
		state.phase = Enums.GamePhase.DISCARD
		events.append(GameEvent.new(Enums.EventType.DISCARD_REQUIRED, player.seat,
				{"count": player.token_count() - state.config.max_tokens}))
		return
	if not noble_step_done and state.config.is_enabled("noble_visit_at_turn_end"):
		if _check_nobles(state, events):
			return
	if not state.endgame_triggered and player.total_points() >= state.config.win_points:
		state.endgame_triggered = true
		state.trigger_seat = player.seat
		events.append(GameEvent.new(Enums.EventType.ENDGAME_TRIGGERED, player.seat,
				{"points": player.total_points()}))
	state.turn_counts[player.seat] += 1
	events.append(GameEvent.new(Enums.EventType.TURN_ENDED, player.seat,
			{"turn_count": state.turn_counts[player.seat]}))
	if state.endgame_triggered and _turn_counts_equal(state):
		_finish_game(state, events, "win_points")
		return
	if _safety_limit_reached(state):
		_finish_game(state, events, "stalled")
		return
	_advance(state, events)

## 贵族来访。返回 true 表示同时满足多位、进入了选择阶段（回合末流程挂起等玩家挑）。
static func _check_nobles(state: GameState, events: Array[GameEvent]) -> bool:
	var player: PlayerState = state.current_player()
	var eligible: Array[NobleData] = []
	for noble: NobleData in state.nobles:
		if _meets_noble(player, noble):
			eligible.append(noble)
	if eligible.is_empty():
		return false
	if state.config.is_enabled("max_one_noble_per_turn") and eligible.size() > 1:
		state.pending_nobles = eligible.duplicate()
		state.phase = Enums.GamePhase.CHOOSE_NOBLE
		events.append(GameEvent.new(Enums.EventType.NOBLE_CHOICE_REQUIRED, player.seat,
				{"noble_ids": _noble_ids(eligible)}))
		return true
	if state.config.is_enabled("max_one_noble_per_turn"):
		_take_noble(state, player, eligible[0], events)
		return false
	for noble: NobleData in eligible:
		_take_noble(state, player, noble, events)
	return false

static func _take_noble(state: GameState, player: PlayerState, noble: NobleData,
		events: Array[GameEvent]) -> void:
	state.nobles.erase(noble)
	state.pending_nobles.erase(noble)
	player.nobles.append(noble)
	events.append(GameEvent.new(Enums.EventType.NOBLE_VISITED, player.seat, {"noble_id": noble.id}))

static func _meets_noble(player: PlayerState, noble: NobleData) -> bool:
	return noble_met(player, noble)

## 这名玩家的折扣是否满足这位贵族的要求（界面显示"谁能拿哪位贵族"、自检都用它）。
static func noble_met(player: PlayerState, noble: NobleData) -> bool:
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		if player.discount_count(color) < noble.requirement_of(color):
			return false
	return true

## 轮到下一个玩家。新玩家没有合法动作就跳过（跳过也算一个回合）；
## 一整圈都没人能动作时提前结束（保险丝，正常对局不会发生）。
static func _advance(state: GameState, events: Array[GameEvent]) -> void:
	var skips: int = 0
	while true:
		state.current_seat = (state.current_seat + 1) % state.player_count
		var view: Dictionary = state.to_dict(state.current_seat)
		if not get_legal_actions(view, state.catalog, state.config).is_empty():
			break
		var player: PlayerState = state.current_player()
		events.append(GameEvent.new(Enums.EventType.TURN_STARTED, player.seat,
				{"turn_count": state.turn_counts[player.seat]}))
		events.append(GameEvent.new(Enums.EventType.PLAYER_SKIPPED, player.seat))
		state.turn_counts[player.seat] += 1
		events.append(GameEvent.new(Enums.EventType.TURN_ENDED, player.seat,
				{"turn_count": state.turn_counts[player.seat]}))
		skips += 1
		if state.endgame_triggered and _turn_counts_equal(state):
			_finish_game(state, events, "win_points")
			return
		if _safety_limit_reached(state):
			_finish_game(state, events, "stalled")
			return
		if skips >= state.player_count:
			_finish_game(state, events, "stalled")
			return
	events.append(GameEvent.new(Enums.EventType.TURN_STARTED, state.current_seat,
			{"turn_count": state.turn_counts[state.current_seat]}))

static func _finish_game(state: GameState, events: Array[GameEvent], reason: String) -> void:
	state.phase = Enums.GamePhase.FINISHED
	state.finished_reason = reason
	state.winners = _compute_winners(state)
	var scores: Dictionary = {}
	for player: PlayerState in state.players:
		scores[str(player.seat)] = player.total_points()
	events.append(GameEvent.new(Enums.EventType.GAME_FINISHED, state.current_seat, {
		"winners": state.winners.duplicate(),
		"reason": reason,
		"scores": scores,
	}))

## 分数最高者胜；平分时已购卡牌少者胜；再相同则并列。
static func _compute_winners(state: GameState) -> Array[int]:
	var best_points: int = -1
	var best_cards: int = 0
	var winners: Array[int] = []
	for player: PlayerState in state.players:
		var points: int = player.total_points()
		var cards: int = player.purchased.size()
		if points > best_points or (points == best_points and cards < best_cards):
			best_points = points
			best_cards = cards
			winners = [player.seat]
		elif points == best_points and cards == best_cards:
			winners.append(player.seat)
	return winners

static func _turn_counts_equal(state: GameState) -> bool:
	for count: int in state.turn_counts:
		if count != state.turn_counts[0]:
			return false
	return true

## 保险丝：任一玩家达到回合上限，且所有人回合数相同（终局时回合数仍然相等）。
## 只用来兜底没有“合法动作”可触发 stalled 的病态循环；正常对局远达不到这个上限。
static func _safety_limit_reached(state: GameState) -> bool:
	if state.config.max_turns_safety <= 0:
		return false
	var highest: int = 0
	for count: int in state.turn_counts:
		highest = maxi(highest, count)
	return highest >= state.config.max_turns_safety and _turn_counts_equal(state)

# ---------------------------------------------------------------- 视图解析

static func _player_dict(view: Dictionary, seat: int) -> Dictionary:
	var players: Array = view.get("players", [])
	if seat < 0 or seat >= players.size() or not players[seat] is Dictionary:
		return {}
	return players[seat]

## 把视图里的 {颜色名: 枚数} 转成枚举键的字典（视图序列化用名字，内存里用枚举）。
static func _tokens_from_view(raw: Dictionary) -> Dictionary[int, int]:
	var tokens: Dictionary[int, int] = {}
	for key: String in raw:
		var color: int = Enums.color_from_string(key)
		if color >= 0:
			tokens[color] = int(raw[key])
	return tokens

static func _color_count(raw: Dictionary, color: Enums.GemColor) -> int:
	return int(raw.get(Enums.color_to_string(color), 0))

static func _deck_count(decks: Dictionary, level: int) -> int:
	var entry: Variant = decks.get(str(level))
	if not entry is Dictionary:
		return 0
	return int((entry as Dictionary).get("count", 0))

static func _bonuses_of_ids(card_ids: Array, catalog: CardCatalog) -> Dictionary[int, int]:
	var bonuses: Dictionary[int, int] = {}
	for item: Variant in card_ids:
		var card: CardData = catalog.card(String(item))
		if card == null:
			continue
		bonuses[card.bonus] = bonuses.get(card.bonus, 0) + 1
	return bonuses

static func _bonuses_of_cards(cards: Array[CardData]) -> Dictionary[int, int]:
	var bonuses: Dictionary[int, int] = {}
	for card: CardData in cards:
		bonuses[card.bonus] = bonuses.get(card.bonus, 0) + 1
	return bonuses

static func _can_afford_card(bonuses: Dictionary[int, int], tokens: Dictionary[int, int],
		catalog: CardCatalog, card_id: String) -> bool:
	var card: CardData = catalog.card(card_id)
	if card == null:
		return false
	return _can_afford(bonuses, tokens, card.cost)

## 买得起吗：先用折扣，再用同色宝石，差额用金币补。
static func _can_afford(bonuses: Dictionary[int, int], tokens: Dictionary[int, int],
		cost: Dictionary[int, int]) -> bool:
	var needed: int = 0
	var available: int = tokens.get(Enums.GemColor.GOLD, 0)
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		var need: int = cost.get(color, 0)
		if need <= 0:
			continue
		var rest: int = need - mini(bonuses.get(color, 0), need)
		needed += rest
		available += mini(tokens.get(color, 0), rest)
	return available >= needed

## 实际支付方案（先决条件：买得起）：颜色 -> 用掉的枚数，金币补差额。
static func _payment(bonuses: Dictionary[int, int], tokens: Dictionary[int, int],
		cost: Dictionary[int, int]) -> Dictionary[int, int]:
	var payment: Dictionary[int, int] = {}
	var gold_needed: int = 0
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		var need: int = cost.get(color, 0)
		if need <= 0:
			continue
		var rest: int = need - mini(bonuses.get(color, 0), need)
		var from_token: int = mini(tokens.get(color, 0), rest)
		if from_token > 0:
			payment[color] = from_token
		gold_needed += rest - from_token
	if gold_needed > 0:
		payment[Enums.GemColor.GOLD] = gold_needed
	return payment

# ---------------------------------------------------------------- 卡牌移动

## 从牌堆顶抽一张（数组末尾是牌堆顶）；牌堆空了返回 null。
static func _draw(state: GameState, level: int) -> CardData:
	var deck: Array = state.decks[level]
	if deck.is_empty():
		return null
	return deck.pop_back()

## 把场面上的某张牌拿走并立即从同级牌堆补齐（牌堆空了那个位置就空着）。
static func _take_from_board(state: GameState, card_id: String) -> CardData:
	for level: int in [1, 2, 3]:
		var slots: Array = state.boards[level]
		for slot: int in slots.size():
			var card: Variant = slots[slot]
			if card != null and (card as CardData).id == card_id:
				slots[slot] = _draw(state, level)
				return card
	push_error("Rules：场面上找不到卡牌 %s" % card_id)
	return null

static func _noble_ids(source: Array[NobleData]) -> Array:
	var ids: Array = []
	for noble: NobleData in source:
		ids.append(noble.id)
	return ids
