## 截图工具：带窗口运行，把陈列场景、牌桌夹具或某个屏幕渲染成 PNG
## （headless 没有渲染，必须开窗口）。
## 窗口模式用于对比缩放方案：
##   godot --path . ui/dev/capture.tscn -- --out /tmp/splendor_ui/g_1280.png --width 1280 --height 800 --scale fractional
## 整页模式用放大的 SubViewport 一次拍下全部零件：
##   godot --path . ui/dev/capture.tscn -- --full --out /tmp/splendor_ui/gallery_full.png --width 1280
## 屏幕模式（U4 起）：main_menu / local_setup / save_browser / pause / hotseat / error21 / error22 / replay
##   godot --path . ui/dev/capture.tscn --quit-after 300 -- --screen main_menu --out /tmp/splendor_ui/main_menu.png --width 1280 --height 800 --wait 10
extends Node

const GALLERY := "res://ui/dev/gallery.tscn"
const CAPTURE_SAVES := "user://capture_saves"


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("截图需要窗口模式：去掉 --headless 再运行。")
		get_tree().quit(1)
		return
	var args := _parse(OS.get_cmdline_user_args())
	var width := int(args.get("width", "1280"))
	var height := int(args.get("height", "800"))
	var out_path := String(args.get("out", "/tmp/splendor_ui/capture.png"))
	var wait_frames := int(args.get("wait", "6"))
	if width <= 0 or (not args.has("full") and height <= 0):
		printerr("截图尺寸必须是正整数：--width %d --height %d" % [width, height])
		get_tree().quit(1)
		return
	_ensure_dir(out_path)

	if args.has("screen"):
		await _capture_screen(String(args["screen"]), width, height, out_path, wait_frames)
	elif args.has("fixture"):
		await _capture_table(String(args["fixture"]), width, height, out_path, wait_frames)
	elif args.has("full"):
		await _capture_full(width, out_path, wait_frames)
	else:
		await _capture_window(width, height, String(args.get("scale", "fractional")),
				int(args.get("scroll", "0")), out_path, wait_frames)


func _prepare_window(width: int, height: int, scale_mode: String) -> Window:
	var window := get_window()
	window.content_scale_size = Vector2i(1280, 800)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.content_scale_stretch = (
			Window.CONTENT_SCALE_STRETCH_INTEGER if scale_mode == "integer"
			else Window.CONTENT_SCALE_STRETCH_FRACTIONAL)
	window.size = Vector2i(width, height)
	DisplayServer.window_set_size(Vector2i(width, height))
	return window


func _capture_table(fixture_name: String, width: int, height: int, out_path: String,
		wait_frames: int) -> void:
	var fixture := UiFixtureLoader.load_fixture(fixture_name)
	if fixture.is_empty():
		printerr("截图失败：夹具 %s 加载不了" % fixture_name)
		get_tree().quit(1)
		return
	var window := _prepare_window(width, height, "fractional")
	await get_tree().process_frame
	await get_tree().process_frame

	var table: UiTableScreen = load("res://ui/screens/table/table_screen.tscn").instantiate()
	table.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(table)
	await get_tree().process_frame
	table.render(fixture["view"], int(fixture["me_seat"]), fixture["session_info"])
	for _i in wait_frames:
		await get_tree().process_frame

	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(out_path)
	print("capture：牌桌夹具 %s，窗口 %s，保存到 %s" % [
		fixture_name, str(window.size), out_path,
	])
	_finish(error, out_path)


