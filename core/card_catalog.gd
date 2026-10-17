## 静态卡牌 / 贵族数据的查表（由 DataRegistry 构造，构造后视为只读）。
## core/ 不引用单例：规则函数需要的卡牌数值都通过这个对象传入。
## 视图里只放 card_id，靠它取回 CardData / NobleData。
class_name CardCatalog
extends RefCounted

var _cards: Dictionary[String, CardData] = {}
var _nobles: Dictionary[String, NobleData] = {}

func _init(cards: Array[CardData] = [], nobles: Array[NobleData] = []) -> void:
	for card: CardData in cards:
		_cards[card.id] = card
	for noble: NobleData in nobles:
		_nobles[noble.id] = noble

func has_card(card_id: String) -> bool:
	return _cards.has(card_id)

## 查不到时返回 null，由调用方报错。
func card(card_id: String) -> CardData:
	return _cards.get(card_id)

func has_noble(noble_id: String) -> bool:
	return _nobles.has(noble_id)

func noble(noble_id: String) -> NobleData:
	return _nobles.get(noble_id)

## 某一级的全部卡牌（开局发牌用），顺序与数据文件一致。
func cards_in_level(level: int) -> Array[CardData]:
	var result: Array[CardData] = []
	for card: CardData in _cards.values():
		if card.level == level:
			result.append(card)
	return result

func all_nobles() -> Array[NobleData]:
	var result: Array[NobleData] = []
	result.assign(_nobles.values())
	return result

## 未知牌占位：id 为空、等级已知。
## 从过滤视图重建状态时（牌堆内容、他人盲抽预留的牌看不到），以及 AI 推演时新翻开的牌，
## 都用它表示"这里有一张几级的牌，但不知道是哪张"。
static func unknown_card(level: int) -> CardData:
	return CardData.new("", level, Enums.GemColor.WHITE, 0, {})
