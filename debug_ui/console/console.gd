## 文本调试台：用命令完整打完一局，验证规则、存档与重放。
## 交互模式：godot --path . debug_ui/console/console.tscn（界面用代码搭，只看 Control + Label）
## 批处理模式（无界面按顺序执行命令文件里的每一行，任一命令失败时退出码 1）：
##   godot --headless --path . debug_ui/console/console.tscn -- --commands <命令文件>
extends Control

const SAVE_DIR: String = "user://saves"
const SCENARIO_DIR: String = "res://tests/scenarios"

## 由 new 开出来的一局（可以用"种子 + 动作序列"存档）/ 由快照载入的一局（只能 dump 快照）。
const ORIGIN_NEW: String = "replay"
const ORIGIN_SNAPSHOT: String = "snapshot"

var _state: GameState = null
var _origin: String = ""
var _origin_seed: int = 0
var _origin_player_count: int = 0
var _action_log: Array[Action] = []
var _failed: bool = false
var _batch: bool = false
var _quit_requested: bool = false

var _log: RichTextLabel
var _status: Label
var _input: LineEdit

func _ready() -> void:
	_batch = not _commands_path().is_empty()
	_build_ui()
	if not DataRegistry.is_valid():
		_print("✗ 数据校验失败，共 %d 个问题：" % DataRegistry.get_errors().size())
		for message: String in DataRegistry.get_errors():
			_print("  x %s" % message)
		_failed = true
		if _batch:
			_finish_batch()
		return
	var commands_path: String = _commands_path()
	if commands_path.is_empty():
		_print("璀璨宝石 · 文本调试台。输入 help 查看命令。")
		_print("试试：new 2 12345 → legal → do 1 → state")
		return
	_print("璀璨宝石 · 文本调试台（批处理：%s）" % commands_path)
	_run_commands_file(commands_path)
	_finish_batch()

func _finish_batch() -> void:
	print("批处理结束：%s" % ("有命令失败（退出码 1）" if _failed else "全部命令成功"))
	get_tree().quit(1 if _failed else 0)

# ---------------------------------------------------------------- 界面

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 8)
	add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)

	_status = Label.new()
	column.add_child(_status)

	_log = RichTextLabel.new()
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.scroll_following = true
	_log.selection_enabled = true
	column.add_child(_log)

	var row := HBoxContainer.new()
	column.add_child(row)
	_input = LineEdit.new()
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.placeholder_text = "输入命令（help 看列表）"
	_input.text_submitted.connect(_on_submitted)
	row.add_child(_input)
	var button := Button.new()
	button.text = "执行"
	button.pressed.connect(func() -> void: _on_submitted(_input.text))
	row.add_child(button)
	_input.grab_focus()
	_update_status()

func _on_submitted(line: String) -> void:
	var trimmed: String = line.strip_edges()
	if trimmed.is_empty():
		return
	_input.clear()
	_print("> %s" % trimmed)
	if not _execute(trimmed):
		_failed = true
	_update_status()

func _print(line: String) -> void:
	_log.append_text(line + "\n")
	if _batch:
		print(line)

func _error(message: String) -> bool:
	_print("✗ %s" % message)
	return false

func _commands_path() -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in args.size():
		if args[index] == "--commands" and index + 1 < args.size():
			return args[index + 1]
	return ""

func _update_status() -> void:
	if _state == null:
		_status.text = "没有进行中的对局（new <2|3|4> [种子]）"
		return
	var stage: String = "轮到座位 %d" % _state.current_seat
	if _state.is_finished():
		stage = "已结束"
	_status.text = "%d 人局 · 种子 %d · %s · %s · 指纹 %s" % [_state.player_count, _state.seed,
			stage, Enums.phase_to_string(_state.phase), _state.fingerprint().substr(0, 8)]

# ---------------------------------------------------------------- 命令分发

func _run_commands_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		_failed = true
		print("✗ 命令文件不存在：%s" % path)
		return
	var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
	for line: String in lines:
		if _quit_requested:
			break
		var trimmed: String = line.strip_edges()
		if trimmed.is_empty() or trimmed.begins_with("#"):
			continue
		print("> %s" % trimmed)
		if not _execute(trimmed):
			_failed = true

