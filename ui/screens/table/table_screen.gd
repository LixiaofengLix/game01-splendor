## 牌桌：按视图整桌重画（U2），并把筹码 / 卡 / 牌堆 / 浮层 / 弹窗的点击信号发出去（U3）。
## 唯一渲染入口 render(view, me_seat, session_info)；重复调用是幂等的，不累积节点。
## 交互状态（已选宝石、选中卡、浮层内容）由 UiTableFlow 放进 session_info；
## 这个脚本只负责画和发信号，不判断规则。
## 几何按 docs/ui/SCREENS.md：顶栏 44 + 左栏 906（市场 470 / 我的面板 246）+ 右栏 330。
class_name UiTableScreen
extends Control

signal gem_chip_clicked(color: int)
signal confirm_pressed
signal cancel_pressed
signal card_clicked(kind: String, id: String, level: int)
signal blank_clicked
signal purchase_pressed
signal reserve_pressed
signal menu_requested
signal rules_requested
## 回放模式的顶栏按钮（U6）。
signal replay_continue_requested
signal replay_exit_requested

const TABLE_MARGIN := 14
const HUD_HEIGHT := 44
const LEFT_WIDTH := 906
const COLUMN_GAP := 16
const RIGHT_MIN_WIDTH := 330
const RIGHT_MAX_WIDTH := 420
const MARKET_HEIGHT := 470
const MARKET_ROW_HEIGHT := 150
const MARKET_ROW_GAP := 10
const MY_PANEL_HEIGHT := 246

var _hud: UiHud
var _content: MarginContainer
var _columns: HBoxContainer
var _left: VBoxContainer
var _market: HBoxContainer
var _nobles: VBoxContainer
var _rows: VBoxContainer
var _bank: UiBankColumn
var _bottom_holder: Control
var _my_panel: UiMyPanel
var _spectator: UiFrame
var _spectator_title: Label
var _spectator_detail: Label
var _spectator_hint: Label
var _right: VBoxContainer
var _opponents: VBoxContainer
var _log: UiLogPanel
var _popover: UiCardPopover
## 动效层：飞行的筹码 / 卡牌 / 贵族，压在牌桌之上、弹窗之下。
var _anim_layer: Control
var _modal_layer: Control
var _modal_center: CenterContainer
var _modal_control: Control = null
## 暂停菜单 / 规则速查 / 换人遮挡叠在回合内弹窗之上。
var _overlay_layer: Control
var _toast: UiToast = null
var _toast_slot: Control

var _deck_piles: Dictionary[int, UiDeckPile] = {}
var _market_cards: Dictionary[int, Array] = {}
var _noble_tiles: Dictionary[String, UiNobleTile] = {}
var _opponent_panels: Dictionary[int, UiOpponentPanel] = {}
## 已按哪套规则搭过市场行；规则里的卡位数变了就重建。
var _market_slots_built: int = -1

var _view: Dictionary = {}
var _me_seat: int = -1
var _session: Dictionary = {}
var _catalog: CardCatalog = null
var _rules: RulesConfig = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_background()
	_build_hud()
	_build_content()
	_build_popover()
	_build_animation_layer()
	_build_modal_layer()
	_build_overlay_layer()
	_build_toast_slot()
	resized.connect(_update_columns)
	resized.connect(_place_popover)
	resized.connect(_layout_toast)
	_update_columns()


func _build_background() -> void:
	var wood := UiAssets.tiled(UiAssets.texture("tile_wood.png"))
	wood.name = "Wood"
	wood.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(wood)


func _build_hud() -> void:
	_hud = UiHud.new()
	_hud.name = "Hud"
	_hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_hud.offset_bottom = HUD_HEIGHT
	_hud.menu_requested.connect(func() -> void: menu_requested.emit())
	_hud.rules_requested.connect(func() -> void: rules_requested.emit())
	_hud.replay_continue_requested.connect(
			func() -> void: replay_continue_requested.emit())
	_hud.replay_exit_requested.connect(func() -> void: replay_exit_requested.emit())
	add_child(_hud)


