## 正式 UI 入口：屏幕路由、牌桌会话的生命周期、弹窗层和异常提示。
## 主菜单 → 本地开局 / 读档 → 牌桌 → 结算 / 回主菜单都在这里装配；
## 屏幕只和桥接层（UiTableSession / UiSaveStore）打交道。
## 运行：godot --path . ui/app/app.tscn
extends Control

const MAIN_MENU_SCENE: String = "res://ui/screens/main_menu/main_menu.tscn"
const LOCAL_SETUP_SCENE: String = "res://ui/screens/local_setup/local_setup.tscn"
const SAVE_BROWSER_SCENE: String = "res://ui/screens/save_browser/save_browser.tscn"
const TABLE_SCENE: String = "res://ui/screens/table/table_screen.tscn"
const REPLAY_SCENE: String = "res://ui/screens/replay/replay_screen.tscn"
const SETTINGS_SCENE: String = "res://ui/screens/settings/settings_screen.tscn"

@onready var screen_root: Control = $ScreenRoot
@onready var modal_root: Control = $ModalLayer/ModalRoot
@onready var toast_root: Control = $ToastLayer/ToastRoot

var _store: UiSaveStore = null
var _session: UiTableSession = null
var _table: UiTableScreen = null
var _flow: UiTableFlow = null
var _replay: UiReplayScreen = null

var _current_screen: Control = null
## 从牌桌打开读档时，牌桌留在栈底（隐藏），返回时恢复。
var _screen_stack: Array[Control] = []


func _ready() -> void:
	UiShortcuts.register()
	UiSettings.load_from_disk()
	_store = UiSaveStore.new()
	_store.name = "SaveStore"
	add_child(_store)
	if DataRegistry.is_valid():
		print("UI：数据层校验通过（%d 张卡牌，%d 位贵族）。" % [
			DataRegistry.all_cards().size(),
			DataRegistry.all_nobles().size(),
		])
		show_main_menu()
		return
	printerr("UI：数据层校验失败（%d 个问题），显示异常提示。" % DataRegistry.get_errors().size())
	_show_data_error()


# ---------------------------------------------------------------- 屏幕路由

## 替换当前屏幕（清空返回栈）。传入 null 时只清空。
func set_screen(screen: Control) -> void:
	if _current_screen == screen:
		return
	if _replay == _current_screen:
		_replay = null
	if is_instance_valid(_current_screen):
		_current_screen.queue_free()
	_current_screen = screen
	if screen != null and screen.get_parent() != screen_root:
		screen_root.add_child(screen)


func push_modal(modal: Control) -> void:
	modal_root.add_child(modal)


func clear_modals() -> void:
	for child in modal_root.get_children():
		modal_root.remove_child(child)
		child.queue_free()


func _push_screen(screen: Control) -> void:
	if is_instance_valid(_current_screen):
		_current_screen.visible = false
		_screen_stack.append(_current_screen)
	_current_screen = screen
	if screen.get_parent() != screen_root:
		screen_root.add_child(screen)


func _pop_screen() -> void:
	if _screen_stack.is_empty():
		show_main_menu()
		return
	var previous: Control = _screen_stack.pop_back()
	var current: Control = _current_screen
	_current_screen = previous
	if is_instance_valid(current):
		current.queue_free()
	if is_instance_valid(previous):
		previous.visible = true


func _reset_stack() -> void:
	# 被换掉的隐藏屏幕（例如从牌桌打开的读档列表）没有别的引用，直接释放。
	for screen: Control in _screen_stack:
		if is_instance_valid(screen) and screen != _current_screen:
			screen.queue_free()
	_screen_stack.clear()


# ---------------------------------------------------------------- 主菜单 / 设置

