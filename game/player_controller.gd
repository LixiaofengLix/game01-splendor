## 座位控制器基类：对局流程不区分人类 / AI / 大模型 / 远程，只向控制器要一个动作。
## 子类拿到的只有过滤后的视图（GameState.to_dict(seat)）和合法动作列表，决定后发出 action_decided。
## 阶段 4 的 AI、阶段 5 的大模型、阶段 6 的远程座位都继承它。
class_name PlayerController
extends Node

signal action_decided(action: Action)

## 由 GameController 在开局时写入。
var seat: int = -1

## 请求一个动作。子类必须最终发出 action_decided（可以同步决定，也可以等玩家点击 / 模型返回）。
func request_action(_view: Dictionary, _legal_actions: Array[Action]) -> void:
	push_error("PlayerController.request_action：子类没有实现")

## GameController 在换局 / 重置 / 释放控制器前调用：作废尚未发出的动作。
## 异步控制器（AI 计时器、大模型 HTTP、远程等待）必须覆盖它，避免旧动作注入新局。
func cancel_pending() -> void:
	pass
