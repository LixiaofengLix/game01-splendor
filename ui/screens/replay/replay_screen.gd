## 回放（14）：同一张牌桌 + 底部播放条。左右方向键 / 空格控制播放，Esc 退出。
## 回放数据全部来自 UiReplaySource；屏幕不碰 GameController，也不把回放当成对局。
class_name UiReplayScreen
extends Control

signal exit_requested
signal continue_requested(entry: UiSaveEntry, step: int)

const TABLE_SCENE: String = "res://ui/screens/table/table_screen.tscn"
## 1x 速度时每一步停留的时间；0.5x / 2x 按比例换算。
const PLAY_INTERVAL: float = 0.9

var _table: UiTableScreen = null
var _bar: UiReplayBar = null
var _source: UiReplaySource = null
var _anim: UiTableAnim = null
var _entry: UiSaveEntry = null
var _step: int = 0
var _viewer_seat: int = -1
var _playing: bool = false
var _speed: float = 1.0
var _timer: Timer = null
var _confirm: UiConfirmModal = null
## 步号 -> 行动座位（-1 = 开局 / 还没算出来）。时间轴颜色按帧在后台补齐。
var _seat_at: Dictionary[int, int] = {0: -1}
var _seat_fill_step: int = 0
var _seat_filling: bool = false


func _ready() -> void:
	UiShortcuts.register()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_table = load(TABLE_SCENE).instantiate()
	_table.name = "Table"
	_table.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_table)

	_bar = UiReplayBar.new()
	_bar.name = "ReplayBar"
	_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_table.bottom_holder().add_child(_bar)

	_bar.seek_requested.connect(seek)
	_bar.next_step_requested.connect(advance_animated)
	_bar.play_toggle_requested.connect(toggle_play)
	_bar.view_changed.connect(_on_viewer_changed)
	_bar.speed_changed.connect(set_speed)
	_table.replay_continue_requested.connect(request_continue)
	_table.replay_exit_requested.connect(func() -> void: exit_requested.emit())

	_anim = UiTableAnim.new()
	_anim.name = "TableAnim"
	add_child(_anim)
	_anim.setup(_table, _apply_animated_view)

	_timer = Timer.new()
	_timer.name = "PlayTimer"
	_timer.one_shot = false
	_timer.wait_time = PLAY_INTERVAL
	_timer.timeout.connect(_on_play_tick)
	add_child(_timer)


## 打开一份回放；失败原因写进 errors。必须在屏幕加入场景树之后调用。
func configure(entry: UiSaveEntry, errors: Array[String]) -> bool:
	if _bar == null:
		errors.append("回放屏还没准备好")
		return false
	if entry == null:
		errors.append("没有选中存档")
		return false
	_entry = entry
	_source = UiReplaySource.new()
	_source.name = "ReplaySource"
	add_child(_source)
	if not _source.open(entry, errors):
		_source.queue_free()
		_source = null
		return false
	_seat_at.clear()
	_seat_at[0] = -1
	_seat_fill_step = 0
	_seat_filling = false
	_bar.configure(_source.step_count(), _source.names())
	seek(0)
	_start_seat_fill()
	return true


func _exit_tree() -> void:
	_seat_filling = false
	_source = null
	_bar = null
	_table = null


## 直接跳转（时间轴、上一步、开头 / 结尾）：不播动效。
func seek(step: int) -> void:
	if _source == null:
		return
	if _anim != null:
		_anim.finish_now()
	_step = clampi(step, 0, _source.step_count())
	if _step >= _source.step_count() and _playing:
		_stop_play()
		return
	_render()


## 走一步并播放该步的动效（【下一步】、右方向键、自动播放）。动效播完才落视图。
func advance_animated() -> void:
	if _source == null or _anim == null:
		return
	if _step >= _source.step_count():
		return
	# 上一拍还没播完就直接落完，避免积压。
	_anim.finish_now()
	_step += 1
	var view: Dictionary = _source.view(_step, _viewer_seat)
	_render_bar(view)
	_anim.enqueue(_source.events_at(_step), view, -1)


func is_animating() -> bool:
	return _anim != null and _anim.is_playing()


func animation_pending() -> int:
	return _anim.pending_count() if _anim != null else 0


func step() -> int:
	return _step


func step_count() -> int:
	return _source.step_count() if _source != null else 0


func set_viewer_seat(seat: int) -> void:
	if _source == null:
		return
	if _anim != null:
		_anim.finish_now()
	_viewer_seat = clampi(seat, -1, _source.player_count() - 1)
	_bar.set_viewer_index(_viewer_seat + 1)
	_render()


func viewer_seat() -> int:
	return _viewer_seat


func toggle_play() -> void:
	if _playing:
		_stop_play()
		return
	if _source == null or _source.step_count() <= 0:
		return
	if _step >= _source.step_count():
		if _anim != null:
			_anim.finish_now()
		_step = 0
	_playing = true
	_timer.wait_time = PLAY_INTERVAL / _speed
	_timer.start()
	_render()


func set_speed(multiplier: float) -> void:
	_speed = multiplier if multiplier in UiReplayBar.SPEEDS else 1.0
	if _playing:
		_timer.wait_time = PLAY_INTERVAL / _speed
		_timer.start()
	_render_bar_only()


func speed_multiplier() -> float:
	return _speed


func is_playing() -> bool:
	return _playing


func source() -> UiReplaySource:
	return _source


func bar() -> UiReplayBar:
	return _bar


func table() -> UiTableScreen:
	return _table


func entry() -> UiSaveEntry:
	return _entry


func _on_play_tick() -> void:
	if _source == null:
		return
	if _step >= _source.step_count():
		_stop_play()
		return
	advance_animated()
	if _step >= _source.step_count():
		_stop_play()


