## 零件陈列：按样张“设计零件”一节，把每个零件的所有状态并排显示。
## 单独启动：godot --path . ui/dev/gallery.tscn（U9 前不影响主场景）。
extends Control

const SECTION_WIDTH := 1200
const MARGIN := 20

## 截图工具用：为 true 时不要滚动容器，整页按自然高度排版（配合放大的 SubViewport）。
var full_page := false

var _content: VBoxContainer


func _ready() -> void:
	_build_background()
	_build_page()


func _build_background() -> void:
	var background := UiAssets.tiled(UiAssets.texture("tile_paper.png"))
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	if full_page:
		var full_margin := MarginContainer.new()
		full_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		full_margin.add_theme_constant_override("margin_left", MARGIN)
		full_margin.add_theme_constant_override("margin_top", MARGIN)
		full_margin.add_theme_constant_override("margin_right", MARGIN)
		full_margin.add_theme_constant_override("margin_bottom", MARGIN)
		add_child(full_margin)
		_content = VBoxContainer.new()
		_content.custom_minimum_size.x = SECTION_WIDTH
		_content.add_theme_constant_override("separation", 24)
		full_margin.add_child(_content)
		return

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", MARGIN)
	margin.add_theme_constant_override("margin_top", MARGIN)
	margin.add_theme_constant_override("margin_right", MARGIN)
	margin.add_theme_constant_override("margin_bottom", MARGIN)
	center.add_child(margin)

	_content = VBoxContainer.new()
	_content.custom_minimum_size.x = SECTION_WIDTH
	_content.add_theme_constant_override("separation", 24)
	margin.add_child(_content)

	var title := Label.new()
	title.theme_type_variation = &"UiHero"
	title.text = "璀璨宝石 · 零件陈列"
	_content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "U1 · 按样张“设计零件”一节排版；所有状态并排，用来对照像素清晰度、颜色与字号。"
	subtitle.add_theme_color_override("font_color", UiPalette.INK_2)
	_content.add_child(subtitle)

	var rule := ColorRect.new()
	rule.color = UiPalette.LINE
	rule.custom_minimum_size.y = 2
	_content.add_child(rule)


func _build_page() -> void:
	_section_gems()
	_section_tiles()
	_section_cards()
	_section_deck_noble()
	_section_controls()
	_section_dialogs()


# ---------------------------------------------------------------- 分区

func _section(title: String, note: String) -> VBoxContainer:
	var frame := UiFrame.new()
	frame.frame_texture = UiAssets.frame_l("ink")
	frame.frame_border = 4
	frame.background_color = UiPalette.CARD
	frame.content_padding = Vector4i(20, 16, 20, 20)
	frame.shadow_enabled = true
	frame.shadow_offset = Vector2i(0, 4)
	frame.top_highlight = true
	frame.custom_minimum_size.x = SECTION_WIDTH
	_content.add_child(frame)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	frame.content.add_child(column)

	var heading := Label.new()
	heading.theme_type_variation = &"UiTitle"
	heading.text = title
	column.add_child(heading)

	var caption := Label.new()
	caption.text = note
	caption.add_theme_color_override("font_color", UiPalette.INK_3)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(caption)

	var body := VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 20)
	column.add_child(body)
	return body


func _row(body: Control, separation: int = 18) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", separation)
	body.add_child(row)
	return row


