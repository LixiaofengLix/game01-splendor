## 一名玩家的状态：宝石、已购卡牌、预留卡牌、贵族。
## 只有数据字段和只读派生（折扣数、分数）；所有判定都在 Rules 里。
class_name PlayerState
extends RefCounted

var seat: int = 0
## 手中的宝石：Enums.GemColor -> 数量（含金币），只存非零项。
var tokens: Dictionary[int, int] = {}
## 已购卡牌，按购买顺序（平分时比购买张数用）。
var purchased: Array[CardData] = []
## 预留卡牌（含盲抽的，见 ReservedCard）。
var reserved: Array[ReservedCard] = []
## 已获得的贵族。
var nobles: Array[NobleData] = []

func _init(p_seat: int = 0) -> void:
	seat = p_seat

## 增减宝石；减到 0 就把键删掉（tokens 只存非零项）。
func add_tokens(color: Enums.GemColor, amount: int) -> void:
	var total: int = token_count_of(color) + amount
	if total == 0:
		tokens.erase(color)
	else:
		tokens[color] = total

func token_count_of(color: Enums.GemColor) -> int:
	return tokens.get(color, 0)

func token_count() -> int:
	var total: int = 0
	for amount: int in tokens.values():
		total += amount
	return total

## 某色折扣数 = 该色加成的已购卡牌数（贵族要求也按这个算）。
func discount_count(color: Enums.GemColor) -> int:
	var count: int = 0
	for card: CardData in purchased:
		if card.bonus == color:
			count += 1
	return count

func card_points() -> int:
	var total: int = 0
	for card: CardData in purchased:
		total += card.points
	return total

func noble_points() -> int:
	var total: int = 0
	for noble: NobleData in nobles:
		total += noble.points
	return total

## 分数不单独存，永远由"卡牌分 + 贵族分"算出来，避免两处数据不一致。
func total_points() -> int:
	return card_points() + noble_points()

func reserved_count() -> int:
	return reserved.size()

func copy() -> PlayerState:
	var duplicate := PlayerState.new(seat)
	duplicate.tokens = tokens.duplicate()
	duplicate.purchased = purchased.duplicate()
	for entry: ReservedCard in reserved:
		duplicate.reserved.append(entry.copy())
	duplicate.nobles = nobles.duplicate()
	return duplicate
