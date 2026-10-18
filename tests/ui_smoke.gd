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
	_check_render_layer_files()
	await _check_components()
	await _check_gallery()
	await _check_view_math()
	await _check_table_fixtures()
	await _check_u3_sanitize()
	await _check_u3_take_and_legal()
	await _check_u3_reserve_privacy()
	await _check_u3_purchase_payment()
	await _check_u3_discard()
	await _check_u3_noble()
	await _check_u3_failure_and_result()
	await _check_u3_result_variants()
	await _check_u3_bot_lock()
	await _check_u3_quick_start()
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


## 渲染层不能直接碰规则引擎 / 控制器（U3 起只通过 ui/bridge/）。
func _check_render_layer_files() -> void:
	var paths: Array[String] = [
		"res://ui/screens/table/table_screen.gd",
		"res://ui/screens/table/table_flow.gd",
		"res://ui/screens/table/table_modals.gd",
		"res://ui/common/view_math.gd",
		"res://ui/common/ui_markup.gd",
		"res://ui/common/event_text.gd",
	]
	for path: String in paths:
		var text := FileAccess.get_file_as_string(path)
		_check(not text.is_empty(), "%s 可以读取" % path.get_file())
		_check(not text.contains("GameState."), "%s 不引用 GameState" % path.get_file())
		_check(not text.contains("GameController"), "%s 不引用 GameController" % path.get_file())
		_check(not text.contains("._state"), "%s 不读 GameState 内部字段" % path.get_file())
	var live := FileAccess.get_file_as_string("res://ui/bridge/live_backend.gd")
	_check(live.contains("GameController") and not live.contains("._state"),
			"LiveBackend 只用 GameController 公开接口")
	var session_text := FileAccess.get_file_as_string("res://ui/bridge/table_session.gd")
	_check(not session_text.contains("GameState.") and not session_text.contains("._state"),
			"TableSession 不碰 GameState 内部")


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

	# ---------------------------------------------------------------- U3：交互零件
	var bank := UiBankColumn.new()
	host.add_child(bank)
	bank.set_counts({Enums.GemColor.RED: 3})
	_check(bank.find_child("ConfirmButton", true, false) != null, "银行有确认按钮")
	_check(bank.find_child("CancelButton", true, false) != null, "银行有取消按钮")
	bank.set_interactive(true)
	bank.set_clickable_colors([Enums.GemColor.RED])
	bank.set_selection({Enums.GemColor.RED: 2})
	var red_chip := bank.chip(Enums.GemColor.RED)
	_check(red_chip != null and red_chip.selected_amount == 2, "银行筹码显示已选 +N")
	_check(red_chip.mouse_filter == Control.MOUSE_FILTER_STOP, "可点筹码响应鼠标")
	_check(bank.chip(Enums.GemColor.GOLD).mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"金币筹码不可点")
	bank.set_confirm_enabled(true)
	_check(not bank.confirm_button().disabled, "银行确认按钮可启用")
	bank.queue_free()

	var me_panel := UiMyPanel.new()
	host.add_child(me_panel)
	_check(me_panel.find_child("CancelButton", true, false) != null, "我的面板托盘有取消按钮")
	me_panel.queue_free()

	var popover := UiCardPopover.new()
	host.add_child(popover)
	popover.render({
		"mode": "market",
		"title": "二级 · 蓝 · 2 分",
		"tag_text": "可买",
		"tag_variant": "mint",
		"payment": {
			"bonus": {Enums.GemColor.BLUE: 2},
			"gems": {Enums.GemColor.BLUE: 2},
			"gold": 1,
			"total": 5,
		},
		"affordable": true,
		"can_buy": true,
		"can_reserve": true,
		"reserve_label": "预留 · +1 金",
		"change_text": "买后：宝石 6 → 3",
	})
	_check(popover.custom_minimum_size.x == 272.0, "卡牌浮层宽 272")
	_check(popover.find_child("PaymentBox", true, false).visible, "浮层显示支付预览")
	_check(popover.find_child("BuyButton", true, false).visible, "浮层显示购买按钮")
	_check(popover.find_child("ReserveButton", true, false).visible, "浮层显示预留按钮")
	popover.render({
		"mode": "deck",
		"title": "三级牌堆 · 盲抽",
		"affordable": true,
		"can_reserve": true,
		"reserve_label": "盲抽预留 · +1 金",
		"note": "看不到是哪张",
	})
	_check(not popover.find_child("PaymentBox", true, false).visible, "牌堆浮层不显示支付预览")
	_check(not popover.find_child("BuyButton", true, false).visible, "牌堆浮层没有购买按钮")
	_check(popover.find_child("ReserveButton", true, false).visible, "牌堆浮层有预留按钮")
	popover.render({
		"mode": "reserved",
		"title": "二级 · 蓝 · 2 分",
		"affordable": true,
		"payment": {"bonus": {}, "gems": {}, "gold": 0, "total": 5},
		"can_buy": true,
		"can_reserve": false,
	})
	_check(popover.find_child("BuyButton", true, false).visible, "预留卡浮层有购买按钮")
	_check(not popover.find_child("ReserveButton", true, false).visible,
			"预留卡浮层没有预留按钮")
	popover.queue_free()

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


# ---------------------------------------------------------------- U2：ViewMath 与牌桌

const TABLE_SCENE := "res://ui/screens/table/table_screen.tscn"
const TABLE_FIXTURES: Array[String] = [
	"g3_turn_mine", "g3_bot_turn", "g3_spectator", "g3_replay", "g4_endgame",
	"g2_bank_edges", "g4_deck_empty", "g3_seed_run", "g4_seed_run",
]


