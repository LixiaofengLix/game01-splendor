## 程序 AI 的局面 / 动作评分与选择器。只从过滤视图推演：
## 先用 GameState.from_dict(view) 重建局面（看不到的牌是未知牌），之后在内存副本上
## duplicate_state() → Rules.apply()，绝不接触主机持有的 GameState。
##
## 三档策略：greedy（一步 + 噪声 / 偶尔犯错）、one_step（一步最优）、
## two_ply（我方一步 + 下一位对手最佳回应，带确定性节点预算与超时安全网）。
## 权重全部来自 AIProfile；分数是整数（厘分），平局按合法动作序号稳定排序。
class_name AIEvaluator
extends RefCounted

## 弃宝石 / 选贵族收尾的循环上限（持币上限是 10，12 足够）。
const MAX_STABILIZE_STEPS: int = 12
const SCORE_MIN: int = -1000000000
## 对手威胁特征的缩放：目标卡分数 × 10（让威胁项与“分”同量级）。
const THREAT_POINT_SCALE: int = 10

var profile: AIProfile
var catalog: CardCatalog
var config: RulesConfig
var rng: RandomNumberGenerator

## 上一次 choose_action 的耗时（不含界面思考延迟），供自检 / 模拟统计。
var last_think_ms: int = 0
## 困难搜索因为超时 / 节点预算没有完整展开的次数。
var timeout_fallbacks: int = 0
var node_limit_fallbacks: int = 0

var _count_nodes: bool = false
var _search_nodes: int = 0

func _init(p_profile: AIProfile, p_catalog: CardCatalog, p_config: RulesConfig,
		rng_seed: int = 0) -> void:
	profile = p_profile
	catalog = p_catalog
	config = p_config
	rng = RandomNumberGenerator.new()
	rng.seed = rng_seed

# ---------------------------------------------------------------- 对外入口

## 从当前玩家的过滤视图选一个动作。返回值保证来自 legal_actions（BotController 会再核对一次）。
func choose_action(view: Dictionary, legal_actions: Array[Action], seat: int) -> Action:
	var started: int = Time.get_ticks_msec()
	last_think_ms = 0
	if profile == null or catalog == null or config == null:
		push_error("AIEvaluator：缺少 profile / catalog / config")
		return legal_actions[0] if not legal_actions.is_empty() else null
	if legal_actions.is_empty():
		push_error("AIEvaluator：合法动作列表为空（座位 %d）" % seat)
		return null

	var errors: Array[String] = []
	var base: GameState = GameState.from_dict(view, config, catalog, errors)
	if base == null:
		push_error("AIEvaluator：过滤视图重建失败：%s" % "；".join(errors))
		return legal_actions[0]
	if seat < 0 or seat >= base.player_count:
		push_error("AIEvaluator：座位越界（%d）" % seat)
		return legal_actions[0]

	var ranked: Array[Dictionary] = _rank_actions(base, legal_actions, seat)
	if ranked.is_empty():
		return legal_actions[0]

	var phase: String = String(view.get("phase", ""))
	var chosen: Action
	if profile.strategy == AIProfile.STRATEGY_TWO_PLY and phase == "playing":
		chosen = _choose_two_ply(ranked, seat)
	else:
		chosen = _choose_one_step(ranked)
	last_think_ms = Time.get_ticks_msec() - started
	return chosen

# ---------------------------------------------------------------- 一步评分 / 排名

## 给每个合法动作打分：执行 → 替自己收尾（弃宝石 / 选贵族）→ 评估结果。
## 保留执行后的局面，困难难度直接复用，避免重复 apply。
func _rank_actions(base: GameState, legal_actions: Array[Action],
		seat: int) -> Array[Dictionary]:
	var blocked: Dictionary = _opponent_target_ids(base, seat)
	var ranked: Array[Dictionary] = []
	for index: int in legal_actions.size():
		var action: Action = legal_actions[index]
		var post: GameState = _simulate(base, action, seat)
		if post == null:
			continue
		var score: int = evaluate(post, seat) + _block_bonus(action, blocked) \
				- _reserve_gap_penalty(base, action, seat)
		if profile.strategy == AIProfile.STRATEGY_GREEDY and profile.random_noise > 0:
			score += rng.randi_range(-profile.random_noise, profile.random_noise)
		ranked.append({
			"action": action,
			"state": post,
			"score": score,
			"index": index,
		})
	ranked.sort_custom(_rank_before)
	return ranked

## 排序比较：分数高的在前；同分按合法动作序号（稳定、可复现）。
static func _rank_before(a: Dictionary, b: Dictionary) -> bool:
	if int(a["score"]) != int(b["score"]):
		return int(a["score"]) > int(b["score"])
	return int(a["index"]) < int(b["index"])

