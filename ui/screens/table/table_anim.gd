## 牌桌动效队列：先事件后视图，按事件顺序播放筹码 / 卡牌 / 贵族飞行，
## 播完（或被跳过）后才让牌桌落到目标视图。动效只画在 AnimationLayer 上，永远不改状态。
## 积压超过 MAX_PENDING 批时直接快进到最新视图，只保留最后一批的光晕（INTERACTION.md 第 7 节）。
class_name UiTableAnim
extends Node

signal queue_drained

## 标准速度的时长（U5 试玩后放慢约 30%，让飞行动作看得更清楚）。
const COIN_FLIGHT := 0.38
const CARD_FLIGHT := 0.40
const NOBLE_FLIGHT := 0.55
const COIN_STAGGER := 0.08
const PAID_STAGGER := 0.05
const FLIP_SECONDS := 0.12
const TAIL := 0.05
## 当前 + 排队超过这么多批就快进。
const MAX_PENDING := 2
const COIN_SIZE := 24

var _screen: UiTableScreen = null
var _apply_view: Callable
var _queue: Array[Dictionary] = []
var _current: Dictionary = {}
var _last_view: Dictionary = {}
var _playing: bool = false
var _generation: int = 0
var _tweens: Array[Tween] = []
var _pulses: Dictionary = {}
## 跳动前的原始位置 / 颜色：连续两次跳动时，第二次不能把“跳起中”的状态当成原点。
var _pulse_base: Dictionary = {}
var _last_duration: float = 0.0
var _last_visuals: int = 0
## 当前批次的动画时长倍率（slow 1.5 / normal 1 / fast 0.5）。
var _speed_multiplier: float = 1.0
## 同一批里连续弃宝石的错峰序号。
var _discard_stagger: int = 0


func setup(screen: UiTableScreen, apply_view: Callable) -> void:
	_screen = screen
	_apply_view = apply_view


func is_playing() -> bool:
	return _playing or not _queue.is_empty()


func pending_count() -> int:
	return _queue.size() + (1 if not _current.is_empty() else 0)


func last_duration() -> float:
	return _last_duration


func last_visual_count() -> int:
	return _last_visuals


# ---------------------------------------------------------------- 队列

## 一批 = 同一视图对应的全部事件。调用方保证事件先于视图、视图已经过滤过隐私。
func enqueue(events: Array[Dictionary], view: Dictionary, me_seat: int) -> void:
	if not UiSettings.animations_enabled():
		# 设置页中途关掉动效时，先把正在播的批次落完（并作废旧协程），再同步落地。
		if is_playing():
			skip_all()
		UiSfx.play_events(events)
		_apply_now(events, view, me_seat, _last_view)
		return
	var batch: Dictionary = {
		"events": events.duplicate(true),
		"view": view.duplicate(true),
		"me_seat": me_seat,
	}
	# 弃宝石是“一次确认、逐个提交”：把同一座位的连续弃宝石并成一批，
	# 否则 3 枚就会触发积压快进，反而看不到飞行动效。
	if _merge_discard_tail(batch):
		return
	_queue.append(batch)
	if pending_count() > MAX_PENDING:
		skip_all()
		return
	if not _playing:
		_start_next()


## 跳过全部积压：直接落到最新视图（中间批次不播、不落地）。
func skip_all() -> void:
	_generation += 1
	_kill_tweens()
	var latest: Dictionary = {}
	var from_view: Dictionary = _last_view
	if not _queue.is_empty():
		latest = _queue[_queue.size() - 1]
		if _queue.size() >= 2:
			from_view = _queue[_queue.size() - 2]["view"]
		elif not _current.is_empty():
			from_view = _current["view"]
		_queue.clear()
	elif not _current.is_empty():
		latest = _current
	_current = {}
	_playing = false
	if latest.is_empty():
		queue_drained.emit()
		return
	_apply_now(latest["events"], latest["view"], int(latest["me_seat"]), from_view)
	queue_drained.emit()