func _check_view_math() -> void:
	var fixture := UiFixtureLoader.load_fixture("g3_turn_mine")
	_check(not fixture.is_empty(), "G3 夹具可以加载")
	if fixture.is_empty():
		return
	var view: Dictionary = fixture["view"]
	var catalog := DataRegistry.card_catalog()
	_check(UiViewMath.round_number(view) == 9, "轮数 = 回合数最小值 + 1")
	var expected_scores: Array[int] = [3, 7, 1]
	var expected_cards: Array[int] = [6, 8, 3]
	for seat: int in 3:
		_check(UiViewMath.score(view, seat, catalog) == expected_scores[seat],
				"G3 座位 %d 分数" % seat)
		_check(UiViewMath.card_count(view, seat) == expected_cards[seat],
				"G3 座位 %d 已购卡数" % seat)
	_check(UiViewMath.token_total(view, 0) == 6, "G3 座位 0 持币 6")
	_check(UiViewMath.token_total(view, 1) == 3, "G3 座位 1 持币 3")
	_check(UiViewMath.token_total(view, 2) == 6, "G3 座位 2 持币 6")
	_check_bonuses(view, 0, {"white": 2, "blue": 2, "green": 1, "black": 1}, catalog)
	_check_bonuses(view, 1, {"white": 1, "green": 3, "red": 2, "black": 2}, catalog)
	_check_bonuses(view, 2, {"blue": 1, "green": 1, "red": 1}, catalog)

	_check(UiViewMath.shortfall(view, 0, "L2-U-03", catalog) == 0, "L2-U-03 买得起")
	_check(UiViewMath.shortfall(view, 0, "L3-W-04", catalog) == 5, "L3-W-04 差 5")
	var payment: Dictionary = UiViewMath.payment_preview(view, 0, "L2-U-03", catalog)
	_check(int(payment.get("total", 0)) == 5, "支付预览总花费 5")
	_check(int((payment["bonus"] as Dictionary).get(Enums.GemColor.BLUE, 0)) == 2,
			"支付预览先用 2 张蓝折扣")
	_check(int((payment["gems"] as Dictionary).get(Enums.GemColor.BLUE, 0)) == 2,
			"支付预览再用 2 枚蓝宝石")
	_check(int(payment.get("gold", 0)) == 1, "支付预览最后补 1 枚金币")
	var missing: Array[Dictionary] = UiViewMath.missing_by_color(view, 0, "L3-W-04", catalog)
	_check(missing.size() == 1 and int(missing[0].get("amount", 0)) == 6
			and int(missing[0].get("color", -1)) == Enums.GemColor.BLACK, "缺口明细只列黑 6")
	_check(UiViewMath.gold_can_pay(view, 0, "L3-W-04", catalog) == 1, "金币可抵 1 枚")
	var buyers: Array[int] = UiViewMath.affordable_by(view, "L1-R-04", catalog)
	_check(buyers == [0, 2], "L1-R-04 买得起的是座位 0 和 2")

	var g4 := UiFixtureLoader.load_fixture("g4_endgame")
	_check(not g4.is_empty(), "G4 夹具可以加载")
	if g4.is_empty():
		return
	var view4: Dictionary = g4["view"]
	var expected4: Array[int] = [15, 12, 9, 11]
	for seat: int in 4:
		_check(UiViewMath.score(view4, seat, catalog) == expected4[seat],
				"G4 座位 %d 分数" % seat)
	_check(UiViewMath.round_number(view4) == 24, "G4 轮数 24")
	var remaining: Array[int] = UiViewMath.endgame_remaining(view4)
	_check(remaining == [1, 2, 3], "G4 终局轮还剩座位 1–3")
	_check(UiViewMath.seat_type_label("bot_hard") == "电脑 · 困难", "座位类型文案")


func _check_bonuses(view: Dictionary, seat: int, expected: Dictionary,
		catalog: CardCatalog) -> void:
	var bonuses: Dictionary = UiViewMath.bonuses(view, seat, catalog)
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		var color_name: String = Enums.color_to_string(color)
		_check(int(bonuses.get(color, 0)) == int(expected.get(color_name, 0)),
				"座位 %d 的%s折扣" % [seat, Enums.color_to_zh(color)])


func _check_table_fixtures() -> void:
	await get_tree().process_frame
	var host := Control.new()
	host.name = "UiTableTestHost"
	host.theme = load(THEME_PATH)
	host.size = Vector2(1280, 800)
	get_tree().root.add_child(host)
	await get_tree().process_frame

	for fixture_name: String in TABLE_FIXTURES:
		var fixture := UiFixtureLoader.load_fixture(fixture_name)
		_check(not fixture.is_empty(), "夹具 %s 可以加载" % fixture_name)
		if fixture.is_empty():
			continue
		var table: UiTableScreen = load(TABLE_SCENE).instantiate()
		table.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		host.add_child(table)
		await get_tree().process_frame
		await get_tree().process_frame
		table.render(fixture["view"], int(fixture["me_seat"]), fixture["session_info"])
		await get_tree().process_frame
		await get_tree().process_frame

		_check(table.size == Vector2(1280, 800), "%s 牌桌按 1280×800 排版" % fixture_name)
		_check_table_render(table, fixture, fixture_name)

		var nodes_before := _count_nodes(table)
		table.render(fixture["view"], int(fixture["me_seat"]), fixture["session_info"])
		await get_tree().process_frame
		await get_tree().process_frame
		_check(_count_nodes(table) == nodes_before, "%s 重复 render 不累积节点" % fixture_name)

		table.queue_free()
		await get_tree().process_frame
	host.queue_free()
	await get_tree().process_frame


