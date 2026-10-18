## 牌桌的回合内弹窗：弃宝石、选贵族、结算。
## 只构建显示；点击回调由 UiTableFlow 传进来（Callable 字典）。
class_name UiTableModals
extends RefCounted

const POSITION_ZH: Dictionary[int, Array] = {
	1: ["这位"],
	2: ["左边这位", "右边这位"],
	3: ["左边这位", "中间这位", "右边这位"],
}


## 弹窗必须先加入场景树（UiModalFrame._ready 会建 body），再调用这个函数填内容。
static func populate_discard(modal: UiModalFrame, view: Dictionary, me_seat: int,
		selection: Dictionary, rules: RulesConfig, callbacks: Dictionary) -> void:
	var total: int = UiViewMath.token_total(view, me_seat)
	var need: int = maxi(total - int(rules.max_tokens), 1)
	var selected_total: int = _sum(selection)

	modal.preferred_width = 560
	modal.title = "宝石太多了"
	modal.set_tag("%d / %d" % [total, int(rules.max_tokens)], &"red")

	var description := Label.new()
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_color_override("font_color", UiPalette.INK_2)
	description.text = "回合结束时最多持有 %d 枚。点筹码选出要还给银行的 %d 枚，金币也可以弃。" % [
		int(rules.max_tokens), need,
	]
	modal.body().add_child(description)

	var row := HBoxContainer.new()
	row.name = "DiscardChips"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	modal.body().add_child(row)
	var tokens: Dictionary[int, int] = UiViewMath.tokens(view, me_seat)
	for color: Enums.GemColor in Enums.ALL_COLORS:
		var held: int = int(tokens.get(color, 0))
		if held <= 0:
			continue
		var selected: int = int(selection.get(color, 0))
		var column := VBoxContainer.new()
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_theme_constant_override("separation", 4)
		row.add_child(column)

		var chip := UiGemChip.new()
		chip.name = "DiscardChip_%s" % Enums.color_to_letter(color)
		chip.gem_color = color
		chip.size_key = &"lg"
		chip.count = held - selected
		chip.discard_amount = selected
		var clickable: bool = held - selected > 0 and selected_total < need
		if clickable:
			chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			chip.mouse_filter = Control.MOUSE_FILTER_STOP
			chip.gui_input.connect(_on_discard_chip_input.bind(color, chip, callbacks))
		else:
			chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(chip)

		var name_label := Label.new()
		name_label.text = Enums.color_to_zh(color)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_color_override("font_color", UiPalette.INK_3)
		column.add_child(name_label)

	var summary := HBoxContainer.new()
	summary.name = "DiscardSummary"
	summary.alignment = BoxContainer.ALIGNMENT_CENTER
	summary.add_theme_constant_override("separation", 6)
	summary.add_theme_color_override("font_color", UiPalette.INK_2)
	modal.body().add_child(summary)
	var summary_label := Label.new()
	summary_label.text = "弃掉"
	summary_label.add_theme_color_override("font_color", UiPalette.INK_2)
	summary.add_child(summary_label)
	for color: Enums.GemColor in Enums.ALL_COLORS:
		var amount: int = int(selection.get(color, 0))
		if amount <= 0:
			continue
		var chip := UiGemChip.new()
		chip.gem_color = color
		chip.count = amount
		chip.size_key = &"sm"
		chip.bare = true
		summary.add_child(chip)
		var amount_label := Label.new()
		amount_label.text = "%s %d" % [Enums.color_to_zh(color), amount]
		amount_label.add_theme_color_override("font_color", UiPalette.INK_2)
		summary.add_child(amount_label)
	var after := Label.new()
	after.name = "DiscardAfter"
	after.text = "　弃后 %d / %d" % [total - selected_total, int(rules.max_tokens)]
	after.add_theme_color_override("font_color", UiPalette.INK_2)
	summary.add_child(after)

	var reset := UiButton.new()
	reset.name = "DiscardReset"
	reset.variant = &"quiet"
	reset.text = "重选"
	reset.focus_mode = Control.FOCUS_NONE
	reset.disabled = selected_total == 0
	reset.pressed.connect(func() -> void:
		var callback: Callable = callbacks.get("reset", Callable())
		if callback.is_valid():
			callback.call())
	modal.add_action(reset)

	var confirm := UiButton.new()
	confirm.name = "DiscardConfirm"
	confirm.variant = &"accent"
	confirm.text = "确认弃掉 %d 枚" % need
	confirm.focus_mode = Control.FOCUS_NONE
	confirm.disabled = selected_total != need
	confirm.pressed.connect(func() -> void:
		var callback: Callable = callbacks.get("confirm", Callable())
		if callback.is_valid():
			callback.call())
	modal.add_action(confirm)


