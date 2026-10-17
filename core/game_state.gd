## 一局对局的完整状态。只有规则引擎（和联网时的主机）持有完整状态，
## AI、大模型、客户端、界面拿到的都是 to_dict(viewer_seat) 过滤后的视图。
##
## 纯数据 + 纯函数：不引用 Node / 场景 / 单例，规则参数（RulesConfig）与卡牌数据（CardCatalog）
## 由外部注入。状态可序列化：to_dict(VIEW_ALL) → from_dict 往返一致，存档 = 种子 + 动作序列。
##
## 字典形态（键都是字符串，颜色 / 阶段 / 动作一律用名字，不用枚举序号）：
##   viewer_seat  -1 = 完整视图；>= 0 时会隐藏"牌堆顺序、他人盲抽预留的牌、种子与随机数状态"
##   decks        {"1": {"count": 剩余张数, "cards": [卡牌 id 或 null]}}
##                cards 数组末尾是牌堆顶（下一个抽的）；过滤视图里没有 cards 这个键
##   boards       {"1": [卡牌 id 或 null, ...]}   null = 空位或未知牌（长度固定为 board_slots_per_level）
##   players[]    {seat, tokens: {颜色名: 枚数}, purchased: [卡牌 id],
##                 reserved: [{id 或 null, level, blind}], nobles: [贵族 id]}
##   分数不单独存：由已购卡牌分 + 贵族分算出来（PlayerState.total_points）。
##   null 一律表示"不知道是哪张牌"（被隐藏，或推演时新翻开还没看到）。
class_name GameState
extends RefCounted

const SCHEMA_VERSION: int = 1
## viewer_seat 取这个值表示完整状态（存档、场景快照、主机内部）。
const VIEW_ALL: int = -1
## 校验用的结构常量（数值来源仍是 data/，这里只用来对账）。
const EXPECTED_LEVEL_TOTALS: Dictionary[int, int] = {1: 40, 2: 30, 3: 20}

var player_count: int = 0
## 开局种子；只有完整视图里才有（过滤视图里会推导出牌堆顺序）。
var seed: int = 0
## 随机数状态：存档后继续用时保持随机序列一致。
var rng_state: int = 0
var current_seat: int = 0
var phase: Enums.GamePhase = Enums.GamePhase.PLAYING
## 每人已经进行完的回合数（终局时所有人相同）。
var turn_counts: Array[int] = []
## 银行剩余宝石：Enums.GemColor -> 数量，含金币。
var bank: Dictionary[int, int] = {}
## 牌堆：等级 -> Array[CardData]，末尾是牌堆顶。
var decks: Dictionary[int, Array] = {}
## 场面翻开的卡：等级 -> Array[CardData 或 null]，长度固定。
var boards: Dictionary[int, Array] = {}
## 场上还没被拿走的贵族。
var nobles: Array[NobleData] = []
var players: Array[PlayerState] = []
var endgame_triggered: bool = false
## 触发终局的座位（未触发时为 -1）。
var trigger_seat: int = -1
## CHOOSE_NOBLE 阶段等当前玩家挑的贵族。
var pending_nobles: Array[NobleData] = []
var winners: Array[int] = []
## "win_points" = 有人到胜利分；"stalled" = 全员都没有合法动作（保险丝，正常对局不会发生）。
var finished_reason: String = ""
## 静态数据（不序列化，由 setup / from_dict 注入）。
var config: RulesConfig = null
var catalog: CardCatalog = null

func current_player() -> PlayerState:
	return players[current_seat]

func is_finished() -> bool:
	return phase == Enums.GamePhase.FINISHED

func deck_count(level: int) -> int:
	return (decks.get(level, []) as Array).size()

func bank_count(color: Enums.GemColor) -> int:
	return bank.get(color, 0)

# ---------------------------------------------------------------- 序列化

