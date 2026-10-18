## 截图工具：带窗口运行，把陈列场景或整页渲染成 PNG（headless 没有渲染，必须开窗口）。
## 窗口模式用于对比缩放方案：
##   godot --path . ui/dev/capture.tscn -- --out /tmp/splendor_ui/g_1280.png --width 1280 --height 800 --scale fractional
## 整页模式用放大的 SubViewport 一次拍下全部零件：
##   godot --path . ui/dev/capture.tscn -- --full --out /tmp/splendor_ui/gallery_full.png --width 1280
extends Node

const GALLERY := "res://ui/dev/gallery.tscn"


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

	if args.has("full"):
		await _capture_full(width, out_path, wait_frames)
	else:
		await _capture_window(width, height, String(args.get("scale", "fractional")),
				int(args.get("scroll", "0")), out_path, wait_frames)


func _capture_window(width: int, height: int, scale_mode: String, scroll: int,
		out_path: String, wait_frames: int) -> void:
	var window := get_window()
	window.content_scale_size = Vector2i(1280, 800)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.content_scale_stretch = (
			Window.CONTENT_SCALE_STRETCH_INTEGER if scale_mode == "integer"
			else Window.CONTENT_SCALE_STRETCH_FRACTIONAL)
	window.size = Vector2i(width, height)
	DisplayServer.window_set_size(Vector2i(width, height))
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