static func populate_noble(modal: UiModalFrame, view: Dictionary, me_seat: int,
		selected_id: String, catalog: CardCatalog, callbacks: Dictionary) -> void:
	var candidates: Array = view.get("pending_nobles", [])
	var count: int = candidates.size()
	modal.preferred_width = 560
	modal.title = "%s贵族都想来拜访你" % ["两位" if count == 2 else "三位"]
	modal.set_tag("回合末", &"purple")

	var description := Label.new()
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_color_override("font_color", UiPalette.INK_2)
	description.text = "你的折扣同时满足%s，但每回合只能请一位。剩下的留在场上，以后仍可能来访。" % (
			"两位" if count == 2 else "三位")
	modal.body().add_child(description)

	var row := HBoxContainer.new()
	row.name = "NobleCandidates"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	modal.body().add_child(row)
	var positions: Array = POSITION_ZH.get(count, [])
	for index: int in count:
		var noble_id := String(candidates[index])
		var column := VBoxContainer.new()
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_theme_constant_override("separation", 6)
		row.add_child(column)

		var tile := UiNobleTile.new()
		tile.name = "NobleCandidate_%s" % noble_id
		tile.catalog = catalog
		tile.noble_id = noble_id
		tile.big = true
		tile.selected = noble_id == selected_id
		tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tile.gui_input.connect(_on_noble_tile_input.bind(noble_id, tile, callbacks))
		column.add_child(tile)

		var position_label := Label.new()
		position_label.text = String(positions[index]) if index < positions.size() else "这位"
		position_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		position_label.add_theme_color_override("font_color", UiPalette.INK_3)
		column.add_child(position_label)

	var discount_row := HBoxContainer.new()
	discount_row.name = "MyDiscounts"
	discount_row.alignment = BoxContainer.ALIGNMENT_CENTER
	discount_row.add_theme_constant_override("separation", 6)
	modal.body().add_child(discount_row)
	var discount_label := Label.new()
	discount_label.text = "你的折扣"
	discount_label.add_theme_color_override("font_color", UiPalette.INK_3)
	discount_row.add_child(discount_label)
	var bonuses: Dictionary[int, int] = UiViewMath.bonuses(view, me_seat, catalog)
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		var tile := UiBonusTile.new()
		tile.gem_color = color
		tile.count = int(bonuses.get(color, 0))
		tile.size_key = &"md"
		discount_row.add_child(tile)

	var confirm := UiButton.new()
	confirm.name = "NobleConfirm"
	confirm.variant = &"accent"
	confirm.focus_mode = Control.FOCUS_NONE
	confirm.disabled = selected_id.is_empty()
	if selected_id.is_empty():
		confirm.text = "先选一位贵族"
	else:
		var index: int = candidates.find(selected_id)
		var position: String = "这位"
		if index >= 0 and index < positions.size():
			position = String(positions[index])
		var noble: NobleData = catalog.noble(selected_id) if catalog != null else null
		var points: int = noble.points if noble != null else 3
		confirm.text = "请%s来访（+%d 分）" % [position, points]
	confirm.pressed.connect(func() -> void:
		var callback: Callable = callbacks.get("confirm", Callable())
		if callback.is_valid():
			callback.call())
	modal.add_action(confirm)