func _check_table_render(table: UiTableScreen, fixture: Dictionary, fixture_name: String) -> void:
	var view: Dictionary = fixture["view"]
	var me_seat: int = int(fixture["me_seat"])
	var session: Dictionary = fixture["session_info"]
	var catalog := DataRegistry.card_catalog()
	var rules := DataRegistry.rules()

	# 市场卡牌 id、牌堆张数、银行数字
	var expected_market: Dictionary[int, Array] = {}
	var allowed_ids: Dictionary = {}
	for level: int in [1, 2, 3]:
		var ids: Array[String] = []
		var board: Array = (view.get("boards", {}) as Dictionary).get(str(level), [])
		for item: Variant in board:
			if item != null:
				ids.append(String(item))
				allowed_ids[String(item)] = true
		expected_market[level] = ids
	var actual_market := table.market_card_ids()
	for level: int in [1, 2, 3]:
		_check(actual_market[level] == expected_market[level],
				"%s 市场 %d 级卡牌 id 与视图一致" % [fixture_name, level])
		var deck: Dictionary = (view.get("decks", {}) as Dictionary).get(str(level), {})
		_check(table.deck_counts()[level] == int(deck.get("count", 0)),
				"%s %d 级牌堆张数" % [fixture_name, level])

	var bank_counts: Dictionary[int, int] = table.bank_column().get_counts()
	var raw_bank: Dictionary = view.get("bank", {})
	var view_players: Array = view.get("players", [])
	for color: Enums.GemColor in Enums.ALL_COLORS:
		var color_name: String = Enums.color_to_string(color)
		_check(bank_counts.get(color, -1) == int(raw_bank.get(color_name, 0)),
				"%s 银行%s数量" % [fixture_name, Enums.color_to_zh(color)])
		var total: int = int(raw_bank.get(color_name, 0))
		for player: Dictionary in view_players:
			total += int((player.get("tokens", {}) as Dictionary).get(color_name, 0))
		var expected: int = rules.gold_count if color == Enums.GemColor.GOLD \
				else rules.gems_per_color_for(int(view.get("player_count", 0)))
		_check(total == expected, "%s %s宝石守恒" % [fixture_name, Enums.color_to_zh(color)])

	# 我的面板
	if me_seat >= 0:
		_check(table.my_panel().visible, "%s 有我的面板" % fixture_name)
		_check(not (table.find_child("Spectator", true, false) as Control).visible,
				"%s 不显示观战条" % fixture_name)
		var data: Dictionary = table.my_panel().get_render_data()
		_check(int(data.get("score", -1)) == UiViewMath.score(view, me_seat, catalog),
				"%s 我的分数与视图一致" % fixture_name)
		_check(int(data.get("card_count", -1)) == UiViewMath.card_count(view, me_seat),
				"%s 我的卡数与视图一致" % fixture_name)
		_check(int(data.get("noble_count", -1)) == UiViewMath.noble_count(view, me_seat),
				"%s 我的贵族数与视图一致" % fixture_name)
		_check((data.get("reserved", []) as Array).size()
				== (UiViewMath.player(view, me_seat).get("reserved", []) as Array).size(),
				"%s 我的预留数与视图一致" % fixture_name)
		var score_label := table.my_panel().find_child("Score", true, false) as Label
		_check(score_label != null
				and score_label.text == str(UiViewMath.score(view, me_seat, catalog)),
				"%s 我的分数标签" % fixture_name)
		for player: Dictionary in (view.get("players", []) as Array):
			for entry: Variant in (player.get("reserved", []) as Array):
				var entry_dict: Dictionary = entry if entry is Dictionary else {}
				if entry_dict.get("id") != null:
					allowed_ids[String(entry_dict["id"])] = true
	else:
		_check(not table.my_panel().visible, "%s 观战隐藏我的面板" % fixture_name)
		_check((table.find_child("Spectator", true, false) as Control).visible,
				"%s 显示观战条" % fixture_name)

	# 对手面板：座位、分数、资源、动作状态
	var expected_seats: Array[int] = []
	var player_count: int = int(view.get("player_count", 0))
	var current: int = int(view.get("current_seat", 0))
	for seat: int in player_count:
		if me_seat < 0 or seat != me_seat:
			expected_seats.append(seat)
	for seat: int in expected_seats:
		var panel: UiOpponentPanel = table.opponent_panel(seat)
		_check(panel != null, "%s 座位 %d 有对手面板" % [fixture_name, seat])
		if panel == null:
			continue
		var data: Dictionary = panel.get_render_data()
		_check(int(data.get("score", -1)) == UiViewMath.score(view, seat, catalog),
				"%s 座位 %d 分数与视图一致" % [fixture_name, seat])
		_check(int(data.get("noble_count", -1)) == UiViewMath.noble_count(view, seat),
				"%s 座位 %d 贵族数与视图一致" % [fixture_name, seat])
		_check((data.get("reserved", []) as Array).size()
				== (UiViewMath.player(view, seat).get("reserved", []) as Array).size(),
				"%s 座位 %d 预留标记数" % [fixture_name, seat])
		_check(bool(data.get("active", false)) == (seat == current),
				"%s 座位 %d 当前行动状态" % [fixture_name, seat])
		_check(_find_cards(panel).is_empty(), "%s 座位 %d 不渲染卡面" % [fixture_name, seat])
	_check(table.find_child("CountTag", true, false) != null, "%s 顶栏人数标签" % fixture_name)

	# 日志条数
	var entries: Array = session.get("log", [])
	var limit: int = 4 if expected_seats.size() >= 3 else 7
	_check(table.log_panel().log_count() == mini(limit, entries.size()),
			"%s 日志条数" % fixture_name)

	# 4 人局右栏不溢出，日志至少 130
	var right := table.right_column()
	_check(right.size.y > 0.0, "%s 右栏有高度" % fixture_name)
	_check(right.get_combined_minimum_size().y <= right.size.y + 1.0,
			"%s 右栏内容不溢出" % fixture_name)
	_check(table.log_panel().size.y >= 130.0, "%s 日志高度 >= 130" % fixture_name)

	# 三级市场在最上面
	var row3 := table.find_child("Row3", true, false) as Control
	var row2 := table.find_child("Row2", true, false) as Control
	var row1 := table.find_child("Row1", true, false) as Control
	_check(row3.get_global_rect().position.y < row2.get_global_rect().position.y
			and row2.get_global_rect().position.y < row1.get_global_rect().position.y,
			"%s 三级市场从上到下" % fixture_name)

	# 渲染出的卡面 id 必须来自视图；观战尤其实验看不到别人的盲抽
	var rendered: Array[UiDevCard] = _find_cards(table)
	for card: UiDevCard in rendered:
		if card.card_id.is_empty():
			continue
		_check(allowed_ids.has(card.card_id),
				"%s 卡面 %s 来自视图" % [fixture_name, card.card_id])
	if fixture_name == "g3_spectator":
		_check(not allowed_ids.has("L3-U-02") and not _has_card_id(table, "L3-U-02"),
				"观战不泄露座位 0 的盲抽")

	# 具体夹具的观察点
	if fixture_name == "g4_endgame":
		var endgame_tag := table.find_child("EndgameTag", true, false) as UiTag
		_check(endgame_tag != null and endgame_tag.visible
				and endgame_tag.text == "终局轮 · 还剩 3 人", "G4 终局轮标签")
		_check(expected_seats.size() == 3, "G4 右栏 3 个对手面板")
	if fixture_name == "g4_deck_empty":
		var deck1 := table.find_child("Deck1", true, false) as UiDeckPile
		var count_label := deck1.find_child("Count", true, false) as Label
		_check(deck1.remaining == 0 and count_label != null and count_label.text == "已空",
				"deck_empty 一级牌堆已空")
	if fixture_name == "g2_bank_edges":
		_check(bank_counts.get(Enums.GemColor.GREEN, -1) == 0, "银行绿宝石见底")
		_check(expected_seats.size() == 1, "2 人局右栏 1 个对手面板")
	if fixture_name == "g3_spectator" or fixture_name == "g3_replay":
		var spectator_frame := table.find_child("Spectator", true, false) as Control
		var title := spectator_frame.find_child("Title", true, false) as Label
		var hint := spectator_frame.find_child("Hint", true, false) as Label
		if fixture_name == "g3_replay":
			_check(title.text == "回放", "回放底部标题")
			_check(hint != null and hint.visible, "回放底部显示播放条占位")
		else:
			_check(title.text == "观战", "观战底部标题")
			_check(hint == null or not hint.visible, "观战不显示回放占位")
	if me_seat >= 0:
		var player_data: Dictionary = UiViewMath.player(view, me_seat)
		_check((table.my_panel().get_render_data().get("reserved", []) as Array).size()
				== (player_data.get("reserved", []) as Array).size(), "%s 我的预留标记" % fixture_name)
	_check(rules.max_tokens > 0, "规则参数可读")


