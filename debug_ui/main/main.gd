## 调试入口：在开局设置界面与可视化桌面之间切换。正式 UI（阶段 7）会替换掉 debug_ui/。
extends Control

@onready var _setup: SetupScreen = $Setup
@onready var _board: BoardScreen = $Board

func _ready() -> void:
	_setup.start_requested.connect(_on_start_requested)
	_board.back_to_setup.connect(_on_back_to_setup)
	_show_setup()

func _on_start_requested(player_count: int, seed: int, seat_types: Array[String]) -> void:
	if _board.start_new_game(player_count, seed, seat_types):
		_setup.hide()
		_board.show()
	else:
		_setup.show_error("开局失败：数据未通过校验，详见 output 面板")

func _on_back_to_setup() -> void:
	_show_setup()

func _show_setup() -> void:
	_setup.show()
	_board.hide()