func _execute(line: String) -> bool:
	var parts: PackedStringArray = line.split(" ", false)
	if parts.is_empty():
		return true
	match parts[0].to_lower():
		"help":
			_print_help()
			return true
		"new":
			return _cmd_new(parts)
		"state":
			return _cmd_state()
		"legal":
			return _cmd_legal()
		"do":
			return _cmd_do(parts)
		"view":
			return _cmd_view(parts)
		"save":
			return _cmd_save(parts)
		"dump":
			return _cmd_dump(parts)
		"load":
			return _cmd_load(parts)
		"replay":
			return _cmd_replay(parts)
		"quit":
			_quit_requested = true
			return true
	return _error("未知命令：%s（输入 help 看命令列表）" % parts[0])

func _print_help() -> void:
	_print("命令：")
	_print("  new <2|3|4> [种子]     开一局（不写种子就随机，种子会打印出来）")
	_print("  state                  打印当前局面（含状态指纹）")
	_print("  legal                  列出当前玩家的合法动作（带编号）")
	_print("  do <编号>              执行编号对应的合法动作")
	_print("  view <座位|all>        打印某个座位的视图（all = 完整视图；用来检查隐藏信息）")
	_print("  save <文件>            存档（种子 + 动作序列，可重放；只对 new 开出来的局有效）")
	_print("  dump <文件>            导出完整状态快照（预设局面就是这种文件）")
	_print("  load <文件>            载入存档或快照（先找 user://saves/，再找 tests/scenarios/）")
	_print("  replay <文件>          重放存档：逐条校验动作并比对末尾指纹")
	_print("  quit                   退出")

# ---------------------------------------------------------------- 命令实现

func _cmd_new(parts: PackedStringArray) -> bool:
	if parts.size() < 2:
		return _error("用法：new <2|3|4> [种子]")
	if not parts[1].is_valid_int():
		return _error("人数必须是 2 / 3 / 4")
	var player_count: int = int(parts[1])
	var seed: int = randi()
	if parts.size() >= 3:
		if not parts[2].is_valid_int():
			return _error("种子必须是整数")
		seed = int(parts[2])
	var state: GameState = Rules.setup(DataRegistry.rules(), DataRegistry.card_catalog(),
			player_count, seed)
	if state == null:
		return _error("开局失败（人数或数据不对）")
	_state = state
	_origin = ORIGIN_NEW
	_origin_seed = seed
	_origin_player_count = player_count
	_action_log.clear()
	_print("开局：%d 人局，种子 %d（重复这一局：new %d %d）" % [player_count, seed, player_count, seed])
	_print_state()
	return true

func _cmd_state() -> bool:
	if _state == null:
		return _error("还没有对局，先 new <人数> [种子]")
	_print_state()
	return true

func _cmd_legal() -> bool:
	if _state == null:
		return _error("还没有对局，先 new <人数> [种子]")
	if _state.is_finished():
		return _error("对局已结束")
	var actions: Array[Action] = _legal_actions()
	_print("轮到座位 %d，合法动作 %d 个：" % [_state.current_seat, actions.size()])
	for index: int in actions.size():
		_print("  %2d) %s" % [index + 1, _describe_action(actions[index])])
	return true

func _cmd_do(parts: PackedStringArray) -> bool:
	if _state == null:
		return _error("还没有对局，先 new <人数> [种子]")
	if parts.size() < 2 or not parts[1].is_valid_int():
		return _error("用法：do <编号>（编号来自 legal）")
	var actions: Array[Action] = _legal_actions()
	var index: int = int(parts[1])
	if index < 1 or index > actions.size():
		return _error("编号超出范围：当前有 %d 个合法动作" % actions.size())
	var action: Action = actions[index - 1]
	var events: Array[GameEvent] = Rules.apply(_state, action)
	if events.is_empty():
		return _error("执行失败：%s（局面可能已经变了，重新 legal 一下）" % action.describe())
	if _origin == ORIGIN_NEW:
		_action_log.append(action)
	_print("执行：%s" % _describe_action(action))
	for event: GameEvent in events:
		_print("  · %s" % event.describe())
	if _state.is_finished():
		_print("★ 对局结束：%s" % _winner_text())
	return true

