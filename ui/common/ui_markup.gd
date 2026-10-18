## 日志 / 顶条文案的简写标记 → RichTextLabel 的 BBCode。
## 支持两种 token：{card:L2-R-01}（带浅色底的卡牌引用）和 {gem:red}（11px 彩色宝石）。
## 其余文字按 BBCode 转义后原样保留；卡牌 / 颜色查不到时保留原 token 文本。
class_name UiMarkup
extends RefCounted

const CARD_PREFIX := "card:"
const GEM_PREFIX := "gem:"
const ICON_SIZE := 11


static func to_bbcode(text: String, catalog: CardCatalog) -> String:
	var result: String = ""
	var index: int = 0
	while index < text.length():
		var open: int = text.find("{", index)
		if open < 0:
			result += _escape(text.substr(index))
			break
		result += _escape(text.substr(index, open - index))
		var close: int = text.find("}", open + 1)
		if close < 0:
			result += _escape(text.substr(open))
			break
		var token: String = text.substr(open + 1, close - open - 1)
		var replacement: String = _token_to_bbcode(token, catalog)
		if replacement.is_empty():
			result += _escape(text.substr(open, close - open + 1))
		else:
			result += replacement
		index = close + 1
	return result


static func _token_to_bbcode(token: String, catalog: CardCatalog) -> String:
	if token.begins_with(CARD_PREFIX):
		return _card_bbcode(token.substr(CARD_PREFIX.length()), catalog)
	if token.begins_with(GEM_PREFIX):
		return _gem_bbcode(token.substr(GEM_PREFIX.length()))
	return ""


static func _gem_bbcode(color_name: String) -> String:
	var color: int = Enums.color_from_string(color_name)
	if color < 0:
		return ""
	return "[img=%dx%d]%sgem_%s.png[/img]" % [
		ICON_SIZE, ICON_SIZE, UiAssets.DIR, Enums.color_to_letter(color),
	]


static func _card_bbcode(card_id: String, catalog: CardCatalog) -> String:
	var card: CardData = catalog.card(card_id) if catalog != null else null
	if card == null:
		return ""
	var tint: String = UiPalette.GEM_TINT[card.bonus].to_html(false)
	var level_name: String = ["", "一级", "二级", "三级"][clampi(card.level, 0, 3)]
	var inner: String = "%s %s%s" % [
		_gem_bbcode(Enums.color_to_string(card.bonus)),
		level_name,
		Enums.color_to_zh(card.bonus),
	]
	if card.points > 0:
		inner += " · %d 分" % card.points
	return "[bgcolor=#%s] %s [/bgcolor]" % [tint, inner]


static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")