## 换人遮挡 / 换屏前用：不播动效，直接落到已收到的最后一帧。
func finish_now() -> void:
	skip_all()


func _start_next() -> void:
	if _queue.is_empty():
		_playing = false
		return
	_current = _queue.pop_front()
	_playing = true
	var batch: Dictionary = _current
	var from_view: Dictionary = _last_view
	var generation: int = _generation + 1
	_generation = generation
	_play(batch, from_view, generation)


func _play(batch: Dictionary, from_view: Dictionary, generation: int) -> void:
	var duration: float = _animate(batch)
	_last_duration = duration
	if duration > 0.0:
		await get_tree().create_timer(duration).timeout
		if generation != _generation:
			return
	if generation != _generation:
		return
	_current = {}
	# 先落视图再播落地后的跳动：渲染时 is_playing() 已经是 false，
	# 轮到我时才会把输入解锁交给最终视图。
	_playing = false
	_last_view = batch["view"]
	_apply_view.call(batch["view"], int(batch["me_seat"]), from_view, batch["events"])
	_post_apply(batch, from_view)
	if _queue.is_empty():
		queue_drained.emit()
	else:
		_start_next()


## 队尾已经是同一座位的弃宝石批次时，把新事件并进去并更新目标视图。
## 最后一批弃宝石会带 turn_ended / turn_started，也要允许并入。
func _merge_discard_tail(batch: Dictionary) -> bool:
	if _queue.is_empty():
		return false
	var events: Array = batch["events"]
	if not _discard_batch(events):
		return false
	var last: Dictionary = _queue[_queue.size() - 1]
	var last_events: Array = last["events"]
	if not _all_discards(last_events):
		return false
	if int((events[0] as Dictionary).get("seat", -1)) \
			!= int((last_events[0] as Dictionary).get("seat", -1)):
		return false
	last_events.append_array(events)
	last["view"] = batch["view"]
	last["me_seat"] = batch["me_seat"]
	return true


## 弃宝石批次：第一件事是弃宝石，其余只允许回合边界事件。
func _discard_batch(events: Array) -> bool:
	if events.is_empty():
		return false
	if String((events[0] as Dictionary).get("type", "")) != "gems_discarded":
		return false
	var seat: int = int((events[0] as Dictionary).get("seat", -1))
	for item: Variant in events:
		if not item is Dictionary:
			return false
		var type: String = String((item as Dictionary).get("type", ""))
		if type == "gems_discarded":
			if int((item as Dictionary).get("seat", -1)) != seat:
				return false
		elif type != "turn_ended" and type != "turn_started":
			return false
	return true


func _all_discards(events: Array) -> bool:
	if events.is_empty():
		return false
	for item: Variant in events:
		if not item is Dictionary:
			return false
		if String((item as Dictionary).get("type", "")) != "gems_discarded":
			return false
	return true


func _apply_now(events: Array, view: Dictionary, me_seat: int,
		from_view: Dictionary) -> void:
	_last_duration = 0.0
	_last_visuals = 0
	_last_view = view
	_apply_view.call(view, me_seat, from_view, events)


# ---------------------------------------------------------------- 事件 → 动效

## 返回这一批的总时长（已乘速度倍率）。
func _animate(batch: Dictionary) -> float:
	_speed_multiplier = UiSettings.speed_multiplier()
	_last_visuals = 0
	_discard_stagger = 0
	var end_time: float = 0.0
	var events: Array = batch["events"]
	UiSfx.play_events(events)
	for item: Variant in events:
		if not item is Dictionary:
			continue
		end_time = maxf(end_time, _animate_event(item as Dictionary))
	if _last_visuals > 0:
		end_time += TAIL
	# _spawn_flight / _spawn_flip 内部已经按倍率缩放；这里只缩放总等待时间。
	return end_time * _speed_multiplier