func _cmd_view(parts: PackedStringArray) -> bool:
	if _state == null:
		return _error("还没有对局，先 new <人数> [种子]")
	if parts.size() < 2:
		return _error("用法：view <座位号|all>")
	var seat: int = GameState.VIEW_ALL
	if parts[1] != "all":
		if not parts[1].is_valid_int():
			return _error("座位号必须是整数，或写 all 看完整视图")
		seat = int(parts[1])
		if seat < 0 or seat >= _state.player_count:
			return _error("座位号应在 0~%d 之间" % (_state.player_count - 1))
	_print(JSON.stringify(_state.to_dict(seat), "  "))
	return true

func _cmd_save(parts: PackedStringArray) -> bool:
	if _state == null:
		return _error("还没有对局，先 new <人数> [种子]")
	if parts.size() < 2:
		return _error("用法：save <文件>")
	if _origin != ORIGIN_NEW:
		return _error("这一局是从快照载入的，只能 dump 完整状态；save 需要 new 开出来的一局")
	var path: String = _resolve_write_path(parts[1])
	var data: Dictionary = SaveFile.build_replay(_origin_player_count, _origin_seed,
			_action_log, _state.fingerprint())
	if not _write_json(path, data):
		return false
	_print("已存档：%s（%d 步动作，指纹 %s）" % [path, _action_log.size(), _state.fingerprint()])
	return true

func _cmd_dump(parts: PackedStringArray) -> bool:
	if _state == null:
		return _error("还没有对局，先 new <人数> [种子]")
	if parts.size() < 2:
		return _error("用法：dump <文件>")
	var path: String = _resolve_write_path(parts[1])
	if not _write_json(path, SaveFile.wrap_snapshot(_state)):
		return false
	_print("已导出快照：%s（指纹 %s）" % [path, _state.fingerprint()])
	return true

func _cmd_load(parts: PackedStringArray) -> bool:
	if parts.size() < 2:
		return _error("用法：load <文件>")
	var data: Dictionary = _read_json(parts[1])
	if data.is_empty():
		return false
	match SaveFile.kind_of(data):
		SaveFile.KIND_REPLAY:
			return _replay_data(data, false)
		SaveFile.KIND_SNAPSHOT:
			return _load_snapshot(SaveFile.unwrap_snapshot(data))
	return _error("无法识别的文件（需要 kind = replay / snapshot 且 schema_version = %d）"
			% SaveFile.SCHEMA_VERSION)

func _cmd_replay(parts: PackedStringArray) -> bool:
	if parts.size() < 2:
		return _error("用法：replay <文件>")
	var data: Dictionary = _read_json(parts[1])
	if data.is_empty():
		return false
	if SaveFile.kind_of(data) != SaveFile.KIND_REPLAY:
		return _error("replay 只接受重放文件（种子 + 动作序列）")
	return _replay_data(data, true)

# ---------------------------------------------------------------- 载入 / 重放

## verbose = true 时逐条打印每个动作（重放 bug 用）。
func _replay_data(data: Dictionary, verbose: bool) -> bool:
	var parsed: Dictionary = SaveFile.parse_replay(data)
	if parsed.is_empty():
		return _error("重放文件解析失败（详见上面的报错）")
	var state: GameState = Rules.setup(DataRegistry.rules(), DataRegistry.card_catalog(),
			int(parsed["player_count"]), int(parsed["seed"]))
	if state == null:
		return _error("重放开局失败：人数 %s 不支持？" % parsed["player_count"])
	var actions: Array[Action] = parsed["actions"]
	for index: int in actions.size():
		var action: Action = actions[index]
		if verbose:
			_print("  %3d/%d  %s" % [index + 1, actions.size(), _describe_action(action)])
		var events: Array[GameEvent] = Rules.apply(state, action)
		if events.is_empty():
			return _error("第 %d 步重放失败：%s（存档与当前规则/数据不一致）"
					% [index + 1, action.describe()])
	_state = state
	_origin = ORIGIN_NEW
	_origin_seed = int(parsed["seed"])
	_origin_player_count = int(parsed["player_count"])
	_action_log.assign(actions)
	var total: int = actions.size()
	var expected: String = String(parsed["fingerprint"])
	if expected.is_empty():
		_print("重放完成：%d 步，指纹 %s（存档里没有记录指纹，无法比对）" % [total, state.fingerprint()])
		_print_state()
		return true
	if expected != state.fingerprint():
		return _error("重放后状态不一致：存档指纹 %s，现在 %s（改过规则或数据？）"
				% [expected, state.fingerprint()])
	_print("重放完成：%d 步，指纹一致 ✓（%s）" % [total, expected])
	if not verbose:
		_print_state()
	return true

