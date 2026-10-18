## 开发辅助（U5 验收用）：在真实对局里触发拿宝石 / 预留 / 购买 / 贵族 / 弃宝石和电脑出手，
## 在飞行途中、补牌翻面时和落地后截图到 /tmp/splendor_ui/，运行后自行退出。
extends Control

const TABLE_SCENE := "res://ui/screens/table/table_screen.tscn"
const THEME := "res://ui/theme/pixel_theme.tres"
const OUT := "/tmp/splendor_ui/"

var _table: UiTableScreen
var _session: UiTableSession
var _flow: UiTableFlow
var _bot_captured: bool = false


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	theme = load(THEME)
	UiSettings.reset_defaults()
	UiSettings.set_animations_enabled(true)
	UiSettings.set_anim_speed(UiSettings.SPEED_NORMAL)
	await _take_scene()
	await _reserve_scene()
	await _purchase_scene()
	await _noble_scene()
	await _discard_scene()
	await _bot_scene()
	get_tree().quit(0)


func _make_parts() -> void:
	_table = load(TABLE_SCENE).instantiate()
	_table.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_table)
	_session = UiTableSession.new()
	add_child(_session)
	_flow = UiTableFlow.new()
	add_child(_flow)
	_flow.setup(_table, _session)
	await get_tree().process_frame
	await get_tree().process_frame


func _drop_parts() -> void:
	_session.close()
	_table.queue_free()
	_session.queue_free()
	_flow.queue_free()
	await get_tree().process_frame


func _start_humans(seed_value: int) -> bool:
	var seats: Array[Dictionary] = [
		{"name": "小明", "type": "human"},
		{"name": "薄荷", "type": "human"},
	]
	return _session.start_local({"count": 2, "seed": seed_value, "seats": seats})


func _snapshot(name: String) -> Dictionary:
	var text := FileAccess.get_file_as_string("res://tests/scenarios/%s.json" % name)
	var parsed: Variant = JSON.parse_string(text)
	return SaveFile.unwrap_snapshot(parsed) if parsed is Dictionary else {}


func _take_scene() -> void:
	await _make_parts()
	if _start_humans(20261018):
		await get_tree().process_frame
		var action: Action = null
		for legal: Action in _session.legal_actions():
			if legal.type == Enums.ActionType.TAKE_THREE:
				action = legal
				break
		if action != null:
			_session.submit(action)
			var duration: float = _flow.last_animation_duration()
			await get_tree().create_timer(0.15).timeout
			await _shot("u5_take_mid")
			await get_tree().create_timer(duration + 0.6).timeout
			await _shot("u5_take_end")
	await _drop_parts()


func _reserve_scene() -> void:
	await _make_parts()
	if _start_humans(20261019):
		await get_tree().process_frame
		var action: Action = null
		for legal: Action in _session.legal_actions():
			if legal.type == Enums.ActionType.RESERVE and not legal.card_id.is_empty():
				action = legal
				break
		if action != null:
			_session.submit(action)
			var duration: float = _flow.last_animation_duration()
			await get_tree().create_timer(0.16).timeout
			await _shot("u5_reserve_mid")
			await get_tree().create_timer(duration - 0.14).timeout
			await _shot("u5_reserve_flip")
			await get_tree().create_timer(0.7).timeout
			await _shot("u5_reserve_end")
	await _drop_parts()


func _purchase_scene() -> void:
	await _make_parts()
	var errors: Array[String] = []
	if _session.load_snapshot(_snapshot("endgame"), errors):
		await get_tree().process_frame
		await get_tree().process_frame
		for legal: Action in _session.legal_actions():
			if legal.type != Enums.ActionType.PURCHASE:
				continue
			var card: CardData = _session.catalog().card(legal.card_id)
			if card == null or card.points <= 0:
				continue
			_session.submit(legal)
			var duration: float = _flow.last_animation_duration()
			await get_tree().create_timer(0.16).timeout
			await _shot("u5_purchase_mid")
			# 落地后 0.02s：补牌牌背仍盖在新卡上、分数 / 折扣刚开始跳。
			await get_tree().create_timer(maxf(duration - 0.14, 0.0)).timeout
			await _shot("u5_purchase_flip")
			await get_tree().create_timer(0.8).timeout
			await _shot("u5_purchase_end")
			break
	await _drop_parts()


