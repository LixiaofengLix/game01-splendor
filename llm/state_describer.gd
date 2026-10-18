## 把过滤视图（GameState.to_dict(viewer_seat)）转成给大模型看的精简中文文本，
## 并把合法动作按固定顺序编号。只读视图，不访问 GameState 内部字段。
## privacy_problems() 用来断言发出去的文本没有泄露牌堆顺序或对手盲抽预留的牌。
class_name StateDescriber
extends RefCounted

## 局面文本。catalog 只用来查卡牌 / 贵族的数值（视图里只存 id）。
static func describe(view: Dictionary, catalog: CardCatalog, config: RulesConfig) -> String:
	var lines: Array[String] = []
	var phase: String = String(view.get("phase", ""))
	var current: int = int(view.get("current_seat", -1))
	var viewer: int = int(view.get("viewer_seat", GameState.VIEW_ALL))
	var current_name: String = "座位 %d" % current
	if current == viewer:
		current_name += "（你）"

	lines.append("【局面】%d 人局 · 第 %d 回合 · 阶段：%s · 当前行动：%s" % [
		int(view.get("player_count", 0)), _round_number(view), _phase_zh(phase), current_name,
	])
	if bool(view.get("endgame_triggered", false)) and phase != "finished":
		lines.append("终局已触发：本轮打完后结算。")
	lines.append("【银行】" + _bank_text(view.get("bank", {})))
	lines.append("【牌堆剩余】" + _decks_text(view.get("decks", {})))
	lines.append("【场面】")
	var boards: Dictionary = view.get("boards", {})
	for level: int in [3, 2, 1]:
		lines.append("  %d 级：" % level)
		var slots: Array = boards.get(str(level), [])
		for slot: int in slots.size():
			var card_id: Variant = slots[slot]
			if card_id == null or String(card_id).is_empty():
				continue
			var card: CardData = catalog.card(String(card_id))
			if card == null:
				lines.append("    位置 %d：未知牌" % (slot + 1))
			else:
				lines.append("    位置 %d：%s" % [slot + 1, _card_text(card)])

	lines.append("【贵族】")
	var nobles: Array = view.get("nobles", [])
	if nobles.is_empty():
		lines.append("  无")
	for noble_id: Variant in nobles:
		var noble: NobleData = catalog.noble(String(noble_id))
		if noble != null:
			lines.append("  " + _noble_text(noble))

	if phase == "choose_noble":
		lines.append("【待选贵族】")
		for noble_id: Variant in view.get("pending_nobles", []):
			var noble: NobleData = catalog.noble(String(noble_id))
			if noble != null:
				lines.append("  " + _noble_text(noble))

	lines.append("【玩家】")
	var players: Array = view.get("players", [])
	for player: Variant in players:
		if not player is Dictionary:
			continue
		lines.append(_player_text(player, viewer, catalog))
	return "\n".join(lines)

## 合法动作列表，编号从 1 开始（与提示词里的 action 编号一致）。
static func describe_actions(view: Dictionary, legal_actions: Array[Action],
		catalog: CardCatalog) -> String:
	var lines: Array[String] = []
	for index: int in legal_actions.size():
		lines.append("%d. %s" % [index + 1, action_detail(legal_actions[index], view, catalog)])
	return "\n".join(lines)

## 单个动作的中文说明（带卡牌数值与"支付自动完成"等提示）。
static func action_detail(action: Action, view: Dictionary, catalog: CardCatalog) -> String:
	if action == null:
		return "（空动作）"
	match action.type:
		Enums.ActionType.TAKE_THREE:
			var names: Array[String] = []
			for color: Enums.GemColor in action.colors:
				names.append(Enums.color_to_zh(color))
			if names.size() < 3:
				return "拿 %d 种不同颜色各 1 枚（颜色不足）：%s" % [names.size(), " ".join(names)]
			return "拿 3 种不同颜色各 1 枚：%s" % " ".join(names)
		Enums.ActionType.TAKE_TWO:
			return "拿 2 枚同色：%s" % Enums.color_to_zh(action.colors[0] if not action.colors.is_empty()
					else Enums.GemColor.WHITE)
		Enums.ActionType.RESERVE:
			var gold_note: String = ""
			var bank: Dictionary = view.get("bank", {})
			if int(bank.get("gold", 0)) > 0:
				gold_note = "，并获得 1 枚金币"
			if not action.card_id.is_empty():
				var card: CardData = catalog.card(action.card_id)
				return "预留 %s%s" % [_card_text(card) if card != null else action.card_id, gold_note]
			return "盲抽预留 %d 级牌堆顶（未知牌）%s" % [action.level, gold_note]
		Enums.ActionType.PURCHASE:
			var card: CardData = catalog.card(action.card_id)
			var from_reserved: bool = _is_own_reserved(action.card_id, view)
			if card == null:
				return "购买 %s（支付自动完成）" % action.card_id
			return "购买 %s%s（支付自动完成）" % [
				_card_text(card), "（从自己的预留中）" if from_reserved else "",
			]
		Enums.ActionType.DISCARD:
			return "弃掉 1 枚%s" % Enums.color_to_zh(action.color)
		Enums.ActionType.CHOOSE_NOBLE:
			var noble: NobleData = catalog.noble(action.noble_id)
			return "选择 %s" % (_noble_text(noble) if noble != null else action.noble_id)
	return action.describe()

