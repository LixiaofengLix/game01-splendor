## 把 GameEvent.to_dict() 转成日志 / 顶条用的中文文案。
## 卡牌用 {card:id}、宝石用 {gem:color} 标记，渲染时由 UiMarkup 换成 BBCode。
## 只使用事件里的公开字段：盲抽预留不带卡牌 id，这里也不会去查。
class_name UiEventText
extends RefCounted

const LEVEL_ZH: Array[String] = ["", "一", "二", "三"]


static func name_of(seat: int, names: Array) -> String:
	if seat >= 0 and seat < names.size():
		var value: String = String(names[seat])
		if not value.is_empty():
			return value
	return "座位 %d" % (seat + 1)


static func level_zh(level: int) -> String:
	return LEVEL_ZH[clampi(level, 0, 3)] + "级"


## 事件的中文描述；不需要写进日志的事件（换人、提示阶段）返回空字符串。
static func text_for(event: Dictionary, catalog: CardCatalog, names: Array) -> String:
	var type: String = String(event.get("type", ""))
	var seat: int = int(event.get("seat", -1))
	var who: String = name_of(seat, names)
	match type:
		"gems_taken":
			return "%s 拿了 %s" % [who, _gems_text(event.get("gems", {}))]
		"card_reserved":
			var gold: int = int(event.get("gold", 0))
			var gold_text: String = "，拿到 1 枚 {gem:gold}" if gold > 0 else "（没有金币了）"
			if bool(event.get("blind", false)):
				return "%s 盲抽预留了%s牌堆顶%s" % [
					who, level_zh(int(event.get("level", 1))), gold_text,
				]
			return "%s 预留了 {card:%s}%s" % [who, String(event.get("card_id", "")), gold_text]
		"card_purchased":
			var paid: String = _paid_text(event.get("paid", {}))
			var suffix: String = "，付 %s" % paid if not paid.is_empty() else ""
			return "%s 购买 {card:%s}%s" % [who, String(event.get("card_id", "")), suffix]
		"gems_discarded":
			var color: String = String(event.get("color", ""))
			return "%s 弃回 {gem:%s}" % [who, color]
		"noble_visited":
			var noble: NobleData = null
			if catalog != null:
				noble = catalog.noble(String(event.get("noble_id", "")))
			if noble == null:
				return "%s 获得一位贵族（+3 分）" % who
			return "贵族（%s）来拜访%s（+%d 分）" % [
				noble_requirement_text(noble), who, noble.points,
			]
		"endgame_triggered":
			return "%s 到 %d 分了！触发终局" % [who, int(event.get("points", 0))]
		"player_skipped":
			return "%s 没有可以做的动作，跳过这一回合" % who
		"game_finished":
			return "对局结束"
	return ""


## 贵族要求文案：“白 4 蓝 4”。
static func noble_requirement_text(noble: NobleData) -> String:
	var parts: Array[String] = []
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		var amount: int = noble.requirement_of(color)
		if amount > 0:
			parts.append("%s %d" % [Enums.color_to_zh(color), amount])
	return " ".join(parts)


## 弃宝石日志合并用：同一批弃掉的多个颜色。
static func discard_colors_text(colors: Array) -> String:
	var parts: Array[String] = []
	for color: Variant in colors:
		parts.append("{gem:%s}" % String(color))
	return " ".join(parts)


static func _gems_text(gems: Dictionary) -> String:
	var colors: Array[String] = []
	var total: int = 0
	for color_name: String in Enums.COLOR_NAMES:
		var amount: int = int(gems.get(color_name, 0))
		if amount <= 0:
			continue
		colors.append(color_name)
		total += amount
	if colors.size() == 1 and total == 2:
		return "2 枚 {gem:%s}" % colors[0]
	if colors.size() == 1:
		return "1 枚 {gem:%s}" % colors[0]
	var tokens: Array[String] = []
	for color_name: String in colors:
		tokens.append("{gem:%s}" % color_name)
	return "%s 各 1 枚" % "".join(tokens)


static func _paid_text(paid: Dictionary) -> String:
	var parts: Array[String] = []
	for color_name: String in Enums.COLOR_NAMES:
		var amount: int = int(paid.get(color_name, 0))
		if amount > 0:
			parts.append("{gem:%s}×%d" % [color_name, amount])
	return " ".join(parts)