func _load_snapshot(state_data: Dictionary) -> bool:
	var errors: Array[String] = []
	var state: GameState = GameState.from_dict(state_data, DataRegistry.rules(),
			DataRegistry.card_catalog(), errors)
	if state == null:
		return _error("快照载入失败（共 %d 个问题，详见上面的报错）" % maxi(errors.size(), 1))
	_state = state
	_origin = ORIGIN_SNAPSHOT
	_action_log.clear()
	_print("已载入快照：%d 人局，指纹 %s" % [state.player_count, state.fingerprint()])
	_print_state()
	return true

# ---------------------------------------------------------------- 打印局面

func _print_state() -> void:
	var state: GameState = _state
	var round_number: int = 1
	for count: int in state.turn_counts:
		round_number = maxi(round_number, count + 1)
	_print("── 局面：%d 人局 · 种子 %d · 第 %d 回合 · 轮到座位 %d · 阶段 %s · 指纹 %s"
			% [state.player_count, state.seed, round_number, state.current_seat,
			Enums.phase_to_string(state.phase), state.fingerprint().substr(0, 12)])
	var bank_parts: Array[String] = []
	for color: Enums.GemColor in Enums.ALL_COLORS:
		bank_parts.append("%s%d" % [Enums.color_to_zh(color), state.bank_count(color)])
	_print("银行：%s" % " ".join(bank_parts))
	_print("牌堆：1 级 %d 张 · 2 级 %d 张 · 3 级 %d 张"
			% [state.deck_count(1), state.deck_count(2), state.deck_count(3)])
	for level: int in [1, 2, 3]:
		var slots: Array = state.boards[level]
		var parts: Array[String] = []
		for slot: Variant in slots:
			parts.append(_card_brief(slot) if slot != null else "—")
		_print("场面 %d 级：%s" % [level, " ｜ ".join(parts)])
	var noble_parts: Array[String] = []
	for noble: NobleData in state.nobles:
		noble_parts.append(_noble_brief(noble))
	_print("贵族（场面）：%s" % (" ".join(noble_parts) if not noble_parts.is_empty() else "无"))
	if not state.pending_nobles.is_empty():
		var pending: Array[String] = []
		for noble: NobleData in state.pending_nobles:
			pending.append(_noble_brief(noble))
		_print("待选贵族：%s" % " ".join(pending))
	for player: PlayerState in state.players:
		_print(_player_line(player))
	if state.endgame_triggered:
		_print("终局：已触发（座位 %d 已到胜利分）" % state.trigger_seat)
	if state.is_finished():
		_print("结果：%s（%s）" % [_winner_text(), state.finished_reason])
		for player: PlayerState in state.players:
			_print("  座位 %d：%d 分（卡牌 %d 分 + 贵族 %d 分），已购 %d 张"
					% [player.seat, player.total_points(), player.card_points(),
					player.noble_points(), player.purchased.size()])

func _player_line(player: PlayerState) -> String:
	var marker: String = "★当前" if player.seat == _state.current_seat and not _state.is_finished() else ""
	var tokens: Array[String] = []
	for color: Enums.GemColor in Enums.ALL_COLORS:
		var amount: int = player.token_count_of(color)
		if amount > 0:
			tokens.append("%s%d" % [Enums.color_to_zh(color), amount])
	var discounts: Array[String] = []
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		var amount: int = player.discount_count(color)
		if amount > 0:
			discounts.append("%s%d" % [Enums.color_to_zh(color), amount])
	var reserved: Array[String] = []
	for entry: ReservedCard in player.reserved:
		var brief: String = entry.card.id if not entry.card.is_unknown() else "?%d级" % entry.card.level
		reserved.append("%s%s" % [brief, "(盲抽)" if entry.blind else ""])
	var nobles: Array[String] = []
	for noble: NobleData in player.nobles:
		nobles.append(noble.id)
	return "座位 %d %s：宝石 %d 枚%s ｜ 卡牌 %d 张 %d 分%s ｜ 预留 %d：%s ｜ 贵族 %s ｜ 合计 %d 分" % [
		player.seat, marker, player.token_count(),
		("（%s）" % " ".join(tokens)) if not tokens.is_empty() else "",
		player.purchased.size(), player.card_points(),
		("（%s）" % " ".join(discounts)) if not discounts.is_empty() else "",
		player.reserved_count(), " ".join(reserved) if not reserved.is_empty() else "无",
		" ".join(nobles) if not nobles.is_empty() else "无",
		player.total_points(),
	]