func _build_content() -> void:
	_content = MarginContainer.new()
	_content.name = "Content"
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.offset_top = HUD_HEIGHT
	_content.add_theme_constant_override("margin_left", TABLE_MARGIN)
	_content.add_theme_constant_override("margin_top", TABLE_MARGIN)
	_content.add_theme_constant_override("margin_right", TABLE_MARGIN)
	_content.add_theme_constant_override("margin_bottom", TABLE_MARGIN)
	add_child(_content)

	_columns = HBoxContainer.new()
	_columns.name = "Columns"
	_columns.alignment = BoxContainer.ALIGNMENT_CENTER
	_columns.add_theme_constant_override("separation", COLUMN_GAP)
	_content.add_child(_columns)

	_build_left()
	_build_right()


func _build_popover() -> void:
	_popover = UiCardPopover.new()
	_popover.name = "CardPopover"
	_popover.z_index = 50
	_popover.visible = false
	_popover.purchase_pressed.connect(func() -> void: purchase_pressed.emit())
	_popover.reserve_pressed.connect(func() -> void: reserve_pressed.emit())
	add_child(_popover)


func _build_animation_layer() -> void:
	_anim_layer = Control.new()
	_anim_layer.name = "AnimationLayer"
	_anim_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_anim_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anim_layer.z_index = 90
	add_child(_anim_layer)


func _build_modal_layer() -> void:
	_modal_layer = Control.new()
	_modal_layer.name = "ModalLayer"
	_modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_layer.z_index = 100
	_modal_layer.visible = false
	add_child(_modal_layer)

	var scrim := ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = UiPalette.SCRIM
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_layer.add_child(scrim)

	_modal_center = CenterContainer.new()
	_modal_center.name = "Center"
	_modal_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal_layer.add_child(_modal_center)


func _build_overlay_layer() -> void:
	_overlay_layer = Control.new()
	_overlay_layer.name = "OverlayLayer"
	_overlay_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 空层不能挡住牌桌点击；有子节点时由子节点（遮罩 / 弹窗）自己接收输入。
	_overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_layer.z_index = 150
	add_child(_overlay_layer)


## 压在最上层的整屏控件：换人遮挡、暂停菜单、规则速查。可以叠多层。
func push_overlay(control: Control) -> void:
	if _overlay_layer == null:
		return
	_overlay_layer.add_child(control)
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_layer.visible = true


func pop_overlay(control: Control = null) -> void:
	if _overlay_layer == null or _overlay_layer.get_child_count() == 0:
		return
	var target: Control = control
	if target == null:
		target = _overlay_layer.get_child(_overlay_layer.get_child_count() - 1) as Control
	if target == null:
		return
	if target.get_parent() == _overlay_layer:
		_overlay_layer.remove_child(target)
	target.queue_free()
	_overlay_layer.visible = _overlay_layer.get_child_count() > 0


func has_overlay() -> bool:
	return _overlay_layer != null and _overlay_layer.get_child_count() > 0


func overlay_control() -> Control:
	if _overlay_layer == null or _overlay_layer.get_child_count() == 0:
		return null
	return _overlay_layer.get_child(_overlay_layer.get_child_count() - 1) as Control


func _build_toast_slot() -> void:
	_toast_slot = Control.new()
	_toast_slot.name = "ToastSlot"
	_toast_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_slot.z_index = 220
	add_child(_toast_slot)


## 牌桌顶部居中的 toast（保存成功、读档提示）。只用于“我刚做的事成功了”。
func show_toast(seat: int, message: String, detail: String = "", duration: float = 2.5) -> void:
	if _toast == null:
		_toast = UiToast.new()
		_toast.name = "TableToast"
		_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_toast_slot.add_child(_toast)
	_toast.show_message(seat, message, detail, duration)
	_layout_toast()


func _layout_toast() -> void:
	if _toast == null or _toast_slot == null:
		return
	var minimum: Vector2 = _toast.get_combined_minimum_size()
	_toast.size = minimum
	_toast.position = Vector2(
			roundf((size.x - minimum.x) * 0.5),
			HUD_HEIGHT + 12)


func show_modal(control: Control) -> void:
	if _modal_layer == null:
		return
	for child in _modal_center.get_children():
		_modal_center.remove_child(child)
		child.queue_free()
	_modal_control = control
	_modal_center.add_child(control)
	_modal_layer.visible = true


func hide_modal() -> void:
	if _modal_layer == null:
		return
	for child in _modal_center.get_children():
		_modal_center.remove_child(child)
		child.queue_free()
	_modal_control = null
	_modal_layer.visible = false


func modal_control() -> Control:
	return _modal_control


func has_modal() -> bool:
	return _modal_layer != null and _modal_layer.visible


