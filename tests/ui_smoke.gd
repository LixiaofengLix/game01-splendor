## 正式 UI 的冒烟测试。U0 起检查主题、字体、像素贴图、入口结构与快捷键；
## 后续阶段继续扩充渲染、交互与流程检查。退出码 0 = 全部通过。
## 运行：/Applications/Godot.app/Contents/MacOS/Godot --headless --path . tests/ui_smoke.tscn
extends Node

const THEME_PATH := "res://ui/theme/pixel_theme.tres"
const APP_PATH := "res://ui/app/app.tscn"
const BODY_FONT := "res://ui/theme/fonts/fusion_pixel_12px_proportional_zh_hans.ttf"
const NUM_FONT := "res://ui/theme/fonts/press_start_2p.ttf"
const PIXEL_DIR := "res://ui/assets/pixel/"

var _checks := 0
var _failures := 0


func _ready() -> void:
	_check_theme()
	_check_text_variants()
	_check_styleboxes()
	_check_assets()
	_check_component_files()
	await _check_components()
	await _check_gallery()
	await _check_app()
	if _failures == 0:
		print("ui_smoke：%d 项全部通过。" % _checks)
		get_tree().quit(0)
	else:
		printerr("ui_smoke：%d / %d 项失败。" % [_failures, _checks])
		get_tree().quit(1)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("失败：" + label)


func _check_theme() -> void:
	var theme: Theme = load(THEME_PATH)
	_check(theme != null, "主题可以加载")
	if theme == null:
		return
	_check(theme.default_font != null and theme.default_font.resource_path == BODY_FONT, "默认字体是 Fusion Pixel")
	_check(theme.default_font_size == 12, "默认字号 12")


func _check_text_variants() -> void:
	var theme: Theme = load(THEME_PATH)
	if theme == null:
		return
	var expected := {
		"UiSmall": [BODY_FONT, 12],
		"UiTitle": [BODY_FONT, 24],
		"UiHero": [BODY_FONT, 48],
		"UiNumSmall": [NUM_FONT, 8],
		"UiNumMid": [NUM_FONT, 12],
		"UiNum": [NUM_FONT, 16],
		"UiNumBig": [NUM_FONT, 32],
	}
	for type_name: String in expected:
		var font: Font = theme.get_font("font", type_name)
		_check(font != null and font.resource_path == expected[type_name][0], "%s 字体" % type_name)
		_check(theme.get_font_size("font_size", type_name) == expected[type_name][1], "%s 字号" % type_name)
		_check(theme.get_type_variation_base(type_name) == "Label", "%s 基类型 Label" % type_name)


func _check_styleboxes() -> void:
	var theme: Theme = load(THEME_PATH)
	if theme == null:
		return
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		_check(theme.get_stylebox(state, "Button") != null, "Button %s 样式" % state)
	for type_name: String in ["UiButtonAccent", "UiButtonDark", "UiButtonGhost", "UiButtonQuiet", "UiButtonDanger"]:
		_check(theme.get_stylebox("normal", type_name) is StyleBoxTexture, "%s normal 是 StyleBoxTexture" % type_name)
		_check(theme.get_stylebox("focus", type_name) is StyleBoxFlat, "%s focus 是 StyleBoxFlat" % type_name)
		_check(theme.get_type_variation_base(type_name) == "Button", "%s 基类型 Button" % type_name)
	_check(theme.get_stylebox("panel", "PanelContainer") is StyleBoxTexture, "面板样式")
	for type_name: String in ["UiTag", "UiTagDark", "UiTagMint", "UiTagOrange", "UiTagPurple", "UiTagRed"]:
		_check(theme.get_stylebox("panel", type_name) is StyleBoxTexture, "%s 样式" % type_name)


func _check_assets() -> void:
	var sizes := {
		"frame_s_ink.png": Vector2i(6, 6),
		"frame_s_ink_fill.png": Vector2i(6, 6),
		"frame_s_dark.png": Vector2i(6, 6),
		"frame_l_ink.png": Vector2i(10, 10),
		"frame_l_hot.png": Vector2i(10, 10),
		"coin_W.png": Vector2i(12, 12),
		"coin_X_empty.png": Vector2i(12, 12),
		"gem_U.png": Vector2i(12, 12),
		"gem_K_mono.png": Vector2i(12, 12),
		"mascot_1.png": Vector2i(16, 16),
		"mascot_sleepy.png": Vector2i(16, 16),
		"tile_paper.png": Vector2i(4, 4),
		"tile_wood.png": Vector2i(48, 48),
		"tile_card_back.png": Vector2i(10, 10),
	}
	for file_name: String in sizes:
		var texture: Texture2D = load(PIXEL_DIR + file_name)
		_check(texture != null, "%s 可以加载" % file_name)
		if texture != null:
			_check(texture.get_size() == Vector2(sizes[file_name]), "%s 尺寸" % file_name)