func _animate_event(event: Dictionary) -> float:
	var type: String = String(event.get("type", ""))
	var seat: int = int(event.get("seat", -1))
	match type:
		"gems_taken":
			return _animate_gems_taken(event, seat)
		"card_reserved":
			return _animate_reserved(event, seat)
		"card_purchased":
			return _animate_purchased(event, seat)
		"gems_discarded":
			var color: int = Enums.color_from_string(String(event.get("color", "")))
			if color < 0:
				return 0.0
			var delay: float = _discard_stagger * COIN_STAGGER
			_discard_stagger += 1
			_fly_coin(color, _screen.seat_token_rect(seat, color),
					_screen.bank_chip_rect(color), delay, COIN_FLIGHT)
			return delay + COIN_FLIGHT
		"noble_visited":
			var noble_id: String = String(event.get("noble_id", ""))
			_fly_noble(noble_id, _screen.noble_rect(noble_id),
					_screen.seat_panel_rect(seat), 0.0, NOBLE_FLIGHT)
			return NOBLE_FLIGHT
		"turn_started":
			return 0.0
	return 0.0


func _animate_gems_taken(event: Dictionary, seat: int) -> float:
	var gems: Dictionary = event.get("gems", {})
	var index: int = 0
	var end_time: float = 0.0
	for color_name: String in Enums.COLOR_NAMES:
		var count: int = int(gems.get(color_name, 0))
		if count <= 0:
			continue
		var color: Enums.GemColor = Enums.color_from_string(color_name)
		var from_rect: Rect2 = _screen.bank_chip_rect(color)
		var to_rect: Rect2 = _screen.seat_token_rect(seat, color)
		for _i: int in count:
			var delay: float = index * COIN_STAGGER
			_fly_coin(color, from_rect, to_rect, delay, COIN_FLIGHT)
			end_time = maxf(end_time, delay + COIN_FLIGHT)
			index += 1
	return end_time


func _animate_reserved(event: Dictionary, seat: int) -> float:
	var blind: bool = bool(event.get("blind", false))
	var level: int = int(event.get("level", 1))
	var card_id: String = String(event.get("card_id", ""))
	var from_rect: Rect2 = _screen.deck_rect(level) if blind \
			else _screen.market_card_rect(card_id)
	var to_rect: Rect2 = _screen.seat_reserved_rect(seat)
	var end_time: float = _fly_card(card_id, from_rect, to_rect, 0.0, CARD_FLIGHT,
			blind, level, false)
	if int(event.get("gold", 0)) > 0:
		_fly_coin(Enums.GemColor.GOLD, _screen.bank_chip_rect(Enums.GemColor.GOLD),
				_screen.seat_token_rect(seat, Enums.GemColor.GOLD), 0.12, COIN_FLIGHT)
		end_time = maxf(end_time, 0.12 + COIN_FLIGHT)
	return end_time


func _animate_purchased(event: Dictionary, seat: int) -> float:
	var card_id: String = String(event.get("card_id", ""))
	var from_reserved: bool = bool(event.get("from_reserved", false))
	var from_rect: Rect2 = _screen.reserved_card_rect(card_id) if from_reserved \
			else _screen.market_card_rect(card_id)
	if from_rect.size == Vector2.ZERO:
		from_rect = _screen.seat_panel_rect(seat)
	var end_time: float = _fly_card(card_id, from_rect, _screen.seat_panel_rect(seat),
			0.0, CARD_FLIGHT, false, int(event.get("level", 1)), from_reserved)
	var paid: Dictionary = event.get("paid", {})
	var index: int = 0
	for color_name: String in Enums.COLOR_NAMES:
		var count: int = int(paid.get(color_name, 0))
		if count <= 0:
			continue
		var color: Enums.GemColor = Enums.color_from_string(color_name)
		for _i: int in count:
			var delay: float = 0.06 + index * PAID_STAGGER
			_fly_coin(color, _screen.seat_token_rect(seat, color),
					_screen.bank_chip_rect(color), delay, COIN_FLIGHT)
			end_time = maxf(end_time, delay + COIN_FLIGHT)
			index += 1
	return end_time