func _build_left() -> void:
	_left = VBoxContainer.new()
	_left.name = "Left"
	_left.custom_minimum_size.x = LEFT_WIDTH
	_left.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_left.add_theme_constant_override("separation", 0)
	_columns.add_child(_left)

	_market = HBoxContainer.new()
	_market.name = "Market"
	_market.custom_minimum_size = Vector2(0, MARKET_HEIGHT)
	_market.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_market.add_theme_constant_override("separation", 14)
	_left.add_child(_market)

	_nobles = VBoxContainer.new()
	_nobles.name = "Nobles"
	_nobles.custom_minimum_size.x = 100
	_nobles.add_theme_constant_override("separation", 10)
	_market.add_child(_nobles)

	_rows = VBoxContainer.new()
	_rows.name = "Rows"
	_rows.custom_minimum_size.x = 648
	_rows.add_theme_constant_override("separation", MARKET_ROW_GAP)
	_market.add_child(_rows)

	_bank = UiBankColumn.new()
	_bank.name = "BankColumn"
	_bank.chip_clicked.connect(func(color: int) -> void: gem_chip_clicked.emit(color))
	_bank.confirm_pressed.connect(func() -> void: confirm_pressed.emit())
	_bank.cancel_pressed.connect(func() -> void: cancel_pressed.emit())
	_market.add_child(_bank)

	var gap := Control.new()
	gap.name = "PanelGap"
	gap.custom_minimum_size.y = 12
	_left.add_child(gap)

	_bottom_holder = Control.new()
	_bottom_holder.name = "Bottom"
	_bottom_holder.custom_minimum_size.y = MY_PANEL_HEIGHT
	_bottom_holder.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_left.add_child(_bottom_holder)

	_my_panel = UiMyPanel.new()
	_my_panel.name = "MyPanel"
	_my_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_my_panel.confirm_pressed.connect(func() -> void: confirm_pressed.emit())
	_my_panel.cancel_pressed.connect(func() -> void: cancel_pressed.emit())
	_my_panel.reserved_card_clicked.connect(
			func(card_id: String) -> void: card_clicked.emit("reserved", card_id, 0))
	_bottom_holder.add_child(_my_panel)

	_build_spectator()

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_left.add_child(spacer)


## 卡位数来自 RulesConfig.board_slots_per_level；规则变了就重建三行。
func _ensure_market_rows() -> void:
	if _rules == null:
		push_error("UiTableScreen：渲染前没有 RulesConfig")
		return
	var slots: int = int(_rules.board_slots_per_level)
	if slots <= 0:
		push_error("UiTableScreen：RulesConfig.board_slots_per_level 必须为正数")
		return
	if slots == _market_slots_built:
		return
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_deck_piles.clear()
	_market_cards.clear()
	for level: int in [3, 2, 1]:
		var row := HBoxContainer.new()
		row.name = "Row%d" % level
		row.custom_minimum_size.y = MARKET_ROW_HEIGHT
		row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_theme_constant_override("separation", 10)
		_rows.add_child(row)

		var deck := UiDeckPile.new()
		deck.name = "Deck%d" % level
		deck.level = level
		deck.gui_input.connect(_on_deck_input.bind(level))
		row.add_child(deck)
		_deck_piles[level] = deck

		var cards: Array[UiDevCard] = []
		for slot: int in slots:
			var card := UiDevCard.new()
			card.name = "Card%d_%d" % [level, slot]
			card.gui_input.connect(_on_market_card_input.bind(card))
			row.add_child(card)
			cards.append(card)
		_market_cards[level] = cards
	var deck_width: float = UiDeckPile.SIZE.x
	var card_width: float = UiDevCard.MARKET_SIZE.x
	_rows.custom_minimum_size.x = deck_width + 10.0 \
			+ slots * card_width + maxf(slots - 1, 0) * 10.0
	_market_slots_built = slots


func _on_market_card_input(event: InputEvent, card: UiDevCard) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse := event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed:
		return
	if card.card_id.is_empty():
		return
	card.accept_event()
	card_clicked.emit("market", card.card_id, 0)


func _on_deck_input(event: InputEvent, level: int) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse := event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed:
		return
	var deck: UiDeckPile = _deck_piles.get(level)
	if deck == null or deck.remaining <= 0:
		return
	deck.accept_event()
	card_clicked.emit("deck", "", level)


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse := event as InputEventMouseButton
	if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
		blank_clicked.emit()