func _find_cards(node: Node) -> Array[UiDevCard]:
	var result: Array[UiDevCard] = []
	for child in node.get_children():
		if child is UiDevCard:
			result.append(child)
		result.append_array(_find_cards(child))
	return result


func _has_card_id(node: Node, card_id: String) -> bool:
	for card: UiDevCard in _find_cards(node):
		if card.card_id == card_id:
			return true
	return false


func _count_nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count


# ---------------------------------------------------------------- U3：交互与真实对局

func _u3_host() -> Array:
	await get_tree().process_frame
	var host := Control.new()
	host.name = "UiU3Host"
	host.theme = load(THEME_PATH)
	host.size = Vector2(1280, 800)
	get_tree().root.add_child(host)
	var table: UiTableScreen = load(TABLE_SCENE).instantiate()
	table.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(table)
	var session := UiTableSession.new()
	session.name = "Session"
	host.add_child(session)
	var flow := UiTableFlow.new()
	flow.name = "Flow"
	host.add_child(flow)
	flow.setup(table, session)
	await get_tree().process_frame
	await get_tree().process_frame
	return [host, table, session, flow]


func _u3_cleanup(parts: Array) -> void:
	var session: UiTableSession = parts[2]
	session.close()
	var host: Control = parts[0]
	host.queue_free()
	await get_tree().process_frame


func _u3_seats(count: int) -> Array[Dictionary]:
	var seats: Array[Dictionary] = []
	for seat: int in count:
		seats.append({"name": ["小明", "薄荷", "紫晶", "橘子"][seat], "type": "human"})
	return seats


func _u3_start_humans(parts: Array, count: int, seed_value: int) -> bool:
	var session: UiTableSession = parts[2]
	return session.start_local({"count": count, "seed": seed_value, "seats": _u3_seats(count)})


func _u3_snapshot(name: String) -> Dictionary:
	var text := FileAccess.get_file_as_string("res://tests/scenarios/%s.json" % name)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return {}
	return SaveFile.unwrap_snapshot(parsed)


