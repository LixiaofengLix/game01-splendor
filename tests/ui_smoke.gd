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
	# U0–U4 的交互检查按“立即落地”编写；U5 的动效检查会显式打开动效。
	UiSettings.reset_defaults()
	UiSettings.set_animations_enabled(false)
	UiSettings.set_sfx_enabled(false)
	UiSfx.clear_calls()
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
	await _check_u4_save_store()
	await _check_u4_session_resume()
	await _check_u4_main_menu()
	await _check_u4_local_setup()
	await _check_u4_save_browser()
	await _check_u4_error_modals()
	await _check_u4_pause_rules()
	await _check_u4_hotseat_cover()
	await _check_u4_flow_autosave()
	await _check_u4_app_flow()
	await _check_u5_settings()
	await _check_u5_animation_targets()
	await _check_u5_flash_slots()
	await _check_u5_animation_on_off()
	await _check_u5_fast_forward()
	await _check_u5_skip_and_speed()
	await _check_u5_bot_spectator()
	await _check_u5_endgame()
	await _check_u6_source()
	await _check_u6_replay_screen()
	await _check_u6_error_modal()
	await _check_u6_result_replay()
	await _check_u6_app_replay()
	UiSettings.reset_defaults()
	UiSettings.set_animations_enabled(false)
	UiSettings.set_sfx_enabled(false)
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

func _u3_host(store: UiSaveStore = null) -> Array:
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
	flow.setup(table, session, store)
	await get_tree().process_frame
	await get_tree().process_frame
	return [host, table, session, flow, store]


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


# ---------------------------------------------------------------- U4：入口与流程

const U4_SAVE_ROOT: String = "user://ui_smoke_saves"


func _u4_new_store() -> UiSaveStore:
	_u4_wipe(U4_SAVE_ROOT)
	var store := UiSaveStore.new()
	store.name = "U4Store"
	store.configure(U4_SAVE_ROOT)
	add_child(store)
	store.ensure_dirs()
	return store


func _u4_wipe(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)
	for child: String in dir.get_directories():
		var sub: String = path.path_join(child)
		_u4_wipe(sub)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(sub))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _u4_free_store(store: UiSaveStore) -> void:
	if is_instance_valid(store):
		store.queue_free()
	await get_tree().process_frame


func _u4_play_replay_data(seed_value: int = 20261018, count: int = 2) -> Dictionary:
	var host := Node.new()
	get_tree().root.add_child(host)
	var session := UiTableSession.new()
	host.add_child(session)
	var seats: Array[Dictionary] = []
	for seat: int in count:
		seats.append({"name": "座位 %d" % (seat + 1), "type": "human"})
	if not session.start_local({"count": count, "seed": seed_value, "seats": seats}):
		host.queue_free()
		return {}
	var steps: int = 0
	while not String(session.view().get("phase", "")).is_empty() \
			and String(session.view().get("phase", "")) != "finished" and steps < 600:
		var actions: Array[Action] = session.legal_actions()
		if actions.is_empty():
			break
		session.submit(actions[0])
		steps += 1
	var data: Dictionary = session.build_save_data()
	session.close()
	host.queue_free()
	return data


func _u4_make_meta(names: Array, types: Array, round_number: int = 1,
		status: String = "in_progress", winners: Array = []) -> Dictionary:
	return UiSaveStore.make_meta(status, names, types, false, 120,
			UiSaveStore.make_summary(round_number, 0, [1, 2], winners))


func _check_u4_save_store() -> void:
	var store: UiSaveStore = _u4_new_store()
	var data: Dictionary = _u4_play_replay_data()
	_check(not data.is_empty(), "U4 能跑出一局可存的回放数据")
	var names: Array = ["小明", "薄荷"]
	var types: Array = ["human", "human"]
	var meta: Dictionary = _u4_make_meta(names, types)
	_check(store.save_autosave(data, meta), "U4 自动存档可以写入")
	var summary: Dictionary = store.autosave_summary()
	_check(not summary.is_empty(), "U4 自动存档摘要非空")
	_check(String(summary.get("text", "")).contains("2 人"), "U4 摘要写人数")
	_check(String(summary.get("text", "")).contains("第 1 轮"), "U4 摘要写轮数")
	var entries: Array[UiSaveEntry] = store.list()
	_check(entries.size() == 1, "U4 列表读到自动存档")
	if not entries.is_empty():
		var entry: UiSaveEntry = entries[0]
		_check(entry.is_autosave, "U4 自动存档标记")
		_check(entry.display_name == "自动存档", "U4 自动存档名称")
		_check(entry.readable() and entry.status() == UiSaveEntry.STATUS_IN_PROGRESS,
				"U4 自动存档状态进行中")
		_check(entry.names() == ["小明", "薄荷"], "U4 ui_meta 名字保留")
		var check_result: Dictionary = store.validate(entry)
		_check(bool(check_result.get("ok", false)), "U4 回放存档可以完整校验")

	_check(store.save_quick(data, meta), "U4 快速存档可以写入")
	entries = store.list()
	_check(entries.size() == 2, "U4 快速存档出现在列表里")
	var quick_path: String = U4_SAVE_ROOT.path_join("quick.json")
	_check(FileAccess.file_exists(quick_path), "U4 快速存档文件存在")
	var finished_meta: Dictionary = _u4_make_meta(names, types, 3, "finished", [0])
	var finished_path: String = store.transfer_finished(data, finished_meta)
	_check(not finished_path.is_empty(), "U4 结束转存返回路径")
	_check(not FileAccess.file_exists(U4_SAVE_ROOT.path_join("autosave.json")),
			"U4 结束转存后删掉自动存档")
	var finished_entry: UiSaveEntry = null
	for entry: UiSaveEntry in store.list():
		if entry.is_finished:
			finished_entry = entry
	_check(finished_entry != null, "U4 结束记录出现在列表里")
	if finished_entry != null:
		_check(finished_entry.status() == UiSaveEntry.STATUS_FINISHED, "U4 结束记录状态")
		_check(finished_entry.display_name.contains("小明获胜"), "U4 结束记录名称写胜者")
		_check(finished_entry.mascot_seat() == 0, "U4 结束记录头像用胜者座位")

	# 坏文件：损坏 / 版本太新 / 不认识的类型。
	var corrupt := FileAccess.open(U4_SAVE_ROOT.path_join("corrupt.json"), FileAccess.WRITE)
	corrupt.store_string("{ 这不是 JSON")
	corrupt.close()
	_write_json(U4_SAVE_ROOT.path_join("too_new.json"), {
		"schema_version": 99, "kind": "replay", "player_count": 2,
	})
	_write_json(U4_SAVE_ROOT.path_join("unknown.json"), {
		"schema_version": 1, "kind": "mystery", "player_count": 2,
	})
	_write_json(U4_SAVE_ROOT.path_join("readonly_replay.json"), data)
	var reasons: Dictionary = {}
	for entry: UiSaveEntry in store.list():
		if entry.readable():
			continue
		reasons[entry.file_name] = entry.reason
	_check(reasons.get("corrupt.json", "") == UiSaveEntry.REASON_CORRUPT, "U4 损坏文件原因")
	_check(reasons.get("too_new.json", "") == UiSaveEntry.REASON_VERSION_TOO_NEW,
			"U4 版本太新原因")
	_check(reasons.get("unknown.json", "") == UiSaveEntry.REASON_UNKNOWN_KIND,
			"U4 未知类型原因")
	var read_only_entry: UiSaveEntry = null
	for entry: UiSaveEntry in store.list():
		if entry.file_name == "readonly_replay.json":
			read_only_entry = entry
	_check(read_only_entry != null and read_only_entry.read_only, "U4 其他 json 只读")
	if read_only_entry != null:
		_check(not store.delete_entry(read_only_entry), "U4 只读存档不能删除")

	# 改坏动作的回放：校验要指出第几步失败（把第 1 步换成买一张不存在的卡）。
	var bad_actions: Array = data.get("actions", []).duplicate(true)
	bad_actions[0] = Action.purchase("L3-R-99").to_dict()
	_write_json(U4_SAVE_ROOT.path_join("bad_replay.json"), {
		"schema_version": 1, "kind": "replay", "player_count": int(data.get("player_count", 2)),
		"seed": int(data.get("seed", 0)), "actions": bad_actions, "fingerprint": "",
	})
	var bad_entry: UiSaveEntry = null
	for entry: UiSaveEntry in store.list():
		if entry.file_name == "bad_replay.json":
			bad_entry = entry
	_check(bad_entry != null, "U4 坏动作回放被列出")
	if bad_entry != null:
		var bad_check: Dictionary = store.validate(bad_entry)
		_check(not bool(bad_check.get("ok", true)), "U4 坏动作回放校验失败")
		_check(int(bad_check.get("step", 0)) == 1,
				"U4 校验指出失败步数")

	var quick_entry: UiSaveEntry = null
	for entry: UiSaveEntry in store.list():
		if entry.is_quick:
			quick_entry = entry
	if quick_entry != null:
		_check(store.delete_entry(quick_entry), "U4 删除自己的存档")
		_check(not FileAccess.file_exists(quick_path), "U4 删除后文件消失")

	_check(UiSaveEntry.relative_time(int(Time.get_unix_time_from_system())) == "刚刚",
			"U4 相对时间刚刚")
	_check(UiSaveEntry.relative_time(int(Time.get_unix_time_from_system()) - 3600) == "1 小时前",
			"U4 相对时间小时")
	_check(UiSaveEntry.relative_time(int(Time.get_unix_time_from_system()) - 86400 * 3) != "",
			"U4 相对时间日期")
	await _u4_free_store(store)
	_u4_wipe(U4_SAVE_ROOT)


func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "  "))
	file.close()