func _check_component_files() -> void:
	var dir := DirAccess.open("res://ui/components")
	_check(dir != null, "零件目录可以打开")
	if dir == null:
		return
	var count := 0
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".gd"):
			count += 1
			var text := FileAccess.get_file_as_string("res://ui/components/" + entry)
			_check(text.contains("class_name Ui"), "%s 使用 Ui 前缀类名" % entry)
			_check(not text.contains("GameState"), "%s 不直接引用 GameState" % entry)
			_check(not text.contains("._state"), "%s 不读 GameState 内部字段" % entry)
		entry = dir.get_next()
	dir.list_dir_end()
	_check(count >= 20, "零件脚本数量不少于 20（实际 %d）" % count)


func _check_components() -> void:
	await get_tree().process_frame
	var host := Control.new()
	host.name = "UiComponentTestHost"
	host.theme = load(THEME_PATH)
	host.size = Vector2(1280, 900)
	get_tree().root.add_child(host)
	await get_tree().process_frame

	# ---------------------------------------------------------------- 筹码
	var chip := UiGemChip.new()
	chip.gem_color = Enums.GemColor.BLUE
	chip.count = 2
	chip.size_key = &"lg"
	host.add_child(chip)
	_check(chip.custom_minimum_size == Vector2(48, 48), "筹码 lg 尺寸 48")
	var chip_number := chip.find_child("Number", true, false) as Label
	_check(chip_number != null and chip_number.text == "2", "筹码显示数字")
	var coin := chip.find_child("Coin", true, false) as TextureRect
	_check(coin != null and coin.texture != null
			and coin.texture.resource_path.ends_with("coin_U.png"), "筹码使用满币贴图")
	chip.selected_amount = 1
	var badge := chip.find_child("Badge", true, false) as Control
	_check(badge != null and badge.visible, "已选筹码显示 +N 角标")
	chip.selected_amount = 0
	chip.discard_amount = 2
	_check(badge != null and badge.visible, "待弃筹码显示 −N 角标")
	chip.discard_amount = 0
	chip.count = 0
	_check(coin != null and coin.texture != null
			and coin.texture.resource_path.ends_with("coin_U_empty.png"), "0 枚筹码使用空心贴图")
	var bare_chip := UiGemChip.new()
	bare_chip.gem_color = Enums.GemColor.GREEN
	bare_chip.count = 1
	bare_chip.size_key = &"sm"
	bare_chip.bare = true
	host.add_child(bare_chip)
	var bare_number := bare_chip.find_child("Number", true, false) as Label
	var bare_icon := bare_chip.find_child("Icon", true, false) as TextureRect
	_check(bare_number != null and not bare_number.visible, "bare 筹码隐藏数字")
	_check(bare_icon != null and bare_icon.visible and bare_icon.size == Vector2(12, 12), "bare 筹码显示 12px 形状")

	# ---------------------------------------------------------------- 折扣块 / 花费
	var tile_sizes := {
		&"noble": Vector2(24, 30),
		&"opp": Vector2(30, 27),
		&"base": Vector2(28, 32),
		&"big": Vector2(42, 50),
		&"md": Vector2(44, 48),
	}
	for key: StringName in tile_sizes:
		var tile := UiBonusTile.new()
		tile.gem_color = Enums.GemColor.RED
		tile.count = 2
		tile.size_key = key
		host.add_child(tile)
		_check(tile.custom_minimum_size == tile_sizes[key], "折扣块尺寸 %s" % key)
		var tile_number := tile.find_child("Number", true, false) as Label
		_check(tile_number != null and tile_number.text == "2", "折扣块数字 %s" % key)
		host.remove_child(tile)
		tile.queue_free()

	var pill := UiCostPill.new()
	pill.gem_color = Enums.GemColor.WHITE
	pill.amount = 3
	host.add_child(pill)
	_check(pill.custom_minimum_size == Vector2(34, 20), "花费药丸尺寸")
	var pill_amount := pill.find_child("Amount", true, false) as Label
	_check(pill_amount != null and pill_amount.text == "3", "花费药丸数字")
	var mini_pill := UiCostPill.new()
	mini_pill.gem_color = Enums.GemColor.BLACK
	mini_pill.amount = 2
	mini_pill.mini = true
	host.add_child(mini_pill)
	_check(mini_pill.custom_minimum_size == Vector2(30, 17), "迷你花费药丸尺寸")

	# ---------------------------------------------------------------- 发展卡
	var catalog := DataRegistry.card_catalog()
	var card := UiDevCard.new()
	card.catalog = catalog
	card.card_id = "L2-K-03"
	host.add_child(card)
	_check(card.custom_minimum_size == Vector2(128, 150), "市场卡尺寸 128×150")
	var points := card.find_child("Points", true, false) as Label
	_check(points != null and points.text == "2", "卡牌点数")
	var costs := card.find_child("Costs", true, false) as VBoxContainer
	_check(costs != null and costs.get_child_count() == 1, "卡牌花费只列非零项")
	card.affordable = true
	var status := card.find_child("Status", true, false) as Control
	var status_label := card.find_child("StatusLabel", true, false) as Label
	_check(status != null and status.visible and status_label.text == "可买", "可买状态")
	card.affordable = false
	card.shortfall = 1
	card.missing = [{"color": Enums.GemColor.WHITE, "amount": 2}]
	card.gold_can_pay = 1
	card.force_need = true
	var need_bar := card.find_child("NeedBar", true, false) as Control
	_check(need_bar != null and need_bar.visible, "缺口条显示")
	if need_bar != null:
		var need_row := need_bar.get_child(0) as HBoxContainer
		_check(need_row != null and need_row.get_child_count() == 3,
				"缺口条包含还差 / 花费 / 金币说明")
	card.selected = true
	var content := card.find_child("Content", true, false) as Control
	_check(content != null and content.position.y == -4.0, "选中卡上移 4px")
	card.queue_free()

	var mini_card := UiDevCard.new()
	mini_card.catalog = catalog
	mini_card.card_id = "L3-U-02"
	mini_card.mini = true
	mini_card.blind_label = true
	host.add_child(mini_card)
	_check(mini_card.custom_minimum_size == Vector2(92, 120), "迷你卡尺寸 92×120")
	var blind_tag := mini_card.find_child("BlindTag", true, false) as Control
	_check(blind_tag != null and blind_tag.visible, "我的盲抽标签")
	mini_card.queue_free()

	var back_card := UiDevCard.new()
	back_card.card_back = true
	back_card.back_level = 3
	host.add_child(back_card)
	var back_level := back_card.find_child("BackLevel", true, false) as Label
	var back_marks := back_card.find_child("BackMarks", true, false) as Label
	_check(back_level != null and back_level.text == "III", "牌背罗马数字")
	_check(back_marks != null and back_marks.text == "◆◆◆", "牌背菱形数量")
	back_card.queue_free()

	var empty_card := UiDevCard.new()
	empty_card.empty = true
	host.add_child(empty_card)
	var empty_label := empty_card.find_child("EmptyLabel", true, false) as Label
	var empty_frame := empty_card.find_child("Frame", true, false) as Control
	_check(empty_label != null and empty_label.visible and empty_label.text == "空位", "空位卡")
	_check(empty_frame != null and not empty_frame.visible, "空位卡隐藏实心边框")
	empty_card.queue_free()

	var threat_card := UiDevCard.new()
	threat_card.catalog = catalog
	threat_card.card_id = "L2-K-03"
	threat_card.threat_seats = [1, 2]
	host.add_child(threat_card)
	var threat_frame := threat_card.find_child("Threat", true, false) as UiFrame
	_check(threat_frame != null and threat_frame.visible, "对手能买头像框")
	_check(threat_frame.content.get_child(0).get_child_count() == 2, "两个对手头像")
	threat_card.queue_free()

	# ---------------------------------------------------------------- 牌堆 / 贵族 / 引用
	var deck := UiDeckPile.new()
	deck.level = 2
	deck.remaining = 20
	host.add_child(deck)
	_check(deck.custom_minimum_size == Vector2(96, 150), "牌堆尺寸 96×150")
	var roman := deck.find_child("Roman", true, false) as Label
	var deck_count := deck.find_child("Count", true, false) as Label
	_check(roman != null and roman.text == "II", "牌堆罗马数字")
	_check(deck_count != null and deck_count.text == "剩 20", "牌堆剩余张数")
	deck.remaining = 0
	var deck_tex := deck.find_child("Texture", true, false) as Control
	_check(deck_count.text == "已空" and not deck_tex.visible, "空牌堆虚线样式")
	deck.queue_free()

	var noble := UiNobleTile.new()
	noble.catalog = catalog
	noble.noble_id = "N-09"
	noble.big = true
	host.add_child(noble)
	_check(noble.custom_minimum_size == Vector2(200, 170), "大号贵族尺寸")
	var noble_points := noble.find_child("Points", true, false) as Label
	var noble_data := catalog.noble("N-09")
	_check(noble_points != null and noble_points.text == str(noble_data.points), "贵族分数来自 CardCatalog")
	var requirements := noble.find_child("Requirements", true, false) as HFlowContainer
	_check(requirements != null and requirements.get_child_count() == noble_data.requirement.size(),
			"贵族要求只列非零项")
	noble.queue_free()

	var ref := UiCardRef.new()
	ref.catalog = catalog
	ref.card_id = "L2-U-03"
	host.add_child(ref)
	var ref_text := ref.find_child("Text", true, false) as Label
	_check(ref_text != null and ref_text.text == "二级蓝 · 2 分", "卡牌引用文案")
	ref.queue_free()

	# ---------------------------------------------------------------- 通用控件
	var tag := UiTag.new()
	tag.text = "思考中"
	tag.variant = &"orange"
	host.add_child(tag)
	var tag_label := tag.find_child("Label", true, false) as Label
	_check(tag_label != null and tag_label.text == "思考中", "标签文案")
	_check(tag.background_color == UiPalette.TAG_ORANGE_BG, "标签 orange 配色")

	var kbd := UiKbd.new()
	kbd.text = "Esc"
	host.add_child(kbd)
	var kbd_label := kbd.find_child("Label", true, false) as Label
	_check(kbd_label != null and kbd_label.text == "Esc", "键帽文案")

	var segment := UiSegmented.new()
	segment.items = ["标准", "快速", "慢速"]
	segment.selected_index = 1
	host.add_child(segment)
	var segment_row := segment.get_child(0) as HBoxContainer
	_check(segment_row.get_child_count() == 3, "分段选项数量")
	var selected_signal := [0]
	segment.selected_changed.connect(func(index: int) -> void: selected_signal[0] = index)
	(segment_row.get_child(2) as Button).pressed.emit()
	_check(segment.selected_index == 2 and selected_signal[0] == 2, "分段点击切换")

	var switch := UiSwitch.new()
	host.add_child(switch)
	_check(switch.toggle_mode, "开关是 toggle 模式")
	switch.set_on(true)
	_check(switch.button_pressed, "开关可以打开")
	switch.queue_free()

	var input := UiInput.new()
	input.placeholder_text = "留空就随机"
	host.add_child(input)
	_check(input.placeholder_text == "留空就随机" and input.custom_minimum_size.y == 32, "输入框")

	var bar := UiProgressBar.new()
	bar.ratio = 1.7
	host.add_child(bar)
	_check(is_equal_approx(bar.ratio, 1.0), "进度条比例钳制")

	var spinner := UiSpinner.new()
	host.add_child(spinner)
	_check(spinner.custom_minimum_size == Vector2(12, 12), "转圈 12×12")

	var list_row := UiListRow.new()
	list_row.title = "自动存档"
	list_row.subtitle = "每回合结束覆盖"
	list_row.meta = "3 分钟前"
	host.add_child(list_row)
	var row_title := list_row.find_child("Title", true, false) as Label
	var row_subtitle := list_row.find_child("Subtitle", true, false) as Label
	var row_meta := list_row.find_child("Meta", true, false) as Label
	_check(row_title != null and row_title.text == "自动存档", "列表行标题")
	_check(row_subtitle != null and row_subtitle.visible, "列表行副标题")
	_check(row_meta != null and row_meta.text == "3 分钟前", "列表行右侧说明")
	list_row.selected = true
	_check(list_row.selected, "列表行选中状态")

	var button := UiButton.new()
	button.variant = &"accent"
	button.size_key = &"sm"
	button.text = "按钮"
	host.add_child(button)
	_check(button.theme_type_variation == &"UiButtonAccent", "按钮 accent 变体")
	var button_style := button.get_theme_stylebox("normal") as StyleBoxTexture
	_check(button_style != null and is_equal_approx(button_style.content_margin_left, 10.0),
			"按钮 sm 内边距")
	button.preview_state = &"disabled"
	_check(button.mouse_filter == Control.MOUSE_FILTER_IGNORE, "陈列按钮不响应鼠标")
	button.queue_free()

	var menu := UiMenuButton.new()
	menu.variant = &"dark"
	menu.title = "本地游戏"
	menu.subtitle = "同屏轮流，空座位交给电脑"
	host.add_child(menu)
	var menu_title := menu.find_child("Title", true, false) as Label
	_check(menu_title != null and menu_title.text == "本地游戏", "菜单大按钮标题")
	_check(menu.custom_minimum_size == Vector2(360, 64), "菜单大按钮尺寸")

	var modal := UiModalFrame.new()
	modal.preferred_width = 560
	modal.title = "弃宝石"
	host.add_child(modal)
	modal.set_tag("还需要弃 2 枚", &"orange")
	_check(modal.get_combined_minimum_size().x >= 560.0, "弹窗宽度")
	var modal_title := modal.find_child("Title", true, false) as Label
	_check(modal_title != null and modal_title.text == "弃宝石", "弹窗标题")
	var modal_tag := modal.find_child("Label", true, false) as Label
	_check(modal_tag != null and modal_tag.text == "还需要弃 2 枚", "弹窗 tag")
	modal.queue_free()

	var toast := UiToast.new()
	toast.auto_hide = false
	host.add_child(toast)
	toast.show_message(0, "已保存", "存档写到 user://saves/quick.json")
	var toast_message := toast.find_child("Message", true, false) as Label
	_check(toast_message != null and toast_message.text == "已保存", "toast 文案")
	var notice := UiNoticeCard.new()
	host.add_child(notice)
	notice.set_content(2, "薄荷掉线了", "电脑先替它打")
	var notice_title := notice.find_child("Title", true, false) as Label
	_check(notice_title != null and notice_title.text == "薄荷掉线了", "提示卡标题")

	host.queue_free()
	await get_tree().process_frame