func _build_spectator() -> void:
	_spectator = UiFrame.new()
	_spectator.name = "Spectator"
	_spectator.frame_texture = UiAssets.frame_l("ink")
	_spectator.frame_border = 4
	_spectator.background_color = UiPalette.CARD
	_spectator.content_padding = Vector4i(24, 18, 24, 18)
	_spectator.shadow_enabled = true
	_spectator.shadow_offset = Vector2i(0, 4)
	_spectator.top_highlight = true
	_spectator.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bottom_holder.add_child(_spectator)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	_spectator.content.add_child(column)

	_spectator_title = Label.new()
	_spectator_title.name = "Title"
	_spectator_title.theme_type_variation = &"UiTitle"
	_spectator_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_spectator_title)

	_spectator_detail = Label.new()
	_spectator_detail.name = "Detail"
	_spectator_detail.add_theme_color_override("font_color", UiPalette.INK_2)
	_spectator_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spectator_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_spectator_detail)

	_spectator_hint = Label.new()
	_spectator_hint.name = "Hint"
	_spectator_hint.text = "回放播放条将在 U6 实现"
	_spectator_hint.add_theme_color_override("font_color", UiPalette.INK_3)
	_spectator_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_spectator_hint)


func _build_right() -> void:
	_right = VBoxContainer.new()
	_right.name = "Right"
	_right.custom_minimum_size.x = RIGHT_MIN_WIDTH
	_right.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_right.add_theme_constant_override("separation", 8)
	_columns.add_child(_right)

	_opponents = VBoxContainer.new()
	_opponents.name = "Opponents"
	_opponents.add_theme_constant_override("separation", 8)
	_right.add_child(_opponents)

	_log = UiLogPanel.new()
	_log.name = "LogPanel"
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right.add_child(_log)


func _update_columns() -> void:
	if _right == null:
		return
	var available: float = size.x - TABLE_MARGIN * 2.0
	var right_width: float = clampf(
			available - LEFT_WIDTH - COLUMN_GAP, 300.0, float(RIGHT_MAX_WIDTH))
	_right.custom_minimum_size.x = right_width


# ---------------------------------------------------------------- 渲染入口

## 视图是唯一真相：每次调用都按视图整桌重画。
## session_info 可选键：names / seat_types / log / strip / pill_text / mode /
## flash_cards / flash_slots / log_limit / catalog / rules / interactive / selection /
## clickable_colors / selected_kind / selected_id / selected_level / popover / take_confirm_enabled。
func render(view: Dictionary, me_seat: int, session_info: Dictionary = {}) -> void:
	# 退出对局时可能还有一拍迟到的视图；不在树里就不要再碰子节点。
	if not is_inside_tree():
		return
	_view = view
	_me_seat = me_seat
	_session = session_info
	var session_catalog: Variant = session_info.get("catalog")
	_catalog = session_catalog if session_catalog is CardCatalog else DataRegistry.card_catalog()
	var session_rules: Variant = session_info.get("rules")
	_rules = session_rules if session_rules is RulesConfig else DataRegistry.rules()

	_render_hud()
	_render_market()
	_render_nobles()
	_render_bank()
	_render_bottom()
	_render_right()
	_update_columns()
	_render_popover()


func _render_hud() -> void:
	var pill: Dictionary
	var pill_text: String = String(_session.get("pill_text", ""))
	var current: int = int(_view.get("current_seat", 0))
	var phase: String = String(_view.get("phase", "playing"))
	if not pill_text.is_empty():
		pill = {"kind": "text", "text": pill_text}
	elif phase == "finished":
		pill = {"kind": "text", "text": "对局结束"}
	elif _is_my_turn():
		pill = {"kind": "mine", "seat": _me_seat, "name": _name(_me_seat)}
	else:
		var seat_type: String = _seat_type(current)
		pill = {
			"kind": "waiting", "seat": current, "name": _name(current),
			"type_label": UiViewMath.seat_type_label(seat_type),
			"thinking": seat_type != "human",
		}
	_hud.render({
		"player_count": int(_view.get("player_count", 2)),
		"round": UiViewMath.round_number(_view),
		"endgame_remaining": UiViewMath.endgame_remaining(_view).size(),
		"pill": pill,
		"mode": String(_session.get("hud_mode", "default")),
	})