# ---------------------------------------------------------------- 视觉元素

func _fly_coin(color: Enums.GemColor, from_rect: Rect2, to_rect: Rect2,
		delay: float, duration: float) -> void:
	if from_rect.size == Vector2.ZERO or to_rect.size == Vector2.ZERO:
		return
	var chip := UiGemChip.new()
	chip.name = "FlyingCoin"
	chip.gem_color = color
	chip.size_key = &"sm"
	chip.count = 1
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.animation_layer().add_child(chip)
	chip.size = Vector2(COIN_SIZE, COIN_SIZE)
	_spawn_flight(chip, from_rect, to_rect, delay, duration)


func _fly_card(card_id: String, from_rect: Rect2, to_rect: Rect2,
		delay: float, duration: float, blind: bool, level: int, mini: bool) -> float:
	if from_rect.size == Vector2.ZERO or to_rect.size == Vector2.ZERO:
		return 0.0
	var card := UiDevCard.new()
	card.name = "FlyingCard"
	card.catalog = _screen.catalog()
	card.mini = mini
	card.card_back = blind
	card.back_level = level
	card.card_id = card_id
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.animation_layer().add_child(card)
	var card_size: Vector2 = UiDevCard.MINI_SIZE if mini else UiDevCard.MARKET_SIZE
	card.size = card_size
	_spawn_flight(card, from_rect, to_rect, delay, duration)
	return duration


func _fly_noble(noble_id: String, from_rect: Rect2, to_rect: Rect2,
		delay: float, duration: float) -> void:
	if noble_id.is_empty() or from_rect.size == Vector2.ZERO or to_rect.size == Vector2.ZERO:
		return
	var tile := UiNobleTile.new()
	tile.name = "FlyingNoble"
	tile.catalog = _screen.catalog()
	tile.noble_id = noble_id
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.animation_layer().add_child(tile)
	tile.size = from_rect.size
	tile.custom_minimum_size = from_rect.size
	_spawn_flight(tile, from_rect, to_rect, delay, duration)


## 在 AnimationLayer 的坐标系里从 from_rect 中心飞到 to_rect 中心。
## 每一步位置都取整到 2px 网格（VISUAL_SPEC 第 1 节）。
func _spawn_flight(node: Control, from_rect: Rect2, to_rect: Rect2,
		delay: float, duration: float) -> void:
	var layer: Control = _screen.animation_layer()
	var origin: Vector2 = layer.get_global_rect().position
	var node_size: Vector2 = node.size
	var start: Vector2 = _snap2(from_rect.position - origin
			+ (from_rect.size - node_size) * 0.5)
	var end: Vector2 = _snap2(to_rect.position - origin
			+ (to_rect.size - node_size) * 0.5)
	node.position = start
	var tween: Tween = create_tween()
	tween.tween_interval(delay * _speed_multiplier)
	tween.tween_method(_set_snapped_position.bind(node), start, end,
			duration * _speed_multiplier)
	tween.tween_callback(_finish_flight.bind(node, tween))
	_tweens.append(tween)
	_last_visuals += 1


static func _snap2(value: Vector2) -> Vector2:
	return Vector2(roundf(value.x * 0.5) * 2.0, roundf(value.y * 0.5) * 2.0)


func _set_snapped_position(value: Vector2, node: Control) -> void:
	if is_instance_valid(node):
		node.position = _snap2(value)


func _finish_flight(node: Control, tween: Tween) -> void:
	if is_instance_valid(node):
		node.queue_free()
	_tweens.erase(tween)


func _kill_tweens() -> void:
	for tween: Tween in _tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_tweens.clear()
	if _screen == null or not is_instance_valid(_screen):
		return
	var layer: Control = _screen.animation_layer()
	if layer == null:
		return
	for child: Node in layer.get_children():
		child.queue_free()