## 把一个零件和一个说明标签并排摆好；零件会立刻进入场景树，_ready 里设置的尺寸/内容才有效。
func _item(row: Control, node: Control, caption: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	row.add_child(box)

	var holder := CenterContainer.new()
	box.add_child(holder)
	holder.add_child(node)
	var minimum := node.get_combined_minimum_size()
	holder.custom_minimum_size = Vector2(maxf(minimum.x, 56), maxf(minimum.y, 28))

	var label := Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", UiPalette.INK_3)
	box.add_child(label)
	return box


func _caption(text: String, color: Color = UiPalette.INK_3) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	return label


func _make_chip(color: Enums.GemColor, count: int, key: StringName = &"lg", selected: int = 0,
		discard: int = 0, bare: bool = false) -> UiGemChip:
	var chip := UiGemChip.new()
	chip.gem_color = color
	chip.count = count
	chip.size_key = key
	chip.selected_amount = selected
	chip.discard_amount = discard
	chip.bare = bare
	return chip


func _make_card(card_id: String, mini: bool = false) -> UiDevCard:
	var card := UiDevCard.new()
	card.catalog = DataRegistry.card_catalog()
	card.card_id = card_id
	card.mini = mini
	return card


func _make_noble(noble_id: String, big: bool = false) -> UiNobleTile:
	var noble := UiNobleTile.new()
	noble.catalog = DataRegistry.card_catalog()
	noble.noble_id = noble_id
	noble.big = big
	return noble


# ---------------------------------------------------------------- 宝石与筹码

func _section_gems() -> void:
	var body := _section("宝石：颜色 + 形状",
			"每种颜色一个专属形状（白◇ 蓝● 绿▮ 红♥ 黑■ 金★）；筹码、折扣、花费、日志里都带着它，红绿色盲也能分。")

	var row := _row(body)
	for color: Enums.GemColor in Enums.ALL_COLORS:
		_item(row, UiAssets.gem_icon(color, 24), Enums.color_to_zh(color))

	var coins := _row(body)
	var bank := [2, 2, 3, 1, 4, 3]
	for index in Enums.ALL_COLORS.size():
		var color: Enums.GemColor = Enums.ALL_COLORS[index]
		_item(coins, _make_chip(color, bank[index]), "%s %d 枚" % [Enums.color_to_zh(color), bank[index]])

	var states := _row(body)
	_item(states, _make_chip(Enums.GemColor.BLUE, 2, &"lg", 1), "已选 +1")
	_item(states, _make_chip(Enums.GemColor.RED, 0), "没了（空心）")
	_item(states, _make_chip(Enums.GemColor.BLACK, 2, &"lg", 0, 2), "待弃 −2")
	_item(states, _make_chip(Enums.GemColor.GREEN, 1, &"sm", 0, 0, true), "无数字（托盘）")
	_item(states, _make_chip(Enums.GemColor.WHITE, 3, &"md"), "持有（中）")
	_item(states, _make_chip(Enums.GemColor.GOLD, 1, &"sm"), "对手（小）")

	var sizes := _row(body)
	for key: StringName in [&"lg", &"md", &"sm", &"xs"]:
		_item(sizes, _make_chip(Enums.GemColor.GREEN, 2, key), String(key))


# ---------------------------------------------------------------- 折扣与花费

func _section_tiles() -> void:
	var body := _section("折扣块 · 花费药丸",
			"方块 = 已购卡的折扣；圆 = 宝石。数量为 0 改成 CARD 底 + 空心描边，不再只降透明度。")

	var bonuses := _row(body)
	var counts := [2, 2, 1, 0, 1]
	for index in Enums.PURCHASABLE_COLORS.size():
		var color: Enums.GemColor = Enums.PURCHASABLE_COLORS[index]
		var tile := UiBonusTile.new()
		tile.gem_color = color
		tile.count = counts[index]
		tile.size_key = &"md"
		_item(bonuses, tile, "%s折扣 %d" % [Enums.color_to_zh(color), counts[index]])

	var sizes := _row(body)
	for key: StringName in [&"noble", &"opp", &"base", &"big", &"md"]:
		var tile := UiBonusTile.new()
		tile.gem_color = Enums.GemColor.RED
		tile.count = 2
		tile.size_key = key
		_item(sizes, tile, String(key))

	var pills := _row(body)
	var pill_data := [
		[Enums.GemColor.WHITE, 1], [Enums.GemColor.BLUE, 2],
		[Enums.GemColor.GREEN, 3], [Enums.GemColor.BLACK, 4],
	]
	for entry: Array in pill_data:
		var pill := UiCostPill.new()
		pill.gem_color = entry[0]
		pill.amount = entry[1]
		_item(pills, pill, "%s %d" % [Enums.color_to_zh(entry[0]), entry[1]])
	var mini_pill := UiCostPill.new()
	mini_pill.gem_color = Enums.GemColor.RED
	mini_pill.amount = 2
	mini_pill.mini = true
	_item(pills, mini_pill, "迷你")


# ---------------------------------------------------------------- 发展卡

func _section_cards() -> void:
	var body := _section("发展卡",
			"顶部整条实色色带 + 形状 = 加成颜色；分数用像素数字；花费在左下竖排；右下是状态（可买 / 差 N），右上头像表示哪个对手现在就买得起。")

	var top_gap := Control.new()
	top_gap.custom_minimum_size.y = 30
	body.add_child(top_gap)

	var market := _row(body, 40)
	_item(market, _make_card("L2-G-04"), "普通")
	var affordable := _make_card("L1-R-04")
	affordable.affordable = true
	_item(market, affordable, "可买")
	var short := _make_card("L2-K-03")
	short.shortfall = 1
	short.missing = [{"color": Enums.GemColor.WHITE, "amount": 2}]
	short.gold_can_pay = 1
	short.force_need = true
	_item(market, short, "差 1（缺口条）")
	var short_tag := _make_card("L3-K-01")
	short_tag.shortfall = 3
	_item(market, short_tag, "差 3（状态标签）")
	var selected := _make_card("L3-W-04")
	selected.selected = true
	_item(market, selected, "选中")
	var threat := _make_card("L2-K-03")
	threat.threat_seats = [1, 2]
	_item(market, threat, "对手能买")
	var flash := _make_card("L2-R-01")
	flash.flash = true
	_item(market, flash, "刚被拿走（光晕）")

	var mini := _row(body, 40)
	_item(mini, _make_card("L2-K-04", true), "迷你")
	var mini_selected := _make_card("L1-G-08", true)
	mini_selected.selected = true
	_item(mini, mini_selected, "迷你选中")
	var blind := _make_card("L3-U-02", true)
	blind.blind_label = true
	_item(mini, blind, "我的盲抽")
	var back := _make_card("", true)
	back.card_back = true
	back.back_level = 3
	_item(mini, back, "别人的盲抽")
	var empty_mini := _make_card("", true)
	empty_mini.empty = true
	_item(mini, empty_mini, "空位（迷你）")

	var extras := _row(body, 40)
	var back_big := _make_card("")
	back_big.card_back = true
	back_big.back_level = 2
	_item(extras, back_big, "牌背")
	_item(extras, _make_card(""), "空位")
	var with_id := _make_card("L2-U-03")
	with_id.show_id = true
	_item(extras, with_id, "显示卡牌 id")
	var refs := VBoxContainer.new()
	refs.add_theme_constant_override("separation", 6)
	refs.alignment = BoxContainer.ALIGNMENT_CENTER
	for card_id: String in ["L3-R-04", "L2-U-03", "L1-G-08"]:
		var ref := UiCardRef.new()
		ref.catalog = DataRegistry.card_catalog()
		ref.card_id = card_id
		refs.add_child(ref)
	_item(extras, refs, "卡牌引用")


# ---------------------------------------------------------------- 牌堆与贵族

func _section_deck_noble() -> void:
	var body := _section("牌堆 · 贵族",
			"牌堆是斜纹深色厚卡 + 金色罗马数字；贵族是金边奶油色方牌、金色徽章写分数，和发展卡明显不是一类东西。")

	var decks := _row(body, 30)
	for level in [1, 2, 3]:
		var deck := UiDeckPile.new()
		deck.level = level
		deck.remaining = [23, 20, 14][level - 1]
		_item(decks, deck, "%s级牌堆" % ["一", "二", "三"][level - 1])
	var deck_empty := UiDeckPile.new()
	deck_empty.level = 3
	deck_empty.remaining = 0
	_item(decks, deck_empty, "已空")
	var deck_selected := UiDeckPile.new()
	deck_selected.level = 2
	deck_selected.remaining = 10
	deck_selected.selected = true
	_item(decks, deck_selected, "选中")

	var nobles := _row(body, 30)
	_item(nobles, _make_noble("N-01"), "市场")
	var noble_selected := _make_noble("N-06")
	noble_selected.selected = true
	_item(nobles, noble_selected, "选中")
	_item(nobles, _make_noble("N-03"), "市场")
	_item(nobles, _make_noble("N-09", true), "大号（选贵族）")


# ---------------------------------------------------------------- 通用控件

func _section_controls() -> void:
	var body := _section("通用控件",
			"按钮 5 种变体 × sm / 默认 / lg × 正常 / 悬停 / 按下 / 禁用；菜单大按钮、分段、开关、输入框、标签、键帽、进度条、转圈、列表行。")

	for size_key: StringName in [&"sm", &"default", &"lg"]:
		body.add_child(_caption("按钮尺寸：%s" % String(size_key), UiPalette.INK_2))
		_button_grid(body, size_key)

	body.add_child(_caption("菜单大按钮", UiPalette.INK_2))
	var menus := _row(body, 16)
	var menu_defs := [
		[&"accent", "继续上一局", "3 人 · 第 9 轮 · 10 分钟前"],
		[&"dark", "本地游戏", "同屏轮流，空座位交给电脑"],
		[&"ghost", "联网游戏", "建房或输入 IP 加入"],
	]
	for entry: Array in menu_defs:
		var menu := UiMenuButton.new()
		menu.variant = entry[0]
		menu.title = entry[1]
		menu.subtitle = entry[2]
		_item(menus, menu, String(entry[0]))

	body.add_child(_caption("分段 · 开关 · 输入框", UiPalette.INK_2))
	var misc := _row(body, 28)
	var segment := UiSegmented.new()
	segment.items = ["标准", "快速", "慢速"]
	segment.selected_index = 1
	_item(misc, segment, "分段（选中第 2 项）")
	var disabled_segment := UiSegmented.new()
	disabled_segment.items = ["简单", "普通", "困难"]
	disabled_segment.disabled_indices = [2]
	_item(misc, disabled_segment, "分段（第 3 项禁用）")
	var switches := VBoxContainer.new()
	switches.add_theme_constant_override("separation", 10)
	var off := UiSwitch.new()
	switches.add_child(off)
	var on := UiSwitch.new()
	switches.add_child(on)
	_item(misc, switches, "开关（关 / 开）")
	on.set_on(true)
	var input_column := VBoxContainer.new()
	input_column.add_theme_constant_override("separation", 10)
	input_column.custom_minimum_size.x = 220
	var placeholder := UiInput.new()
	placeholder.placeholder_text = "留空就随机"
	input_column.add_child(placeholder)
	var filled := UiInput.new()
	filled.text = "小明"
	input_column.add_child(filled)
	_item(misc, input_column, "输入框")

	body.add_child(_caption("标签 · 键帽 · 进度条 · 转圈", UiPalette.INK_2))
	var small := _row(body, 20)
	var tags := HBoxContainer.new()
	tags.add_theme_constant_override("separation", 6)
	var tag_defs := [[&"default", "默认"], [&"dark", "你"], [&"mint", "已连接"], [&"orange", "思考中"], [&"purple", "大模型"], [&"red", "离线"]]
	for entry: Array in tag_defs:
		var tag := UiTag.new()
		tag.text = entry[1]
		tag.variant = entry[0]
		tags.add_child(tag)
	_item(small, tags, "标签 6 种配色")
	var keys := HBoxContainer.new()
	keys.add_theme_constant_override("separation", 6)
	for key_text: String in ["Enter", "Esc", "L"]:
		var kbd := UiKbd.new()
		kbd.text = key_text
		keys.add_child(kbd)
	_item(small, keys, "键帽")
	var bars := VBoxContainer.new()
	bars.add_theme_constant_override("separation", 10)
	bars.custom_minimum_size.x = 240
	var bar := UiProgressBar.new()
	bar.ratio = 0.35
	bar.fill_color = Color("#bdb3a2")
	bars.add_child(bar)
	var hot_bar := UiProgressBar.new()
	hot_bar.ratio = 0.82
	bars.add_child(hot_bar)
	_item(small, bars, "进度条（普通 / 高）")
	_item(small, UiSpinner.new(), "转圈")

	body.add_child(_caption("列表行", UiPalette.INK_2))
	var list_row_wrap := _row(body, 20)
	var rows := VBoxContainer.new()
	rows.custom_minimum_size.x = 520
	rows.add_theme_constant_override("separation", 4)
	var row_normal := UiListRow.new()
	row_normal.title = "自动存档"
	row_normal.subtitle = "每回合结束覆盖；快速存档另存一份"
	row_normal.meta = "3 分钟前"
	rows.add_child(row_normal)
	var row_selected := UiListRow.new()
	row_selected.title = "本地对局 · 3 人"
	row_selected.subtitle = "小明 · 薄荷 · 紫晶"
	row_selected.meta = "第 9 轮"
	row_selected.selected = true
	rows.add_child(row_selected)
	rows.add_child(_caption("选中行：2px INK 外框 + #fff6df 底"))
	_item(list_row_wrap, rows, "列表行（普通 / 选中）")


func _button_grid(body: Control, size_key: StringName) -> void:
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	body.add_child(grid)
	for heading: String in ["", "正常", "悬停", "按下", "禁用"]:
		grid.add_child(_caption(heading))
	var variants := [
		[&"accent", "主按钮"], [&"dark", "深色"], [&"ghost", "浅色"],
		[&"quiet", "次按钮"], [&"danger", "危险"],
	]
	for entry: Array in variants:
		grid.add_child(_caption(entry[1]))
		for state: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
			var button := UiButton.new()
			button.variant = entry[0]
			button.size_key = size_key
			button.preview_state = state
			button.text = "按钮"
			grid.add_child(button)


# ---------------------------------------------------------------- 弹窗、toast、提示卡

func _section_dialogs() -> void:
	var body := _section("弹窗 · toast · 提示卡",
			"弹窗大框 + 向下 6px 硬投影；toast 只用于“我刚做的事成功了”，2.5 秒后消失；提示卡是持续状态，状态结束才移除。")

	var row := _row(body, 30)

	var modal := UiModalFrame.new()
	modal.preferred_width = 560
	modal.title = "弃宝石"
	_item(row, modal, "弹窗 · 弃宝石 560")
	modal.set_tag("还需要弃 2 枚", &"orange")
	var modal_text := Label.new()
	modal_text.text = "手里 12 枚，上限 10 枚。点筹码选择要弃掉的数量，选够 2 枚才能确认。"
	modal_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_text.custom_minimum_size.x = 500
	modal.body().add_child(modal_text)
	var chip_row := HBoxContainer.new()
	chip_row.add_theme_constant_override("separation", 10)
	for color: Enums.GemColor in Enums.ALL_COLORS:
		var chip := _make_chip(color, 1, &"md", 0, 0)
		chip_row.add_child(chip)
	modal.body().add_child(chip_row)
	var cancel := UiButton.new()
	cancel.variant = &"quiet"
	cancel.text = "取消"
	modal.add_action(cancel)
	var confirm := UiButton.new()
	confirm.variant = &"accent"
	confirm.text = "确认弃掉"
	modal.add_action(confirm)

	var error_modal := UiModalFrame.new()
	error_modal.preferred_width = 420
	error_modal.title = "数据加载失败"
	_item(row, error_modal, "异常弹窗 420")
	var error_text := Label.new()
	error_text.text = "data/cards.json：L2-U-03 的花费颜色拼写错误。\n请修正数据文件后重新启动。"
	error_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_text.custom_minimum_size.x = 360
	error_modal.body().add_child(error_text)
	var quit_button := UiButton.new()
	quit_button.variant = &"danger"
	quit_button.text = "退出"
	error_modal.add_action(quit_button)

	var notice_row := _row(body, 30)
	var notices := VBoxContainer.new()
	notices.add_theme_constant_override("separation", 12)
	var toast := UiToast.new()
	toast.auto_hide = false
	notices.add_child(toast)
	var notice := UiNoticeCard.new()
	notices.add_child(notice)
	_item(notice_row, notices, "toast / 提示卡")
	toast.show_message(0, "已保存", "存档写到 user://saves/quick.json")
	notice.set_content(2, "薄荷掉线了", "电脑先替它打，重连后恢复")

	var footer := Label.new()
	footer.text = "截图：godot --path . ui/dev/capture.tscn -- --out /tmp/splendor_ui/gallery.png --width 1280 --height 800 --scale fractional"
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_theme_color_override("font_color", UiPalette.INK_3)
	body.add_child(footer)


## 整页截图时需要的逻辑高度。
func page_height() -> float:
	if _content == null:
		return 0.0
	return _content.get_combined_minimum_size().y + MARGIN * 2


## 窗口截图时滚到指定位置。
func scroll_to(offset: int) -> void:
	var scroll := get_node_or_null("Scroll") as ScrollContainer
	if scroll != null:
		scroll.scroll_vertical = offset