static func populate_result(modal: UiModalFrame, result: Dictionary, view: Dictionary,
		rules: RulesConfig, names: Array, types: Array, callbacks: Dictionary,
		can_save: bool = true, saved: bool = false) -> void:
	var player_count: int = int(view.get("player_count", 0))
	var scores: Dictionary = result.get("scores", {})
	var cards: Dictionary = result.get("cards", {})
	var nobles: Dictionary = result.get("nobles", {})
	var winners: Array = result.get("winners", [])
	var stalled: bool = String(result.get("reason", "")) == "stalled"

	modal.preferred_width = 720
	modal.title = "对局僵持，按分数结算" if stalled else "对局结束"
	modal.set_tag("第 %d 轮" % int(result.get("round", 1)), &"dark")

	var header := HBoxContainer.new()
	header.name = "ResultHeader"
	header.add_theme_constant_override("separation", 14)
	modal.body().add_child(header)
	var winner_seat: int = int(winners[0]) if not winners.is_empty() else 0
	header.add_child(UiAssets.mascot_icon(winner_seat, 64))

	var title_column := VBoxContainer.new()
	title_column.add_theme_constant_override("separation", 4)
	title_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(title_column)
	var title := Label.new()
	title.name = "ResultTitle"
	title.theme_type_variation = &"UiTitle"
	title.text = _result_title(result, winners, names, stalled)
	title_column.add_child(title)
	var subtitle := Label.new()
	subtitle.name = "ResultSubtitle"
	subtitle.add_theme_color_override("font_color", UiPalette.INK_2)
	subtitle.text = _result_subtitle(result, rules, stalled)
	title_column.add_child(subtitle)

	var ranking := VBoxContainer.new()
	ranking.name = "ResultRanking"
	ranking.add_theme_constant_override("separation", 4)
	modal.body().add_child(ranking)
	var order: Array[int] = []
	for seat: int in player_count:
		order.append(seat)
	order.sort_custom(func(a: int, b: int) -> bool:
		var score_a: int = int(scores.get(str(a), 0))
		var score_b: int = int(scores.get(str(b), 0))
		if score_a != score_b:
			return score_a > score_b
		var cards_a: int = int(cards.get(str(a), 0))
		var cards_b: int = int(cards.get(str(b), 0))
		if cards_a != cards_b:
			return cards_a < cards_b
		return a < b)
	for index: int in order.size():
		ranking.add_child(_ranking_row(order[index], index + 1, winners, scores, cards, nobles,
				names, types))

	var tiebreak: String = String(result.get("tiebreak", ""))
	if not tiebreak.is_empty():
		var note := UiFrame.new()
		note.name = "TiebreakNote"
		note.frame_texture = UiAssets.frame_s("dark")
		note.frame_border = 2
		note.background_color = UiPalette.HUD_HIGHLIGHT
		note.content_padding = Vector4i(10, 7, 10, 7)
		modal.body().add_child(note)
		var note_label := Label.new()
		note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note_label.add_theme_color_override("font_color", UiPalette.CREAM)
		note_label.text = _tiebreak_text(result, names)
		note.content.add_child(note_label)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal.body().add_child(footer)
	var footer_label := Label.new()
	footer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_label.add_theme_color_override("font_color", UiPalette.INK_3)
	footer_label.text = _result_footer(result, rules, stalled)
	footer.add_child(footer_label)

	var close := UiButton.new()
	close.name = "ResultClose"
	close.variant = &"quiet"
	close.text = "查看牌桌"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void:
		var callback: Callable = callbacks.get("close", Callable())
		if callback.is_valid():
			callback.call())
	modal.add_action(close)

	var main_menu := UiButton.new()
	main_menu.name = "ResultMainMenu"
	main_menu.variant = &"ghost"
	main_menu.text = "回主菜单"
	main_menu.focus_mode = Control.FOCUS_NONE
	main_menu.pressed.connect(func() -> void:
		var callback: Callable = callbacks.get("main_menu", Callable())
		if callback.is_valid():
			callback.call())
	modal.add_action(main_menu)

	var save_replay := UiButton.new()
	save_replay.name = "ResultSaveReplay"
	save_replay.variant = &"ghost"
	save_replay.focus_mode = Control.FOCUS_NONE
	if not can_save:
		save_replay.text = "保存回放（不可用）"
		save_replay.disabled = true
		save_replay.tooltip_text = "这局来自预设局面，没有种子和动作序列"
	elif saved:
		save_replay.text = "已保存回放"
		save_replay.disabled = true
	else:
		save_replay.text = "保存回放"
	save_replay.pressed.connect(func() -> void:
		var callback: Callable = callbacks.get("save_replay", Callable())
		if callback.is_valid():
			callback.call())
	modal.add_action(save_replay)

	var rematch := UiButton.new()
	rematch.name = "ResultRematch"
	rematch.variant = &"accent"
	rematch.text = "再来一局"
	rematch.focus_mode = Control.FOCUS_NONE
	rematch.pressed.connect(func() -> void:
		var callback: Callable = callbacks.get("rematch", Callable())
		if callback.is_valid():
			callback.call())
	modal.add_action(rematch)