func _choose_one_step(ranked: Array[Dictionary]) -> Action:
	# 简单难度偶尔从“非最高分”的动作里随机选一个，保证是真正的失误。
	if profile.strategy == AIProfile.STRATEGY_GREEDY and ranked.size() > 1 \
			and profile.mistake_chance > 0.0 and rng.randf() < profile.mistake_chance:
		return ranked[rng.randi_range(1, ranked.size() - 1)]["action"]
	return ranked[0]["action"]

# ---------------------------------------------------------------- 两层搜索

## 对一步评分最高的 top_k 个动作展开“我方一步 + 下一位对手最佳回应”。
## max_nodes 是确定性的 apply 预算；timeout_ms 只是安全网。超限时回退到一步最优。
func _choose_two_ply(ranked: Array[Dictionary], seat: int) -> Action:
	var fallback_action: Action = ranked[0]["action"]
	var best_action: Action = fallback_action
	var best_value: int = SCORE_MIN
	var completed: bool = false
	var deadline: int = Time.get_ticks_msec() + profile.timeout_ms
	_count_nodes = true
	_search_nodes = 0
	var expansions: int = mini(profile.top_k, ranked.size())
	for rank_index: int in expansions:
		if _out_of_budget(deadline):
			break
		var entry: Dictionary = ranked[rank_index]
		var post: GameState = entry["state"]
		var value: Variant = _opponent_response_value(post, seat, deadline)
		if value == null:
			break  # 预算用完，后面的候选也无法完整展开
		completed = true
		if int(value) > best_value:
			best_value = int(value)
			best_action = entry["action"]
	_count_nodes = false

	if not completed:
		if _search_nodes >= profile.max_nodes:
			node_limit_fallbacks += 1
		else:
			timeout_fallbacks += 1
		return fallback_action
	return best_action

## 返回“对手按自己的评分做出最佳回应后，我方局面的分数”；被打断时返回 null。
func _opponent_response_value(post: GameState, seat: int, deadline: int) -> Variant:
	if post.is_finished():
		return evaluate(post, seat)
	var next_seat: int = post.current_seat
	if next_seat == seat:
		return evaluate(post, seat)
	var next_view: Dictionary = post.to_dict(next_seat)
	var next_legal: Array[Action] = Rules.get_legal_actions(next_view, catalog, config)
	if next_legal.is_empty():
		return evaluate(post, seat)
	var ordered: Array[Action] = _order_responses(next_legal)
	var limit: int = mini(profile.opponent_top_m, ordered.size())
	var best_opponent_score: int = SCORE_MIN
	var our_value: int = SCORE_MIN
	var any: bool = false
	for index: int in limit:
		if _out_of_budget(deadline):
			return null
		var response: Action = ordered[index]
		var response_state: GameState = _simulate(post, response, next_seat)
		if response_state == null:
			continue
		var opponent_score: int = evaluate(response_state, next_seat)
		if not any or opponent_score > best_opponent_score:
			best_opponent_score = opponent_score
			our_value = evaluate(response_state, seat)
			any = true
	if not any:
		return null
	return our_value

func _out_of_budget(deadline: int) -> bool:
	if _count_nodes and _search_nodes >= profile.max_nodes:
		return true
	return Time.get_ticks_msec() > deadline

## 对手回应的廉价排序：购买 → 预留 → 拿宝石；用于挑出前 opponent_top_m 个完整模拟。
func _order_responses(legal_actions: Array[Action]) -> Array[Action]:
	var scored: Array[Dictionary] = []
	for index: int in legal_actions.size():
		var action: Action = legal_actions[index]
		scored.append({
			"action": action,
			"score": _response_order_score(action),
			"index": index,
		})
	scored.sort_custom(_rank_before)
	var ordered: Array[Action] = []
	for entry: Dictionary in scored:
		ordered.append(entry["action"])
	return ordered

func _response_order_score(action: Action) -> int:
	match action.type:
		Enums.ActionType.PURCHASE:
			var purchase_card: CardData = catalog.card(action.card_id)
			return 100000 + (0 if purchase_card == null
					else purchase_card.points * 1000 + purchase_card.level)
		Enums.ActionType.RESERVE:
			if action.card_id.is_empty():
				return 40000
			var reserve_card: CardData = catalog.card(action.card_id)
			return 50000 + (0 if reserve_card == null
					else reserve_card.points * 1000 + reserve_card.level)
		Enums.ActionType.TAKE_THREE, Enums.ActionType.TAKE_TWO:
			return 10000 + action.colors.size() * 100
		Enums.ActionType.DISCARD, Enums.ActionType.CHOOSE_NOBLE:
			return 200000
	return 0