## 检查发给大模型的视图和文本有没有隐藏信息。返回问题列表（空 = 通过）。
## full_view 传入完整视图（VIEW_ALL）时，会额外检查文本里是否出现了牌堆卡牌 id
## 和对手盲抽预留的卡牌 id；只有测试 / 调试能拿到完整视图，控制器只传前两个参数。
static func privacy_problems(view: Dictionary, text: String,
		full_view: Dictionary = {}) -> Array[String]:
	var problems: Array[String] = []
	var viewer: int = int(view.get("viewer_seat", GameState.VIEW_ALL))
	if viewer == GameState.VIEW_ALL:
		problems.append("发给大模型的视图是完整视图（viewer_seat = -1）")
	if view.has("seed") or view.has("rng_state"):
		problems.append("视图里带有种子 / 随机数状态")

	var decks: Dictionary = view.get("decks", {})
	for level: int in [1, 2, 3]:
		var entry: Variant = decks.get(str(level))
		if entry is Dictionary and (entry as Dictionary).has("cards"):
			problems.append("视图里带有 %d 级牌堆的具体卡牌顺序" % level)

	var players: Array = view.get("players", [])
	for player: Variant in players:
		if not player is Dictionary:
			continue
		var data: Dictionary = player
		var seat: int = int(data.get("seat", -1))
		for entry: Variant in data.get("reserved", []):
			if not entry is Dictionary:
				continue
			var reserved: Dictionary = entry
			if bool(reserved.get("blind", false)) and seat != viewer and reserved.get("id") != null:
				problems.append("视图里泄露了座位 %d 的盲抽预留卡 %s"
						% [seat, reserved.get("id")])

	if not full_view.is_empty():
		var hidden_ids: Array[String] = []
		var full_decks: Dictionary = full_view.get("decks", {})
		for level: int in [1, 2, 3]:
			var full_entry: Variant = full_decks.get(str(level))
			if not full_entry is Dictionary:
				continue
			for card_id: Variant in (full_entry as Dictionary).get("cards", []):
				if card_id != null:
					hidden_ids.append(String(card_id))
		for player: Variant in full_view.get("players", []):
			if not player is Dictionary:
				continue
			var data: Dictionary = player
			var seat: int = int(data.get("seat", -1))
			if seat == viewer:
				continue
			for entry: Variant in data.get("reserved", []):
				if not entry is Dictionary:
					continue
				var reserved: Dictionary = entry
				if bool(reserved.get("blind", false)) and reserved.get("id") != null:
					hidden_ids.append(String(reserved.get("id")))
		for card_id: String in hidden_ids:
			if text.contains(card_id):
				problems.append("文本泄露了隐藏卡牌 %s" % card_id)
	return problems

# ---------------------------------------------------------------- 文本片段

static func _round_number(view: Dictionary) -> int:
	var counts: Array = view.get("turn_counts", [])
	if counts.is_empty():
		return 1
	var round_number: int = int(counts[0]) + 1
	for count: Variant in counts:
		round_number = mini(round_number, int(count) + 1)
	return round_number

static func _phase_zh(phase: String) -> String:
	match phase:
		"playing":
			return "正常回合"
		"discard":
			return "弃宝石"
		"choose_noble":
			return "选贵族"
		"finished":
			return "已结束"
	return phase

static func _bank_text(raw: Dictionary) -> String:
	var parts: Array[String] = []
	for color: Enums.GemColor in Enums.ALL_COLORS:
		parts.append("%s %d" % [Enums.color_to_zh(color), int(raw.get(Enums.color_to_string(color), 0))])
	return " · ".join(parts)