func _check_u4_session_resume() -> void:
	var store: UiSaveStore = _u4_new_store()
	var host := Node.new()
	get_tree().root.add_child(host)
	var first := UiTableSession.new()
	host.add_child(first)
	var seats: Array[Dictionary] = [
		{"name": "小明", "type": "human"}, {"name": "薄荷", "type": "human"},
	]
	_check(first.start_local({"count": 2, "seed": 20261019, "seats": seats}),
			"U4 续档测试开局")
	first.submit(first.legal_actions()[0])
	first.submit(first.legal_actions()[0])
	var fingerprint: String = first.fingerprint()
	var current_seat: int = int(first.view().get("current_seat", -1))
	var data: Dictionary = first.build_save_data()
	var meta: Dictionary = _u4_make_meta(["小明", "薄荷"], ["human", "bot_hard"])
	meta["elapsed_sec"] = 600
	meta["hotseat_cover"] = true
	store.save_autosave(data, meta)
	var entry: UiSaveEntry = store.autosave_entry()
	_check(entry != null, "U4 续档入口存在")
	first.close()

	var second := UiTableSession.new()
	host.add_child(second)
	var errors: Array[String] = []
	var ok: bool = second.resume(entry, errors) if entry != null else false
	_check(ok, "U4 回放存档可以继续")
	_check(errors.is_empty(), "U4 继续成功没有错误")
	_check(second.fingerprint() == fingerprint, "U4 续档后状态指纹一致")
	_check(int(second.view().get("current_seat", -1)) == current_seat, "U4 续档后轮到同一座位")
	_check(second.names() == ["小明", "薄荷"], "U4 续档保留名字")
	_check(second.seat_types() == ["human", "human"], "U4 IR-04 前座位恢复成人类")
	_check(second.original_seat_types() == ["human", "bot_hard"], "U4 原座位类型保留")
	_check(not second.resume_note().is_empty(), "U4 电脑座位恢复提示")
	_check(second.elapsed_seconds() >= 600, "U4 续档接上用时")
	_check(second.hotseat_cover(), "U4 续档恢复同屏遮挡设置")
	var rematch: Dictionary = second.rematch_setup()
	var rematch_types: Array[String] = []
	for item: Variant in rematch.get("seats", []):
		rematch_types.append(String((item as Dictionary).get("type", "")))
	_check(rematch_types == ["human", "bot_hard"], "U4 再来一局沿用原座位类型")
	second.close()

	# 快照存档：继续后全部人类、不能保存回放。
	var snapshot_text: String = FileAccess.get_file_as_string("res://tests/scenarios/token_limit.json")
	_check(not snapshot_text.is_empty(), "U4 快照文件可读")
	_write_json(U4_SAVE_ROOT.path_join("preset_snapshot.json"), JSON.parse_string(snapshot_text))
	var snap_entry: UiSaveEntry = null
	for item: UiSaveEntry in store.list():
		if item.file_name == "preset_snapshot.json":
			snap_entry = item
	_check(snap_entry != null and snap_entry.kind == "snapshot", "U4 预设快照被识别")
	var third := UiTableSession.new()
	host.add_child(third)
	errors.clear()
	_check(third.resume(snap_entry, errors) if snap_entry != null else false,
			"U4 快照可以继续")
	_check(String(third.view().get("phase", "")) == "playing", "U4 快照恢复到对局中")
	_check(UiViewMath.token_total(third.view(), 0) == 10, "U4 快照持币数正确")
	_check(not third.can_save(), "U4 快照来源的局不能保存回放")
	third.close()
	host.queue_free()
	await get_tree().process_frame
	await _u4_free_store(store)
	_u4_wipe(U4_SAVE_ROOT)