func _capture_screen(screen_name: String, width: int, height: int,
		out_path: String, wait_frames: int) -> void:
	var window := _prepare_window(width, height, "fractional")
	await get_tree().process_frame
	await get_tree().process_frame

	var host := Control.new()
	host.name = "ScreenHost"
	host.theme = load("res://ui/theme/pixel_theme.tres")
	host.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(host)

	var background := UiAssets.tiled(UiAssets.texture("tile_paper.png"))
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(background)

	var cleanup := func() -> void: pass
	match screen_name:
		"main_menu":
			var menu: UiMainMenu = load("res://ui/screens/main_menu/main_menu.tscn").instantiate()
			host.add_child(menu)
			menu.configure({"text": "4 人 · 第 9 轮 · 10 分钟前"})
		"local_setup":
			var setup: UiLocalSetup = load("res://ui/screens/local_setup/local_setup.tscn").instantiate()
			host.add_child(setup)
		"save_browser":
			var store := _capture_store()
			var browser: UiSaveBrowser = load(
					"res://ui/screens/save_browser/save_browser.tscn").instantiate()
			browser.configure(store)
			host.add_child(browser)
			cleanup = func() -> void: _capture_wipe(CAPTURE_SAVES)
		"hotseat":
			var cover := UiHotseatCover.new()
			cover.next_seat = 1
			cover.next_name = "薄荷"
			cover.previous_seat = 0
			cover.previous_name = "小明"
			cover.summary = "小明 购买了 二级红 · 1 分　现在轮到 薄荷"
			host.add_child(cover)
		"pause":
			await _capture_pause_scene(host)
		"replay":
			await _capture_replay_scene(host)
		"error21":
			var data_modal := UiErrorModal.new()
			host.add_child(data_modal)
			await get_tree().process_frame
			data_modal.setup_data_errors([
				"cards.json：第 12 条 cost.white 必须是正整数",
				"rules.json：max_tokens 应为正数，实际为 0",
			])
		"error22":
			var save_modal := UiErrorModal.new()
			host.add_child(save_modal)
			await get_tree().process_frame
			save_modal.setup_save_error(UiSaveEntry.REASON_VERIFY_FAILED,
					"重放后状态不一致：存档指纹 1e6f9b3e…，现在 4387e6b0…", 37)
		_:
			printerr("截图失败：不认识的屏幕 %s" % screen_name)
			get_tree().quit(1)
			return

	for _i in wait_frames:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(out_path)
	print("capture：屏幕 %s，窗口 %s，保存到 %s" % [screen_name, str(window.size), out_path])
	cleanup.call()
	_finish(error, out_path)


func _capture_replay_scene(host: Control) -> void:
	var data := _capture_replay_data(28, 4)
	var names: Array = ["小明", "薄荷", "紫晶", "橘子"]
	var types: Array = ["human", "human", "human", "human"]
	var entry := UiSaveEntry.new()
	entry.kind = "replay"
	entry.data = data
	entry.player_count = int(data.get("player_count", 2))
	entry.seed = int(data.get("seed", 0))
	var raw_actions: Variant = data.get("actions", [])
	entry.action_count = (raw_actions as Array).size() if raw_actions is Array else 0
	entry.display_name = "自动存档"
	entry.ui_meta = {"names": names.slice(0, entry.player_count), "seat_types": types.slice(0, entry.player_count)}
	var replay: UiReplayScreen = load("res://ui/screens/replay/replay_screen.tscn").instantiate()
	host.add_child(replay)
	await get_tree().process_frame
	var errors: Array[String] = []
	if not replay.configure(entry, errors):
		printerr("截图失败：回放打不开（%s）" % "\n".join(errors))
		return
	replay.seek(mini(24, replay.step_count()))


func _capture_pause_scene(host: Control) -> void:
	var fixture := UiFixtureLoader.load_fixture("g3_turn_mine")
	if fixture.is_empty():
		return
	var table: UiTableScreen = load("res://ui/screens/table/table_screen.tscn").instantiate()
	table.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(table)
	await get_tree().process_frame
	table.render(fixture["view"], int(fixture["me_seat"]), fixture["session_info"])
	var pause := UiPauseMenu.new()
	pause.configure(true, "", "退出后可从「继续上一局」或「读取存档」回来。")
	host.add_child(pause)
	pause.setup_rules(DataRegistry.rules())


func _capture_store() -> UiSaveStore:
	_capture_wipe(CAPTURE_SAVES)
	UiSaveStore.root_override = CAPTURE_SAVES
	var store := UiSaveStore.new()
	store.name = "CaptureStore"
	store.configure(CAPTURE_SAVES)
	add_child(store)
	store.ensure_dirs()
	var data := _capture_replay_data()
	var names: Array = ["小明", "薄荷", "紫晶", "橘子"]
	var types: Array = ["human", "bot_normal", "bot_hard", "human"]
	var meta: Dictionary = UiSaveStore.make_meta("in_progress", names, types, true, 620,
			UiSaveStore.make_summary(9, 1, [3, 7, 1, 5], []))
	store.save_quick(data, meta)
	store.transfer_finished(data, UiSaveStore.make_meta("finished", names, types, true, 2280,
			UiSaveStore.make_summary(27, 0, [16, 12, 9, 7], [0])))
	store.save_autosave(data, meta)
	var snapshot_text: String = FileAccess.get_file_as_string("res://tests/scenarios/token_limit.json")
	_write_capture_file(CAPTURE_SAVES.path_join("preset_token_limit.json"), snapshot_text)
	_write_capture_file(CAPTURE_SAVES.path_join("corrupt.json"), "{ 这不是 JSON")
	_write_capture_file(CAPTURE_SAVES.path_join("too_new.json"),
			JSON.stringify({"schema_version": 99, "kind": "replay", "player_count": 2}))
	return store