static func _decks_text(raw: Dictionary) -> String:
	var parts: Array[String] = []
	for level: int in [3, 2, 1]:
		var entry: Variant = raw.get(str(level))
		var count: int = 0
		if entry is Dictionary:
			count = int((entry as Dictionary).get("count", 0))
		parts.append("%d 级 %d 张" % [level, count])
	return " · ".join(parts)

static func _card_text(card: CardData) -> String:
	if card == null or card.is_unknown():
		return "未知牌"
	return "%s（%s加成 %d 分，花费 %s）" % [
		card.id, Enums.color_to_zh(card.bonus), card.points, _cost_text(card),
	]

static func _cost_text(card: CardData) -> String:
	var parts: Array[String] = []
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		var amount: int = card.cost_of(color)
		if amount > 0:
			parts.append("%s%d" % [Enums.color_to_zh(color), amount])
	return " ".join(parts) if not parts.is_empty() else "无"

static func _noble_text(noble: NobleData) -> String:
	var parts: Array[String] = []
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		var amount: int = noble.requirement_of(color)
		if amount > 0:
			parts.append("%s%d" % [Enums.color_to_zh(color), amount])
	return "%s：%d 分，要求 %s" % [noble.id, noble.points, " ".join(parts)]

static func _player_text(player: Dictionary, viewer: int, catalog: CardCatalog) -> String:
	var seat: int = int(player.get("seat", -1))
	var relation: String = "（你）" if seat == viewer else "（对手）"
	var purchased: Array = player.get("purchased", [])
	var nobles: Array = player.get("nobles", [])
	var card_points: int = 0
	var discounts: Dictionary[int, int] = {}
	for card_id: Variant in purchased:
		var card: CardData = catalog.card(String(card_id))
		if card == null:
			continue
		card_points += card.points
		discounts[card.bonus] = discounts.get(card.bonus, 0) + 1
	var noble_points: int = 0
	var noble_names: Array[String] = []
	for noble_id: Variant in nobles:
		var noble: NobleData = catalog.noble(String(noble_id))
		if noble != null:
			noble_points += noble.points
			noble_names.append(noble.id)

	var lines: Array[String] = []
	lines.append("  座位 %d%s：%d 分（卡牌 %d + 贵族 %d）｜宝石 %s｜折扣 %s｜已购 %d 张｜贵族 %s" % [
		seat, relation, card_points + noble_points, card_points, noble_points,
		_tokens_text(player.get("tokens", {})), _discount_text(discounts), purchased.size(),
		" ".join(noble_names) if not noble_names.is_empty() else "无",
	])
	var reserved: Array = player.get("reserved", [])
	if not reserved.is_empty():
		lines.append("    预留：")
		for entry: Variant in reserved:
			if not entry is Dictionary:
				continue
			var data: Dictionary = entry
			var card_id: Variant = data.get("id")
			var level: int = int(data.get("level", 0))
			if card_id == null:
				lines.append("      %d 级（盲抽，未知）" % level)
			else:
				var card: CardData = catalog.card(String(card_id))
				lines.append("      " + (_card_text(card) if card != null else String(card_id)))
	return "\n".join(lines)

static func _tokens_text(raw: Dictionary) -> String:
	var parts: Array[String] = []
	for color: Enums.GemColor in Enums.ALL_COLORS:
		var amount: int = int(raw.get(Enums.color_to_string(color), 0))
		if amount > 0:
			parts.append("%s%d" % [Enums.color_to_zh(color), amount])
	return " ".join(parts) if not parts.is_empty() else "无"

static func _discount_text(raw: Dictionary[int, int]) -> String:
	var parts: Array[String] = []
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		var amount: int = raw.get(color, 0)
		if amount > 0:
			parts.append("%s%d" % [Enums.color_to_zh(color), amount])
	return " ".join(parts) if not parts.is_empty() else "无"

static func _is_own_reserved(card_id: String, view: Dictionary) -> bool:
	var viewer: int = int(view.get("viewer_seat", GameState.VIEW_ALL))
	var players: Array = view.get("players", [])
	if viewer < 0 or viewer >= players.size() or not players[viewer] is Dictionary:
		return false
	var player: Dictionary = players[viewer]
	for entry: Variant in player.get("reserved", []):
		if entry is Dictionary and String((entry as Dictionary).get("id", "")) == card_id:
			return true
	return false