static func _ranking_row(seat: int, rank: int, winners: Array, scores: Dictionary,
		cards: Dictionary, nobles: Dictionary, names: Array, types: Array) -> Control:
	var row := HBoxContainer.new()
	row.name = "ResultSeat%d" % seat
	row.add_theme_constant_override("separation", 10)

	var rank_label := Label.new()
	rank_label.theme_type_variation = &"UiNum"
	rank_label.custom_minimum_size.x = 26
	rank_label.text = str(rank)
	rank_label.add_theme_color_override(
			"font_color", UiPalette.ORANGE if winners.has(seat) else UiPalette.INK_3)
	row.add_child(rank_label)
	row.add_child(UiAssets.mascot_icon(seat, 26))

	var name_label := Label.new()
	name_label.text = UiEventText.name_of(seat, names)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var seat_type: String = String(types[seat]) if seat < types.size() else "human"
	var type_tag := UiTag.new()
	type_tag.text = UiViewMath.seat_type_label(seat_type)
	type_tag.variant = UiViewMath.seat_type_tag_variant(seat_type)
	row.add_child(type_tag)

	var detail := Label.new()
	detail.text = "卡 %d · 贵族 %d" % [int(cards.get(str(seat), 0)), int(nobles.get(str(seat), 0))]
	detail.add_theme_color_override("font_color", UiPalette.INK_2)
	row.add_child(detail)

	var score := Label.new()
	score.theme_type_variation = &"UiNumBig"
	score.text = str(int(scores.get(str(seat), 0)))
	score.custom_minimum_size.x = 48
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score.add_theme_color_override(
			"font_color", UiPalette.ORANGE if winners.has(seat) else UiPalette.INK)
	row.add_child(score)
	return row


static func _result_title(result: Dictionary, winners: Array, names: Array, stalled: bool) -> String:
	if stalled:
		return "对局僵持，按分数结算"
	var labels: Array[String] = []
	for item: Variant in winners:
		labels.append(UiEventText.name_of(int(item), names))
	if labels.is_empty():
		return "对局结束"
	if labels.size() == 1:
		return "%s 获胜" % labels[0]
	return "%s 并列获胜" % "、".join(labels)


static func _result_subtitle(result: Dictionary, rules: RulesConfig,
		stalled: bool) -> String:
	var scores: Dictionary = result.get("scores", {})
	var winners: Array = result.get("winners", [])
	if stalled:
		return "没有人的分数达到 %d 分，按现有分数结算" % int(rules.win_points)
	if winners.is_empty():
		return "对局结束"
	var top: int = int(scores.get(str(int(winners[0])), 0))
	return "达到 %d 分（胜利分 %d）" % [top, int(rules.win_points)]


static func _result_footer(result: Dictionary, rules: RulesConfig, stalled: bool) -> String:
	var seconds: int = int(result.get("elapsed_sec", 0))
	var minutes: int = int(seconds / 60)
	var time_text: String = "用时 %d 分钟" % minutes if minutes > 0 else "用时不到 1 分钟"
	var reason: String = "对局无法继续推进" if stalled else "达到 %d 分" % int(rules.win_points)
	return "%s · 结束原因：%s" % [time_text, reason]


static func _tiebreak_text(result: Dictionary, names: Array) -> String:
	var scores: Dictionary = result.get("scores", {})
	var cards: Dictionary = result.get("cards", {})
	var winners: Array = result.get("winners", [])
	var top: int = -1
	for value: Variant in scores.values():
		top = maxi(top, int(value))
	var tied: Array[int] = []
	for key: Variant in scores:
		if int(scores[key]) == top:
			tied.append(int(key))
	tied.sort()
	if tied.size() <= 1:
		return ""
	var parts: Array[String] = []
	for seat: int in tied:
		parts.append("%s %d 张" % [UiEventText.name_of(seat, names), int(cards.get(str(seat), 0))])
	var who: Array[String] = []
	for seat: int in tied:
		who.append(UiEventText.name_of(seat, names))
	if String(result.get("tiebreak", "")) == "tie":
		return "%s同为 %d 分，购买的卡牌数也相同（%s），并列获胜。" % [
			"和".join(who), top, "、".join(parts),
		]
	var winner_names: Array[String] = []
	for item: Variant in winners:
		winner_names.append(UiEventText.name_of(int(item), names))
	return "%s同为 %d 分，按规则比较购买的卡牌数：%s，%s胜。" % [
		"和".join(who), top, "、".join(parts), "、".join(winner_names),
	]


static func _on_discard_chip_input(event: InputEvent, color: int, chip: Control,
		callbacks: Dictionary) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse := event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed:
		return
	chip.accept_event()
	var callback: Callable = callbacks.get("color", Callable())
	if callback.is_valid():
		callback.call(color)


static func _on_noble_tile_input(event: InputEvent, noble_id: String, tile: Control,
		callbacks: Dictionary) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse := event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed:
		return
	tile.accept_event()
	var callback: Callable = callbacks.get("select", Callable())
	if callback.is_valid():
		callback.call(noble_id)


static func _sum(values: Dictionary) -> int:
	var total: int = 0
	for value: Variant in values.values():
		total += int(value)
	return total