func _check_gallery() -> void:
	await get_tree().process_frame
	var scene: PackedScene = load("res://ui/dev/gallery.tscn")
	_check(scene != null, "陈列场景可以加载")
	if scene == null:
		return
	var gallery: Control = scene.instantiate()
	get_tree().root.add_child(gallery)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(gallery.get_node_or_null("Scroll") != null, "陈列场景有滚动容器")
	_check(float(gallery.call("page_height")) > 1000.0, "陈列内容高度足够展示全部零件")
	gallery.queue_free()
	await get_tree().process_frame


func _check_app() -> void:
	var scene: PackedScene = load(APP_PATH)
	_check(scene != null, "入口场景可以加载")
	if scene == null:
		return
	var app: Control = scene.instantiate()
	await get_tree().process_frame
	get_tree().root.add_child(app)
	await get_tree().process_frame
	_check(app.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "入口根节点使用 Nearest 过滤")
	_check(app.theme != null and app.theme.resource_path == THEME_PATH, "入口挂载主题")
	_check(app.get_node_or_null("ScreenRoot") != null, "屏幕路由层存在")
	_check(app.get_node_or_null("ModalLayer/ModalRoot") != null, "弹窗层存在")
	_check(app.get_node_or_null("ToastLayer/ToastRoot") != null, "toast 层存在")
	var actions := [
		"spl_color_1", "spl_color_2", "spl_color_3", "spl_color_4", "spl_color_5",
		"spl_confirm", "spl_cancel", "spl_reserve", "spl_log",
		"spl_replay_prev", "spl_replay_next", "spl_replay_play",
	]
	for action: String in actions:
		_check(InputMap.has_action(action), "快捷键动作 %s" % action)
	_check(DataRegistry.is_valid(), "数据层校验通过")
	app.queue_free()