func show_main_menu() -> void:
	_teardown_table()
	_reset_stack()
	var menu: UiMainMenu = load(MAIN_MENU_SCENE).instantiate()
	menu.name = "MainMenu"
	menu.continue_pressed.connect(continue_last_game)
	menu.local_pressed.connect(show_local_setup)
	menu.saves_pressed.connect(func() -> void: show_save_browser(false))
	menu.settings_pressed.connect(func() -> void: show_settings(false))
	menu.quit_pressed.connect(func() -> void: get_tree().quit())
	set_screen(menu)
	menu.configure(_store.autosave_summary())


func show_local_setup() -> void:
	_teardown_table()
	_reset_stack()
	var setup: UiLocalSetup = load(LOCAL_SETUP_SCENE).instantiate()
	setup.name = "LocalSetup"
	setup.back_requested.connect(show_main_menu)
	setup.start_requested.connect(_on_start_requested)
	set_screen(setup)


func _on_start_requested(setup: Dictionary) -> void:
	var target: Control = _current_screen
	if start_game(setup):
		return
	if target is UiLocalSetup:
		(target as UiLocalSetup).report_start_failed(
				"开局失败：请检查数据与电脑配置（详见控制台输出）。")


## 用 setup 字典开一局。成功时牌桌成为当前屏幕。
func start_game(setup: Dictionary) -> bool:
	_teardown_table()
	_create_table_nodes(bool(setup.get("hotseat_cover", true)))
	if not _session.start_local(setup):
		_teardown_table()
		return false
	_show_table()
	return true


# ---------------------------------------------------------------- 读档 / 继续

## 主菜单“继续上一局”。失败时显示 22，并允许返回读档列表。
func continue_last_game() -> void:
	var entry: UiSaveEntry = _store.autosave_entry()
	if entry == null:
		show_main_menu()
		return
	var check: Dictionary = _store.validate(entry)
	if not bool(check.get("ok", false)):
		_show_save_error(entry, String(check.get("reason", entry.reason)),
				String(check.get("detail", "")), int(check.get("step", 0)), true)
		return
	var errors: Array[String] = []
	if _resume_entry(entry, errors):
		return
	_show_save_error(entry, UiSaveEntry.REASON_VERIFY_FAILED, "\n".join(errors), 0, true)


## 设置屏（15 / 16）：从主菜单打开是普通换屏；从牌桌暂停菜单打开时压栈，返回回到牌桌。
func show_settings(from_table: bool) -> void:
	var screen: UiSettingsScreen = load(SETTINGS_SCENE).instantiate()
	screen.name = "Settings"
	screen.configure({"from_table": from_table, "usage": _llm_usage()})
	screen.back_requested.connect(func() -> void:
		if from_table:
			_pop_screen()
			# 显示卡牌 id / 动画速度这类设置要立即反映到返回后的牌桌。
			if _flow != null:
				_flow.refresh()
		else:
			show_main_menu())
	if from_table:
		_push_screen(screen)
	else:
		set_screen(screen)


func _llm_usage() -> Dictionary:
	if _session == null:
		return {}
	return _session.llm_profile_usage()


func show_save_browser(from_table: bool) -> void:
	var browser: UiSaveBrowser = load(SAVE_BROWSER_SCENE).instantiate()
	browser.name = "SaveBrowser"
	browser.configure(_store, "‹ 返回" if from_table else "‹ 主菜单")
	browser.back_requested.connect(func() -> void:
		if from_table:
			_pop_screen()
		else:
			show_main_menu())
	browser.continue_requested.connect(_on_browser_continue)
	browser.replay_requested.connect(_on_browser_replay)
	if from_table:
		_push_screen(browser)
	else:
		set_screen(browser)


func _on_browser_continue(entry: UiSaveEntry) -> void:
	if not entry.readable():
		_show_save_error(entry, entry.reason, entry.reason_detail, 0, true)
		return
	var check: Dictionary = _store.validate(entry)
	if not bool(check.get("ok", false)):
		_show_save_error(entry, String(check.get("reason", UiSaveEntry.REASON_VERIFY_FAILED)),
				String(check.get("detail", "")), int(check.get("step", 0)), true)
		return
	var errors: Array[String] = []
	if _resume_entry(entry, errors):
		return
	_show_save_error(entry, UiSaveEntry.REASON_VERIFY_FAILED, "\n".join(errors), 0, true)