func _render_market() -> void:
	_ensure_market_rows()
	var phase: String = String(_view.get("phase", ""))
	var playing_input: bool = _input_interactive() and phase == "playing"
	var show_for_me: bool = _me_seat >= 0 and phase == "playing"
	var selected_kind: String = String(_session.get("selected_kind", ""))
	var selected_id: String = String(_session.get("selected_id", ""))
	var selected_level: int = int(_session.get("selected_level", 0))
	var boards: Dictionary = _view.get("boards", {})
	var decks: Dictionary = _view.get("decks", {})
	var flash_cards: Array = _session.get("flash_cards", [])
	var flash_slots: Array = _session.get("flash_slots", [])
	for level: int in [3, 2, 1]:
		var deck_entry: Variant = decks.get(str(level), {})
		var deck_count: int = int((deck_entry as Dictionary).get("count", 0)) \
				if deck_entry is Dictionary else 0
		var deck: UiDeckPile = _deck_piles[level]
		deck.remaining = deck_count
		deck.selected = selected_kind == "deck" and selected_level == level
		deck.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND \
				if playing_input and deck_count > 0 else Control.CURSOR_ARROW

		var slots: Array = boards.get(str(level), [])
		var cards: Array = _market_cards[level]
		for index: int in cards.size():
			var card: UiDevCard = cards[index]
			var raw_id: Variant = slots[index] if index < slots.size() else null
			var card_id: String = String(raw_id) if raw_id != null else ""
			card.catalog = _catalog
			card.card_back = false
			card.blind_label = false
			card.show_status = playing_input
			card.selected = selected_kind == "market" and card_id == selected_id
			card.flash = (not card_id.is_empty() and card_id in flash_cards) \
					or flash_slots.has(Vector2i(level, index))
			card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND \
					if playing_input and not card_id.is_empty() else Control.CURSOR_ARROW
			if card_id.is_empty():
				var no_missing: Array[Dictionary] = []
				var no_threats: Array[int] = []
				card.card_id = ""
				card.empty = true
				card.affordable = false
				card.shortfall = 0
				card.missing = no_missing
				card.gold_can_pay = 0
				card.threat_seats = no_threats
				continue
			card.empty = false
			card.card_id = card_id
			var shortfall: int = 0
			var missing: Array[Dictionary] = []
			var gold_can_pay: int = 0
			if show_for_me:
				shortfall = UiViewMath.shortfall(_view, _me_seat, card_id, _catalog)
				if shortfall > 0:
					missing = UiViewMath.missing_by_color(_view, _me_seat, card_id, _catalog)
					gold_can_pay = UiViewMath.gold_can_pay(_view, _me_seat, card_id, _catalog)
			card.shortfall = shortfall
			card.missing = missing
			card.gold_can_pay = gold_can_pay
			card.affordable = playing_input and shortfall == 0
			var threats: Array[int] = []
			if show_for_me:
				threats = _threat_seats(card_id)
			elif _me_seat < 0:
				# 观战 / 回放：所有买得起的人都标出来（INTERACTION.md 第 3 节）。
				threats = UiViewMath.affordable_by(_view, card_id, _catalog)
			card.threat_seats = threats


func _threat_seats(card_id: String) -> Array[int]:
	var result: Array[int] = []
	for seat: int in UiViewMath.affordable_by(_view, card_id, _catalog):
		if seat != _me_seat:
			result.append(seat)
	return result


func _render_nobles() -> void:
	for child in _nobles.get_children():
		_nobles.remove_child(child)
		child.queue_free()
	_noble_tiles.clear()
	var noble_ids: Array = _view.get("nobles", [])
	for item: Variant in noble_ids:
		var noble_id: String = String(item)
		var tile := UiNobleTile.new()
		tile.catalog = _catalog
		tile.noble_id = noble_id
		_nobles.add_child(tile)
		_noble_tiles[noble_id] = tile


func _render_bank() -> void:
	var raw: Dictionary = _view.get("bank", {})
	var counts: Dictionary[int, int] = {}
	for color: Enums.GemColor in Enums.ALL_COLORS:
		counts[color] = int(raw.get(Enums.color_to_string(color), 0))
	var phase: String = String(_view.get("phase", ""))
	var playing_input: bool = _input_interactive() and phase == "playing"
	_bank.set_counts(counts)
	_bank.set_selection(_session.get("selection", {}))
	_bank.set_clickable_colors(_session.get("clickable_colors", []))
	_bank.set_interactive(playing_input)
	_bank.set_confirm_enabled(bool(_session.get("take_confirm_enabled", false)))
	_bank.set_hint("点筹码\n选宝石" if playing_input else "")