func _stop_play() -> void:
	_playing = false
	if _timer != null:
		_timer.stop()
	# 动效可能还在播，这里只更新播放条，不提前把牌桌落到目标视图。
	_render_bar_only()


func _on_viewer_changed(seat: int) -> void:
	if _anim != null:
		_anim.finish_now()
	_viewer_seat = clampi(seat, -1, (_source.player_count() - 1) if _source != null else -1)
	_render()


# ---------------------------------------------------------------- 渲染

## 直接落到第 _step 步：整桌 + 播放条。跳转 / 换视角走这里。
func _render() -> void:
	if _source == null or _table == null or _bar == null:
		return
	var view: Dictionary = _source.view(_step, _viewer_seat)
	_render_table(view)
	_render_bar(view)


func _render_table(view: Dictionary) -> void:
	if _table == null or _source == null:
		return
	var info: Dictionary = {
		"names": _source.names(),
		"seat_types": _source.seat_types(),
		"log": _source.log_entries(_step),
		"catalog": DataRegistry.card_catalog(),
		"rules": DataRegistry.rules(),
		"interactive": false,
		"mode": "replay",
		"hud_mode": "replay",
		"bottom_custom": true,
		# 4 人回放时右栏要放 4 个玩家面板，日志只剩两行的高度。
		"log_limit": 2 if _source.player_count() >= 4 else 0,
		"pill_text": "回放 · %s · 第 %d / %d 步" % [
			_entry.display_name if _entry != null else "", _step, _source.step_count(),
		],
	}
	_table.render(view, -1, info)
	if _anim != null:
		_anim.sync_view(view)


## 动效队列落地时只重画牌桌；播放条在动作开始时就已更新到目标步。
func _apply_animated_view(view: Dictionary, _me_seat: int, _from_view: Dictionary,
		_events: Array) -> void:
	_render_table(view)


func _render_bar(view: Dictionary) -> void:
	if _bar == null or _source == null:
		return
	var actor: int = -1
	if _step > 0:
		actor = _source.actor_at(_step)
		_seat_at[_step] = actor
	_bar.render({
		"step": _step,
		"step_count": _source.step_count(),
		"seat": actor,
		"round": _source.round_at(_step) if _step > 0 else UiViewMath.round_number(view),
		"text": _source.step_text(_step),
		"playing": _playing,
		"catalog": DataRegistry.card_catalog(),
		"seat_at": _timeline_seats(),
	})


func _render_bar_only() -> void:
	if _source == null or _bar == null:
		return
	_render_bar(_source.view(_step, _viewer_seat))


# ---------------------------------------------------------------- 时间轴颜色

## 时间轴需要每一步的行动者。用临时实现载入每个前缀比较慢，所以按帧在后台补齐：
## 打开回放立刻可看；已播放但还没算出来的格子先用中性色，算好后自动换色。
func _start_seat_fill() -> void:
	if _seat_filling or _source == null:
		return
	_seat_filling = true
	_fill_seat_colors()


func _fill_seat_colors() -> void:
	while _seat_filling and _source != null and _bar != null \
			and _seat_fill_step < _source.step_count():
		for _index: int in 2:
			if _seat_fill_step >= _source.step_count():
				break
			_seat_fill_step += 1
			_seat_at[_seat_fill_step] = _source.actor_at(_seat_fill_step)
		_bar.set_seat_at(_timeline_seats())
		await get_tree().process_frame
	_seat_filling = false
	if _bar != null:
		_bar.set_seat_at(_timeline_seats())


func _timeline_seats() -> Array[int]:
	var result: Array[int] = []
	var count: int = _source.step_count() if _source != null else 0
	for number: int in count + 1:
		result.append(int(_seat_at.get(number, -1)))
	return result


# ---------------------------------------------------------------- 从这里接着玩

func request_continue() -> void:
	if _confirm != null or _source == null:
		return
	if _anim != null:
		_anim.finish_now()
	_stop_play()
	var remaining: int = _source.step_count() - _step
	_confirm = UiConfirmModal.new()
	_confirm.name = "ReplayContinueConfirm"
	_confirm.title = "从这里接着玩"
	_confirm.message = (
			"会以第 %d 步为起点开一局，后面的 %d 步会被丢弃。原存档不会被修改。" % [_step, remaining]
			if remaining > 0 else
			"会以最后一步为起点继续这一局。原存档不会被修改。")
	_confirm.confirm_text = "从这里接着玩"
	_confirm.z_index = 200
	_confirm.confirmed.connect(_on_continue_confirmed)
	_confirm.cancelled.connect(_close_confirm)
	add_child(_confirm)


func _on_continue_confirmed() -> void:
	var entry: UiSaveEntry = _entry
	var step_number: int = _step
	_close_confirm()
	continue_requested.emit(entry, step_number)


func _close_confirm() -> void:
	if _confirm != null:
		_confirm.queue_free()
		_confirm = null


func confirm_visible() -> bool:
	return _confirm != null


func confirm_message() -> String:
	return _confirm.message if _confirm != null else ""


func confirm_continue() -> void:
	if _confirm != null:
		_confirm.confirmed.emit()


# ---------------------------------------------------------------- 输入

func _unhandled_input(event: InputEvent) -> void:
	if _source == null:
		return
	if _confirm != null:
		if event.is_action_pressed("spl_cancel"):
			_close_confirm()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("spl_replay_prev"):
		seek(_step - 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("spl_replay_next"):
		advance_animated()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("spl_replay_play"):
		toggle_play()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("spl_cancel"):
		exit_requested.emit()
		get_viewport().set_input_as_handled()