func _check_u3_sanitize() -> void:
	var view := {
		"viewer_seat": 1,
		"players": [
			{"reserved": [{"id": "L1-K-04", "level": 1, "blind": true}]},
			{"reserved": [{"id": "L2-U-03", "level": 2, "blind": true}]},
			{"reserved": [{"id": "L2-R-01", "level": 2, "blind": false}]},
		],
	}
	var cache := {0: ["L1-K-04"]}
	var mine: Dictionary = UiTableSession.sanitize_view(view, 0, cache)
	_check(int(mine["viewer_seat"]) == 0, "隐私过滤把 viewer 改成我")
	_check(String(((mine["players"] as Array)[0]["reserved"] as Array)[0]["id"]) == "L1-K-04",
			"自己的盲抽从缓存补上")
	_check(((mine["players"] as Array)[1]["reserved"] as Array)[0]["id"] == null,
			"别人的盲抽一律隐藏")
	_check(String(((mine["players"] as Array)[2]["reserved"] as Array)[0]["id"]) == "L2-R-01",
			"公开预留保持可见")
	var other: Dictionary = UiTableSession.sanitize_view(view, 1, cache)
	_check(((other["players"] as Array)[0]["reserved"] as Array)[0]["id"] == null,
			"换个视角时我的盲抽也隐藏")
	_check(String(((other["players"] as Array)[1]["reserved"] as Array)[0]["id"]) == "L2-U-03",
			"当前视角自己的盲抽可见")
	var no_me: Dictionary = UiTableSession.sanitize_view(view, -1, {})
	for seat: int in 2:
		_check(((no_me["players"] as Array)[seat]["reserved"] as Array)[0]["id"] == null,
				"观战视角不泄露座位 %d 的盲抽" % seat)
	_check(String(((no_me["players"] as Array)[2]["reserved"] as Array)[0]["id"]) == "L2-R-01",
			"观战视角保留公开预留")

	var cache2 := {0: ["L1-W-01", "L1-K-04"]}
	UiTableSession.update_blind_cache(cache2, 0, {
		"type": "card_purchased", "seat": 0, "card_id": "L1-W-01", "from_reserved": true,
	})
	_check(cache2[0] == ["L1-K-04"], "从预留区购买后缓存移除对应位置")
	UiTableSession.update_blind_cache(cache2, 0, {
		"type": "card_purchased", "seat": 0, "card_id": "L2-U-03", "from_reserved": true,
	})
	_check(cache2[0] == ["L1-K-04"], "买掉未见过的盲抽时移除一个空位（没有空位则不动）")
	UiTableSession.update_blind_cache(cache2, 0, {
		"type": "card_reserved", "seat": 0, "card_id": "", "blind": true,
	})
	_check(cache2[0] == ["L1-K-04", ""], "盲抽预留追加一个未知位置")
	UiTableSession.update_blind_cache(cache2, 0, {
		"type": "card_reserved", "seat": 0, "card_id": "L1-R-02", "blind": false,
	})
	_check(cache2[0] == ["L1-K-04", "", "L1-R-02"], "公开预留追加卡牌 id")


func _check_u3_take_and_legal() -> void:
	var parts := await _u3_host()
	var session: UiTableSession = parts[2]
	var flow: UiTableFlow = parts[3]
	var table: UiTableScreen = parts[1]
	_check(_u3_start_humans(parts, 2, 20261018), "U3 2 人人类局可以开局")
	await get_tree().process_frame
	_check(session.me_seat() == 0, "开局时我是座位 0")
	_check(session.is_my_turn(), "开局轮到我")
	_check(int(session.view().get("viewer_seat", -1)) == 0, "发出的视图 viewer 是我")
	var legal: Array[Action] = session.legal_actions()
	_check(legal.size() > 0, "开局有合法动作")
	var take_colors: Dictionary = {}
	for action: Action in legal:
		if action.type == Enums.ActionType.TAKE_THREE or action.type == Enums.ActionType.TAKE_TWO:
			for color: Enums.GemColor in action.colors:
				take_colors[color] = true
		if action.type == Enums.ActionType.PURCHASE:
			_check(flow.can_purchase(action.card_id), "购买动作 %s 有入口" % action.card_id)
		if action.type == Enums.ActionType.RESERVE and not action.card_id.is_empty():
			_check(flow.can_reserve(action.card_id), "预留动作 %s 有入口" % action.card_id)
		if action.type == Enums.ActionType.RESERVE and action.card_id.is_empty():
			_check(flow.can_reserve_blind(action.level), "%d 级盲抽预留有入口" % action.level)
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		_check(flow.is_color_clickable(color) == take_colors.has(color),
				"%s筹码可点状态和合法动作一致" % Enums.color_to_zh(color))

	# 同色 2 枚：点两次 → 托盘 → 确认
	var double_color: int = -1
	for action: Action in legal:
		if action.type == Enums.ActionType.TAKE_TWO:
			double_color = action.colors[0]
			break
	_check(double_color >= 0, "开局有拿两枚同色的动作")
	table.gem_chip_clicked.emit(double_color)
	table.gem_chip_clicked.emit(double_color)
	_check(int(flow.selection().get(double_color, 0)) == 2, "同色点两次选中 2 枚")
	var strip: Dictionary = table.my_panel().get_render_data().get("strip", {})
	_check(String(strip.get("tray_text", "")).contains("2 枚"), "托盘写同色 2 枚")
	_check((strip.get("tray_colors", []) as Array).size() == 2, "托盘逐枚记录已选筹码")
	var tray_chips := table.my_panel().find_child("TrayChips", true, false) as HBoxContainer
	_check(tray_chips != null and tray_chips.get_child_count() == 2, "托盘显示两枚筹码")
	_check(bool(strip.get("confirm_enabled", false)), "同色 2 枚可以确认")
	var before: int = UiViewMath.token_count(session.view(), 0, double_color)
	table.confirm_pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(UiViewMath.token_count(session.view(), 0, double_color) == before + 2,
			"确认后拿到 2 枚")
	_check(int(session.view().get("current_seat", -1)) == 1, "动作后轮到座位 1")
	_check(session.me_seat() == 1, "同屏换人后我是当前人类座位")
	_check(table.popover_visible() == false, "提交后浮层关闭")
	var log_entries: Array[Dictionary] = session.log_entries()
	_check(not log_entries.is_empty() and String(log_entries[0].get("text", "")).contains("拿了 2 枚"),
			"日志写拿了两枚")
	await _u3_cleanup(parts)


