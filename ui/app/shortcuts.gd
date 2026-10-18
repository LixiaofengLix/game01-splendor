## 运行时注册正式 UI 的全局快捷键（INTERACTION.md 第 8 节）。
## 动作名统一用 spl_ 前缀，避开 Godot 内置动作；重复调用是幂等的。
## app.tscn 与 ui/dev/quick_start.tscn 共用这一份定义。
class_name UiShortcuts
extends RefCounted

const SHORTCUTS: Dictionary = {
	"spl_color_1": [KEY_1],
	"spl_color_2": [KEY_2],
	"spl_color_3": [KEY_3],
	"spl_color_4": [KEY_4],
	"spl_color_5": [KEY_5],
	"spl_confirm": [KEY_ENTER, KEY_KP_ENTER],
	"spl_cancel": [KEY_ESCAPE],
	"spl_reserve": [KEY_R],
	"spl_log": [KEY_L],
	"spl_replay_prev": [KEY_LEFT],
	"spl_replay_next": [KEY_RIGHT],
	"spl_replay_play": [KEY_SPACE],
}


static func register() -> void:
	for action: String in SHORTCUTS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for keycode: Key in SHORTCUTS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_add_event(action, event)