func _check_u4_main_menu() -> void:
	var menu: UiMainMenu = load("res://ui/screens/main_menu/main_menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	await get_tree().process_frame
	_check(menu.find_child("HeroTitle", true, false) != null, "U4 主菜单标题")
	var hero := menu.find_child("HeroTitle", true, false) as Label
	_check(hero != null and hero.text == "璀璨宝石", "U4 主菜单标题文字")
	_check(not menu.continue_button().visible, "U4 没有自动存档时隐藏继续")
	_check(menu.local_button() != null and not menu.local_button().disabled, "U4 本地游戏按钮可点")
	_check(menu.online_button().disabled, "U4 联网入口禁用")
	_check(menu.find_child("SettingsButton", true, false) != null
			and (menu.find_child("SettingsButton", true, false) as Button).disabled,
			"U4 设置入口禁用")
	_check(menu.still_life_card_ids().size() == 3, "U4 主菜单三张扇形卡")
	menu.configure({"text": "3 人 · 第 9 轮 · 10 分钟前"})
	_check(menu.continue_button().visible, "U4 有自动存档时显示继续")
	_check(menu.continue_button().subtitle.contains("第 9 轮"), "U4 继续按钮副标题")
	var clicked: Array[String] = []
	menu.local_pressed.connect(func() -> void: clicked.append("local"))
	menu.local_button().pressed.emit()
	_check(clicked == ["local"], "U4 本地游戏按钮发信号")
	menu.queue_free()
	await get_tree().process_frame


func _check_u4_local_setup() -> void:
	var setup: UiLocalSetup = load("res://ui/screens/local_setup/local_setup.tscn").instantiate()
	get_tree().root.add_child(setup)
	await get_tree().process_frame
	_check(setup.seat_count() == 3, "U4 默认 3 个座位")
	var data: Dictionary = setup.start_data()
	_check(int(data.get("count", 0)) == 3, "U4 默认开局人数")
	var types: Array[String] = []
	for item: Variant in data.get("seats", []):
		types.append(String((item as Dictionary).get("type", "")))
	_check(types == ["human", "bot_normal", "bot_normal"], "U4 默认座位类型")
	_check(not bool(data.get("hotseat_cover", true)), "U4 1 人类不开遮挡")

	setup.set_seed_text("1234")
	_check(int(setup.start_data().get("seed", 0)) == 1234, "U4 种子写进开局设置")
	setup.set_seed_text("abc")
	var starts: Array[Dictionary] = []
	setup.start_requested.connect(func(value: Dictionary) -> void: starts.append(value))
	setup.start_pressed()
	_check(starts.is_empty() and not setup.error_text().is_empty(), "U4 非法种子被拦下")
	setup.set_seed_text("")

	setup.apply_preset("duel")
	_check(setup.seat_count() == 2, "U4 单挑组合人数")
	var duel: Dictionary = setup.start_data()
	_check(String((duel["seats"] as Array)[1]["type"]) == "bot_hard", "U4 单挑组合困难电脑")

	setup.apply_preset("hotseat")
	_check(setup.seat_count() == 4, "U4 同屏组合 4 人")
	var hotseat: Dictionary = setup.start_data()
	_check(bool(hotseat.get("hotseat_cover", false)), "U4 同屏组合打开遮挡")
	var human_count: int = 0
	for item: Variant in hotseat.get("seats", []):
		if String((item as Dictionary).get("type", "")) == "human":
			human_count += 1
	_check(human_count == 4, "U4 同屏组合全是人类")

	setup.apply_preset("bots")
	_check(setup.start_button().text == "开始观战", "U4 全电脑时按钮改开始观战")
	_check(setup.rule_value("胜利分") == "%d 分" % int(DataRegistry.rules().win_points),
			"U4 规则只读标签取 RulesConfig")
	_check(setup.rule_value("宝石").contains("每色"), "U4 宝石规则标签")

	setup.apply_preset("standard")
	setup.count_segment().selected_changed.emit(2)
	await get_tree().process_frame
	_check(setup.seat_count() == 4, "U4 人数分段同步座位数")
	setup.count_segment().selected_changed.emit(0)
	await get_tree().process_frame
	_check(setup.seat_count() == 2, "U4 人数分段可以减少座位")
	setup.queue_free()
	await get_tree().process_frame


func _check_u4_save_browser() -> void:
	var store: UiSaveStore = _u4_new_store()
	var data: Dictionary = _u4_play_replay_data()
	var meta: Dictionary = _u4_make_meta(["小明", "薄荷"], ["human", "human"])
	store.save_autosave(data, meta)
	store.save_quick(data, _u4_make_meta(["小明", "薄荷"], ["human", "human"], 2))
	var snapshot_text: String = FileAccess.get_file_as_string("res://tests/scenarios/token_limit.json")
	_write_json(U4_SAVE_ROOT.path_join("preset_snapshot.json"), JSON.parse_string(snapshot_text))
	var corrupt := FileAccess.open(U4_SAVE_ROOT.path_join("corrupt.json"), FileAccess.WRITE)
	corrupt.store_string("not json")
	corrupt.close()
	_write_json(U4_SAVE_ROOT.path_join("too_new.json"), {
		"schema_version": 99, "kind": "replay", "player_count": 2,
	})
	_write_json(U4_SAVE_ROOT.path_join("unknown.json"), {
		"schema_version": 1, "kind": "mystery", "player_count": 2,
	})

	var browser: UiSaveBrowser = load("res://ui/screens/save_browser/save_browser.tscn").instantiate()
	browser.configure(store)
	get_tree().root.add_child(browser)
	await get_tree().process_frame
	_check(browser.row_count() == 6, "U4 读档列表包含全部文件")
	_check(browser.selected_entry() != null, "U4 默认选中第一份存档")
	_check(browser.details_integrity_text().contains("✓"), "U4 选中时校验可以完整重放")
	_check(browser.continue_button() != null and not browser.continue_button().disabled,
			"U4 可读存档的继续按钮启用")

	var corrupt_entry: UiSaveEntry = null
	var read_only_entry: UiSaveEntry = null
	var quick_entry: UiSaveEntry = null
	for entry: UiSaveEntry in browser.entries():
		match entry.file_name:
			"corrupt.json":
				corrupt_entry = entry
			"preset_snapshot.json":
				read_only_entry = entry
			"quick.json":
				quick_entry = entry
	_check(corrupt_entry != null and not corrupt_entry.readable(), "U4 损坏存档留在列表里")
	_check(read_only_entry != null and read_only_entry.read_only, "U4 预设局面只读")
	if corrupt_entry != null:
		browser.select_path(corrupt_entry.path)
		_check(browser.find_child("DetailReason", true, false) != null, "U4 损坏存档写明原因")
		_check(browser.continue_button() == null, "U4 损坏存档没有继续按钮")
	if read_only_entry != null:
		browser.select_path(read_only_entry.path)
		_check(browser.delete_button() != null and browser.delete_button().disabled,
				"U4 只读存档删除按钮禁用")
	if quick_entry != null:
		browser.select_path(quick_entry.path)
		browser.request_delete()
		_check(browser.confirm_modal_visible(), "U4 删除前二次确认")
		browser.confirm_delete()
		await get_tree().process_frame
		_check(not FileAccess.file_exists(U4_SAVE_ROOT.path_join("quick.json")),
				"U4 确认后删除存档")
		_check(browser.row_count() == 5, "U4 删除后列表刷新")

	var selected: Array[UiSaveEntry] = []
	browser.continue_requested.connect(func(entry: UiSaveEntry) -> void: selected.append(entry))
	browser.select_path(U4_SAVE_ROOT.path_join("autosave.json"))
	if browser.continue_button() != null:
		browser.continue_button().pressed.emit()
	_check(selected.size() == 1 and selected[0].is_autosave, "U4 继续按钮发出选中存档")
	browser.queue_free()
	await get_tree().process_frame
	await _u4_free_store(store)
	_u4_wipe(U4_SAVE_ROOT)


func _check_u4_error_modals() -> void:
	var data_modal := UiErrorModal.new()
	get_tree().root.add_child(data_modal)
	await get_tree().process_frame
	data_modal.setup_data_errors(["cards.json：文件不存在", "rules.json：win_points 应为正数"])
	var title := data_modal.find_child("Title", true, false) as Label
	_check(title != null and title.text == "游戏数据有问题，没法开局", "U4 数据错误弹窗标题")
	var error_list := data_modal.find_child("ErrorList", true, false)
	_check(error_list != null and error_list.get_child_count() == 2, "U4 数据错误逐条列出")
	_check(data_modal.find_child("ErrorCopy", true, false) != null, "U4 复制错误按钮")
	var quit_requested: Array[bool] = []
	data_modal.exit_requested.connect(func() -> void: quit_requested.append(true))
	(data_modal.find_child("ErrorQuit", true, false) as Button).pressed.emit()
	_check(quit_requested == [true], "U4 数据错误弹窗退出信号")
	data_modal.queue_free()
	await get_tree().process_frame

	var version_modal := UiErrorModal.new()
	get_tree().root.add_child(version_modal)
	await get_tree().process_frame
	version_modal.setup_save_error(UiSaveEntry.REASON_VERSION_TOO_NEW, "版本 99")
	_check(_modal_text(version_modal).contains("更新版本"), "U4 版本太新文案")
	version_modal.queue_free()
	await get_tree().process_frame

	var verify_modal := UiErrorModal.new()
	get_tree().root.add_child(verify_modal)
	await get_tree().process_frame
	verify_modal.setup_save_error(UiSaveEntry.REASON_VERIFY_FAILED, "指纹不一致", 37)
	_check(_modal_text(verify_modal).contains("第 37 步"), "U4 重放校验失败写步数")
	_check(verify_modal.find_child("SaveErrorBack", true, false) != null, "U4 存档错误返回列表")
	_check(verify_modal.find_child("SaveErrorReadUntil", true, false) == null,
			"U4 IR-03 前不显示读到某步")
	verify_modal.queue_free()
	await get_tree().process_frame


func _modal_text(modal: UiErrorModal) -> String:
	var text: String = ""
	for node: Node in modal.find_children("*", "Label", true, false):
		text += (node as Label).text + "\n"
	return text


func _check_u4_pause_rules() -> void:
	var store: UiSaveStore = _u4_new_store()
	var parts := await _u3_host(store)
	var session: UiTableSession = parts[2]
	var flow: UiTableFlow = parts[3]
	_check(_u3_start_humans(parts, 2, 20261023), "U4 暂停菜单测试开局")
	await get_tree().process_frame
	flow.open_pause()
	_check(flow.is_paused() and flow.pause_menu() != null, "U4 Esc / 菜单打开暂停")
	var pause: UiPauseMenu = flow.pause_menu()
	_check(pause.save_button().disabled == false, "U4 可保存的局保存按钮启用")
	var rules_text: String = ""
	for line: Dictionary in UiRulesPanel.lines(session.rules()):
		rules_text += String(line.get("text", ""))
	_check(rules_text.contains(str(int(session.rules().win_points))), "U4 规则速查含胜利分")
	_check(rules_text.contains(str(int(session.rules().max_tokens))), "U4 规则速查含持币上限")
	pause.request_exit_confirm()
	_check((pause.find_child("ExitConfirmRow", true, false) as Control).visible,
			"U4 退出前展开二次确认")
	pause.cancel_exit_confirm()
	_check((pause.find_child("ExitRow", true, false) as Control).visible, "U4 取消退出确认")
	flow.quick_save()
	_check(FileAccess.file_exists(U4_SAVE_ROOT.path_join("quick.json")), "U4 快速存档写入")
	flow.close_pause()
	_check(not flow.is_paused(), "U4 关闭暂停")

	flow.open_rules()
	_check(flow.rules_visible(), "U4 顶栏规则打开速查")
	flow.close_rules()
	_check(not flow.rules_visible(), "U4 关闭规则速查")
	await _u3_cleanup(parts)

	# 弃宝石弹窗上还能叠开暂停（关掉后回到弃宝石）。
	var parts2 := await _u3_host(store)
	var flow2: UiTableFlow = parts2[3]
	var session2: UiTableSession = parts2[2]
	session2.load_snapshot(_u3_snapshot("token_limit"))
	await get_tree().process_frame
	var table2: UiTableScreen = parts2[1]
	table2.gem_chip_clicked.emit(Enums.GemColor.RED)
	table2.gem_chip_clicked.emit(Enums.GemColor.RED)
	table2.confirm_pressed.emit()
	await get_tree().process_frame
	_check(flow2.modal_kind() == "discard", "U4 预设局面进入弃宝石弹窗")
	flow2.open_pause()
	_check(flow2.is_paused(), "U4 弃宝石弹窗上叠开暂停")
	flow2.close_pause()
	_check(flow2.modal_kind() == "discard", "U4 关闭暂停后回到弃宝石弹窗")
	await _u3_cleanup(parts2)
	await _u4_free_store(store)
	_u4_wipe(U4_SAVE_ROOT)


func _check_u4_hotseat_cover() -> void:
	var store: UiSaveStore = _u4_new_store()
	var parts := await _u3_host(store)
	var table: UiTableScreen = parts[1]
	var session: UiTableSession = parts[2]
	var flow: UiTableFlow = parts[3]
	flow.set_hotseat_cover_enabled(true)
	var seats: Array[Dictionary] = _u3_seats(2)
	_check(session.start_local({"count": 2, "seed": 20261024, "seats": seats,
			"hotseat_cover": true}), "U4 同屏两人局开局")
	await get_tree().process_frame
	_check(flow.cover_visible(), "U4 开局先显示换人遮挡")
	_check(flow.cover_seat() == 0, "U4 遮挡指向座位 1")
	_check(table.my_panel().get_render_data().is_empty(), "U4 遮挡期间不渲染私密信息")
	flow.dismiss_cover()
	_check(not flow.cover_visible(), "U4 点开始后收起遮挡")
	_check(int(table.my_panel().get_render_data().get("seat", -1)) == 0,
			"U4 遮挡收起后渲染座位 1")
	var colors: Array[int] = flow.clickable_colors()
	for index: int in 3:
		flow.click_color(colors[index])
	flow.confirm()
	await get_tree().process_frame
	_check(flow.cover_visible(), "U4 换到另一位人类时再次遮挡")
	_check(flow.cover_seat() == 1, "U4 遮挡指向座位 2")
	_check(flow.cover_summary().contains("拿了"), "U4 遮挡总结上一位的动作")
	flow.dismiss_cover()
	_check(int(table.my_panel().get_render_data().get("seat", -1)) == 1,
			"U4 收起后渲染座位 2")
	await _u3_cleanup(parts)
	await _u4_free_store(store)
	_u4_wipe(U4_SAVE_ROOT)


func _check_u4_flow_autosave() -> void:
	var store: UiSaveStore = _u4_new_store()
	var parts := await _u3_host(store)
	var session: UiTableSession = parts[2]
	var flow: UiTableFlow = parts[3]
	_check(_u3_start_humans(parts, 2, 20261025), "U4 自动存档测试开局")
	await get_tree().process_frame
	var colors: Array[int] = flow.clickable_colors()
	for index: int in 3:
		flow.click_color(colors[index])
	flow.confirm()
	await get_tree().process_frame
	var entry: UiSaveEntry = store.autosave_entry()
	_check(entry != null, "U4 回合结束写自动存档")
	if entry != null:
		_check(entry.names() == ["小明", "薄荷"], "U4 自动存档带名字")
		_check(int(entry.summary().get("round", 0)) >= 1, "U4 自动存档带轮数")
	await _u3_cleanup(parts)

	# 用一份已经打完的回放继续：载入后立刻结算并转存 finished。
	var finished_data: Dictionary = _u4_play_replay_data(20261026, 2)
	_check(not finished_data.is_empty(), "U4 能生成完整对局回放")
	store.save_autosave(finished_data, _u4_make_meta(["小明", "薄荷"],
			["human", "human"], 20))
	var finished_entry: UiSaveEntry = store.autosave_entry()
	_check(finished_entry != null, "U4 完整对局存档在列表里")
	var parts2 := await _u3_host(store)
	var session2: UiTableSession = parts2[2]
	var flow2: UiTableFlow = parts2[3]
	var errors: Array[String] = []
	_check(session2.resume(finished_entry, errors), "U4 可以直接继续已结束的回放")
	await get_tree().process_frame
	_check(String(session2.view().get("phase", "")) == "finished", "U4 继续后进入结束状态")
	_check(flow2.result_saved(), "U4 对局结束自动转存 finished")
	_check(not FileAccess.file_exists(U4_SAVE_ROOT.path_join("autosave.json")),
			"U4 结束转存后自动存档移除")
	var has_finished: bool = false
	for item: UiSaveEntry in store.list():
		if item.is_finished:
			has_finished = true
	_check(has_finished, "U4 列表出现结束记录")
	var table2: UiTableScreen = parts2[1]
	var result_modal: Control = table2.modal_control()
	_check(result_modal != null and result_modal.name == "ResultModal", "U4 结算弹窗出现")
	if result_modal != null:
		var save_button := result_modal.find_child("ResultSaveReplay", true, false) as Button
		_check(save_button != null and save_button.disabled and save_button.text == "已保存回放",
				"U4 结算弹窗显示已保存回放")
		var rematch_button := result_modal.find_child("ResultRematch", true, false) as Button
		var main_menu_button := result_modal.find_child("ResultMainMenu", true, false) as Button
		_check(rematch_button != null and main_menu_button != null, "U4 结算弹窗有再来一局 / 回主菜单")
		var rematches: Array[Dictionary] = []
		flow2.rematch_requested.connect(func(setup: Dictionary) -> void: rematches.append(setup))
		if rematch_button != null:
			rematch_button.pressed.emit()
		_check(rematches.size() == 1 and int(rematches[0].get("count", 0)) == 2,
				"U4 再来一局沿用人数")
		var rematch_seed_ok: bool = false
		if not rematches.is_empty():
			rematch_seed_ok = int(rematches[0].get("seed", 0)) == -1
		_check(rematch_seed_ok, "U4 再来一局用新种子")
		var leaves: Array[bool] = []
		flow2.leave_requested.connect(func() -> void: leaves.append(true))
		if main_menu_button != null:
			main_menu_button.pressed.emit()
		_check(leaves == [true], "U4 结算弹窗回主菜单")
	await _u3_cleanup(parts2)
	await _u4_free_store(store)
	_u4_wipe(U4_SAVE_ROOT)


func _check_u4_app_flow() -> void:
	UiSaveStore.root_override = U4_SAVE_ROOT
	_u4_wipe(U4_SAVE_ROOT)
	var app: Control = load(APP_PATH).instantiate()
	get_tree().root.add_child(app)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(app.main_menu() != null, "U4 启动直接进主菜单")
	_check(app.session() == null, "U4 主菜单没有会话")
	app.show_local_setup()
	await get_tree().process_frame
	await get_tree().process_frame
	var setup: UiLocalSetup = app.local_setup()
	_check(setup != null, "U4 主菜单能进本地设置")
	setup.apply_preset("hotseat")
	setup.set_hotseat_cover(false)
	setup.set_seed_text("20261027")
	setup.start_pressed()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(app.session() != null and app.table() != null and app.flow() != null,
			"U4 设置界面能开一局")
	_check(app.current_screen() == app.table(), "U4 开局后当前屏幕是牌桌")
	var session: UiTableSession = app.session()
	var flow: UiTableFlow = app.flow()
	var colors: Array[int] = flow.clickable_colors()
	for index: int in 3:
		flow.click_color(colors[index])
	flow.confirm()
	await get_tree().process_frame
	var fingerprint: String = session.fingerprint()
	var current_seat: int = int(session.view().get("current_seat", -1))
	_check(app.store().autosave_entry() != null, "U4 对局中产生自动存档")
	flow.open_pause()
	var pause: UiPauseMenu = flow.pause_menu()
	(pause.find_child("PauseLoad", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(app.save_browser() != null, "U4 暂停菜单能打开读档")
	_check(app.screen_stack_size() == 1 and not app.table().visible, "U4 读档时牌桌留在栈底")
	app.save_browser().back_button().pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(app.current_screen() == app.table() and app.table().visible, "U4 从读档返回牌桌")
	_check(app.session().fingerprint() == fingerprint, "U4 读档往返后牌桌状态不变")
	app.show_save_browser(true)
	await get_tree().process_frame
	await get_tree().process_frame
	var browser2: UiSaveBrowser = app.save_browser()
	_check(browser2 != null, "U4 再次打开读档")
	if browser2 != null:
		browser2.select_path(U4_SAVE_ROOT.path_join("autosave.json"))
		if browser2.continue_button() != null:
			browser2.continue_button().pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(app.current_screen() == app.table() and app.session() != null,
			"U4 从读档列表继续这局")
	_check(app.session().fingerprint() == fingerprint if app.session() != null else false,
			"U4 从读档列表继续后状态一致")
	_check(app.screen_stack_size() == 0, "U4 从读档列表继续后清空返回栈")
	app.back_to_main_menu()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(app.main_menu() != null, "U4 牌桌能回主菜单")
	_check(app.main_menu().continue_button().visible, "U4 主菜单显示继续上一局")
	_check(app.main_menu().continue_button().subtitle.contains("人"),
			"U4 继续按钮带摘要")
	app.continue_last_game()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(app.session() != null, "U4 继续上一局恢复会话")
	if app.session() != null:
		_check(app.session().fingerprint() == fingerprint, "U4 继续后状态一致")
		_check(int(app.session().view().get("current_seat", -1)) == current_seat,
				"U4 继续后轮到同一座位")
		_check(app.session().names()[0] == "小明", "U4 继续后名字恢复")
	app.back_to_main_menu()
	await get_tree().process_frame
	app.queue_free()
	await get_tree().process_frame
	UiSaveStore.root_override = ""
	_u4_wipe(U4_SAVE_ROOT)


# ---------------------------------------------------------------- U5：动效与反馈

func _check_u5_settings() -> void:
	UiSettings.reset_defaults()
	_check(UiSettings.animations_enabled(), "U5 动效默认开启")
	_check(UiSettings.anim_speed() == UiSettings.SPEED_NORMAL, "U5 动画速度默认标准")
	_check(is_equal_approx(UiSettings.speed_multiplier(), 1.0), "U5 标准速度倍率 1")
	UiSettings.set_anim_speed(UiSettings.SPEED_SLOW)
	_check(is_equal_approx(UiSettings.speed_multiplier(), 1.5), "U5 慢速倍率 1.5")
	UiSettings.set_anim_speed(UiSettings.SPEED_FAST)
	_check(is_equal_approx(UiSettings.speed_multiplier(), 0.5), "U5 快速倍率 0.5")
	UiSettings.set_anim_speed("bogus")
	_check(UiSettings.anim_speed() == UiSettings.SPEED_NORMAL, "U5 未知速度回退标准")

	UiSettings.set_animations_enabled(false)
	_check(not UiSettings.animations_enabled(), "U5 动效可以关闭")
	UiSettings.set_animations_enabled(true)
	_check(UiSettings.animations_enabled(), "U5 动效可以打开")

	UiSettings.set_sfx_enabled(false)
	UiSfx.clear_calls()
	UiSfx.play("take")
	_check(UiSfx.take_calls().is_empty(), "U5 音效关闭时不播放")
	UiSettings.set_sfx_enabled(true)
	UiSfx.clear_calls()
	UiSfx.play("take")
	var calls: Array[String] = UiSfx.take_calls()
	_check(calls == ["take"], "U5 音效打开时记录调用点")
	var button := UiButton.new()
	add_child(button)
	button.pressed.emit()
	_check(UiSfx.take_calls().has("click"), "U5 按钮点击接入音效钩子")
	button.queue_free()
	_check(not FileAccess.file_exists(UiSfx.DIR + "gems_taken.wav"), "U5 音效素材暂时为空")
	UiSettings.set_sfx_enabled(false)
	UiSettings.reset_defaults()
	UiSettings.set_animations_enabled(false)
	UiSettings.set_sfx_enabled(false)


func _u5_fixture_host(fixture_name: String) -> Array:
	await get_tree().process_frame
	var host := Control.new()
	host.name = "UiU5FixtureHost"
	host.theme = load(THEME_PATH)
	host.size = Vector2(1280, 800)
	get_tree().root.add_child(host)
	var table: UiTableScreen = load(TABLE_SCENE).instantiate()
	table.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(table)
	var fixture := UiFixtureLoader.load_fixture(fixture_name)
	await get_tree().process_frame
	await get_tree().process_frame
	table.render(fixture["view"], int(fixture["me_seat"]), fixture["session_info"])
	await get_tree().process_frame
	await get_tree().process_frame
	return [host, table, fixture]


func _check_u5_animation_targets() -> void:
	var parts: Array = await _u5_fixture_host("g3_turn_mine")
	var table: UiTableScreen = parts[1]
	var fixture: Dictionary = parts[2]
	var view: Dictionary = fixture["view"]
	var me_seat: int = int(fixture["me_seat"])
	_check(table.animation_layer() != null, "U5 动效层存在")
	_check(table.animation_layer().z_index == 90, "U5 动效层在弹窗之下")
	_check(table.animation_layer().mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"U5 动效层不拦截鼠标")
	_check(table.bank_chip_rect(Enums.GemColor.WHITE).size.x > 0.0, "U5 银行筹码定位")
	var first_card: String = String((view["boards"]["1"] as Array)[0])
	_check(table.market_card_rect(first_card).size.x > 0.0, "U5 市场卡定位")
	_check(table.market_slot_rect(1, 0).size.x > 0.0, "U5 市场卡位定位")
	_check(table.deck_rect(1).size.x > 0.0, "U5 牌堆定位")
	_check(table.noble_rect(String((view["nobles"] as Array)[0])).size.x > 0.0, "U5 贵族定位")
	_check(table.seat_panel_rect(me_seat).size.x > 0.0, "U5 玩家面板定位")
	_check(table.seat_token_rect(me_seat, Enums.GemColor.WHITE).size.x > 0.0, "U5 玩家筹码定位")
	_check(table.seat_score_control(me_seat) != null, "U5 分数控件存在")
	_check(table.seat_bonus_control(me_seat, Enums.GemColor.WHITE) != null, "U5 折扣块存在")
	_check(table.reserved_card_rect("L2-K-04").size.x > 0.0, "U5 我的预留卡定位")

	# 卡位光晕：session_info.flash_slots 命中时，该卡位进入两帧闪烁。
	var info: Dictionary = (fixture["session_info"] as Dictionary).duplicate(true)
	info["flash_slots"] = [Vector2i(1, 0)]
	table.render(view, me_seat, info)
	await get_tree().process_frame
	var card: UiDevCard = table.find_child("Card1_0", true, false) as UiDevCard
	_check(card != null and card.flash, "U5 卡位光晕命中新补的牌")
	var parts2: Array = await _u5_fixture_host("g4_endgame")
	var table2: UiTableScreen = parts2[1]
	var tag: Control = table2.endgame_tag_control()
	_check(tag != null and tag.visible, "U5 终局轮标签可定位")
	for part: Array in [parts, parts2]:
		(part[0] as Control).queue_free()
	await get_tree().process_frame


func _u5_first_action(legal: Array[Action], type: int) -> Action:
	for action: Action in legal:
		if action.type == type:
			return action
	return null


func _u5_view_snapshot(view: Dictionary) -> Dictionary:
	return {
		"current_seat": int(view.get("current_seat", -1)),
		"phase": String(view.get("phase", "")),
		"boards": view.get("boards", {}),
		"bank": view.get("bank", {}),
		"players": view.get("players", []),
		"nobles": view.get("nobles", []),
		"endgame_triggered": bool(view.get("endgame_triggered", false)),
	}


func _u5_wait_idle(flow: UiTableFlow, timeout_ms: int = 8000) -> bool:
	var start: int = Time.get_ticks_msec()
	while flow.is_animating() and Time.get_ticks_msec() - start < timeout_ms:
		await get_tree().process_frame
	return not flow.is_animating()


func _check_u5_flash_slots() -> void:
	UiSettings.set_animations_enabled(false)
	var parts: Array = await _u3_host()
	if not _u3_start_humans(parts, 2, 20261018):
		_check(false, "U5 预留光晕检查开局")
		await _u3_cleanup(parts)
		return
	await get_tree().process_frame
	var session: UiTableSession = parts[2]
	var flow: UiTableFlow = parts[3]
	var reserve: Action = _u5_first_action(session.legal_actions(), Enums.ActionType.RESERVE)
	_check(reserve != null, "U5 开局有预留动作")
	if reserve != null:
		_check(session.submit(reserve), "U5 预留提交成功")
		await get_tree().process_frame
		await get_tree().process_frame
		_check(not flow.is_animating(), "U5 关闭动效时视图立即落地")
		_check(flow.flash_cards().has(reserve.card_id), "U5 预留的卡进入光晕列表")
		_check(not flow.flash_slots().is_empty(), "U5 补牌卡位进入光晕列表")
	await _u3_cleanup(parts)


func _check_u5_animation_on_off() -> void:
	# 关闭动效：动作后立即落地。
	UiSettings.set_animations_enabled(false)
	UiSettings.set_sfx_enabled(false)
	var off_parts: Array = await _u3_host()
	if not _u3_start_humans(off_parts, 2, 20261018):
		_check(false, "U5 动效对比开局（关）")
		await _u3_cleanup(off_parts)
		return
	await get_tree().process_frame
	var off_session: UiTableSession = off_parts[2]
	var off_flow: UiTableFlow = off_parts[3]
	var take: Action = _u5_first_action(off_session.legal_actions(), Enums.ActionType.TAKE_THREE)
	if take == null:
		take = _u5_first_action(off_session.legal_actions(), Enums.ActionType.TAKE_TWO)
	_check(take != null, "U5 开局有拿宝石动作")
	if take == null:
		await _u3_cleanup(off_parts)
		return
	_check(off_session.submit(take), "U5 关闭动效的提交成功")
	await get_tree().process_frame
	if not off_session.legal_actions().is_empty():
		_check(not off_flow.is_animating(), "U5 关闭动效时不产生动画")
	var off_snapshot: Dictionary = _u5_view_snapshot(off_flow.displayed_view())
	var off_fingerprint: String = off_session.fingerprint()
	var off_market: Dictionary = (off_parts[1] as UiTableScreen).market_card_ids()
	var off_bank: Dictionary = (off_parts[1] as UiTableScreen).bank_column().get_counts()
	await _u3_cleanup(off_parts)

	# 打开动效：同一动作先停在起点，播完后落到同一状态。
	UiSettings.set_animations_enabled(true)
	UiSettings.set_anim_speed(UiSettings.SPEED_NORMAL)
	var on_parts: Array = await _u3_host()
	if not _u3_start_humans(on_parts, 2, 20261018):
		_check(false, "U5 动效对比开局（开）")
		await _u3_cleanup(on_parts)
		return
	await get_tree().process_frame
	var on_session: UiTableSession = on_parts[2]
	var on_flow: UiTableFlow = on_parts[3]
	var on_take: Action = null
	for legal: Action in on_session.legal_actions():
		if legal.equals(take):
			on_take = legal
			break
	_check(on_take != null, "U5 同一动作在相同种子下合法")
	if on_take != null:
		var start_seat: int = int(on_flow.displayed_view().get("current_seat", -1))
		_check(on_session.submit(on_take), "U5 打开动效的提交成功")
		await get_tree().process_frame
		_check(on_flow.is_animating(), "U5 打开动效时动作先播动画")
		_check(on_flow.last_animation_visuals() >= on_take.colors.size(),
				"U5 拿宝石生成逐个筹码")
		_check(int(on_flow.displayed_view().get("current_seat", -1)) == start_seat,
				"U5 动效期间牌桌停在起点")
		var idle_ok: bool = await _u5_wait_idle(on_flow)
		_check(idle_ok, "U5 动效队列在超时前播完")
		_check(_u5_view_snapshot(on_flow.displayed_view()) == off_snapshot,
				"U5 动效开 / 关最终视图一致")
		_check(on_session.fingerprint() == off_fingerprint, "U5 动效开 / 关最终指纹一致")
		_check((on_parts[1] as UiTableScreen).market_card_ids() == off_market,
				"U5 动效开 / 关最终市场一致")
		_check((on_parts[1] as UiTableScreen).bank_column().get_counts() == off_bank,
				"U5 动效开 / 关最终银行一致")
	await _u3_cleanup(on_parts)
	UiSettings.set_animations_enabled(false)


func _check_u5_fast_forward() -> void:
	UiSettings.set_animations_enabled(true)
	UiSettings.set_anim_speed(UiSettings.SPEED_NORMAL)
	var parts: Array = await _u3_host()
	if not _u3_start_humans(parts, 2, 20261027):
		_check(false, "U5 积压快进开局")
		await _u3_cleanup(parts)
		return
	await get_tree().process_frame
	var session: UiTableSession = parts[2]
	var flow: UiTableFlow = parts[3]
	var submitted: int = 0
	for _i: int in 5:
		var legal: Array[Action] = session.legal_actions()
		if legal.is_empty():
			break
		var action: Action = _u5_first_action(legal, Enums.ActionType.TAKE_THREE)
		if action == null:
			action = legal[0]
		if not session.submit(action):
			break
		submitted += 1
	_check(submitted >= 4, "U5 连续快速提交 4 个以上动作")
	await get_tree().process_frame
	_check(flow.pending_animation_batches() <= 2, "U5 积压超过 2 批后快进")
	var idle_ok: bool = await _u5_wait_idle(flow)
	_check(idle_ok, "U5 快速提交后动效队列不卡死")
	_check(_u5_view_snapshot(flow.displayed_view()) == _u5_view_snapshot(session.view()),
			"U5 快速提交后牌桌追上最新视图")
	_check(not flow.is_animating() and flow.pending_animation_batches() == 0,
			"U5 快速提交后没有残留批次")
	await _u3_cleanup(parts)
	UiSettings.set_animations_enabled(false)


func _check_u5_skip_and_speed() -> void:
	UiSettings.set_animations_enabled(true)
	UiSettings.set_anim_speed(UiSettings.SPEED_NORMAL)
	var parts: Array = await _u3_host()
	if not _u3_start_humans(parts, 2, 20261101):
		_check(false, "U5 跳过动效开局")
		await _u3_cleanup(parts)
		return
	await get_tree().process_frame
	var session: UiTableSession = parts[2]
	var flow: UiTableFlow = parts[3]
	var take: Action = _u5_first_action(session.legal_actions(), Enums.ActionType.TAKE_THREE)
	_check(take != null, "U5 跳过检查有拿宝石动作")
	if take != null:
		UiSettings.set_sfx_enabled(true)
		UiSfx.clear_calls()
		_check(session.submit(take), "U5 跳过检查提交成功")
		await get_tree().process_frame
		_check(flow.is_animating(), "U5 跳过前正在播放")
		_check(UiSfx.take_calls().has("take"), "U5 动效事件触发音效钩子")
		UiSettings.set_sfx_enabled(false)
		var duration: float = flow.last_animation_duration()
		_check(duration > 0.0, "U5 标准速度有动画时长")
		flow.skip_animation()
		_check(not flow.is_animating(), "U5 跳过立即结束动效")
		_check(flow.pending_animation_batches() == 0, "U5 跳过清空积压")
		_check(_u5_view_snapshot(flow.displayed_view()) == _u5_view_snapshot(session.view()),
				"U5 跳过后直接落在最新视图")
		var expected: float = (take.colors.size() - 1) * UiTableAnim.COIN_STAGGER \
				+ UiTableAnim.COIN_FLIGHT + UiTableAnim.TAIL
		_check(is_equal_approx(duration, expected), "U5 拿 %d 色筹码的标准时长" % take.colors.size())
	await _u3_cleanup(parts)

	# 速度倍率：同一动作在快速设置下时长减半。
	UiSettings.set_anim_speed(UiSettings.SPEED_FAST)
	var fast_parts: Array = await _u3_host()
	if not _u3_start_humans(fast_parts, 2, 20261101):
		_check(false, "U5 快速设置开局")
		await _u3_cleanup(fast_parts)
	else:
		await get_tree().process_frame
		var fast_session: UiTableSession = fast_parts[2]
		var fast_flow: UiTableFlow = fast_parts[3]
		var fast_take: Action = _u5_first_action(fast_session.legal_actions(),
				Enums.ActionType.TAKE_THREE)
		if fast_take != null:
			fast_session.submit(fast_take)
			await get_tree().process_frame
			var expected_fast: float = ((fast_take.colors.size() - 1) * UiTableAnim.COIN_STAGGER \
					+ UiTableAnim.COIN_FLIGHT + UiTableAnim.TAIL) * 0.5
			_check(is_equal_approx(fast_flow.last_animation_duration(), expected_fast),
					"U5 快速设置时长减半")
			await _u5_wait_idle(fast_flow)
		await _u3_cleanup(fast_parts)

	# 动效播放中直接关闭对局：节点释放不能报错或卡住。
	UiSettings.set_anim_speed(UiSettings.SPEED_NORMAL)
	var close_parts: Array = await _u3_host()
	if _u3_start_humans(close_parts, 2, 20261101):
		await get_tree().process_frame
		var close_session: UiTableSession = close_parts[2]
		var close_flow: UiTableFlow = close_parts[3]
		var close_take: Action = _u5_first_action(close_session.legal_actions(),
				Enums.ActionType.TAKE_THREE)
		if close_take != null:
			close_session.submit(close_take)
			await get_tree().process_frame
			_check(close_flow.is_animating(), "U5 关闭前正在播动效")
			var host: Control = close_parts[0]
			await _u3_cleanup(close_parts)
			await get_tree().process_frame
			_check(not is_instance_valid(host), "U5 动效中关闭对局可以正常释放")
		else:
			await _u3_cleanup(close_parts)
	else:
		await _u3_cleanup(close_parts)
	UiSettings.set_animations_enabled(false)


## 4 个电脑观战：动效持续播放时队列必须有界，画面不能越落越远。
func _check_u5_bot_spectator() -> void:
	UiSettings.set_animations_enabled(true)
	UiSettings.set_anim_speed(UiSettings.SPEED_NORMAL)
	var parts: Array = await _u3_host()
	var session: UiTableSession = parts[2]
	var flow: UiTableFlow = parts[3]
	var seats: Array[Dictionary] = []
	for seat: int in 4:
		seats.append({"name": "电脑%d" % (seat + 1), "type": "bot_easy"})
	var ok: bool = session.start_local({"count": 4, "seed": 20261102, "seats": seats})
	_check(ok, "U5 4 个电脑观战可以开局")
	if ok:
		for _i: int in 10:
			await get_tree().create_timer(0.5).timeout
			_check(flow.pending_animation_batches() <= 2,
					"U5 电脑观战动效积压有界")
		var displayed: Dictionary = flow.displayed_view()
		var live: Dictionary = session.view()
		_check(not displayed.is_empty() and not live.is_empty(), "U5 观战有视图")
		_check(flow.pending_animation_batches() <= 2, "U5 观战后动效积压仍 <= 2")
		var displayed_turns: int = _u5_turn_total(displayed)
		var live_turns: int = _u5_turn_total(live)
		_check(live_turns - displayed_turns <= 3,
				"U5 观战画面不会越播越落后（差 %d 回合）" % (live_turns - displayed_turns))
	_check(not session.is_my_turn(), "U5 全电脑观战没有可操作回合")
	await _u3_cleanup(parts)
	UiSettings.set_animations_enabled(false)


func _u5_turn_total(view: Dictionary) -> int:
	var counts: Array = view.get("turn_counts", [])
	var total: int = 0
	for value: Variant in counts:
		total += int(value)
	return total


## 动效开着的终局：结算要等队列播完，game_ended 不能被中间视图清掉。
func _check_u5_endgame() -> void:
	UiSettings.set_animations_enabled(true)
	UiSettings.set_anim_speed(UiSettings.SPEED_FAST)
	var parts: Array = await _u3_host()
	var session: UiTableSession = parts[2]
	var flow: UiTableFlow = parts[3]
	var errors: Array[String] = []
	if not session.load_snapshot(_u3_snapshot("endgame"), errors):
		_check(false, "U5 动效终局局面可以载入")
		await _u3_cleanup(parts)
		return
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
	_check(purchase != null, "U5 动效终局有计分购买")
	if purchase != null:
		flow.click_card("market", purchase.card_id, 0)
		flow.purchase_selected()
		await get_tree().process_frame
		_check(flow.is_animating(), "U5 终局动作先播动效")
		var legal1: Array[Action] = session.legal_actions()
		if not legal1.is_empty():
			session.submit(legal1[0])
		var idle_ok: bool = await _u5_wait_idle(flow, 10000)
		_check(idle_ok, "U5 终局动效队列播完")
		_check(String(session.view().get("phase", "")) == "finished", "U5 动效终局结束")
		_check(not flow.result().is_empty(), "U5 动效终局产生结算数据")
		_check(flow.modal_kind() == "result", "U5 动效播完后打开结算弹窗")
		_check(not flow.is_animating(), "U5 结算后没有残留动效")
	await _u3_cleanup(parts)
	UiSettings.set_animations_enabled(false)


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


# ---------------------------------------------------------------- U6：回放

const U6_REPLAY_PATH: String = "res://ui/screens/replay/replay_screen.tscn"


## 按固定策略跑一局（优先盲抽预留 / 购买，其余走合法列表），记录每一步之后的公开视图。
func _u6_play(seed_value: int = 20261101, count: int = 2,
		max_steps: int = 160) -> Dictionary:
	var host := Node.new()
	get_tree().root.add_child(host)
	var session := UiTableSession.new()
	host.add_child(session)
	var seats: Array[Dictionary] = []
	for seat: int in count:
		seats.append({"name": ["小明", "薄荷", "紫晶", "橘子"][seat], "type": "human"})
	var ok: bool = session.start_local({"count": count, "seed": seed_value, "seats": seats})
	var views: Array[Dictionary] = []
	views.append(UiTableSession.sanitize_view(session.view(), -1, {}))
	var steps: int = 0
	while ok and steps < max_steps and String(session.view().get("phase", "")) != "finished":
		var legal: Array[Action] = session.legal_actions()
		if legal.is_empty():
			break
		var action: Action = _u6_pick(legal, steps)
		if not session.submit(action):
			break
		steps += 1
		views.append(UiTableSession.sanitize_view(session.view(), -1, {}))
	var data: Dictionary = session.build_save_data()
	var fingerprint: String = session.fingerprint()
	var names: Array[String] = session.names()
	var types: Array[String] = session.original_seat_types()
	session.close()
	host.queue_free()
	return {
		"data": data, "views": views, "fingerprint": fingerprint,
		"names": names, "types": types,
	}


func _u6_pick(legal: Array[Action], step: int) -> Action:
	if step % 4 == 0:
		for action: Action in legal:
			if action.type == Enums.ActionType.RESERVE and action.card_id.is_empty():
				return action
	if step % 4 == 1:
		for action: Action in legal:
			if action.type == Enums.ActionType.PURCHASE:
				return action
	for action: Action in legal:
		if action.type == Enums.ActionType.RESERVE:
			return action
	for action: Action in legal:
		if action.type == Enums.ActionType.PURCHASE:
			return action
	return legal[step % legal.size()]


func _u6_make_entry(game: Dictionary) -> UiSaveEntry:
	var data: Dictionary = game["data"]
	var entry := UiSaveEntry.new()
	entry.kind = "replay"
	entry.data = data
	entry.player_count = int(data.get("player_count", 0))
	entry.seed = int(data.get("seed", 0))
	var actions: Variant = data.get("actions", [])
	entry.action_count = (actions as Array).size() if actions is Array else 0
	entry.display_name = "测试回放"
	entry.ui_meta = {
		"names": game["names"], "seat_types": game["types"],
	}
	return entry


func _u6_view_has_blind(view: Dictionary, seat: int) -> bool:
	var players: Array = view.get("players", [])
	if seat < 0 or seat >= players.size():
		return false
	var player: Dictionary = players[seat] if players[seat] is Dictionary else {}
	for item: Variant in player.get("reserved", []):
		if item is Dictionary and bool((item as Dictionary).get("blind", false)) \
				and (item as Dictionary).get("id") != null:
			return true
	return false


func _u6_any_blind(view: Dictionary) -> bool:
	var players: Array = view.get("players", [])
	for seat: int in players.size():
		if _u6_view_has_blind(view, seat):
			return true
	return false


func _u6_market_ids(view: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var boards: Dictionary = view.get("boards", {})
	for level: int in [1, 2, 3]:
		var ids: Array[String] = []
		for item: Variant in boards.get(str(level), []):
			if item != null:
				ids.append(String(item))
		result[level] = ids
	return result


func _u6_bank_counts(view: Dictionary) -> Dictionary[int, int]:
	var result: Dictionary[int, int] = {}
	var bank: Dictionary = view.get("bank", {})
	for color: Enums.GemColor in Enums.ALL_COLORS:
		result[color] = int(bank.get(Enums.color_to_string(color), 0))
	return result


func _check_u6_source() -> void:
	var game: Dictionary = _u6_play()
	var views: Array = game["views"]
	_check(not game["data"].is_empty(), "U6 能跑出一局可回放数据")
	_check(views.size() >= 8, "U6 测试局有足够的步数")
	var entry: UiSaveEntry = _u6_make_entry(game)
	var host := Node.new()
	get_tree().root.add_child(host)
	var source := UiReplaySource.new()
	host.add_child(source)
	var errors: Array[String] = []
	_check(source.open(entry, errors), "U6 回放数据源能打开")
	_check(source.step_count() == views.size() - 1, "U6 步数等于动作数")
	_check(source.fingerprint() == String(game["fingerprint"]), "U6 最终指纹与原局一致")

	var all_match: bool = true
	var privacy_ok: bool = true
	for step: int in views.size():
		var public_view: Dictionary = source.public_view(step)
		if public_view != views[step]:
			all_match = false
		if _u6_any_blind(public_view):
			privacy_ok = false
	_check(all_match, "U6 每一步的公开视图和对局时记录的一致")
	_check(privacy_ok, "U6 全部公开视图不泄露任何盲抽")

	var revealed_step: int = -1
	var revealed_seat: int = -1
	for step: int in range(1, source.step_count() + 1):
		for seat: int in source.player_count():
			if source.blind_visible(step, seat):
				revealed_step = step
				revealed_seat = seat
				break
		if revealed_step >= 0:
			break
	_check(revealed_step >= 0, "U6 测试局里有可见的盲抽预留（覆盖隐私分支）")
	if revealed_step >= 0:
		_check(_u6_view_has_blind(source.view(revealed_step, revealed_seat), revealed_seat),
				"U6 行动者视角能看到自己的盲抽")
		var others_ok: bool = true
		for seat: int in source.player_count():
			if seat == revealed_seat:
				continue
			if _u6_view_has_blind(source.view(revealed_step, seat), seat):
				others_ok = false
		_check(others_ok, "U6 其他视角看不到该玩家的盲抽")
		var actor_view: Dictionary = source.view(revealed_step, revealed_seat)
		var others_hidden: bool = true
		for seat: int in source.player_count():
			if seat != revealed_seat and _u6_view_has_blind(actor_view, seat):
				others_hidden = false
		_check(others_hidden, "U6 行动者视角仍然隐藏其他人的盲抽")

	var texts_ok: bool = true
	for step: int in range(1, source.step_count() + 1):
		if source.step_text(step).is_empty():
			texts_ok = false
	_check(texts_ok, "U6 每一步都有中文说明")
	_check(source.actor_at(1) == int(views[0].get("current_seat", -1)),
			"U6 第一步的行动者与开局视图一致")
	_check(source.round_at(1) >= 1, "U6 步骤说明带轮次")
	var logs: Array[Dictionary] = source.log_entries(source.step_count())
	_check(not logs.is_empty() and String(logs[0].get("time", "")) == "#%d" % source.step_count(),
			"U6 日志按步编号且最新一条是当前步")

	# 动效事件：由动作 + 前后视图合成，类型与动作一致；购买支付与筹码差一致。
	var events_ok: bool = true
	var paid_ok: bool = true
	for step: int in range(1, source.step_count() + 1):
		var events: Array[Dictionary] = source.events_at(step)
		if events.is_empty():
			events_ok = false
			continue
		var action: Action = source.action_at(step)
		var first: Dictionary = events[0]
		var event_type: String = String(first.get("type", ""))
		match action.type:
			Enums.ActionType.TAKE_THREE:
				events_ok = events_ok and event_type == "gems_taken"
				var gems: Dictionary = first.get("gems", {})
				var total: int = 0
				for value: Variant in gems.values():
					total += int(value)
				events_ok = events_ok and total == action.colors.size()
			Enums.ActionType.TAKE_TWO:
				events_ok = events_ok and event_type == "gems_taken"
				var gems2: Dictionary = first.get("gems", {})
				events_ok = events_ok and int(gems2.values()[0]) == 2
			Enums.ActionType.RESERVE:
				events_ok = events_ok and event_type == "card_reserved"
				events_ok = events_ok \
						and bool(first.get("blind", false)) == action.card_id.is_empty()
			Enums.ActionType.PURCHASE:
				events_ok = events_ok and event_type == "card_purchased"
				events_ok = events_ok and String(first.get("card_id", "")) == action.card_id
				var before: Dictionary = source.public_view(step - 1)
				var after: Dictionary = source.public_view(step)
				var actor: int = source.actor_at(step)
				var paid: Dictionary = first.get("paid", {})
				for color: Enums.GemColor in Enums.ALL_COLORS:
					var expected: int = UiViewMath.token_count(before, actor, color) \
							- UiViewMath.token_count(after, actor, color)
					if int(paid.get(Enums.color_to_string(color), 0)) != expected:
						paid_ok = false
			Enums.ActionType.DISCARD:
				events_ok = events_ok and event_type == "gems_discarded"
			Enums.ActionType.CHOOSE_NOBLE:
				events_ok = events_ok and event_type == "noble_visited"
	_check(events_ok, "U6 每一步都能合成正确的动效事件")
	_check(paid_ok, "U6 购买事件的支付与前后视图一致")
	_check(source.events_at(0).is_empty(), "U6 开局没有动效事件")
	source.close()
	host.queue_free()


func _check_u6_replay_screen() -> void:
	var game: Dictionary = _u6_play(20261102, 2, 120)
	var entry: UiSaveEntry = _u6_make_entry(game)
	var host := Node.new()
	get_tree().root.add_child(host)
	var screen: UiReplayScreen = load(U6_REPLAY_PATH).instantiate()
	host.add_child(screen)
	await get_tree().process_frame
	var errors: Array[String] = []
	_check(screen.configure(entry, errors), "U6 回放屏能打开")
	_check(screen.step() == 0, "U6 打开时停在第 0 步")
	_check(screen.table() != null and screen.bar() != null, "U6 回放屏复用牌桌并带播放条")
	_check(screen.table().hud().pill_text().contains("回放"), "U6 顶栏胶囊写回放")
	_check(screen.bar().step_label_text().contains("第 0 /"), "U6 播放条显示步数")
	_check(screen.bar().legend_text().contains("小明") and screen.bar().legend_text().contains("薄荷"),
			"U6 时间轴图例列出每个玩家")

	var total: int = screen.step_count()
	var mid: int = mini(6, total)
	screen.seek(mid)
	_check(screen.step() == mid, "U6 能跳转到指定步")
	var expected: Dictionary = screen.source().public_view(mid)
	_check(screen.table().market_card_ids() == _u6_market_ids(expected), "U6 跳转后市场卡牌与视图一致")
	_check(screen.table().bank_column().get_counts() == _u6_bank_counts(expected),
			"U6 跳转后银行数字与视图一致")
	_check(screen.table().hud().pill_text().contains("第 %d / %d 步" % [mid, total]),
			"U6 胶囊显示当前步 / 总步数")
	_check(screen.bar().step_label_text().contains("第 %d / %d 步" % [mid, total]),
			"U6 播放条显示当前步 / 总步数")
	var timeline: UiReplayTimeline = screen.bar().timeline()
	timeline.size = Vector2(1000, 28)
	_check(timeline.step_at_x(0.0) == 0 and timeline.step_at_x(999.0) == total,
			"U6 时间轴点击能映射到步数")

	# 视角：找一个能看到盲抽的步与座位。
	var revealed_step: int = -1
	var revealed_seat: int = -1
	for step: int in range(1, total + 1):
		for seat: int in screen.source().player_count():
			if screen.source().blind_visible(step, seat):
				revealed_step = step
				revealed_seat = seat
				break
		if revealed_step >= 0:
			break
	if revealed_step >= 0:
		screen.seek(revealed_step)
		screen.set_viewer_seat(revealed_seat)
		_check(screen.viewer_seat() == revealed_seat, "U6 能切换视角")
		var panel: UiOpponentPanel = screen.table().opponent_panel(revealed_seat)
		_check(panel != null, "U6 视角对应的玩家面板存在")
		if panel != null:
			var reserved: Array = panel.get_render_data().get("reserved", [])
			var found_blind: bool = false
			for item: Variant in reserved:
				if item is Dictionary and bool((item as Dictionary).get("blind", false)):
					found_blind = (item as Dictionary).get("id") != null
			_check(found_blind, "U6 选中该座位时能显示他自己的盲抽")
		screen.set_viewer_seat(-1)
		if panel != null:
			var public_reserved: Array = panel.get_render_data().get("reserved", [])
			var leaked: bool = false
			for item: Variant in public_reserved:
				if item is Dictionary and bool((item as Dictionary).get("blind", false)) \
						and (item as Dictionary).get("id") != null:
					leaked = true
			_check(not leaked, "U6 全部公开时不显示盲抽")

	# 播放与速度。
	screen.seek(0)
	screen.toggle_play()
	_check(screen.is_playing(), "U6 能开始自动播放")
	await get_tree().create_timer(1.0).timeout
	_check(screen.step() >= 1, "U6 自动播放会推进步数")
	screen.toggle_play()
	_check(not screen.is_playing(), "U6 能暂停自动播放")
	screen.set_speed(2.0)
	_check(screen.speed_multiplier() == 2.0, "U6 能切换回放速度")
	screen.set_speed(1.0)

	# 键盘：← / → / 空格。
	screen.seek(2)
	var next_event := InputEventAction.new()
	next_event.action = "spl_replay_next"
	next_event.pressed = true
	screen._unhandled_input(next_event)
	_check(screen.step() == 3, "U6 右方向键走下一步")
	var prev_event := InputEventAction.new()
	prev_event.action = "spl_replay_prev"
	prev_event.pressed = true
	screen._unhandled_input(prev_event)
	_check(screen.step() == 2, "U6 左方向键回上一步")
	var play_event := InputEventAction.new()
	play_event.action = "spl_replay_play"
	play_event.pressed = true
	screen._unhandled_input(play_event)
	_check(screen.is_playing(), "U6 空格开始播放")
	screen.toggle_play()

	# 动效：下一步先播，播完再落视图；关掉动效时同步落地。
	UiSettings.set_animations_enabled(true)
	UiSettings.set_anim_speed(UiSettings.SPEED_FAST)
	screen.seek(1)
	var old_market: Dictionary = screen.table().market_card_ids()
	var old_bank: Dictionary = screen.table().bank_column().get_counts()
	screen.advance_animated()
	_check(screen.step() == 2, "U6 下一步推进步数")
	_check(screen.is_animating(), "U6 回放下一步会播动效")
	_check(screen.table().market_card_ids() == old_market
			and screen.table().bank_column().get_counts() == old_bank,
			"U6 动效播放期间牌桌停在起点")
	var deadline: int = Time.get_ticks_msec() + 5000
	while screen.is_animating() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(not screen.is_animating(), "U6 回放动效会播完")
	var anim_target: Dictionary = screen.source().public_view(screen.step())
	_check(screen.table().market_card_ids() == _u6_market_ids(anim_target)
			and screen.table().bank_column().get_counts() == _u6_bank_counts(anim_target),
			"U6 动效播完后落到目标视图")
	UiSettings.set_animations_enabled(false)
	screen.seek(2)
	screen.advance_animated()
	var sync_target: Dictionary = screen.source().public_view(3)
	_check(not screen.is_animating(), "U6 关掉动效后不播")
	_check(screen.table().market_card_ids() == _u6_market_ids(sync_target)
			and screen.table().bank_column().get_counts() == _u6_bank_counts(sync_target),
			"U6 关掉动效后同步落地")
	UiSettings.set_anim_speed(UiSettings.SPEED_NORMAL)

	# 从这里接着玩：确认框说明丢弃步数。
	screen.seek(4)
	var got_entry: Array[UiSaveEntry] = [null]
	var got_step: Array[int] = [-1]
	screen.continue_requested.connect(func(value: UiSaveEntry, step: int) -> void:
		got_entry[0] = value
		got_step[0] = step)
	screen.request_continue()
	_check(screen.confirm_visible(), "U6 从这里接着玩有确认框")
	_check(screen.confirm_message().contains("后面的"), "U6 确认框说明丢弃后面的步数")
	screen.confirm_continue()
	_check(got_entry[0] == entry and got_step[0] == 4, "U6 确认后发出截断步数")

	var exit_pressed: Array[bool] = [false]
	screen.exit_requested.connect(func() -> void: exit_pressed[0] = true)
	var exit_button := screen.table().find_child("ReplayExitButton", true, false) as Button
	_check(exit_button != null, "U6 顶栏有退出回放按钮")
	if exit_button != null:
		exit_button.pressed.emit()
		_check(exit_pressed[0], "U6 退出回放发出信号")

	host.queue_free()
	await get_tree().process_frame


func _check_u6_error_modal() -> void:
	var modal := UiErrorModal.new()
	add_child(modal)
	await get_tree().process_frame
	modal.setup_save_error(UiSaveEntry.REASON_VERIFY_FAILED, "第 7 步失败", 7)
	var button: UiButton = modal.resume_until_button()
	_check(button != null, "U6 校验失败提供读到第 N 步为止")
	if button != null:
		_check(button.text.contains("第 6 步"), "U6 按钮写到失败前一步")
		var requested: Array[int] = [-1]
		modal.resume_until_requested.connect(func(step: int) -> void: requested[0] = step)
		button.pressed.emit()
		_check(requested[0] == 6, "U6 读到第 N 步为止发出步数")
	modal.queue_free()
	await get_tree().process_frame

	var modal2 := UiErrorModal.new()
	add_child(modal2)
	await get_tree().process_frame
	modal2.setup_save_error(UiSaveEntry.REASON_VERIFY_FAILED, "", 0)
	_check(modal2.resume_until_button() == null, "U6 不知道失败步数时不显示按钮")
	modal2.queue_free()
	await get_tree().process_frame


func _check_u6_result_replay() -> void:
	var host := Control.new()
	host.theme = load(THEME_PATH)
	host.size = Vector2(1280, 800)
	get_tree().root.add_child(host)
	await get_tree().process_frame
	var view := {"player_count": 2}
	var clicks: Array[bool] = [false]
	var modal := UiModalFrame.new()
	host.add_child(modal)
	UiTableModals.populate_result(modal, {
		"winners": [0], "scores": {"0": 16, "1": 9}, "cards": {"0": 10, "1": 7},
		"nobles": {"0": 1, "1": 0}, "reason": "win_points", "tiebreak": "",
		"round": 20, "elapsed_sec": 120,
	}, view, DataRegistry.rules(), ["小明", "薄荷"], ["human", "human"],
			{"replay": func() -> void: clicks[0] = true})
	var replay_button := modal.find_child("ResultReplay", true, false) as UiButton
	_check(replay_button != null and not replay_button.disabled, "U6 结算弹窗有看回放")
	if replay_button != null:
		replay_button.pressed.emit()
		_check(clicks[0], "U6 看回放按钮触发回调")

	var snapshot_modal := UiModalFrame.new()
	host.add_child(snapshot_modal)
	UiTableModals.populate_result(snapshot_modal, {
		"winners": [0], "scores": {"0": 16, "1": 9}, "cards": {"0": 10, "1": 7},
		"nobles": {"0": 1, "1": 0}, "reason": "win_points", "tiebreak": "",
		"round": 20, "elapsed_sec": 120,
	}, view, DataRegistry.rules(), ["小明", "薄荷"], ["human", "human"], {}, false)
	var disabled := snapshot_modal.find_child("ResultReplay", true, false) as UiButton
	_check(disabled == null or disabled.disabled, "U6 快照局看回放不可用")
	host.queue_free()
	await get_tree().process_frame


func _check_u6_app_replay() -> void:
	var game: Dictionary = _u6_play(20261103, 2, 120)
	_check((game["data"].get("actions", []) as Array).size() >= 8, "U6 流程测试局步数足够")
	UiSaveStore.root_override = U4_SAVE_ROOT
	var store: UiSaveStore = _u4_new_store()
	var meta: Dictionary = UiSaveStore.make_meta("finished", game["names"], game["types"],
			false, 300, UiSaveStore.make_summary(1, 0, [0, 0], []))
	_check(store.save_quick(game["data"], meta), "U6 回放存档可以写入")
	var quick_path: String = U4_SAVE_ROOT.path_join("quick.json")

	var app: Control = load(APP_PATH).instantiate()
	get_tree().root.add_child(app)
	await get_tree().process_frame
	await get_tree().process_frame
	app.show_save_browser(false)
	await get_tree().process_frame
	await get_tree().process_frame
	var browser: UiSaveBrowser = app.save_browser()
	_check(browser != null, "U6 能从主菜单打开读档")
	if browser == null:
		app.queue_free()
		await get_tree().process_frame
		UiSaveStore.root_override = ""
		_u4_wipe(U4_SAVE_ROOT)
		return
	browser.select_path(quick_path)
	var replay_button: UiButton = browser.replay_button()
	_check(replay_button != null and replay_button.visible, "U6 回放存档显示从头看回放")
	if replay_button != null:
		replay_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var replay: UiReplayScreen = app.replay_screen()
	_check(replay != null and app.current_screen() == replay, "U6 从头看回放进入回放屏")
	if replay != null:
		var mid: int = mini(5, replay.step_count())
		replay.seek(mid)
		var expected: Dictionary = replay.source().public_view(mid)
		var exit_button := replay.table().find_child("ReplayExitButton", true, false) as Button
		if exit_button != null:
			exit_button.pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
		_check(app.save_browser() != null, "U6 退出回放回到读档列表")
		_check(app.replay_screen() == null, "U6 退出后释放回放屏")

		# 再开一次，从当前步接着玩。
		browser = app.save_browser()
		if browser != null:
			browser.select_path(quick_path)
			var again: UiButton = browser.replay_button()
			if again != null:
				again.pressed.emit()
			await get_tree().process_frame
			await get_tree().process_frame
		replay = app.replay_screen()
		_check(replay != null, "U6 再次打开回放")
		if replay != null:
			replay.seek(mid)
			replay.request_continue()
			replay.confirm_continue()
			await get_tree().process_frame
			await get_tree().process_frame
			_check(app.session() != null and app.current_screen() == app.table(),
					"U6 从这里接着玩进入牌桌")
			if app.session() != null:
				var actual: Dictionary = UiTableSession.sanitize_view(
						app.session().view(), -1, {})
				_check(actual == expected, "U6 接着玩的局面和回放当前步一致")

		# 结算弹窗的看回放：会话内存数据直接打开回放屏。
		if app.session() != null:
			app.flow().replay_requested.emit()
			await get_tree().process_frame
			await get_tree().process_frame
			_check(app.replay_screen() != null, "U6 结算弹窗能打开本局回放")
			if app.replay_screen() != null:
				app.replay_screen().exit_requested.emit()
				await get_tree().process_frame
				await get_tree().process_frame
				_check(app.current_screen() == app.table(), "U6 从结算回放回到牌桌")

	# 22：坏动作的回放，读到失败前一步。
	var bad: Dictionary = game["data"].duplicate(true)
	var actions: Array = bad.get("actions", [])
	actions[5] = Action.purchase("L3-R-99").to_dict()
	bad["actions"] = actions
	bad["fingerprint"] = ""
	_check(store.save_quick(bad, meta), "U6 坏动作回放可以写入")
	app.show_save_browser(true)
	await get_tree().process_frame
	await get_tree().process_frame
	var bad_browser: UiSaveBrowser = app.save_browser()
	_check(bad_browser != null, "U6 能从牌桌打开读档")
	if bad_browser != null:
		bad_browser.select_path(quick_path)
		var continue_button: UiButton = bad_browser.continue_button()
		if continue_button != null:
			continue_button.pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
		var modal := app.find_child("SaveErrorModal", true, false) as UiErrorModal
		_check(modal != null, "U6 坏动作回放显示 22")
		if modal != null:
			var until: UiButton = modal.resume_until_button()
			_check(until != null and until.text.contains("第 5 步"), "U6 22 提供读到第 5 步为止")
			if until != null:
				until.pressed.emit()
				await get_tree().process_frame
				await get_tree().process_frame
				_check(app.session() != null and app.current_screen() == app.table(),
						"U6 读到第 5 步为止进入牌桌")
				if app.session() != null:
					var actual: Dictionary = UiTableSession.sanitize_view(
							app.session().view(), -1, {})
					_check(actual == game["views"][5], "U6 读到的局面等于原局第 5 步")

	app.queue_free()
	await get_tree().process_frame
	store.queue_free()
	await get_tree().process_frame
	UiSaveStore.root_override = ""
	_u4_wipe(U4_SAVE_ROOT)
