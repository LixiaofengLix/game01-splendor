## 生成 tests/scenarios/ 下的预设局面（边界局面 JSON，供调试台 load 直接进入）。
## 改过 data/cards.json 或规则后重跑一次即可（局面里嵌了卡牌 id）。
## 用法：godot --headless --path . tests/scenarios/build_scenarios.tscn
##
## 局面都是"完整状态快照"（SaveFile 的 snapshot）：先按固定种子正常开局，再把牌 / 宝石摆成
## 想验证的边界情况，最后过一遍 GameState.validate() 和"当前玩家必须有合法动作"两道检查。
extends Node

const OUTPUT_DIR: String = "res://tests/scenarios"

var _config: RulesConfig
var _catalog: CardCatalog
var _failed: bool = false

func _ready() -> void:
	if not DataRegistry.is_valid():
		push_error("数据校验失败，先跑 tests/data_report.tscn")
		get_tree().quit(1)
		return
	_config = DataRegistry.rules()
	_catalog = DataRegistry.card_catalog()
	print("生成预设局面：")
	_build_token_limit()
	_build_two_nobles()
	_build_endgame()
	_build_bank_edges()
	_build_colors_short()
	_build_deck_empty()
	if _failed:
		print("有局面没生成成功，见上面的报错。")
		get_tree().quit(1)
		return
	print("全部生成完毕。")
	get_tree().quit(0)

# ---------------------------------------------------------------- 六个局面

## 手持 10 枚（上限）宝石：随便再拿一次就会进弃宝石阶段。
func _build_token_limit() -> void:
	var state: GameState = _new_state(2, 20261001)
	_move_tokens(state, 0, Enums.GemColor.WHITE, 4)
	_move_tokens(state, 0, Enums.GemColor.BLUE, 4)
	_move_tokens(state, 0, Enums.GemColor.GREEN, 2)
	_write("token_limit", state, "座位 0 已有 10 枚宝石（上限），再拿就会进弃宝石阶段")

## 座位 0 的折扣同时满足两位贵族：回合末进选择阶段。
func _build_two_nobles() -> void:
	var state: GameState = _new_state(2, 20261002)
	var pair: Array = _find_noble_pair(state)
	if pair.is_empty():
		_fail("two_nobles", "这局的贵族凑不出「恰好满足两位」的组合，换个种子试试")
		return
	var required: Dictionary = _union_requirement(pair[0], pair[1])
	for color: int in required:
		for amount: int in required[color]:
			_give(state, 0, _take_by_bonus(state, color))
	_write("two_nobles", state, "座位 0 同时满足 %s 和 %s，回合末会出现二选一"
			% [pair[0].id, pair[1].id])

## 座位 0 已 14 分，场上有一张买得起的有分卡：买下来就触发终局。
func _build_endgame() -> void:
	var state: GameState = _new_state(2, 20261003)
	# 用四种不同加成色、合计 14 分的卡（每种颜色各 1 张，凑不出贵族要求）
	var wanted: Array = [[3, 5], [3, 4], [3, 3], [2, 2]]
	var colors: Array = [Enums.GemColor.WHITE, Enums.GemColor.BLUE, Enums.GemColor.GREEN,
			Enums.GemColor.RED]
	for index: int in wanted.size():
		var card: CardData = _take_from_deck(state, wanted[index][0], colors[index], wanted[index][1])
		if card == null:
			_fail("endgame", "牌堆里找不到 %d 级 %d 分的卡" % [wanted[index][0], wanted[index][1]])
			return
		_give(state, 0, card)
	# 给座位 0 刚好够买一张有分卡的宝石
	var target: CardData = _pick_affordable_board_card(state, 1)
	if target == null:
		_fail("endgame", "场面上没有买得起的有分卡")
		return
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		if target.cost_of(color) > 0:
			_move_tokens(state, 0, color, target.cost_of(color))
	_write("endgame", state, "座位 0 已 14 分，买下 %s（%d 分）就触发终局"
			% [target.id, target.points])