## 生成视图。viewer_seat = VIEW_ALL 得到完整状态（存档 / 场景 / 主机）；
## 传座位号则隐藏该玩家看不到的信息：牌堆顺序、他人盲抽预留的牌、种子与随机数状态。
func to_dict(viewer_seat: int = VIEW_ALL) -> Dictionary:
	var full: bool = viewer_seat == VIEW_ALL
	var view: Dictionary = {
		"schema_version": SCHEMA_VERSION,
		"viewer_seat": viewer_seat,
		"player_count": player_count,
		"current_seat": current_seat,
		"phase": Enums.phase_to_string(phase),
		"turn_counts": turn_counts.duplicate(),
		"endgame_triggered": endgame_triggered,
		"trigger_seat": trigger_seat,
		"winners": winners.duplicate(),
		"finished_reason": finished_reason,
		"bank": _bank_to_dict(),
		"decks": _decks_to_dict(full),
		"boards": _boards_to_dict(),
		"nobles": _noble_ids(nobles),
		"pending_nobles": _noble_ids(pending_nobles),
		"players": _players_to_dict(viewer_seat),
	}
	if full:
		view["seed"] = seed
		view["rng_state"] = rng_state
	return view

## 从字典重建状态。接受完整状态，也接受过滤视图：看不到的牌会变成"未知牌"占位
## （id 为空、等级已知），AI 推演时把它当作空位即可。
## 出错时把问题写进 errors（同时 push_error）并返回 null。
static func from_dict(data: Dictionary, config: RulesConfig, catalog: CardCatalog,
		errors: Array[String] = []) -> GameState:
	if config == null or catalog == null:
		errors.append("缺少 RulesConfig / CardCatalog")
		return _reject(errors)
	var state := GameState.new()
	state.config = config
	state.catalog = catalog
	if int(data.get("schema_version", 0)) != SCHEMA_VERSION:
		errors.append("schema_version 应为 %d，实际为 %s（旧格式不兼容）"
				% [SCHEMA_VERSION, data.get("schema_version")])
		return _reject(errors)
	state.player_count = int(data.get("player_count", 0))
	if not config.supported_player_counts().has(state.player_count):
		errors.append("player_count 不是支持的人数：%s" % str(data.get("player_count")))
		return _reject(errors)
	state.current_seat = int(data.get("current_seat", -1))
	if state.current_seat < 0 or state.current_seat >= state.player_count:
		errors.append("current_seat 越界：%d" % state.current_seat)
		return _reject(errors)
	var phase: int = Enums.phase_from_string(String(data.get("phase", "")))
	if phase < 0:
		errors.append("phase 不是合法阶段：\"%s\"" % data.get("phase"))
		return _reject(errors)
	state.phase = phase
	state.turn_counts = _int_array(data.get("turn_counts", []))
	if state.turn_counts.size() != state.player_count:
		errors.append("turn_counts 长度应为 %d，实际 %d" % [state.player_count, state.turn_counts.size()])
		return _reject(errors)

	_parse_bank(state, data.get("bank", {}), errors)
	_parse_decks(state, data.get("decks", {}), errors)
	_parse_boards(state, data.get("boards", {}), errors)
	state.nobles = _parse_nobles(data.get("nobles", []), catalog, errors, "nobles")
	state.pending_nobles = _parse_nobles(data.get("pending_nobles", []), catalog, errors, "pending_nobles")
	_parse_players(state, data.get("players", []), errors)

	state.endgame_triggered = bool(data.get("endgame_triggered", false))
	state.trigger_seat = int(data.get("trigger_seat", -1))
	state.winners = _int_array(data.get("winners", []))
	state.finished_reason = String(data.get("finished_reason", ""))
	state.seed = int(data.get("seed", 0))
	state.rng_state = int(data.get("rng_state", 0))
	if not errors.is_empty():
		return _reject(errors)
	var problems: Array[String] = state.validate()
	if not problems.is_empty():
		errors.append_array(problems)
		return _reject(errors)
	return state

## 深拷贝。卡牌 / 贵族对象是只读的，可以共享；容器全部复制，改副本不影响原状态。
func duplicate_state() -> GameState:
	var duplicate := GameState.new()
	duplicate.player_count = player_count
	duplicate.seed = seed
	duplicate.rng_state = rng_state
	duplicate.current_seat = current_seat
	duplicate.phase = phase
	duplicate.turn_counts = turn_counts.duplicate()
	duplicate.bank = bank.duplicate()
	for level: int in decks:
		duplicate.decks[level] = (decks[level] as Array).duplicate()
	for level: int in boards:
		duplicate.boards[level] = (boards[level] as Array).duplicate()
	duplicate.nobles = nobles.duplicate()
	duplicate.pending_nobles = pending_nobles.duplicate()
	for player: PlayerState in players:
		duplicate.players.append(player.copy())
	duplicate.endgame_triggered = endgame_triggered
	duplicate.trigger_seat = trigger_seat
	duplicate.winners = winners.duplicate()
	duplicate.finished_reason = finished_reason
	duplicate.config = config
	duplicate.catalog = catalog
	return duplicate