func _check_u3_reserve_privacy() -> void:
	var parts := await _u3_host()
	var session: UiTableSession = parts[2]
	var flow: UiTableFlow = parts[3]
	var table: UiTableScreen = parts[1]
	_check(_u3_start_humans(parts, 2, 20261021), "U3 盲抽隐私局可以开局")
	await get_tree().process_frame
	var blind_level: int = 0
	for action: Action in session.legal_actions():
		if action.type == Enums.ActionType.RESERVE and action.card_id.is_empty():
			blind_level = action.level
			break
	_check(blind_level > 0, "开局可以盲抽预留")
	table.card_clicked.emit("deck", "", blind_level)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(table.popover_visible(), "点牌堆打开浮层")
	var data: Dictionary = flow.popover_data()
	_check(String(data.get("mode", "")) == "deck", "牌堆浮层是盲抽模式")
	_check(bool(data.get("can_reserve", false)), "牌堆浮层可以盲抽预留")
	table.reserve_pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(int(session.view().get("current_seat", -1)) == 1, "盲抽后轮到座位 1")
	var reserved0: Array = (session.view()["players"] as Array)[0]["reserved"]
	_check(reserved0.size() == 1 and reserved0[0]["id"] == null,
			"轮到别人时我的盲抽画牌背")
	var colors: Array[int] = flow.clickable_colors()
	for index: int in 3:
		flow.click_color(colors[index])
	flow.confirm()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(int(session.view().get("current_seat", -1)) == 0, "座位 1 动作后回到我")
	var mine: Array = (session.view()["players"] as Array)[0]["reserved"]
	_check(mine.size() == 1 and mine[0]["id"] != null, "轮到我时能看到自己的盲抽")
	if mine.size() == 1 and mine[0]["id"] != null:
		var reserved_id: String = String(mine[0]["id"])
		table.card_clicked.emit("reserved", reserved_id, 0)
		await get_tree().process_frame
		await get_tree().process_frame
		_check(flow.selected_kind() == "reserved" and flow.selected_card_id() == reserved_id,
				"点我的预留卡可以选中")
		_check(table.popover_visible(), "预留卡打开浮层")
		_check(String(flow.popover_data().get("mode", "")) == "reserved",
				"预留卡浮层是购买模式")
		table.blank_clicked.emit()
		await get_tree().process_frame
	var log_entries: Array[Dictionary] = session.log_entries()
	_check(not log_entries.is_empty() and String(log_entries[0].get("text", "")).contains("拿了"),
			"座位 1 的动作写进日志")
	await _u3_cleanup(parts)


func _check_u3_purchase_payment() -> void:
	var parts := await _u3_host()
	var session: UiTableSession = parts[2]
	var flow: UiTableFlow = parts[3]
	var table: UiTableScreen = parts[1]
	var errors: Array[String] = []
	_check(session.load_snapshot(_u3_snapshot("endgame"), errors), "U3 终局局面可以载入")
	await get_tree().process_frame
	await get_tree().process_frame
	var purchase: Action = null
	var card: CardData = null
	for action: Action in session.legal_actions():
		if action.type != Enums.ActionType.PURCHASE:
			continue
		var candidate: CardData = session.catalog().card(action.card_id)
		if candidate != null and candidate.points > 0:
			purchase = action
			card = candidate
			break
	_check(purchase != null, "终局局面有买得起的计分卡")
	if purchase == null:
		await _u3_cleanup(parts)
		return
	var captured: Array[Dictionary] = []
	session.events_arrived.connect(func(events: Array[Dictionary]) -> void:
		captured.append_array(events))
	table.card_clicked.emit("market", purchase.card_id, 0)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(table.popover_visible(), "选中卡后浮层可见")
	var data: Dictionary = flow.popover_data()
	_check(bool(data.get("can_buy", false)) and bool(data.get("affordable", false)),
			"浮层里这张卡可以购买")
	_check(String(data.get("title", "")).contains("分"), "浮层标题带分数")
	var preview: Dictionary = data.get("payment", {})
	var score_before: int = UiViewMath.score(session.view(), 0, session.catalog())
	table.purchase_pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(bool(session.view().get("endgame_triggered", false)), "购买计分卡触发终局")
	_check(UiViewMath.score(session.view(), 0, session.catalog()) == score_before + card.points,
			"买后分数增加")
	var purchased: Dictionary = {}
	for event: Dictionary in captured:
		if String(event.get("type", "")) == "card_purchased":
			purchased = event
			break
	_check(not purchased.is_empty(), "收到 card_purchased 事件")
	_check(flow.flash_cards().has(purchase.card_id), "购买后相关卡进入光晕列表")
	if not purchased.is_empty():
		var paid: Dictionary = purchased.get("paid", {})
		for color: Enums.GemColor in Enums.ALL_COLORS:
			var expected: int = int((preview.get("gems", {}) as Dictionary).get(color, 0))
			if color == Enums.GemColor.GOLD:
				expected += int(preview.get("gold", 0))
			_check(int(paid.get(Enums.color_to_string(color), 0)) == expected,
					"支付预览与事件一致：%s" % Enums.color_to_zh(color))
	await _u3_cleanup(parts)


