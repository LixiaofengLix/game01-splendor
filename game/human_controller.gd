## 人类座位：界面点击后调用 submit()，控制器把动作交给 GameController。
## 界面也可以只用 GameController 的信号；action_requested 是给需要自己渲染操作面板的正式 UI 用的。
class_name HumanController
extends PlayerController

signal action_requested(view: Dictionary, legal_actions: Array[Action])

var _waiting: bool = false

func request_action(view: Dictionary, legal_actions: Array[Action]) -> void:
	_waiting = true
	action_requested.emit(view, legal_actions)

## 界面调用：提交玩家选中的动作。重复 / 过期的点击会被拒绝。
func submit(action: Action) -> bool:
	if not _waiting:
		push_error("HumanController：没有等待中的动作请求（重复或过期的点击）")
		return false
	_waiting = false
	action_decided.emit(action)
	return true

func is_waiting() -> bool:
	return _waiting

func cancel_pending() -> void:
	_waiting = false
