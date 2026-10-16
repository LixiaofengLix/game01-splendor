## 阶段 1 的数据层自检：
## 1) 加载 data/ 并校验，有问题就逐条打印并以退出码 1 结束（故意改坏 JSON 时能看到明确报错）；
## 2) 打印统计：每级 / 每色张数、分数分布、贵族要求；
## 3) 按「等级 + 颜色」排序生成 docs/CARD_LIST.md，供对照实体卡人工核对。
## 用法：godot --headless --path . tests/data_report.tscn
extends Node

const OUTPUT_PATH: String = "res://docs/CARD_LIST.md"

func _ready() -> void:
	if not DataRegistry.is_valid():
		print("数据校验失败，共 %d 个问题：" % DataRegistry.get_errors().size())
		for error_message: String in DataRegistry.get_errors():
			print("  x %s" % error_message)
		get_tree().quit(1)
		return

	_print_stats()
	var written: bool = _write_card_list()
	print("")
	print("OK - 数据校验通过，卡表已写入 %s" % OUTPUT_PATH if written else "OK - 数据校验通过（卡表未写入）")
	get_tree().quit(0)

func _print_stats() -> void:
	var rules: RulesConfig = DataRegistry.rules()
	print("=== 璀璨宝石 数据统计 ===")
	print("规则：2/3/4 人每色宝石 %d/%d/%d，金币 %d，胜利分 %d，持币上限 %d，预留上限 %d，每级场面 %d 张"
			% [rules.gems_per_color_for(2), rules.gems_per_color_for(3), rules.gems_per_color_for(4),
			rules.gold_count, rules.win_points, rules.max_tokens, rules.max_reserved,
			rules.board_slots_per_level])
	print("")
	print("发展卡：%d 张" % DataRegistry.all_cards().size())
	for level: int in [1, 2, 3]:
		var cards: Array[CardData] = DataRegistry.cards_in_level(level)
		var per_color: Array[String] = []
		var point_histogram: Dictionary = {}
		for card: CardData in cards:
			point_histogram[card.points] = point_histogram.get(card.points, 0) + 1
		for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
			var count: int = 0
			for card: CardData in cards:
				if card.bonus == color:
					count += 1
			per_color.append("%s%d" % [Enums.color_to_zh(color), count])
		var points_desc: Array[String] = []
		var point_values: Array = point_histogram.keys()
		point_values.sort()
		for points: int in point_values:
			points_desc.append("%d分 %d张" % [points, point_histogram[points]])
		print("  %d 级：%d 张（%s）；%s"
				% [level, cards.size(), " ".join(per_color), " / ".join(points_desc)])
	print("")
	print("贵族：%d 位" % DataRegistry.all_nobles().size())
	for noble: NobleData in DataRegistry.all_nobles():
		print("  %s" % noble.describe())

func _write_card_list() -> bool:
	var lines: PackedStringArray = []
	lines.append("# 发展卡卡表（按等级 + 颜色排序）")
	lines.append("")
	lines.append("> 由 `tests/data_report.tscn` 生成，请勿手工编辑；改完 `data/cards.json` 重跑即可。")
	lines.append("> 颜色简写：W=白 U=蓝 G=绿 R=红 K=黑。单元格是该颜色的花费枚数，`·` 表示 0。")
	lines.append("")
	lines.append("## 发展卡")
	lines.append("")
	for level: int in [1, 2, 3]:
		var cards: Array[CardData] = DataRegistry.cards_in_level(level)
		cards.sort_custom(_compare_cards)
		lines.append("### %d 级（%d 张）" % [level, cards.size()])
		lines.append("")
		lines.append("| id | 加成 | 分 | 白 W | 蓝 U | 绿 G | 红 R | 黑 K | 合计 |")
		lines.append("|---|---|---|---|---|---|---|---|---|")
		for card: CardData in cards:
			lines.append("| %s | %s | %d | %s | %d |"
					% [card.id, Enums.color_to_zh(card.bonus), card.points,
					" | ".join(_cost_cells(card)), card.total_cost()])
		lines.append("")
	lines.append("## 贵族")
	lines.append("")
	lines.append("| id | 分 | 白 W | 蓝 U | 绿 G | 红 R | 黑 K |")
	lines.append("|---|---|---|---|---|---|---|")
	for noble: NobleData in DataRegistry.all_nobles():
		var cells: Array[String] = []
		for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
			var amount: int = noble.requirement_of(color)
			cells.append(str(amount) if amount > 0 else "·")
		lines.append("| %s | %d | %s |" % [noble.id, noble.points, " | ".join(cells)])
	lines.append("")

	var file: FileAccess = FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("写不了 %s：%s" % [OUTPUT_PATH, error_string(FileAccess.get_open_error())])
		return false
	file.store_string("\n".join(lines))
	file.close()
	return true

func _cost_cells(card: CardData) -> Array[String]:
	var cells: Array[String] = []
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		var amount: int = card.cost_of(color)
		cells.append(str(amount) if amount > 0 else "·")
	return cells

## 等级 -> 颜色 -> id。
func _compare_cards(a: CardData, b: CardData) -> bool:
	if a.level != b.level:
		return a.level < b.level
	if a.bonus != b.bonus:
		return a.bonus < b.bonus
	return a.id < b.id