func _check_u3_discard() -> void:
	var parts := await _u3_host()
	var session: UiTableSession = parts[2]
	var flow: UiTableFlow = parts[3]
	var table: UiTableScreen = parts[1]
	var errors: Array[String] = []
	_check(session.load_snapshot(_u3_snapshot("token_limit"), errors), "U3 持币上限局面可以载入")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(UiViewMath.token_total(session.view(), 0) == 10, "载入时持币 10 枚（上限）")
	table.gem_chip_clicked.emit(Enums.GemColor.RED)
	table.gem_chip_clicked.emit(Enums.GemColor.RED)
	var strip: Dictionary = table.my_panel().get_render_data().get("strip", {})
	_check(String(strip.get("text", "")).contains("拿后 12 枚"), "拿宝石时提前提示要弃 2 枚")
	table.confirm_pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(String(session.view().get("phase", "")) == "discard", "超过上限进入弃宝石阶段")
	_check(flow.modal_kind() == "discard", "弃宝石弹窗打开")
	_check(table.modal_control() != null and table.modal_control().name == "DiscardModal",
			"弃宝石弹窗是 DiscardModal")
	var confirm := table.modal_control().find_child("DiscardConfirm", true, false) as Button
	_check(confirm != null and confirm.disabled, "选够之前确认按钮禁用")
	flow.choose_discard_color(Enums.GemColor.RED)
	flow.choose_discard_color(Enums.GemColor.RED)
	_check(int(flow.discard_selection().get(Enums.GemColor.RED, 0)) == 2, "弹窗里选了 2 枚红")
	confirm = table.modal_control().find_child("DiscardConfirm", true, false) as Button
	_check(confirm != null and not confirm.disabled, "选够之后确认按钮可用")
	flow.confirm_discard()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(String(session.view().get("phase", "")) == "playing", "弃够后回到正常回合")
	_check(UiViewMath.token_total(session.view(), 0) == 10, "弃后持币回到 10 枚")
	_check(int(session.view().get("current_seat", -1)) == 1, "弃完轮到座位 1")
	_check(flow.modal_kind().is_empty(), "弃宝石弹窗关闭")
	var log_entries: Array[Dictionary] = session.log_entries()
	_check(not log_entries.is_empty()
			and String(log_entries[0].get("text", "")).count("弃回") == 1
			and String(log_entries[0].get("text", "")).count("{gem:red}") == 2,
			"连续弃宝石合并成一条日志")
	await _u3_cleanup(parts)


func _check_u3_noble() -> void:
	var parts := await _u3_host()
	var session: UiTableSession = parts[2]
	var flow: UiTableFlow = parts[3]
	var table: UiTableScreen = parts[1]
	var errors: Array[String] = []
	_check(session.load_snapshot(_u3_snapshot("two_nobles"), errors), "U3 双贵族局面可以载入")
	await get_tree().process_frame
	await get_tree().process_frame
	var colors: Array[int] = flow.clickable_colors()
	for index: int in 3:
		flow.click_color(colors[index])
	flow.confirm()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(String(session.view().get("phase", "")) == "choose_noble", "回合末进入选贵族阶段")
	_check(flow.modal_kind() == "noble", "选贵族弹窗打开")
	var pending: Array = session.view().get("pending_nobles", [])
	_check(pending.size() == 2, "同时满足两位贵族")
	var confirm := table.modal_control().find_child("NobleConfirm", true, false) as Button
	_check(confirm != null and confirm.disabled, "没选贵族时确认按钮禁用")
	flow.choose_noble(String(pending[1]))
	await get_tree().process_frame
	confirm = table.modal_control().find_child("NobleConfirm", true, false) as Button
	_check(confirm != null and not confirm.disabled, "选中贵族后确认按钮可用")
	_check(confirm.text.contains("来访"), "确认按钮按位置指代贵族")
	flow.confirm_noble()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(String(session.view().get("phase", "")) == "playing", "选完贵族回到正常回合")
	var nobles0: Array = (session.view()["players"] as Array)[0]["nobles"]
	_check(nobles0.has(pending[1]), "选中的贵族来到我的面板")
	_check(flow.modal_kind().is_empty(), "选贵族弹窗关闭")
	await _u3_cleanup(parts)


func _check_u3_failure_and_result() -> void:
	# 非法动作：直接提交一个买不起的购买，桥接层把 action_rejected 转成 action_failed。
	var parts := await _u3_host()
	var session: UiTableSession = parts[2]
	var flow: UiTableFlow = parts[3]
	var table: UiTableScreen = parts[1]
	_check(_u3_start_humans(parts, 2, 20261023), "U3 失败提示局可以开局")
	await get_tree().process_frame
	session.submit(Action.purchase("L3-W-04"))
	await get_tree().process_frame
	_check(not flow.last_failure().is_empty(), "非法动作产生失败提示")
	var strip: Dictionary = table.my_panel().get_render_data().get("strip", {})
	_check(String(strip.get("text", "")).contains("这一步没成功"), "顶条显示失败提示")
	await _u3_cleanup(parts)

	# 结算：买下计分卡触发终局，座位 1 再走一步后结算弹窗。
	parts = await _u3_host()
	session = parts[2]
	flow = parts[3]
	table = parts[1]
	var errors: Array[String] = []
	_check(session.load_snapshot(_u3_snapshot("endgame"), errors), "U3 结算局面可以载入")
	await get_tree().process_frame
	await get_tree().process_frame
	var purchase: Action = null
	for action: Action in session.legal_actions():
		if action.type != Enums.ActionType.PURCHASE:
			continue
		var card: CardData = session.catalog().card(action.card_id)
		if card != null and card.points > 0:
			purchase = action
			break
	if purchase != null:
		flow.click_card("market", purchase.card_id, 0)
		flow.purchase_selected()
		await get_tree().process_frame
		var legal1: Array[Action] = session.legal_actions()
		_check(legal1.size() > 0, "终局轮里座位 1 还有动作")
		if not legal1.is_empty():
			session.submit(legal1[0])
		await get_tree().process_frame
		await get_tree().process_frame
		_check(String(session.view().get("phase", "")) == "finished", "所有人回合数相同后结束")
		var result: Dictionary = flow.result()
		_check(not result.is_empty(), "产生结算数据")
		_check((result.get("winners", []) as Array).has(0), "座位 0 获胜")
		_check(flow.modal_kind() == "result", "结算弹窗打开")
		_check(table.modal_control() != null and table.modal_control().name == "ResultModal",
				"结算弹窗是 ResultModal")
		var title := table.modal_control().find_child("ResultTitle", true, false) as Label
		_check(title != null and title.text.contains("获胜"), "结算标题写出胜者")
		_check(table.modal_control().find_child("ResultSeat0", true, false) != null,
				"结算名次表列出座位 0")
		_check(int(result.get("scores", {}).get("0", 0)) >= 15, "结算分数达到胜利分")
	await _u3_cleanup(parts)


