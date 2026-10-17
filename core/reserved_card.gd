## 一名玩家预留的一张牌：牌本身 + 是不是盲抽来的。
## 盲抽预留的牌对别人不可见（见 GameState.to_dict 的 viewer_seat），场面预留的牌所有人可见。
class_name ReservedCard
extends RefCounted

var card: CardData
var blind: bool = false

func _init(p_card: CardData = null, p_blind: bool = false) -> void:
	card = p_card
	blind = p_blind

func copy() -> ReservedCard:
	return ReservedCard.new(card, blind)