# ---------------------------------------------------------------- 落地后的反馈

func _post_apply(batch: Dictionary, from_view: Dictionary) -> void:
	_play_refills(from_view, batch["view"])
	for item: Variant in batch["events"]:
		if not item is Dictionary:
			continue
		var event: Dictionary = item
		var type: String = String(event.get("type", ""))
		var seat: int = int(event.get("seat", -1))
		match type:
			"card_purchased":
				_pulse_control(_screen.seat_score_control(seat), 2)
				var catalog: CardCatalog = _screen.catalog()
				var card: CardData = null
				if catalog != null:
					card = catalog.card(String(event.get("card_id", "")))
				if card != null:
					_pulse_control(_screen.seat_bonus_control(seat, card.bonus), 2)
			"noble_visited":
				_pulse_control(_screen.seat_score_control(seat), 2)
			"endgame_triggered":
				_pulse_control(_screen.seat_score_control(seat), 2)
				_pulse_control(_screen.endgame_tag_control(), 2)


## 补牌翻开：新牌先盖一张牌背，两帧后揭开（视图已经落在新牌上）。
func _play_refills(from_view: Dictionary, to_view: Dictionary) -> void:
	if from_view.is_empty() or to_view.is_empty():
		return
	var from_boards: Dictionary = from_view.get("boards", {})
	var to_boards: Dictionary = to_view.get("boards", {})
	for level: int in [1, 2, 3]:
		var old_slots: Array = from_boards.get(str(level), [])
		var new_slots: Array = to_boards.get(str(level), [])
		var count: int = mini(old_slots.size(), new_slots.size())
		for index: int in count:
			var old_id: String = String(old_slots[index]) if old_slots[index] != null else ""
			var new_id: String = String(new_slots[index]) if new_slots[index] != null else ""
			if old_id == new_id or new_id.is_empty():
				continue
			_spawn_flip(level, index)


func _spawn_flip(level: int, slot: int) -> void:
	var rect: Rect2 = _screen.market_slot_rect(level, slot)
	if rect.size == Vector2.ZERO:
		return
	var layer: Control = _screen.animation_layer()
	var origin: Vector2 = layer.get_global_rect().position
	var back := UiDevCard.new()
	back.name = "RefillFlip"
	back.card_back = true
	back.back_level = level
	back.back_label = ""
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(back)
	back.size = UiDevCard.MARKET_SIZE
	back.position = _snap2(rect.position - origin)
	var tween: Tween = create_tween()
	tween.tween_interval(FLIP_SECONDS * _speed_multiplier)
	tween.tween_callback(func() -> void:
		if is_instance_valid(back):
			back.queue_free()
	)


## 两帧交替的颜色 / 位移跳动；不改变布局，结束时恢复原样。
func _pulse_control(control: Control, times: int) -> void:
	if control == null or not is_instance_valid(control):
		return
	var old: Tween = _pulses.get(control)
	if old != null and old.is_valid():
		old.kill()
	var state: Dictionary = _pulse_base.get(control, {})
	if state.is_empty():
		state = {"origin": control.position, "color": control.modulate}
		_pulse_base[control] = state
	var origin: Vector2 = state["origin"]
	var base_color: Color = state["color"]
	var step: float = 0.10 * _speed_multiplier
	var tween: Tween = create_tween()
	for _i: int in times:
		tween.tween_callback(func() -> void:
			if is_instance_valid(control):
				control.position = origin + Vector2(0, -4)
				control.modulate = UiPalette.ORANGE
		)
		tween.tween_interval(step)
		tween.tween_callback(func() -> void:
			if is_instance_valid(control):
				control.position = origin
				control.modulate = base_color
		)
		tween.tween_interval(step)
	tween.finished.connect(func() -> void:
		if is_instance_valid(control):
			control.position = origin
			control.modulate = base_color
		_pulses.erase(control)
		_pulse_base.erase(control)
	)
	_pulses[control] = tween