## 读档列表的【从头看回放】（U6）。
func _on_browser_replay(entry: UiSaveEntry) -> void:
	if entry == null:
		return
	if not entry.readable():
		_show_save_error(entry, entry.reason, entry.reason_detail, 0, true)
		return
	var check: Dictionary = _store.validate(entry)
	if not bool(check.get("ok", false)):
		_show_save_error(entry, String(check.get("reason", UiSaveEntry.REASON_VERIFY_FAILED)),
				String(check.get("detail", "")), int(check.get("step", 0)), true)
		return
	show_replay(entry)


## 打开回放屏（03 的“从头看回放”、12 的“看回放”）。失败时显示 22 并留在原屏幕。
func show_replay(entry: UiSaveEntry) -> bool:
	if entry == null:
		return false
	var screen: UiReplayScreen = load(REPLAY_SCENE).instantiate()
	screen.name = "Replay"
	_push_screen(screen)
	_replay = screen
	var errors: Array[String] = []
	if not screen.configure(entry, errors):
		_replay = null
		_pop_screen()
		_show_save_error(entry, UiSaveEntry.REASON_VERIFY_FAILED,
				"\n".join(errors), 0, false)
		return false
	screen.exit_requested.connect(_close_replay)
	screen.continue_requested.connect(_on_replay_continue)
	return true


func _close_replay() -> void:
	var screen: UiReplayScreen = _replay
	_replay = null
	if screen == null or not is_instance_valid(screen):
		return
	if screen == _current_screen:
		_pop_screen()
	else:
		screen.queue_free()


## 回放屏的【从这里接着玩】：截断到当前步，开一局新的（原存档不变）。
func _on_replay_continue(entry: UiSaveEntry, step: int) -> void:
	var errors: Array[String] = []
	if _resume_entry_until(entry, step, errors):
		_replay = null
		return
	_show_save_error(entry, UiSaveEntry.REASON_VERIFY_FAILED, "\n".join(errors), 0, false)


func _resume_entry_until(entry: UiSaveEntry, step: int, errors: Array[String]) -> bool:
	_teardown_table()
	_create_table_nodes(bool(entry.ui_meta.get("hotseat_cover", true)))
	if not _session.resume_until(entry, step, errors):
		_teardown_table()
		return false
	_show_table()
	_flow.show_resume_notice(_session.resume_note())
	if step > 0:
		_table.show_toast(-1, "已读到第 %d 步为止" % step, "后面的步数没有载入", 4.0)
	return true


## 读档继续：创建牌桌并恢复存档。失败时不改变当前屏幕。
func _resume_entry(entry: UiSaveEntry, errors: Array[String]) -> bool:
	_teardown_table()
	_create_table_nodes(bool(entry.ui_meta.get("hotseat_cover", true)))
	if not _session.resume(entry, errors):
		_teardown_table()
		return false
	_show_table()
	_flow.show_resume_notice(_session.resume_note())
	return true


# ---------------------------------------------------------------- 牌桌

func _create_table_nodes(hotseat_cover: bool) -> void:
	_table = load(TABLE_SCENE).instantiate()
	_table.name = "Table"
	_table.visible = false
	screen_root.add_child(_table)

	_session = UiTableSession.new()
	_session.name = "TableSession"
	add_child(_session)

	_flow = UiTableFlow.new()
	_flow.name = "TableFlow"
	add_child(_flow)
	_flow.setup(_table, _session, _store, {"hotseat_cover": hotseat_cover})
	_flow.leave_requested.connect(back_to_main_menu)
	_flow.load_requested.connect(func() -> void: show_save_browser(true))
	_flow.rematch_requested.connect(_on_rematch)
	_flow.replay_requested.connect(_open_session_replay)
	_flow.settings_requested.connect(func() -> void: show_settings(true))