## 银行边界：蓝剩 4（可以拿两枚）、红剩 3（不可以）、绿剩 0（排除）。
func _build_bank_edges() -> void:
	var state: GameState = _new_state(2, 20261004)
	_move_tokens(state, 1, Enums.GemColor.RED, 1)
	_move_tokens(state, 1, Enums.GemColor.GREEN, 4)
	_write("bank_edges", state, "银行：蓝 4（可拿两枚）、红 3（不可）、绿 0（不能拿）")

## 银行只剩 2 种颜色：按官方规则说明，拿三枚可以只拿 1~2 种。
func _build_colors_short() -> void:
	var state: GameState = _new_state(2, 20261005)
	_move_tokens(state, 0, Enums.GemColor.GREEN, 4)
	_move_tokens(state, 0, Enums.GemColor.RED, 2)
	_move_tokens(state, 1, Enums.GemColor.RED, 2)
	_move_tokens(state, 1, Enums.GemColor.BLACK, 4)
	_write("colors_short", state, "银行只剩白、蓝：拿三枚可以只拿 1 种或 2 种")

## 1 级牌堆已空：不能盲抽预留 1 级；预留 / 买走场面卡后那个位置就空着。
## 4 人局，每级 1 级牌摊到四个人身上，每家每种颜色最多 2 张——顺手凑不出贵族。
func _build_deck_empty() -> void:
	for seed_value: int in range(20261006, 20261100):
		var state: GameState = _new_state(4, seed_value)
		_spread_level_one_deck(state)
		if _any_noble_met(state):
			continue  # 换一个种子重来（发牌不同，贵族搭配也不同）
		if state.decks[1].size() != 0:
			_fail("deck_empty", "1 级牌堆没腾空（还剩 %d 张）" % state.decks[1].size())
			return
		_write("deck_empty", state, "1 级牌堆已空：没有「盲抽预留 1 级」，场面卡照常")
		return
	_fail("deck_empty", "试了 94 个种子都凑不出「不满足任何贵族」的摊法")

## 把 1 级牌堆剩下的牌摊给四个人（每家每种颜色最多 2 张，避免顺手凑够贵族）。
func _spread_level_one_deck(state: GameState) -> void:
	var deck: Array = state.decks[1]
	var per_color: Array[Dictionary] = []
	for seat: int in state.player_count:
		per_color.append({})
	while not deck.is_empty():
		var card: CardData = deck.pop_back()
		var chosen: int = -1
		for seat: int in state.player_count:
			if per_color[seat].get(card.bonus, 0) < 2:
				if chosen < 0 or state.players[seat].purchased.size() \
						< state.players[chosen].purchased.size():
					chosen = seat
		if chosen < 0:
			for seat: int in state.player_count:
				if chosen < 0 or state.players[seat].purchased.size() \
						< state.players[chosen].purchased.size():
					chosen = seat
		per_color[chosen][card.bonus] = per_color[chosen].get(card.bonus, 0) + 1
		_give(state, chosen, card)

# ---------------------------------------------------------------- 摆局面的小工具

func _new_state(player_count: int, seed_value: int) -> GameState:
	return Rules.setup(_config, _catalog, player_count, seed_value)

func _give(state: GameState, seat: int, card: CardData) -> void:
	state.players[seat].purchased.append(card)

func _move_tokens(state: GameState, seat: int, color: Enums.GemColor, amount: int) -> void:
	state.bank[color] = state.bank_count(color) - amount
	state.players[seat].add_tokens(color, amount)

## 从牌堆里拿走一张指定（等级、加成、分数）的牌；找不到返回 null（表示这道局面凑不出来）。
func _take_from_deck(state: GameState, level: int, bonus: Enums.GemColor,
		points: int) -> CardData:
	var deck: Array = state.decks[level]
	for index: int in deck.size():
		var card: CardData = deck[index]
		if card.bonus == bonus and card.points == points:
			deck.remove_at(index)
			return card
	return null

