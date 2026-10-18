## 正式 UI 入口：注册全局快捷键，持有屏幕路由、弹窗层和 toast 层，启动时检查数据层。
## U0 只有空壳；各屏幕在后续阶段接进来。运行：godot --path . ui/app/app.tscn
extends Control

@onready var placeholder: Control = $Placeholder
@onready var screen_root: Control = $ScreenRoot
@onready var modal_root: Control = $ModalLayer/ModalRoot
@onready var toast_root: Control = $ToastLayer/ToastRoot

var _current_screen: Control = null


func _ready() -> void:
	UiShortcuts.register()
	_check_data()


## 切换当前屏幕。传入 null 时清空（显示 U0 的占位画面）。
func set_screen(screen: Control) -> void:
	if _current_screen == screen:
		return
	if is_instance_valid(_current_screen):
		_current_screen.queue_free()
	_current_screen = screen
	placeholder.visible = screen == null
	if screen != null:
		screen_root.add_child(screen)


func push_modal(modal: Control) -> void:
	modal_root.add_child(modal)


func clear_modals() -> void:
	for child in modal_root.get_children():
		child.queue_free()


func _check_data() -> void:
	if DataRegistry.is_valid():
		print("UI：数据层校验通过（%d 张卡牌，%d 位贵族）。" % [
			DataRegistry.all_cards().size(),
			DataRegistry.all_nobles().size(),
		])
		return
	printerr("UI：数据层校验失败（%d 个问题），正式流程会在 U4 弹出异常提示。" % DataRegistry.get_errors().size())
	for message: String in DataRegistry.get_errors():
		printerr("  " + message)