# ---------------------------------------------------------------- 模拟

## 复制局面 → 执行动作 → 替 actor 收尾（弃宝石 / 选贵族）。失败返回 null。
func _simulate(base: GameState, action: Action, actor_seat: int) -> GameState:
	var state: GameState = base.duplicate_state()
	if not _apply_counted(state, action):
		return null
	_stabilize(state, actor_seat)
	return state

## 当前玩家还处于弃宝石 / 选贵族阶段时，用确定性规则继续执行，
## 让后续评分看到“这件事已经办完”的局面。
## 这里用便宜的启发式而不是对每个候选再跑一次完整评估：困难搜索会调用它几百次，
## 真正的“当前这一步弃哪枚”仍由 _rank_actions 逐个评估。
func _stabilize(state: GameState, seat: int) -> void:
	var steps: int = 0
	while steps < MAX_STABILIZE_STEPS:
		if state.is_finished() or state.current_seat != seat:
			return
		var view: Dictionary = state.to_dict(seat)
		var legal: Array[Action] = Rules.get_legal_actions(view, catalog, config)
		if legal.is_empty():
			return
		var chosen: Action = null
		if state.phase == Enums.GamePhase.CHOOSE_NOBLE:
			chosen = legal[0]  # 贵族都是 3 分，按合法列表顺序稳定选择
		elif state.phase == Enums.GamePhase.DISCARD:
			chosen = _choose_discard_fast(state, state.players[seat], legal)
		else:
			return
		if chosen == null or not _apply_counted(state, chosen):
			return
		steps += 1

## 弃宝石的便宜启发式：优先弃“目标卡用不上、手里又多”的颜色，尽量不弃金币。
func _choose_discard_fast(state: GameState, player: PlayerState,
		legal: Array[Action]) -> Action:
	var target: Dictionary = _best_target(state, player, true)
	var best_action: Action = null
	var best_score: int = SCORE_MIN
	for action: Action in legal:
		if action.type != Enums.ActionType.DISCARD:
			continue
		var color: Enums.GemColor = action.color
		var need: int = 0
		if not target.is_empty():
			var target_card: CardData = target["card"]
			need = maxi(0, target_card.cost_of(color) - player.discount_count(color))
		var score: int = -need * 10 - player.token_count_of(color) * 2
		if color == Enums.GemColor.GOLD:
			score -= 20
		if score > best_score:
			best_score = score
			best_action = action
	return best_action if best_action != null else legal[0]

func _apply_counted(state: GameState, action: Action) -> bool:
	if _count_nodes:
		_search_nodes += 1
	return not Rules.apply(state, action).is_empty()

# ---------------------------------------------------------------- 评估

## 从 seat 的视角给完整（但只包含可见信息的）局面打分。终局用 ±win 覆盖。
func evaluate(state: GameState, seat: int) -> int:
	if state == null or seat < 0 or seat >= state.players.size():
		return SCORE_MIN
	if state.is_finished():
		return profile.weight_win if state.winners.has(seat) else -profile.weight_win

	var player: PlayerState = state.players[seat]
	var score: int = 0
	score += player.total_points() * profile.weight_points
	score += player.purchased.size() * profile.weight_card_bonus

	var token_total: int = 0
	for color: Enums.GemColor in Enums.ALL_COLORS:
		token_total += player.token_count_of(color)
	score += token_total * profile.weight_token
	score += player.token_count_of(Enums.GemColor.GOLD) * profile.weight_gold

	score -= _noble_gap(state, player) * profile.weight_noble_gap

	var target: Dictionary = _best_target(state, player, true)
	if not target.is_empty():
		var target_card: CardData = target["card"]
		var value: int = target_card.points * profile.weight_target_points \
				+ profile.weight_target_bonus
		score += value - int(target["gap"]) * profile.weight_target_gap
		score -= _waste(player, target_card) * profile.weight_waste

	score += _affordable_count(state, player) * profile.weight_affordable
	score -= _opponent_threat(state, seat) * profile.weight_opponent_threat
	return score

## 场上每位贵族还差多少折扣（按颜色求和）。越接近贵族，扣分越少。
func _noble_gap(state: GameState, player: PlayerState) -> int:
	var gap: int = 0
	for noble: NobleData in state.nobles:
		for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
			gap += maxi(0, noble.requirement_of(color) - player.discount_count(color))
	return gap