## 从牌堆里拿一张指定加成的牌（优先低分，少惹麻烦）。
func _take_by_bonus(state: GameState, bonus: Enums.GemColor) -> CardData:
	for points: int in [0, 1, 2, 3, 4, 5]:
		for level: int in [1, 2, 3]:
			var card: CardData = _take_from_deck(state, level, bonus, points)
			if card != null:
				return card
	_fail("build", "牌堆里没有 %s 加成的牌了" % Enums.color_to_zh(bonus))
	return null

## 找一对贵族：同时满足它们需要的每种颜色的最大张数，且不会顺手满足第三位。
func _find_noble_pair(state: GameState) -> Array:
	var best: Array = []
	var best_size: int = 99
	for first: int in state.nobles.size():
		for second: int in range(first + 1, state.nobles.size()):
			var required: Dictionary = _union_requirement(state.nobles[first], state.nobles[second])
			var total: int = 0
			var feasible: bool = true
			for color: int in required:
				total += required[color]
				if _deck_count_of_color(state, color) < required[color]:
					feasible = false
			if not feasible or total >= best_size:
				continue
			var others: Array[NobleData] = []
			for index: int in state.nobles.size():
				if index != first and index != second:
					others.append(state.nobles[index])
			if _satisfies_from_counts(required, others):
				continue  # 会顺手满足第三位
			best = [state.nobles[first], state.nobles[second]]
			best_size = total
	return best

func _union_requirement(first: NobleData, second: NobleData) -> Dictionary:
	var required: Dictionary = {}
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		var amount: int = maxi(first.requirement_of(color), second.requirement_of(color))
		if amount > 0:
			required[color] = amount
	return required

## 这些折扣数会不会满足 nobles 里任意一位贵族。
func _satisfies_from_counts(counts: Dictionary, nobles: Array[NobleData]) -> bool:
	for noble: NobleData in nobles:
		var met: bool = true
		for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
			if counts.get(color, 0) < noble.requirement_of(color):
				met = false
				break
		if met:
			return true
	return false

func _deck_count_of_color(state: GameState, color: Enums.GemColor) -> int:
	var count: int = 0
	for level: int in [1, 2, 3]:
		for card: CardData in state.decks[level]:
			if card.bonus == color:
				count += 1
	return count

## 找一张场面上的卡：分数不低于 min_points，且每种颜色的花费不超过银行里剩的。
func _pick_affordable_board_card(state: GameState, min_points: int) -> CardData:
	for level: int in [1, 2, 3]:
		for slot: Variant in state.boards[level]:
			if slot == null:
				continue
			var card: CardData = slot
			if card.points < min_points:
				continue
			var affordable: bool = true
			for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
				if card.cost_of(color) > state.bank_count(color):
					affordable = false
			if affordable:
				return card
	return null

func _any_noble_met(state: GameState) -> bool:
	for player: PlayerState in state.players:
		for noble: NobleData in state.nobles:
			if Rules.noble_met(player, noble):
				return true
	return false

# ---------------------------------------------------------------- 写出与检查

func _write(name: String, state: GameState, description: String) -> void:
	if _failed:
		return
	var problems: Array[String] = state.validate()
	if not problems.is_empty():
		_fail(name, "局面不合法：" + "；".join(problems))
		return
	var legal: Array[Action] = Rules.get_legal_actions(state.to_dict(state.current_seat),
			_catalog, _config)
	if legal.is_empty():
		_fail(name, "当前玩家没有合法动作，载入后会卡住")
		return
	var path: String = "%s/%s.json" % [OUTPUT_DIR, name]
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail(name, "写不了 %s：%s" % [path, error_string(FileAccess.get_open_error())])
		return
	file.store_string(JSON.stringify(SaveFile.wrap_snapshot(state), "  "))
	file.close()
	print("  ✓ %s.json —— %s" % [name, description])

func _fail(name: String, message: String) -> void:
	_failed = true
	push_error("%s：%s" % [name, message])
	print("  ✗ %s：%s" % [name, message])