## 状态指纹（完整视图的 JSON 的 md5）：用来验证"同一种子开局一致 / 存档读档重放一致"。
## 注意：md5 只用于比对，不做安全用途。
func fingerprint() -> String:
	return JSON.stringify(to_dict(VIEW_ALL)).md5_text()

# ---------------------------------------------------------------- 不变量校验

## 校验规则不变量，返回问题列表（空 = 通过）。自检脚本、读档、场景文件都用它。
## 过滤视图重建出的状态同样能通过（未知牌按"该级的一张牌"计）。
func validate() -> Array[String]:
	var problems: Array[String] = []
	if config == null or catalog == null:
		return ["缺少 RulesConfig / CardCatalog"]
	if players.size() != player_count:
		return ["players 应为 %d 人，实际 %d 人" % [player_count, players.size()]]
	if turn_counts.size() != player_count:
		return ["turn_counts 长度应为 %d，实际 %d" % [player_count, turn_counts.size()]]

	_validate_tokens(problems)
	_validate_cards(problems)
	_validate_nobles(problems)
	_validate_limits(problems)
	_validate_phase(problems)
	return problems

## 宝石守恒：银行 + 所有玩家 = 开局总量；不能出现负数。
func _validate_tokens(problems: Array[String]) -> void:
	var expected: Dictionary[int, int] = {}
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		expected[color] = config.gems_per_color_for(player_count)
	expected[Enums.GemColor.GOLD] = config.gold_count
	for color: Enums.GemColor in expected:
		var total: int = bank_count(color)
		if total < 0:
			problems.append("银行%s为负数（%d）" % [Enums.color_to_zh(color), total])
		for player: PlayerState in players:
			var held: int = player.token_count_of(color)
			if held < 0:
				problems.append("座位 %d 的%s为负数（%d）" % [player.seat, Enums.color_to_zh(color), held])
			total += held
		if total != expected[color]:
			problems.append("%s宝石总数应为 %d，实际 %d（银行 + 玩家）"
					% [Enums.color_to_zh(color), expected[color], total])

## 卡牌守恒：每级的牌堆 + 场面 + 预留 + 已购 = 该级总数；同一张牌不能出现在两处。
func _validate_cards(problems: Array[String]) -> void:
	var per_level: Dictionary = {}
	var seen_ids: Dictionary = {}
	for level: int in [1, 2, 3]:
		for card: CardData in decks.get(level, []):
			_count_card(card, level, "%d 级牌堆" % level, per_level, seen_ids, problems)
		for card: Variant in boards.get(level, []):
			if card == null:
				continue
			_count_card(card, level, "%d 级场面" % level, per_level, seen_ids, problems)
	for player: PlayerState in players:
		for card: CardData in player.purchased:
			_count_card(card, card.level, "座位 %d 的已购卡" % player.seat, per_level, seen_ids, problems)
		for entry: ReservedCard in player.reserved:
			_count_card(entry.card, entry.card.level,
					"座位 %d 的预留卡" % player.seat, per_level, seen_ids, problems)
	for level: int in EXPECTED_LEVEL_TOTALS:
		var actual: int = per_level.get(level, 0)
		if actual != EXPECTED_LEVEL_TOTALS[level]:
			problems.append("%d 级卡牌总数应为 %d，实际 %d" % [level, EXPECTED_LEVEL_TOTALS[level], actual])

func _count_card(card: CardData, zone_level: int, zone: String, per_level: Dictionary,
		seen_ids: Dictionary, problems: Array[String]) -> void:
	if card == null:
		problems.append("%s 里有空位" % zone)
		return
	if card.level != zone_level:
		problems.append("%s 里出现 %d 级卡：%s" % [zone, card.level, card.id])
	per_level[card.level] = per_level.get(card.level, 0) + 1
	if card.is_unknown():
		return
	if seen_ids.has(card.id):
		problems.append("卡牌 %s 同时出现在 %s 和 %s" % [card.id, seen_ids[card.id], zone])
	else:
		seen_ids[card.id] = zone

