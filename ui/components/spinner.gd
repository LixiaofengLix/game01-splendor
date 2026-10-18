## 像素转圈：12×12 的 2×2 方块环，四帧跳动；不使用旋转矢量圆。
class_name UiSpinner
extends Control

const BLOCK := 2
const FRAMES := 4
const FRAME_SECONDS := 0.15
## 环上 8 个方块的位置（左上角），按顺时针排列。
const BLOCKS: Array[Vector2i] = [
	Vector2i(5, 1), Vector2i(8, 3), Vector2i(9, 5), Vector2i(8, 8),
	Vector2i(5, 9), Vector2i(2, 8), Vector2i(1, 5), Vector2i(2, 3),
]

var _frame := 0
var _timer: Timer


func _ready() -> void:
	custom_minimum_size = Vector2(12, 12)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timer = Timer.new()
	_timer.wait_time = FRAME_SECONDS
	_timer.timeout.connect(_advance)
	add_child(_timer)
	_timer.start()


func _advance() -> void:
	_frame = (_frame + 1) % FRAMES
	queue_redraw()


func _draw() -> void:
	for index in BLOCKS.size():
		var position := Vector2(BLOCKS[index])
		var lit := (index - _frame * 2 + BLOCKS.size()) % BLOCKS.size() < 2
		var color := UiPalette.ORANGE if lit else Color(UiPalette.INK_3.r, UiPalette.INK_3.g, UiPalette.INK_3.b, 0.55)
		draw_rect(Rect2(position, Vector2(BLOCK, BLOCK)), color)