func _render_bottom() -> void:
	var spectator: bool = _me_seat < 0
	_my_panel.visible = not spectator
	# 回放屏在同一个位置放播放条；这时不显示观战占位框。
	_spectator.visible = spectator and not bool(_session.get("bottom_custom", false))
	if spectator:
		if _spectator.visible:
			var mode: String = String(_session.get("mode", "spectate"))
			var current: int = int(_view.get("current_seat", 0))
			var replay: bool = mode == "replay"
			_spectator_hint.visible = replay
			if replay:
				_spectator_title.text = "回放"
				_spectator_detail.text = String(_session.get("replay_label", "逐步回放"))
			else:
				_spectator_title.text = "观战"
				_spectator_detail.text = "全部 %d 位玩家在右栏 · 当前轮到 %s" % [
					int(_view.get("player_count", 2)), _name(current),
				]
		return

	var player: Dictionary = UiViewMath.player(_view, _me_seat)
	var tokens: Dictionary[int, int] = UiViewMath.tokens(_view, _me_seat)
	var bonuses: Dictionary[int, int] = UiViewMath.bonuses(_view, _me_seat, _catalog)
	var phase: String = String(_view.get("phase", ""))
	var playing_input: bool = _input_interactive() and phase == "playing"
	var raw_reserved: Array = player.get("reserved", [])
	var reserved: Array[Dictionary] = []
	for item: Variant in raw_reserved:
		var entry: Dictionary = item if item is Dictionary else {}
		var card_id: String = UiViewMath.reserved_card_id(entry)
		reserved.append({
			"id": card_id,
			"level": int(entry.get("level", 1)),
			"blind": UiViewMath.is_blind(entry),
			"affordable": playing_input and not card_id.is_empty()
					and UiViewMath.can_afford(_view, _me_seat, card_id, _catalog),
		})
	_my_panel.render({
		"seat": _me_seat,
		"name": _name(_me_seat),
		"seat_type": _seat_type(_me_seat),
		"score": UiViewMath.score(_view, _me_seat, _catalog),
		"win_points": int(_rules.win_points),
		"card_count": UiViewMath.card_count(_view, _me_seat),
		"noble_count": UiViewMath.noble_count(_view, _me_seat),
		"tokens": tokens,
		"bonuses": bonuses,
		"reserved": reserved,
		"max_tokens": int(_rules.max_tokens),
		"max_reserved": int(_rules.max_reserved),
		"catalog": _catalog,
		"can_buy": playing_input,
		"can_select_reserved": playing_input,
		"selected_kind": String(_session.get("selected_kind", "")),
		"selected_id": String(_session.get("selected_id", "")),
		"strip": _strip_data(),
	})


func _strip_data() -> Dictionary:
	var strip_override: Variant = _session.get("strip")
	if strip_override is Dictionary and not (strip_override as Dictionary).is_empty():
		return strip_override
	if _is_my_turn():
		return {
			"kind": "note",
			"text": "轮到你：点银行拿宝石，或点一张卡购买 / 预留",
			"tray_text": "还没选宝石",
			"confirm_label": "确认拿取",
			"confirm_enabled": false,
		}
	if String(_view.get("phase", "")) == "discard" \
			and int(_view.get("current_seat", -1)) == _me_seat:
		return {"kind": "note", "text": "持币超过上限，先弃回银行"}
	return {
		"kind": "note",
		"text": "等 %s 出手…你可以先看看场面" % _name(int(_view.get("current_seat", 0))),
	}