func _winner_text() -> String:
	var seats: Array[String] = []
	for seat: int in _state.winners:
		seats.append("座位 %d" % seat)
	return "%s 获胜" % "、".join(seats) if not seats.is_empty() else "无胜者"

func _card_brief(card: Variant) -> String:
	if card == null:
		return "—"
	var data: CardData = card
	if data.is_unknown():
		return "?%d级" % data.level
	return "%s %s%d分[%s]" % [data.id, Enums.color_to_zh(data.bonus), data.points, _cost_text(data)]

func _cost_text(card: CardData) -> String:
	var parts: Array[String] = []
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		if card.cost_of(color) > 0:
			parts.append("%s%d" % [Enums.color_to_zh(color), card.cost_of(color)])
	return " ".join(parts) if not parts.is_empty() else "无"

func _noble_brief(noble: NobleData) -> String:
	var parts: Array[String] = []
	for color: Enums.GemColor in Enums.PURCHASABLE_COLORS:
		if noble.requirement_of(color) > 0:
			parts.append("%s%d" % [Enums.color_to_zh(color), noble.requirement_of(color)])
	return "%s[%s]" % [noble.id, " ".join(parts)]

## 动作描述 + 卡牌细节（core 里的 describe 不查卡表，这里补上）。
func _describe_action(action: Action) -> String:
	var suffix: String = ""
	if not action.card_id.is_empty():
		var card: CardData = _state.catalog.card(action.card_id)
		if card != null:
			suffix = "（%s级 %s加成 %d分 花费[%s]）" % [card.level, Enums.color_to_zh(card.bonus),
					card.points, _cost_text(card)]
	return action.describe() + suffix

func _legal_actions() -> Array[Action]:
	return Rules.get_legal_actions(_state.to_dict(_state.current_seat),
			DataRegistry.card_catalog(), DataRegistry.rules())

# ---------------------------------------------------------------- 文件

func _read_json(name: String) -> Dictionary:
	var path: String = _resolve_read_path(name)
	if path.is_empty():
		_error("找不到文件：%s（先找 user://saves/，再找 tests/scenarios/；也可以写完整 res:// 或 user:// 路径）" % name)
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		_error("%s：第 %d 行 JSON 语法错误：%s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	if not json.data is Dictionary:
		_error("%s：顶层必须是一个对象" % path)
		return {}
	_print("读取：%s" % path)
	return json.data

func _write_json(path: String, data: Dictionary) -> bool:
	var directory: String = path.get_base_dir()
	if path.begins_with("user://") and not DirAccess.dir_exists_absolute(directory):
		var error: Error = DirAccess.make_dir_recursive_absolute(directory)
		if error != OK:
			return _error("建不了目录 %s：%s" % [directory, error_string(error)])
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _error("写不了 %s：%s" % [path, error_string(FileAccess.get_open_error())])
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	return true

func _candidate_paths(name: String) -> Array[String]:
	if name.contains("://"):
		return [name]
	var file_name: String = name if name.ends_with(".json") else name + ".json"
	return ["%s/%s" % [SAVE_DIR, file_name], "%s/%s" % [SCENARIO_DIR, file_name]]

func _resolve_read_path(name: String) -> String:
	for path: String in _candidate_paths(name):
		if FileAccess.file_exists(path):
			return path
	return ""

func _resolve_write_path(name: String) -> String:
	if name.contains("://"):
		return name
	var file_name: String = name if name.ends_with(".json") else name + ".json"
	return "%s/%s" % [SAVE_DIR, file_name]