## 贵族：总数 = 人数 + 1，不重复，已发的贵族要求必须已满足。
## 待选贵族是场面贵族的子集（还摆在桌上，只是这几张当前玩家可以挑）。
func _validate_nobles(problems: Array[String]) -> void:
	var seen: Dictionary = {}
	for noble: NobleData in nobles:
		_claim_noble(noble, "场面", seen, problems)
	var pending_seen: Dictionary = {}
	for noble: NobleData in pending_nobles:
		if pending_seen.has(noble.id):
			problems.append("待选贵族 %s 重复" % noble.id)
		pending_seen[noble.id] = true
		if not seen.has(noble.id):
			problems.append("待选贵族 %s 不在场面上" % noble.id)
	for player: PlayerState in players:
		for noble: NobleData in player.nobles:
			_claim_noble(noble, "座位 %d 的贵族" % player.seat, seen, problems)
			for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
				if player.discount_count(color) < noble.requirement_of(color):
					problems.append("座位 %d 拿到贵族 %s 但%s折扣不够（%d < %d）"
							% [player.seat, noble.id, Enums.color_to_zh(color),
							player.discount_count(color), noble.requirement_of(color)])
	var expected: int = config.nobles_for(player_count)
	if seen.size() != expected:
		problems.append("贵族总数应为 %d，实际 %d" % [expected, seen.size()])

func _claim_noble(noble: NobleData, zone: String, seen: Dictionary, problems: Array[String]) -> void:
	if seen.has(noble.id):
		problems.append("贵族 %s 同时出现在 %s 和 %s" % [noble.id, seen[noble.id], zone])
	else:
		seen[noble.id] = zone

## 上限：预留 ≤ max_reserved；持币 ≤ max_tokens（弃宝石阶段的当前玩家除外，他正超着）。
func _validate_limits(problems: Array[String]) -> void:
	for player: PlayerState in players:
		if player.reserved_count() > config.max_reserved:
			problems.append("座位 %d 预留 %d 张，超过上限 %d"
					% [player.seat, player.reserved_count(), config.max_reserved])
		var over_limit: bool = player.token_count() > config.max_tokens
		var may_exceed: bool = phase == Enums.GamePhase.DISCARD and player.seat == current_seat
		if over_limit and not may_exceed:
			problems.append("座位 %d 持币 %d 枚，超过上限 %d"
					% [player.seat, player.token_count(), config.max_tokens])

## 阶段与字段的一致性，以及回合数的推进关系。
func _validate_phase(problems: Array[String]) -> void:
	if phase == Enums.GamePhase.CHOOSE_NOBLE and pending_nobles.is_empty():
		problems.append("阶段是 choose_noble 但没有待选贵族")
	if phase != Enums.GamePhase.CHOOSE_NOBLE and not pending_nobles.is_empty():
		problems.append("有 %d 位待选贵族，但阶段不是 choose_noble" % pending_nobles.size())
	if phase == Enums.GamePhase.DISCARD \
			and current_player().token_count() <= config.max_tokens:
		problems.append("阶段是 discard，但座位 %d 的持币没有超上限" % current_seat)
	if phase == Enums.GamePhase.FINISHED and winners.is_empty():
		problems.append("阶段是 finished 但没有胜者")
	if endgame_triggered and (trigger_seat < 0 or trigger_seat >= player_count):
		problems.append("trigger_seat 越界：%d" % trigger_seat)
	var lowest: int = turn_counts[0]
	var highest: int = turn_counts[0]
	for count: int in turn_counts:
		lowest = mini(lowest, count)
		highest = maxi(highest, count)
	if highest - lowest > 1:
		problems.append("回合数差距超过 1：%s" % str(turn_counts))

# ---------------------------------------------------------------- 解析辅助

static func _reject(errors: Array[String]) -> GameState:
	for message: String in errors:
		push_error("GameState.from_dict：%s" % message)
	return null

static func _int_array(raw: Variant) -> Array[int]:
	var result: Array[int] = []
	if raw is Array:
		for item: Variant in raw:
			result.append(int(item))
	return result

## 卡牌引用：卡牌 id 字符串，或 null（空位 / 未知牌）。
static func _parse_card_ref(item: Variant, level: int, catalog: CardCatalog,
		errors: Array[String], where: String) -> CardData:
	if item == null:
		return CardCatalog.unknown_card(level)
	var card_id: String = String(item)
	var card: CardData = catalog.card(card_id)
	if card == null:
		errors.append("%s 里有不存在的卡牌 id：\"%s\"" % [where, card_id])
		return CardCatalog.unknown_card(level)
	return card