func _render_right() -> void:
	var seats: Array[int] = []
	var current: int = int(_view.get("current_seat", 0))
	var player_count: int = int(_view.get("player_count", 0))
	for seat: int in player_count:
		if _me_seat < 0 or seat != _me_seat:
			seats.append(seat)

	for seat: int in _opponent_panels.keys():
		if seat in seats:
			continue
		var stale: UiOpponentPanel = _opponent_panels[seat]
		_opponents.remove_child(stale)
		stale.queue_free()
		_opponent_panels.erase(seat)

	for index: int in seats.size():
		var seat: int = seats[index]
		var panel: UiOpponentPanel = _opponent_panels.get(seat)
		if panel == null:
			panel = UiOpponentPanel.new()
			panel.name = "Opponent%d" % seat
			_opponents.add_child(panel)
			_opponent_panels[seat] = panel
		_opponents.move_child(panel, index)
		var seat_type: String = _seat_type(seat)
		var replay: bool = String(_session.get("mode", "")) == "replay"
		panel.render({
			"seat": seat,
			"name": _name(seat),
			"seat_type": seat_type,
			"score": UiViewMath.score(_view, seat, _catalog),
			"win_points": int(_rules.win_points),
			"tokens": UiViewMath.tokens(_view, seat),
			"bonuses": UiViewMath.bonuses(_view, seat, _catalog),
			"noble_count": UiViewMath.noble_count(_view, seat),
			"reserved": UiViewMath.player(_view, seat).get("reserved", []),
			"max_tokens": int(_rules.max_tokens),
			"catalog": _catalog,
			"active": seat == current,
			"thinking": seat == current and seat_type != "human" and not replay,
		})

	var entries: Variant = _session.get("log", [])
	var requested_limit: int = int(_session.get("log_limit", 0))
	var default_limit: int = 4 if seats.size() >= 3 else 7
	var limit: int = requested_limit if requested_limit > 0 else default_limit
	_log.render(entries if entries is Array else [], UiViewMath.round_number(_view),
			limit, _catalog)


# ---------------------------------------------------------------- 浮层

func _render_popover() -> void:
	var data: Variant = _session.get("popover", {})
	if not data is Dictionary or (data as Dictionary).is_empty():
		_popover.visible = false
		return
	_popover.render(data)
	_popover.visible = true
	_place_popover()
	_place_popover.call_deferred()


## 浮层出现在选中卡的右侧 14px、顶部 −12px；超出牌桌右边界时翻到左侧。
func _place_popover() -> void:
	if _popover == null or not _popover.visible:
		return
	var anchor: Control = _find_anchor()
	if anchor == null:
		_popover.visible = false
		return
	var origin: Vector2 = get_global_rect().position
	var rect: Rect2 = anchor.get_global_rect()
	var popover_size: Vector2 = _popover.get_combined_minimum_size()
	var x: float = rect.end.x - origin.x + 14.0
	var y: float = rect.position.y - origin.y - 12.0
	if x + popover_size.x > size.x - TABLE_MARGIN:
		x = rect.position.x - origin.x - 14.0 - popover_size.x
	x = clampf(x, TABLE_MARGIN, maxf(size.x - popover_size.x - TABLE_MARGIN, TABLE_MARGIN))
	y = clampf(y, HUD_HEIGHT + TABLE_MARGIN,
			maxf(size.y - popover_size.y - TABLE_MARGIN, HUD_HEIGHT + TABLE_MARGIN))
	_popover.position = Vector2(roundf(x), roundf(y))
	_popover.size = popover_size


func _find_anchor() -> Control:
	var kind: String = String(_session.get("selected_kind", ""))
	var selected_id: String = String(_session.get("selected_id", ""))
	match kind:
		"market":
			for level: int in _market_cards:
				for card: UiDevCard in _market_cards[level]:
					if card.card_id == selected_id:
						return card
		"deck":
			var deck: UiDeckPile = _deck_piles.get(int(_session.get("selected_level", 0)))
			return deck
		"reserved":
			return _my_panel.find_reserved_card(selected_id)
	return null


# ---------------------------------------------------------------- 显示辅助

func _input_interactive() -> bool:
	if _session.has("interactive"):
		return bool(_session.get("interactive", false))
	return _is_my_turn()


func _is_my_turn() -> bool:
	return _me_seat >= 0 \
			and String(_view.get("phase", "")) == "playing" \
			and int(_view.get("current_seat", -1)) == _me_seat


func _name(seat: int) -> String:
	var names: Variant = _session.get("names", [])
	if names is Array and seat >= 0 and seat < (names as Array).size():
		var value: String = String((names as Array)[seat])
		if not value.is_empty():
			return value
	return "座位 %d" % (seat + 1)


func _seat_type(seat: int) -> String:
	var types: Variant = _session.get("seat_types", [])
	if types is Array and seat >= 0 and seat < (types as Array).size():
		var value: String = String((types as Array)[seat])
		if not value.is_empty():
			return value
	return "human"


# ---------------------------------------------------------------- 动效定位

func animation_layer() -> Control:
	return _anim_layer


func catalog() -> CardCatalog:
	return _catalog


