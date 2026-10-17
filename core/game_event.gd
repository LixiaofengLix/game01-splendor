## 规则引擎 apply() 产生的事件：给日志、界面和联网同步用。
## 只带公开信息（例如盲抽预留不带 card_id，只有等级），所以可以原样发给任何一方。
##
## 各类型的 payload 字段（序列化时与 type/seat 平铺在同一个字典里）：
##   gems_taken              gems: {颜色名: 枚数}
##   card_reserved           card_id: "" 或卡牌 id（盲抽时为空）、level、blind、gold（拿到几枚金币，0/1）
##   card_purchased          card_id、level、points、paid: {颜色名: 枚数}、from_reserved
##   gems_discarded          color
##   noble_visited           noble_id
##   noble_choice_required   noble_ids: [贵族 id]
##   discard_required        count（需要弃掉几枚）
##   turn_started            turn_count（该玩家已经进行到第几个回合）
##   turn_ended              turn_count
##   player_skipped          无
##   endgame_triggered       points
##   game_finished           winners: [座位号]、reason（"win_points" / "stalled"）、scores: {座位号: 分数}
class_name GameEvent
extends RefCounted

var type: Enums.EventType = Enums.EventType.TURN_STARTED
var seat: int = -1
var payload: Dictionary = {}

func _init(p_type: Enums.EventType = Enums.EventType.TURN_STARTED, p_seat: int = -1,
		p_payload: Dictionary = {}) -> void:
	type = p_type
	seat = p_seat
	payload = p_payload

func to_dict() -> Dictionary:
	var result: Dictionary = {"type": Enums.event_type_to_string(type), "seat": seat}
	for key: String in payload:
		result[key] = payload[key]
	return result

func describe() -> String:
	match type:
		Enums.EventType.GEMS_TAKEN:
			return "座位 %d 拿宝石：%s" % [seat, _gem_text(payload.get("gems", {}))]
		Enums.EventType.CARD_RESERVED:
			var who: String = ""
			if bool(payload.get("blind", false)):
				who = "盲抽预留 %d 级牌堆顶" % int(payload.get("level", 0))
			else:
				who = "预留 %s" % payload.get("card_id", "")
			return "座位 %d %s%s" % [seat, who, _gold_text(int(payload.get("gold", 0)))]
		Enums.EventType.CARD_PURCHASED:
			return "座位 %d 购买 %s（%d 分，支付 %s）" % [seat, payload.get("card_id", ""),
					int(payload.get("points", 0)), _gem_text(payload.get("paid", {}))]
		Enums.EventType.GEMS_DISCARDED:
			return "座位 %d 弃掉 1 枚%s" % [seat, Enums.color_to_zh(Enums.color_from_string(String(payload.get("color", ""))))]
		Enums.EventType.NOBLE_VISITED:
			return "座位 %d 获得贵族 %s" % [seat, payload.get("noble_id", "")]
		Enums.EventType.NOBLE_CHOICE_REQUIRED:
			return "座位 %d 同时满足 %d 位贵族，请选择：%s" % [seat,
					(payload.get("noble_ids", []) as Array).size(), " ".join(payload.get("noble_ids", []))]
		Enums.EventType.DISCARD_REQUIRED:
			return "座位 %d 持币超过上限，还需弃掉 %d 枚" % [seat, int(payload.get("count", 0))]
		Enums.EventType.TURN_STARTED:
			return "轮到座位 %d（第 %d 回合）" % [seat, int(payload.get("turn_count", 0)) + 1]
		Enums.EventType.TURN_ENDED:
			return "座位 %d 回合结束（已进行 %d 个回合）" % [seat, int(payload.get("turn_count", 0))]
		Enums.EventType.PLAYER_SKIPPED:
			return "座位 %d 没有合法动作，跳过（也算一个回合）" % seat
		Enums.EventType.ENDGAME_TRIGGERED:
			return "座位 %d 达到 %d 分，触发终局：本轮打完（所有人回合数相同）后结算" % [seat,
					int(payload.get("points", 0))]
		Enums.EventType.GAME_FINISHED:
			return "对局结束（%s）：%s；比分 %s" % [payload.get("reason", ""), _winners_text(),
					_scores_text(payload.get("scores", {}))]
	return "事件 %s" % Enums.event_type_to_string(type)

func _winners_text() -> String:
	var seats: Array = payload.get("winners", [])
	var labels: Array[String] = []
	for value: Variant in seats:
		labels.append("座位 %d" % int(value))
	if labels.size() > 1:
		return "%s 并列获胜" % "、".join(labels)
	return "%s 获胜" % (labels[0] if not labels.is_empty() else "无")

func _gold_text(gold: int) -> String:
	if gold > 0:
		return "（附带 %d 枚金币）" % gold
	return ""

## 把 {颜色名: 枚数} 渲染成 "白1 蓝2"。
static func _gem_text(gems: Dictionary) -> String:
	if gems.is_empty():
		return "无"
	var parts: Array[String] = []
	for color_name: String in Enums.COLOR_NAMES:
		var amount: int = int(gems.get(color_name, 0))
		if amount > 0:
			parts.append("%s%d" % [Enums.color_to_zh(Enums.color_from_string(color_name)), amount])
	return " ".join(parts)

func _scores_text(scores: Dictionary) -> String:
	var parts: Array[String] = []
	for key: Variant in scores:
		parts.append("座位 %s %d 分" % [key, int(scores[key])])
	return "，".join(parts)
