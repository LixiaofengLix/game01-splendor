## 规则速查：暂停菜单右栏和顶栏“规则”按钮共用的内容块。
## 所有数值从 RulesConfig 拼，界面里不写死。
class_name UiRulesPanel
extends VBoxContainer


func _init() -> void:
	add_theme_constant_override("separation", 6)


func setup(rules: RulesConfig) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var title := Label.new()
	title.name = "RulesTitle"
	title.text = "规则速查"
	title.add_theme_color_override("font_color", UiPalette.INK)
	add_child(title)
	for entry: Dictionary in lines(rules):
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 1)
		add_child(row)
		var heading := Label.new()
		heading.text = String(entry.get("title", ""))
		heading.add_theme_color_override("font_color", UiPalette.INK_2)
		row.add_child(heading)
		var body := Label.new()
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_theme_color_override("font_color", UiPalette.INK_3)
		body.text = String(entry.get("text", ""))
		row.add_child(body)


## [{title, text}]，测试也直接检查这份文案里的数值。
static func lines(rules: RulesConfig) -> Array[Dictionary]:
	if rules == null:
		return []
	return [
		{
			"title": "拿宝石",
			"text": "拿 3 种不同颜色各 1 枚；同一种颜色拿 2 枚时，银行里至少要有 %d 枚。金币不能主动拿。"
					% int(rules.take_two_min_remaining),
		},
		{
			"title": "预留",
			"text": "最多预留 %d 张。预留时若银行还有金币，额外拿 1 枚金币。" % int(rules.max_reserved),
		},
		{
			"title": "购买",
			"text": "购买发展卡可以提升折扣和分数。支付顺序：先用折扣，再用同色宝石，最后用金币补差。",
		},
		{
			"title": "回合末",
			"text": "回合结束时最多持有 %d 枚宝石（金币也算）。超出要弃回银行；同一回合最多请一位贵族。"
					% int(rules.max_tokens),
		},
		{
			"title": "终局",
			"text": "有人达到 %d 分后触发终局轮：其余每人再行动一回合，分数最高者获胜；同分时购买卡牌少者胜。"
					% int(rules.win_points),
		},
		{
			"title": "快捷键",
			"text": "1–5 选宝石 · Enter 确认 · R 预留 · Esc 取消 / 暂停 · L 查看完整日志",
		},
	]