static func _parse_nobles(raw: Variant, catalog: CardCatalog, errors: Array[String],
		where: String) -> Array[NobleData]:
	var result: Array[NobleData] = []
	if not raw is Array:
		errors.append("%s 必须是数组" % where)
		return result
	for item: Variant in raw:
		var noble: NobleData = catalog.noble(String(item))
		if noble == null:
			errors.append("%s 里有不存在的贵族 id：\"%s\"" % [where, item])
			continue
		result.append(noble)
	return result

static func _parse_bank(state: GameState, raw: Variant, errors: Array[String]) -> void:
	if not raw is Dictionary:
		errors.append("bank 必须是对象")
		return
	var bank: Dictionary = raw
	for key: String in bank:
		var color: int = Enums.color_from_string(key)
		if color < 0:
			errors.append("bank 里有非法颜色：\"%s\"" % key)
			continue
		var amount: int = int(bank[key])
		if amount < 0:
			errors.append("bank.%s 为负数：%d" % [key, amount])
			continue
		state.bank[color] = amount

static func _parse_decks(state: GameState, raw: Variant, errors: Array[String]) -> void:
	if not raw is Dictionary:
		errors.append("decks 必须是对象")
		return
	var decks: Dictionary = raw
	for level: int in [1, 2, 3]:
		var entry: Variant = decks.get(str(level))
		if not entry is Dictionary:
			errors.append("decks 缺少 %d 级" % level)
			continue
		var entry_dict: Dictionary = entry
		var count: int = int(entry_dict.get("count", -1))
		if count < 0:
			errors.append("decks.%d.count 不能为负：%d" % [level, count])
			count = 0
		var cards: Array[CardData] = []
		if entry_dict.has("cards"):
			var raw_cards: Array = entry_dict["cards"]
			if raw_cards.size() != count:
				errors.append("decks.%d 的 count=%d 与 cards 张数 %d 不一致"
						% [level, count, raw_cards.size()])
			for item: Variant in raw_cards:
				cards.append(_parse_card_ref(item, level, state.catalog, errors, "decks.%d" % level))
		else:
			# 过滤视图：只知道还有几张，不知道是哪几张。
			for index: int in count:
				cards.append(CardCatalog.unknown_card(level))
		state.decks[level] = cards

static func _parse_boards(state: GameState, raw: Variant, errors: Array[String]) -> void:
	if not raw is Dictionary:
		errors.append("boards 必须是对象")
		return
	var boards: Dictionary = raw
	for level: int in [1, 2, 3]:
		var raw_slots: Variant = boards.get(str(level))
		if not raw_slots is Array:
			errors.append("boards 缺少 %d 级" % level)
			continue
		var slots: Array = []
		for item: Variant in raw_slots:
			if item == null:
				# 场面上的 null 是空位（牌堆空了，或者推演时新翻开的牌还没看到）
				slots.append(null)
				continue
			slots.append(_parse_card_ref(item, level, state.catalog, errors, "boards.%d" % level))
		if slots.size() != state.config.board_slots_per_level:
			errors.append("boards.%d 应有 %d 个位置，实际 %d"
					% [level, state.config.board_slots_per_level, slots.size()])
		state.boards[level] = slots

