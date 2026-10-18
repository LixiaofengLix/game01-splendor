## 回放时间轴：每一步一格（最左一格是开局），按行动座位着色；
## 已播放的实色、未播放的浅灰，当前步加高并描橙框；点击某一格跳转。
class_name UiReplayTimeline
extends Control

signal seek_requested(step: int)

const HEIGHT := 28
## 和四个吉祥物的身体颜色一致（mascot_1..4），一眼能对上是谁。
const SEAT_COLORS: Array[Color] = [
	Color("#26201a"), Color("#2fd3a8"), Color("#7b6cf6"), Color("#ff6a2b"),
]
const IDLE := Color("#cfc3ac")
const CURRENT_BORDER := Color("#e8582a")

var _step: int = 0
var _step_count: int = 0
## 下标 = 步号（0 是开局），值 = 行动座位；开局用 -1。
var _seats: Array[int] = []


func _ready() -> void:
	custom_minimum_size.y = HEIGHT
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	resized.connect(queue_redraw)


func configure(step_count: int, seats: Array[int]) -> void:
	_step_count = maxi(step_count, 0)
	_seats.clear()
	for item: int in seats:
		_seats.append(item)
	queue_redraw()


func set_state(step: int, step_count: int, seats: Array[int]) -> void:
	_step = clampi(step, 0, step_count)
	_step_count = step_count
	_seats = seats.duplicate()
	queue_redraw()


func step() -> int:
	return _step


## 横坐标对应哪一步（点击 / 测试用）。
func step_at_x(x: float) -> int:
	return _step_at(x)


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse := event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed:
		return
	accept_event()
	seek_requested.emit(_step_at(mouse.position.x))


func _step_at(x: float) -> int:
	var count: int = _step_count + 1
	if count <= 0 or size.x <= 0.0:
		return 0
	return clampi(int(floorf(x / size.x * count)), 0, _step_count)


func _draw() -> void:
	var count: int = _step_count + 1
	var height: float = float(HEIGHT)
	var top: float = 6.0
	var bar_height: float = height - 12.0
	for index: int in count:
		var x0: int = int(floorf(float(index) * size.x / float(count)))
		var x1: int = int(floorf(float(index + 1) * size.x / float(count)))
		var width: int = maxi(x1 - x0, 1)
		var played: bool = index <= _step
		var color: Color = IDLE
		if index == 0:
			color = UiPalette.INK_3 if played else IDLE
		elif played:
			var seat: int = _seats[index] if index < _seats.size() else -1
			# 座位颜色还在后台补算时先用中性色，补上后自动换色。
			color = SEAT_COLORS[seat % SEAT_COLORS.size()] if seat >= 0 else UiPalette.INK_3
		var lift: float = 2.0 if index == _step else 0.0
		draw_rect(Rect2(x0, top - lift, width, bar_height + lift), color)
		if index == _step:
			draw_rect(Rect2(x0, top - lift, width, bar_height + lift),
					CURRENT_BORDER, false, 2.0)