func _capture_replay_data(min_steps: int = 4, count: int = 2) -> Dictionary:
	var host := Node.new()
	add_child(host)
	var session := UiTableSession.new()
	host.add_child(session)
	var seats: Array[Dictionary] = []
	var seat_names: Array[String] = ["小明", "薄荷", "紫晶", "橘子"]
	for seat: int in count:
		seats.append({"name": seat_names[seat], "type": "human"})
	session.start_local({"count": count, "seed": 20261018, "seats": seats})
	var index: int = 0
	while index < mini(min_steps, 600) \
			and String(session.view().get("phase", "")) != "finished":
		var actions: Array[Action] = session.legal_actions()
		if actions.is_empty():
			break
		# 固定步进取合法动作里靠后的几种，让截图局面有购买和预留。
		session.submit(actions[(index * 7 + 3) % actions.size()])
		index += 1
	var data: Dictionary = session.build_save_data()
	session.close()
	host.queue_free()
	return data


func _write_capture_file(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _capture_wipe(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)
	for child: String in dir.get_directories():
		var sub: String = path.path_join(child)
		_capture_wipe(sub)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(sub))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _capture_window(width: int, height: int, scale_mode: String, scroll: int,
		out_path: String, wait_frames: int) -> void:
	var window := _prepare_window(width, height, scale_mode)
	await get_tree().process_frame
	await get_tree().process_frame

	var gallery: Control = load(GALLERY).instantiate()
	add_child(gallery)
	gallery.scroll_to(scroll)
	for _i in wait_frames:
		await get_tree().process_frame

	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(out_path)
	var visible := get_viewport().get_visible_rect().size
	var ratio := float(window.size.x) / maxf(visible.x, 1.0)
	print("capture：窗口 %s，逻辑视口 %s，窗口/视口比 %.3f，缩放模式 %s，滚动 %d" % [
		str(window.size), str(visible), ratio, scale_mode, scroll,
	])
	_finish(error, out_path)


func _capture_full(width: int, out_path: String, wait_frames: int) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(width, 800)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	add_child(viewport)

	var gallery: Control = load(GALLERY).instantiate()
	gallery.full_page = true
	viewport.add_child(gallery)
	for _i in wait_frames:
		await get_tree().process_frame

	var page_height := int(ceilf(gallery.page_height()))
	viewport.size = Vector2i(width, page_height)
	for _i in wait_frames:
		await get_tree().process_frame

	var image := viewport.get_texture().get_image()
	var error := image.save_png(out_path)
	print("capture：整页 %dx%d，保存到 %s" % [width, page_height, out_path])
	_finish(error, out_path)


func _finish(save_error: Error, out_path: String) -> void:
	if save_error != OK:
		printerr("截图失败：%s（%s）" % [out_path, error_string(save_error)])
		get_tree().quit(1)
		return
	get_tree().quit(0)


func _ensure_dir(path: String) -> void:
	var base := path.get_base_dir()
	if base.is_empty():
		return
	var error := DirAccess.make_dir_recursive_absolute(base)
	if error != OK and error != ERR_ALREADY_EXISTS:
		printerr("无法创建截图目录 %s：%s" % [base, error_string(error)])


func _parse(args: PackedStringArray) -> Dictionary:
	var result := {}
	var index := 0
	while index < args.size():
		var arg := args[index]
		if not arg.begins_with("--"):
			index += 1
			continue
		var key := arg.substr(2)
		if key == "full":
			result[key] = true
			index += 1
		elif index + 1 < args.size():
			result[key] = args[index + 1]
			index += 2
		else:
			result[key] = ""
			index += 1
	return result