func _noble_scene() -> void:
	await _make_parts()
	var errors: Array[String] = []
	if _session.load_snapshot(_snapshot("two_nobles"), errors):
		await get_tree().process_frame
		await get_tree().process_frame
		var colors: Array[int] = _flow.clickable_colors()
		for index: int in 3:
			_flow.click_color(colors[index])
		_flow.confirm()
		await get_tree().create_timer(0.8).timeout
		var pending: Array = _session.view().get("pending_nobles", [])
		if not pending.is_empty():
			_flow.choose_noble(String(pending[0]))
			_flow.confirm_noble()
			var duration: float = _flow.last_animation_duration()
			await get_tree().create_timer(0.20).timeout
			await _shot("u5_noble_mid")
			await get_tree().create_timer(maxf(duration - 0.18, 0.0)).timeout
			await _shot("u5_noble_flip")
			await get_tree().create_timer(0.8).timeout
			await _shot("u5_noble_end")
	await _drop_parts()


func _discard_scene() -> void:
	await _make_parts()
	var errors: Array[String] = []
	if _session.load_snapshot(_snapshot("token_limit"), errors):
		await get_tree().process_frame
		await get_tree().process_frame
		var colors: Array[int] = _flow.clickable_colors()
		for index: int in 3:
			_flow.click_color(colors[index])
		_flow.confirm()
		await get_tree().create_timer(0.9).timeout
		if String(_session.view().get("phase", "")) == "discard":
			var view: Dictionary = _session.view()
			var tokens: Dictionary = UiViewMath.tokens(view, _session.me_seat())
			var need: int = UiViewMath.token_total(view, _session.me_seat()) \
					- int(_session.rules().max_tokens)
			var selected: int = 0
			for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
				for _i: int in int(tokens.get(color, 0)):
					if selected >= need:
						break
					_flow.choose_discard_color(color)
					selected += 1
				if selected >= need:
					break
			_flow.confirm_discard()
			await get_tree().create_timer(0.15).timeout
			await _shot("u5_discard_mid")
			await get_tree().create_timer(0.9).timeout
			await _shot("u5_discard_end")
	await _drop_parts()


## 1 人类 + 2 电脑：看电脑动作的筹码 / 卡牌飞向右侧对手面板。
func _bot_scene() -> void:
	await _make_parts()
	var seats: Array[Dictionary] = [
		{"name": "小明", "type": "human"},
		{"name": "薄荷", "type": "bot_easy"},
		{"name": "紫晶", "type": "bot_normal"},
	]
	if not _session.start_local({"count": 3, "seed": 20261103, "seats": seats}):
		await _drop_parts()
		return
	await get_tree().process_frame
	_bot_captured = false
	_session.events_arrived.connect(_on_bot_events)
	var colors: Array[int] = _flow.clickable_colors()
	for index: int in 3:
		_flow.click_color(colors[index])
	_flow.confirm()
	# 人类动作之后，电脑会在思考延迟后出手；等信号钩子拍到第一张。
	var started: int = Time.get_ticks_msec()
	while not _bot_captured and Time.get_ticks_msec() - started < 6000:
		await get_tree().create_timer(0.05).timeout
	await _wait_idle()
	await _drop_parts()


func _on_bot_events(events: Array[Dictionary]) -> void:
	if _bot_captured or events.is_empty():
		return
	if int(events[0].get("seat", 0)) == 0:
		return
	_bot_captured = true
	_capture_bot_flight()


func _capture_bot_flight() -> void:
	await get_tree().create_timer(0.12).timeout
	await _shot("u5_bot_mid")
	await _wait_idle()
	await _shot("u5_bot_end")


func _wait_idle() -> void:
	var started: int = Time.get_ticks_msec()
	while _flow.is_animating() and Time.get_ticks_msec() - started < 5000:
		await get_tree().create_timer(0.02).timeout


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = OUT + file_name + ".png"
	image.save_png(path)
	print("截图：" + path)