## 结算弹窗的【看回放】：把当前会话的内存数据当成一份回放存档打开。
func _open_session_replay() -> void:
	if _session == null or _table == null:
		return
	var data: Dictionary = _session.build_save_data()
	if data.is_empty():
		_table.show_toast(_session.me_seat(), "看不了回放", "这局来自预设局面，没有动作序列", 3.0)
		return
	var entry := UiSaveEntry.new()
	entry.kind = "replay"
	entry.data = data
	entry.player_count = int(data.get("player_count", 0))
	entry.seed = int(data.get("seed", 0))
	var raw_actions: Variant = data.get("actions", [])
	entry.action_count = (raw_actions as Array).size() if raw_actions is Array else 0
	entry.display_name = "本局回放"
	entry.ui_meta = {
		"status": UiSaveEntry.STATUS_FINISHED,
		"names": _session.names(),
		"seat_types": _session.original_seat_types(),
		"hotseat_cover": _session.hotseat_cover(),
	}
	show_replay(entry)


func _show_table() -> void:
	_reset_stack()
	if _replay == _current_screen:
		_replay = null
	if is_instance_valid(_current_screen) and _current_screen != _table:
		_current_screen.queue_free()
	_current_screen = _table
	_table.visible = true


func _teardown_table() -> void:
	if _session != null:
		_session.close()
		_session.queue_free()
		_session = null
	if _flow != null:
		_flow.queue_free()
		_flow = null
	if _table != null:
		if _current_screen == _table:
			_current_screen = null
		_screen_stack.erase(_table)
		_table.queue_free()
		_table = null


func back_to_main_menu() -> void:
	_teardown_table()
	show_main_menu()


func _on_rematch(setup: Dictionary) -> void:
	if not start_game(setup):
		show_main_menu()


# ---------------------------------------------------------------- 异常提示

func _show_data_error() -> void:
	var modal := UiErrorModal.new()
	modal.name = "DataErrorModal"
	modal_root.add_child(modal)
	modal.setup_data_errors(DataRegistry.get_errors())
	modal.exit_requested.connect(func() -> void: get_tree().quit())


func _show_save_error(entry: UiSaveEntry, reason: String, detail: String,
		step: int, go_to_list: bool) -> void:
	var modal := UiErrorModal.new()
	modal.name = "SaveErrorModal"
	modal_root.add_child(modal)
	modal.setup_save_error(reason, detail, step)
	modal.closed.connect(func() -> void:
		modal.queue_free()
		if go_to_list and not (_current_screen is UiSaveBrowser):
			show_save_browser(false))
	if step > 1 and entry != null and entry.kind == "replay":
		modal.resume_until_requested.connect(func(until_step: int) -> void:
			modal.queue_free()
			var errors: Array[String] = []
			if not _resume_entry_until(entry, until_step, errors):
				_show_save_error(entry, UiSaveEntry.REASON_VERIFY_FAILED,
						"\n".join(errors), 0, false))


# ---------------------------------------------------------------- 测试用

func store() -> UiSaveStore:
	return _store


func session() -> UiTableSession:
	return _session


func table() -> UiTableScreen:
	return _table


func flow() -> UiTableFlow:
	return _flow


func current_screen() -> Control:
	return _current_screen


func main_menu() -> UiMainMenu:
	return _current_screen as UiMainMenu


func local_setup() -> UiLocalSetup:
	return _current_screen as UiLocalSetup


func save_browser() -> UiSaveBrowser:
	return _current_screen as UiSaveBrowser


func settings_screen() -> UiSettingsScreen:
	return _current_screen as UiSettingsScreen


func replay_screen() -> UiReplayScreen:
	return _replay if is_instance_valid(_replay) else null


func screen_stack_size() -> int:
	return _screen_stack.size()