func me_seat() -> int:
	return _me_seat


func bank_chip_rect(color: Enums.GemColor) -> Rect2:
	return _bank.chip_rect(color) if _bank != null else Rect2()


func market_card_rect(card_id: String) -> Rect2:
	if card_id.is_empty():
		return Rect2()
	for level: int in _market_cards:
		for card: UiDevCard in _market_cards[level]:
			if card.card_id == card_id:
				return card.get_global_rect()
	return Rect2()


func market_slot_rect(level: int, slot: int) -> Rect2:
	var cards: Array = _market_cards.get(level, [])
	if slot < 0 or slot >= cards.size():
		return Rect2()
	return (cards[slot] as UiDevCard).get_global_rect()


func deck_rect(level: int) -> Rect2:
	var deck: UiDeckPile = _deck_piles.get(level) as UiDeckPile
	return deck.get_global_rect() if deck != null else Rect2()


func noble_rect(noble_id: String) -> Rect2:
	var tile: UiNobleTile = _noble_tiles.get(noble_id) as UiNobleTile
	return tile.get_global_rect() if tile != null else Rect2()


func seat_panel_control(seat: int) -> Control:
	if seat >= 0 and seat == _me_seat and _my_panel != null and _my_panel.visible:
		return _my_panel
	return _opponent_panels.get(seat) as Control


func seat_panel_rect(seat: int) -> Rect2:
	var panel: Control = seat_panel_control(seat)
	return panel.get_global_rect() if panel != null else Rect2()


func seat_reserved_rect(seat: int) -> Rect2:
	if seat >= 0 and seat == _me_seat and _my_panel != null and _my_panel.visible:
		return _my_panel.reserved_area_rect()
	return seat_panel_rect(seat)


func seat_token_rect(seat: int, color: Enums.GemColor) -> Rect2:
	var panel := seat_panel_control(seat)
	if panel is UiMyPanel:
		var own_chip: UiGemChip = (panel as UiMyPanel).token_chip(color)
		if own_chip != null:
			return own_chip.get_global_rect()
	elif panel is UiOpponentPanel:
		var other_chip: UiGemChip = (panel as UiOpponentPanel).token_chip(color)
		if other_chip != null:
			return other_chip.get_global_rect()
	return seat_panel_rect(seat)


func seat_score_control(seat: int) -> Control:
	var panel := seat_panel_control(seat)
	if panel is UiMyPanel:
		return (panel as UiMyPanel).score_control()
	if panel is UiOpponentPanel:
		return (panel as UiOpponentPanel).score_control()
	return null


func seat_bonus_control(seat: int, color: Enums.GemColor) -> Control:
	var panel := seat_panel_control(seat)
	if panel is UiMyPanel:
		return (panel as UiMyPanel).bonus_tile(color)
	if panel is UiOpponentPanel:
		return (panel as UiOpponentPanel).bonus_tile(color)
	return null


func reserved_card_rect(card_id: String) -> Rect2:
	if _my_panel == null or not _my_panel.visible:
		return Rect2()
	return _my_panel.reserved_card_rect(card_id)


func endgame_tag_control() -> Control:
	return _hud.endgame_tag_control() if _hud != null else null


# ---------------------------------------------------------------- 测试 / 调试用

func market_card_ids() -> Dictionary[int, Array]:
	var result: Dictionary[int, Array] = {}
	for level: int in _market_cards:
		var ids: Array[String] = []
		for card: UiDevCard in _market_cards[level]:
			if not card.card_id.is_empty():
				ids.append(card.card_id)
		result[level] = ids
	return result


func deck_counts() -> Dictionary[int, int]:
	var result: Dictionary[int, int] = {}
	for level: int in _deck_piles:
		result[level] = _deck_piles[level].remaining
	return result


func opponent_panel(seat: int) -> UiOpponentPanel:
	return _opponent_panels.get(seat)


func hud() -> UiHud:
	return _hud


func my_panel() -> UiMyPanel:
	return _my_panel


## 左栏底部区域（高 246）：回放屏把播放条挂在这里，和“我的面板”同位置。
func bottom_holder() -> Control:
	return _bottom_holder


func log_panel() -> UiLogPanel:
	return _log


func bank_column() -> UiBankColumn:
	return _bank


func right_column() -> VBoxContainer:
	return _right


func popover() -> UiCardPopover:
	return _popover


func popover_visible() -> bool:
	return _popover != null and _popover.visible
