## 从过滤视图 + CardCatalog 算界面要显示的派生数据：分数、折扣、持币、缺口、支付预览、
## 买得起的座位、轮数与终局剩余人数。只读视图，不引用 GameState，也不改任何状态。
## 买得起判断与支付拆分和 core/rules.gd 的 _can_afford / _payment 同一算法（IR-02 的临时实现）。
class_name UiViewMath
extends RefCounted

## 一位玩家的视图字典。座位越界时返回空字典。
static func player(view: Dictionary, seat: int) -> Dictionary:
	var players: Array = view.get("players", [])
	if seat < 0 or seat >= players.size():
		return {}
	var entry: Variant = players[seat]
	return entry if entry is Dictionary else {}


## 某座位手里的宝石：Enums.GemColor -> 枚数（只含视图里出现的颜色，取不到的按 0 处理）。
static func tokens(view: Dictionary, seat: int) -> Dictionary[int, int]:
	var result: Dictionary[int, int] = {}
	var raw: Variant = player(view, seat).get("tokens", {})
	if not raw is Dictionary:
		return result
	for key: Variant in raw:
		var color: int = Enums.color_from_string(String(key))
		if color >= 0:
			result[color] = int((raw as Dictionary)[key])
	return result


static func token_count(view: Dictionary, seat: int, color: Enums.GemColor) -> int:
	return tokens(view, seat).get(color, 0)


## 持币总数（含金币）。
static func token_total(view: Dictionary, seat: int) -> int:
	var total: int = 0
	for amount: int in tokens(view, seat).values():
		total += amount
	return total


## 已购卡牌 id（按购买顺序）。
static func purchased_ids(view: Dictionary, seat: int) -> Array:
	var raw: Variant = player(view, seat).get("purchased", [])
	return raw if raw is Array else []


static func card_count(view: Dictionary, seat: int) -> int:
	return purchased_ids(view, seat).size()


## 某座位的五色折扣：Enums.GemColor -> 张数（不含金币）。
static func bonuses(view: Dictionary, seat: int, catalog: CardCatalog) -> Dictionary[int, int]:
	var result: Dictionary[int, int] = {}
	for item: Variant in purchased_ids(view, seat):
		var card: CardData = catalog.card(String(item)) if catalog != null else null
		if card == null:
			continue
		result[card.bonus] = result.get(card.bonus, 0) + 1
	return result


## 已购卡牌分（不含贵族）。
static func card_points(view: Dictionary, seat: int, catalog: CardCatalog) -> int:
	var total: int = 0
	for item: Variant in purchased_ids(view, seat):
		var card: CardData = catalog.card(String(item)) if catalog != null else null
		if card != null:
			total += card.points
	return total


static func noble_ids(view: Dictionary, seat: int) -> Array:
	var raw: Variant = player(view, seat).get("nobles", [])
	return raw if raw is Array else []


static func noble_count(view: Dictionary, seat: int) -> int:
	return noble_ids(view, seat).size()


static func noble_points(view: Dictionary, seat: int, catalog: CardCatalog) -> int:
	var total: int = 0
	for item: Variant in noble_ids(view, seat):
		var noble: NobleData = catalog.noble(String(item)) if catalog != null else null
		if noble != null:
			total += noble.points
	return total


## 总分 = 卡牌分 + 贵族分（和 PlayerState.total_points 一致）。
static func score(view: Dictionary, seat: int, catalog: CardCatalog) -> int:
	return card_points(view, seat, catalog) + noble_points(view, seat, catalog)


## 买这张卡还差几枚（折扣、同色宝石、金币依次抵扣）。
static func shortfall(view: Dictionary, seat: int, card_id: String, catalog: CardCatalog) -> int:
	var card: CardData = catalog.card(card_id) if catalog != null else null
	if card == null:
		return 0
	var player_bonuses: Dictionary[int, int] = bonuses(view, seat, catalog)
	var held: Dictionary[int, int] = tokens(view, seat)
	var needed: int = 0
	var available: int = held.get(Enums.GemColor.GOLD, 0)
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		var need: int = card.cost_of(color)
		if need <= 0:
			continue
		var rest: int = need - mini(player_bonuses.get(color, 0), need)
		needed += rest
		available += mini(held.get(color, 0), rest)
	return maxi(needed - available, 0)


static func can_afford(view: Dictionary, seat: int, card_id: String, catalog: CardCatalog) -> bool:
	var card: CardData = catalog.card(card_id) if catalog != null else null
	return card != null and shortfall(view, seat, card_id, catalog) == 0