func _check_u3_result_variants() -> void:
	await get_tree().process_frame
	var host := Control.new()
	host.theme = load(THEME_PATH)
	host.size = Vector2(1280, 800)
	get_tree().root.add_child(host)
	await get_tree().process_frame
	var view := {"player_count": 2}

	var stalled := UiModalFrame.new()
	host.add_child(stalled)
	UiTableModals.populate_result(stalled, {
		"winners": [0], "scores": {"0": 14, "1": 9}, "cards": {"0": 10, "1": 7},
		"nobles": {"0": 1, "1": 0}, "reason": "stalled", "tiebreak": "",
		"round": 150, "elapsed_sec": 600,
	}, view, DataRegistry.rules(), ["小明", "薄荷"], ["human", "human"], {})
	var stalled_title := stalled.find_child("ResultTitle", true, false) as Label
	_check(stalled_title != null and stalled_title.text.contains("僵持"), "stalled 结算标题")
	var stalled_footer := stalled.find_child("ResultSubtitle", true, false) as Label
	_check(stalled_footer != null and stalled_footer.text.contains("按现有分数"),
			"stalled 结算说明")

	var tiebreak := UiModalFrame.new()
	host.add_child(tiebreak)
	UiTableModals.populate_result(tiebreak, {
		"winners": [0], "scores": {"0": 16, "1": 16}, "cards": {"0": 12, "1": 14},
		"nobles": {"0": 1, "1": 1}, "reason": "win_points", "tiebreak": "cards",
		"round": 20, "elapsed_sec": 120,
	}, view, DataRegistry.rules(), ["小明", "薄荷"], ["human", "human"], {})
	var note := tiebreak.find_child("TiebreakNote", true, false)
	_check(note != null, "破同分说明卡存在")
	if note != null:
		var labels := note.find_children("*", "Label", true, false)
		_check(labels.size() > 0 and (labels[0] as Label).text.contains("12 张")
				and (labels[0] as Label).text.contains("14 张"),
				"破同分说明写卡牌数")
	var tiebreak_title := tiebreak.find_child("ResultTitle", true, false) as Label
	_check(tiebreak_title != null and tiebreak_title.text.contains("小明 获胜"),
			"破同分后标题写胜者")

	var tie := UiModalFrame.new()
	host.add_child(tie)
	UiTableModals.populate_result(tie, {
		"winners": [0, 1], "scores": {"0": 16, "1": 16}, "cards": {"0": 12, "1": 12},
		"nobles": {"0": 1, "1": 1}, "reason": "win_points", "tiebreak": "tie",
		"round": 20, "elapsed_sec": 120,
	}, view, DataRegistry.rules(), ["小明", "薄荷"], ["human", "human"], {})
	var tie_title := tie.find_child("ResultTitle", true, false) as Label
	_check(tie_title != null and tie_title.text.contains("并列获胜"), "完全平局标题")
	host.queue_free()
	await get_tree().process_frame


func _check_u3_bot_lock() -> void:
	var parts := await _u3_host()
	var session: UiTableSession = parts[2]
	var flow: UiTableFlow = parts[3]
	var table: UiTableScreen = parts[1]
	var seats: Array[Dictionary] = [
		{"name": "小明", "type": "human"}, {"name": "薄荷", "type": "bot_easy"},
	]
	_check(session.start_local({"count": 2, "seed": 20261020, "seats": seats}),
			"U3 人机局可以开局")
	await get_tree().process_frame
	var colors: Array[int] = flow.clickable_colors()
	for index: int in 3:
		flow.click_color(colors[index])
	flow.confirm()
	# 电脑回合：动作同步结束后立刻检查（不等它的思考计时器）。
	_check(int(session.view().get("current_seat", -1)) == 1, "动作后轮到电脑")
	_check(not flow.is_interactive(), "电脑回合界面锁定")
	_check(flow.clickable_colors().is_empty(), "电脑回合没有可点颜色")
	_check(table.bank_column().chip(Enums.GemColor.WHITE).mouse_filter
			== Control.MOUSE_FILTER_IGNORE, "电脑回合银行筹码不可点")
	_check(table.popover_visible() == false, "电脑回合不显示浮层")
	var strip: Dictionary = table.my_panel().get_render_data().get("strip", {})
	_check(String(strip.get("kind", "")) == "event"
			or String(strip.get("text", "")).contains("等"),
			"电脑回合顶条写事件或等待")
	await _u3_cleanup(parts)


func _check_u3_quick_start() -> void:
	var scene: PackedScene = load("res://ui/dev/quick_start.tscn")
	_check(scene != null, "U3 临时开局场景可以加载")
	if scene == null:
		return
	var quick: Control = scene.instantiate()
	get_tree().root.add_child(quick)
	await get_tree().process_frame
	await get_tree().process_frame
	var setup: Control = quick.setup_root()
	_check(setup != null, "临时入口先显示开局设置")
	if setup != null:
		_check(setup.find_child("CountSegment", true, false) != null, "人数分段存在")
		_check(setup.find_child("DifficultySegment", true, false) != null, "难度分段存在")
		_check(setup.find_child("StartButton", true, false) != null, "开始按钮存在")
	_check(quick.start_game(3, "normal", 20261022), "临时入口可以开 3 人局")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(quick.session() != null and quick.flow() != null and quick.table() != null,
			"临时入口创建会话、交互和牌桌")
	_check(quick.setup_root() == null, "开局后隐藏设置")
	_check(int(quick.session().view().get("player_count", 0)) == 3, "临时入口人数正确")
	_check(quick.session().seat_types() == ["human", "bot_normal", "bot_normal"],
			"临时入口座位类型正确")
	_check(quick.table().find_child("CardPopover", true, false) != null, "牌桌有卡牌浮层")
	_check(quick.table().find_child("ModalLayer", true, false) != null, "牌桌有弹窗层")
	quick.queue_free()
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