static func _parse_players(state: GameState, raw: Variant, errors: Array[String]) -> void:
	if not raw is Array or (raw as Array).size() != state.player_count:
		errors.append("players 应是 %d 个玩家的数组" % state.player_count)
		return
	var raw_players: Array = raw
	for index: int in raw_players.size():
		if not raw_players[index] is Dictionary:
			errors.append("players[%d] 必须是对象" % index)
			continue
		var entry: Dictionary = raw_players[index]
		var player := PlayerState.new(index)
		if int(entry.get("seat", index)) != index:
			errors.append("players[%d].seat 应为 %d，实际 %s" % [index, index, entry.get("seat")])
		_parse_tokens(player, entry.get("tokens", {}), errors)
		state.players.append(player)
		# 下面几项要在 player 进数组之后解析（顺序无所谓，但错误信息里带座位号）
		for item: Variant in entry.get("purchased", []):
			var card: CardData = state.catalog.card(String(item))
			if card == null:
				errors.append("座位 %d 的已购卡里有不存在的 id：\"%s\"" % [index, item])
				continue
			player.purchased.append(card)
		for item: Variant in entry.get("reserved", []):
			if not item is Dictionary:
				errors.append("座位 %d 的预留卡必须是对象" % index)
				continue
			var reserved: Dictionary = item
			var level: int = int(reserved.get("level", 0))
			var card_id: Variant = reserved.get("id")
			var card: CardData = null
			if card_id == null:
				card = CardCatalog.unknown_card(level)
			else:
				card = state.catalog.card(String(card_id))
				if card == null:
					errors.append("座位 %d 的预留卡里有不存在的 id：\"%s\"" % [index, card_id])
					continue
			if not reserved.has("blind"):
				errors.append("座位 %d 的预留卡 %s 缺少 blind 字段" % [index, card_id])
			player.reserved.append(ReservedCard.new(card, bool(reserved.get("blind", false))))
		for item: Variant in entry.get("nobles", []):
			var noble: NobleData = state.catalog.noble(String(item))
			if noble == null:
				errors.append("座位 %d 的贵族里有不存在的 id：\"%s\"" % [index, item])
				continue
			player.nobles.append(noble)

static func _parse_tokens(player: PlayerState, raw: Variant, errors: Array[String]) -> void:
	if not raw is Dictionary:
		errors.append("座位 %d 的 tokens 必须是对象" % player.seat)
		return
	var tokens: Dictionary = raw
	for key: String in tokens:
		var color: int = Enums.color_from_string(key)
		if color < 0:
			errors.append("座位 %d 的 tokens 里有非法颜色：\"%s\"" % [player.seat, key])
			continue
		var amount: int = int(tokens[key])
		if amount < 0:
			errors.append("座位 %d 的 tokens.%s 为负数：%d" % [player.seat, key, amount])
			continue
		if amount > 0:
			player.tokens[color] = amount

# ---------------------------------------------------------------- 内部转字典

func _bank_to_dict() -> Dictionary:
	var result: Dictionary = {}
	for color: int in Enums.COLOR_NAMES.size():
		result[Enums.color_to_string(color)] = bank_count(color)
	return result

func _decks_to_dict(full: bool) -> Dictionary:
	var result: Dictionary = {}
	for level: int in [1, 2, 3]:
		var deck: Array = decks.get(level, [])
		var entry: Dictionary = {"count": deck.size()}
		if full:
			var ids: Array = []
			for card: CardData in deck:
				ids.append(_card_ref(card))
			entry["cards"] = ids
		result[str(level)] = entry
	return result

func _boards_to_dict() -> Dictionary:
	var result: Dictionary = {}
	for level: int in [1, 2, 3]:
		var ids: Array = []
		for card: Variant in boards.get(level, []):
			ids.append(_card_ref(card))
		result[str(level)] = ids
	return result

func _players_to_dict(viewer_seat: int) -> Array:
	var result: Array = []
	for player: PlayerState in players:
		var reserved: Array = []
		for entry: ReservedCard in player.reserved:
			var hidden: bool = entry.blind and viewer_seat != VIEW_ALL and viewer_seat != player.seat
			reserved.append({
				"id": null if hidden else _card_ref(entry.card),
				"level": entry.card.level,
				"blind": entry.blind,
			})
		var tokens: Dictionary = {}
		for color: int in Enums.COLOR_NAMES.size():
			if player.token_count_of(color) > 0:
				tokens[Enums.color_to_string(color)] = player.token_count_of(color)
		result.append({
			"seat": player.seat,
			"tokens": tokens,
			"purchased": _card_ids(player.purchased),
			"reserved": reserved,
			"nobles": _noble_ids(player.nobles),
		})
	return result

## 未知牌的 id 为空，序列化成 null（"不知道是哪张"）。
func _card_ref(card: Variant) -> Variant:
	if card == null or (card as CardData).is_unknown():
		return null
	return (card as CardData).id

func _card_ids(cards: Array[CardData]) -> Array:
	var ids: Array = []
	for card: CardData in cards:
		ids.append(card.id)
	return ids

func _noble_ids(source: Array[NobleData]) -> Array:
	var ids: Array = []
	for noble: NobleData in source:
		ids.append(noble.id)
	return ids