## 目标卡：场面卡 +（可选）自己预留卡里，“价值 − 缺口 × 惩罚”最高的一张。
## 跳过未知牌（推演时新翻开的牌、别人盲抽预留的牌）。
func _best_target(state: GameState, player: PlayerState, include_reserved: bool) -> Dictionary:
	var best: Dictionary = {}
	var best_score: int = SCORE_MIN
	for level: int in [1, 2, 3]:
		var slots: Array = state.boards.get(level, [])
		for slot: Variant in slots:
			if not (slot is CardData):
				continue
			var card: CardData = slot
			if card.is_unknown():
				continue
			var candidate: Dictionary = _target_candidate(player, card)
			var candidate_score: int = int(candidate["value"]) \
					- int(candidate["gap"]) * profile.weight_target_gap
			if candidate_score > best_score:
				best = candidate
				best_score = candidate_score
	if include_reserved:
		for entry: ReservedCard in player.reserved:
			if entry.card.is_unknown():
				continue
			var candidate: Dictionary = _target_candidate(player, entry.card)
			var candidate_score: int = int(candidate["value"]) \
					- int(candidate["gap"]) * profile.weight_target_gap
			if candidate_score > best_score:
				best = candidate
				best_score = candidate_score
	return best

func _target_candidate(player: PlayerState, card: CardData) -> Dictionary:
	return {
		"card": card,
		"value": card.points * profile.weight_target_points + profile.weight_target_bonus,
		"gap": _affordability_gap(player, card),
	}

## 买这张卡还差几枚宝石：先用折扣，再用同色宝石，最后用金币补。
func _affordability_gap(player: PlayerState, card: CardData) -> int:
	var gap: int = 0
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		var need: int = card.cost_of(color)
		if need <= 0:
			continue
		var after_discount: int = maxi(0, need - player.discount_count(color))
		gap += after_discount - mini(player.token_count_of(color), after_discount)
	return maxi(0, gap - player.token_count_of(Enums.GemColor.GOLD))

## 相对当前最佳目标“用不上”的宝石数（金币是万能牌，不算浪费）。
func _waste(player: PlayerState, target_card: CardData) -> int:
	var waste: int = 0
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		var need: int = maxi(0, target_card.cost_of(color) - player.discount_count(color))
		waste += player.token_count_of(color) - mini(player.token_count_of(color), need)
	return waste

## 当前买得起的可见卡数量（场面 + 自己预留）。
func _affordable_count(state: GameState, player: PlayerState) -> int:
	var count: int = 0
	for level: int in [1, 2, 3]:
		var slots: Array = state.boards.get(level, [])
		for slot: Variant in slots:
			if not (slot is CardData):
				continue
			var card: CardData = slot
			if card.is_unknown():
				continue
			if _affordability_gap(player, card) == 0:
				count += 1
	for entry: ReservedCard in player.reserved:
		if entry.card.is_unknown():
			continue
		if _affordability_gap(player, entry.card) == 0:
			count += 1
	return count

## 对手（按可见信息）离目标卡有多近：卡片分数 × 10 − 缺口 × 2，取最强的一位。
func _opponent_threat(state: GameState, seat: int) -> int:
	var threat: int = 0
	for other: PlayerState in state.players:
		if other.seat == seat:
			continue
		var target: Dictionary = _best_target(state, other, true)
		if target.is_empty():
			continue
		var card: CardData = target["card"]
		var value: int = card.points * THREAT_POINT_SCALE + 1 - int(target["gap"]) * 2
		threat = maxi(threat, maxi(0, value))
	return threat

## 每位对手最想要的场面卡（board-only），用于“预留 / 买走对手目标”的阻挡加分。
func _opponent_target_ids(state: GameState, seat: int) -> Dictionary:
	var ids: Dictionary = {}
	for other: PlayerState in state.players:
		if other.seat == seat:
			continue
		var target: Dictionary = _best_target(state, other, false)
		if target.is_empty():
			continue
		var card: CardData = target["card"]
		ids[card.id] = int(ids.get(card.id, 0)) + 1
	return ids

func _block_bonus(action: Action, blocked: Dictionary) -> int:
	if action.type != Enums.ActionType.RESERVE and action.type != Enums.ActionType.PURCHASE:
		return 0
	if action.card_id.is_empty() or not blocked.has(action.card_id):
		return 0
	return profile.weight_block_bonus * int(blocked[action.card_id])

## 预留一张自己短期买不起的牌，会白占名额；缺口越大，惩罚越重。
func _reserve_gap_penalty(base: GameState, action: Action, seat: int) -> int:
	if action.type != Enums.ActionType.RESERVE or action.card_id.is_empty():
		return 0
	var card: CardData = catalog.card(action.card_id)
	if card == null:
		return 0
	return _affordability_gap(base.players[seat], card) * profile.weight_reserve_gap