## 缺口明细（不含金币能抵的部分）：[{color, amount}]，按白蓝绿红黑顺序。
static func missing_by_color(view: Dictionary, seat: int, card_id: String,
		catalog: CardCatalog) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var card: CardData = catalog.card(card_id) if catalog != null else null
	if card == null:
		return result
	var player_bonuses: Dictionary[int, int] = bonuses(view, seat, catalog)
	var held: Dictionary[int, int] = tokens(view, seat)
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		var need: int = card.cost_of(color)
		if need <= 0:
			continue
		var rest: int = need - mini(player_bonuses.get(color, 0), need)
		var missing: int = rest - mini(held.get(color, 0), rest)
		if missing > 0:
			result.append({"color": color, "amount": missing})
	return result


## 缺口里金币最多能抵几枚。
static func gold_can_pay(view: Dictionary, seat: int, card_id: String, catalog: CardCatalog) -> int:
	var missing: Array[Dictionary] = missing_by_color(view, seat, card_id, catalog)
	var total: int = 0
	for entry: Dictionary in missing:
		total += int(entry.get("amount", 0))
	return mini(token_count(view, seat, Enums.GemColor.GOLD), total)


## 支付预览（先折扣、再同色宝石、最后金币）。
## 返回 {"bonus": {颜色: 枚数}, "gems": {颜色: 枚数}, "gold": 枚数, "total": 花费总数}。
static func payment_preview(view: Dictionary, seat: int, card_id: String,
		catalog: CardCatalog) -> Dictionary:
	var bonus_used: Dictionary[int, int] = {}
	var gems_used: Dictionary[int, int] = {}
	var gold_needed: int = 0
	var cost_total: int = 0
	var card: CardData = catalog.card(card_id) if catalog != null else null
	if card == null:
		return {"bonus": bonus_used, "gems": gems_used, "gold": 0, "total": 0}
	var player_bonuses: Dictionary[int, int] = bonuses(view, seat, catalog)
	var held: Dictionary[int, int] = tokens(view, seat)
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		var need: int = card.cost_of(color)
		if need <= 0:
			continue
		cost_total += need
		var from_bonus: int = mini(player_bonuses.get(color, 0), need)
		var rest: int = need - from_bonus
		var from_gems: int = mini(held.get(color, 0), rest)
		if from_bonus > 0:
			bonus_used[color] = from_bonus
		if from_gems > 0:
			gems_used[color] = from_gems
		gold_needed += rest - from_gems
	return {"bonus": bonus_used, "gems": gems_used, "gold": gold_needed, "total": cost_total}


## 现在买得起这张卡的座位（含自己），升序。
static func affordable_by(view: Dictionary, card_id: String, catalog: CardCatalog) -> Array[int]:
	var result: Array[int] = []
	var players: Array = view.get("players", [])
	for seat: int in players.size():
		if can_afford(view, seat, card_id, catalog):
			result.append(seat)
	return result


## 当前是第几轮：每人已完成的回合数的最小值 + 1；终局后用已完成的回合数。
static func round_number(view: Dictionary) -> int:
	var counts: Array = view.get("turn_counts", [])
	if counts.is_empty():
		return 1
	var lowest: int = int(counts[0])
	var highest: int = int(counts[0])
	for item: Variant in counts:
		lowest = mini(lowest, int(item))
		highest = maxi(highest, int(item))
	if String(view.get("phase", "")) == "finished":
		return maxi(highest, 1)
	return maxi(lowest + 1, 1)


## 终局轮里还没行动的座位（回合数少于最大值的座位）。未触发终局时为空。
static func endgame_remaining(view: Dictionary) -> Array[int]:
	var result: Array[int] = []
	if not bool(view.get("endgame_triggered", false)):
		return result
	var counts: Array = view.get("turn_counts", [])
	if counts.is_empty():
		return result
	var highest: int = int(counts[0])
	for item: Variant in counts:
		highest = maxi(highest, int(item))
	for seat: int in counts.size():
		if int(counts[seat]) < highest:
			result.append(seat)
	return result


static func seat_type_label(seat_type: String) -> String:
	match seat_type:
		"human":
			return "人类"
		"bot_easy":
			return "电脑 · 简单"
		"bot_normal":
			return "电脑 · 普通"
		"bot_hard":
			return "电脑 · 困难"
		"llm":
			return "大模型"
		"remote":
			return "远程"
	return "人类"


## 大模型座位用紫色标签，其余用默认配色。
static func seat_type_tag_variant(seat_type: String) -> StringName:
	return &"purple" if seat_type == "llm" else &"default"


## 预留项里的卡牌 id；盲抽且看不到时视图给 null。
static func reserved_card_id(entry: Dictionary) -> String:
	var value: Variant = entry.get("id")
	return String(value) if value != null else ""


static func is_blind(entry: Dictionary) -> bool:
	return bool(entry.get("blind", false))
