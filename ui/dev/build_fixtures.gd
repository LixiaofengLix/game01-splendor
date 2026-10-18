## 生成 U2 的牌桌夹具到 ui/dev/fixtures/。
## 1. G3 / G4：照着 docs/ui-mockup-v4.html 的局面数据手写（卡牌 id 真实、宝石守恒）；
## 2. 预设局面：tests/scenarios/bank_edges.json / deck_empty.json 转成过滤视图；
## 3. 按种子跑一局（GameController + 随机合法动作控制器），取中途“轮到我”的视图。
## 运行：godot --headless --path . ui/dev/build_fixtures.tscn
extends Node

const FIXTURE_DIR := "res://ui/dev/fixtures"
const VIEW_DIR := "res://ui/dev/fixtures/views"

const G3_SEATS: Array[Dictionary] = [
	{"name": "小明", "type": "human"},
	{"name": "薄荷", "type": "bot_hard"},
	{"name": "紫晶", "type": "bot_normal"},
]
const G4_SEATS: Array[Dictionary] = [
	{"name": "小明", "type": "human"},
	{"name": "薄荷", "type": "bot_hard"},
	{"name": "紫晶", "type": "bot_normal"},
	{"name": "橘子", "type": "llm"},
]
const G2_SEATS: Array[Dictionary] = [
	{"name": "小明", "type": "human"},
	{"name": "薄荷", "type": "bot_normal"},
]
const G4_SCENARIO_SEATS: Array[Dictionary] = [
	{"name": "小明", "type": "human"},
	{"name": "薄荷", "type": "bot_hard"},
	{"name": "紫晶", "type": "bot_normal"},
	{"name": "橘子", "type": "bot_easy"},
]

const G3_MARKET := {
	"3": ["L3-W-04", "L3-G-02", "L3-R-03", "L3-K-01"],
	"2": ["L2-U-03", "L2-G-04", "L2-R-01", "L2-K-03"],
	"1": ["L1-W-03", "L1-U-02", "L1-G-08", "L1-R-04"],
}
const G3_NOBLES: Array[String] = ["N-01", "N-06", "N-09", "N-10"]
const G3_BANK := {"white": 2, "blue": 2, "green": 3, "red": 1, "black": 4, "gold": 3}
const G3_DECKS := {"1": 23, "2": 20, "3": 14}
const G3_PURCHASED: Array[Array] = [
	["L1-W-08", "L1-W-01", "L1-U-08", "L1-U-01", "L1-G-03", "L1-K-08"],
	["L2-W-01", "L1-G-04", "L1-G-02", "L2-G-06", "L1-R-08", "L1-R-02", "L1-K-02", "L2-K-05"],
	["L1-U-03", "L2-G-01", "L1-R-05"],
]
const G3_TOKENS: Array[Dictionary] = [
	{"white": 1, "blue": 2, "green": 1, "red": 1, "gold": 1},
	{"blue": 1, "red": 2},
	{"white": 2, "green": 1, "red": 1, "black": 1, "gold": 1},
]
const G3_LOG: Array[Dictionary] = [
	{"seat": 2, "text": "紫晶 拿了 {gem:white}{gem:green}{gem:black} 各 1 枚", "time": "刚刚"},
	{"seat": 1, "text": "薄荷 盲抽预留了三级牌堆顶（没有金币了）", "time": "20 秒"},
	{"seat": 0, "text": "小明 购买 {card:L1-W-02}，付 {gem:red}×1", "time": "1 分钟"},
	{"seat": 2, "text": "紫晶 预留 {card:L2-W-03}，拿到 1 枚 {gem:gold}", "time": "1 分钟"},
	{"seat": 1, "text": "薄荷 购买 {card:L2-G-03}", "time": "2 分钟"},
	{"seat": 0, "text": "小明 拿了 {gem:blue}{gem:blue} 2 枚", "time": "2 分钟"},
	{"seat": 2, "text": "紫晶 拿了 {gem:white}{gem:red}{gem:gold}…", "time": "3 分钟"},
]
const G3_BOT_LOG: Array[Dictionary] = [
	{"seat": 1, "text": "薄荷 预留 {card:L2-R-01}，拿到 1 枚 {gem:gold}", "time": "刚刚"},
	{"seat": 2, "text": "紫晶 拿了 {gem:white}{gem:green}{gem:black} 各 1 枚", "time": "20 秒"},
	{"seat": 1, "text": "薄荷 盲抽预留了三级牌堆顶（没有金币了）", "time": "1 分钟"},
	{"seat": 0, "text": "小明 购买 {card:L1-W-02}，付 {gem:red}×1", "time": "1 分钟"},
	{"seat": 2, "text": "紫晶 预留 {card:L2-W-03}，拿到 1 枚 {gem:gold}", "time": "2 分钟"},
	{"seat": 1, "text": "薄荷 购买 {card:L2-G-03}", "time": "2 分钟"},
	{"seat": 0, "text": "小明 拿了 {gem:blue}{gem:blue} 2 枚", "time": "3 分钟"},
]

const G4_MARKET := {
	"3": ["L3-W-01", "L3-U-04", "L3-R-02", "L3-K-03"],
	"2": ["L2-W-05", "L2-U-01", "L2-G-06", "L2-K-01"],
	"1": ["L1-U-07", "L1-G-04", "L1-R-06", "L1-K-05"],
}
const G4_NOBLES: Array[String] = ["N-04", "N-05", "N-08", "N-10"]
const G4_BANK := {"white": 3, "blue": 1, "green": 4, "red": 2, "black": 3, "gold": 2}
const G4_DECKS := {"1": 12, "2": 14, "3": 9}
const G4_PURCHASED: Array[Array] = [
	["L1-W-08", "L2-W-01", "L2-W-03", "L2-W-04",
			"L1-U-08", "L2-U-02", "L1-U-01",
			"L2-G-01", "L1-G-01",
			"L1-R-08", "L1-R-01",
			"L1-K-08", "L2-K-02", "L1-K-01"],
	["L1-W-01", "L1-W-02", "L1-U-03",
			"L1-G-03", "L2-G-03", "L2-G-04", "L3-G-01",
			"L2-R-01", "L1-R-04", "L2-R-03",
			"L1-K-02", "L2-K-04"],
	["L1-W-05", "L3-U-01", "L3-U-03", "L2-U-03",
			"L1-G-05", "L1-R-02", "L1-K-03", "L1-K-04"],
	["L1-W-06", "L1-W-07", "L3-U-02", "L2-U-04",
			"L1-G-06", "L2-G-05",
			"L2-R-02", "L1-R-07", "L2-R-04",
			"L1-K-06"],
]
const G4_TOKENS: Array[Dictionary] = [
	{"white": 2, "blue": 1, "red": 1, "black": 2, "gold": 1},
	{"white": 1, "blue": 2, "green": 1, "red": 1},
	{"blue": 1, "green": 1, "red": 2, "black": 1, "gold": 1},
	{"white": 1, "blue": 2, "green": 1, "red": 1, "black": 1, "gold": 1},
]
const G4_NOBLES_OWNED: Array[Array] = [["N-02"], [], [], []]
const G4_LOG: Array[Dictionary] = [
	{"seat": 0, "text": "小明 购买 {card:L2-W-04}，到达 15 分，触发终局", "time": "刚刚"},
	{"seat": 0, "text": "一位贵族来拜访小明（+3 分）", "time": "刚刚"},
	{"seat": 3, "text": "橘子 拿了 {gem:blue}{gem:green}{gem:black}", "time": "30 秒"},
	{"seat": 2, "text": "紫晶 购买 {card:L1-U-03}", "time": "1 分钟"},
	{"seat": 1, "text": "薄荷 购买 {card:L3-G-01}", "time": "1 分钟"},
]

var _catalog: CardCatalog = null
var _rules: RulesConfig = null
var _failed: bool = false


class RandomController extends PlayerController:
	var rng := RandomNumberGenerator.new()

	func request_action(_view: Dictionary, legal_actions: Array[Action]) -> void:
		if legal_actions.is_empty():
			return
		action_decided.emit(legal_actions[rng.randi_range(0, legal_actions.size() - 1)])


func _ready() -> void:
	if not DataRegistry.is_valid():
		push_error("数据校验失败，先跑 tests/data_report.tscn")
		get_tree().quit(1)
		return
	_catalog = DataRegistry.card_catalog()
	_rules = DataRegistry.rules()
	_ensure_dirs()

	_build_g3_turn_mine()
	_build_g3_bot_turn()
	_build_g3_llm_waiting()
	_build_g3_spectator()
	_build_g3_replay()
	_build_g4_endgame()
	_build_scenario("g2_bank_edges", "res://tests/scenarios/bank_edges.json",
			G2_SEATS, [])
	_build_scenario("g4_deck_empty", "res://tests/scenarios/deck_empty.json",
			G4_SCENARIO_SEATS, [])
	_build_seed_run("g3_seed_run", 3, 20261018, G3_SEATS)
	_build_seed_run("g4_seed_run", 4, 20261019, G4_SEATS)

	if _failed:
		print("夹具生成失败，见上面的报错。")
		get_tree().quit(1)
		return
	print("夹具生成完毕：%s" % FIXTURE_DIR)
	get_tree().quit(0)


# ---------------------------------------------------------------- G3 / G4

func _build_g3_turn_mine() -> void:
	_write_fixture("g3_turn_mine", G3_SEATS, 0, _g3_view(0), G3_LOG, {})


func _build_g3_bot_turn() -> void:
	_write_fixture("g3_bot_turn", G3_SEATS, 0, _g3_view(2), G3_BOT_LOG, {
		"flash_cards": ["L2-R-01"],
		"strip": {
			"kind": "event",
			"seat": 1,
			"text": "薄荷 预留了 {card:L2-R-01}　拿到 1 枚 {gem:gold} · 现在轮到紫晶",
			"right": "刚刚",
		},
	})


## U7 / 17：大模型思考中。座位 2 换成大模型，日志里带一条理由和一条兜底记录。
func _build_g3_llm_waiting() -> void:
	var seats: Array[Dictionary] = G3_SEATS.duplicate(true)
	seats[2]["type"] = "llm"
	var entries: Array[Dictionary] = G3_BOT_LOG.duplicate(true)
	entries[0]["reason"] = "先拿蓝宝石，之后这张二级红很稳。"
	entries[1]["fallback_reason"] = "parse_failed"
	entries[1]["fallback_bot"] = "bot_hard"
	_write_fixture("g3_llm_waiting", seats, 0, _g3_view(2), entries, {
		"llm_waiting": {
			"seat": 2, "profile": "DeepSeek", "attempt": 1,
			"elapsed_sec": 12.4, "limit_sec": 30.0,
		},
		"strip": {
			"kind": "event",
			"seat": 1,
			"text": "薄荷 预留了 {card:L2-R-01}　拿到 1 枚 {gem:gold} · 现在轮到紫晶",
			"right": "刚刚",
		},
	})


func _build_g3_spectator() -> void:
	var view: Dictionary = _g3_view(0)
	view["viewer_seat"] = -1
	# 观战者看不到任何人的盲抽：把座位 0 的盲抽 id 也隐藏。
	var players: Array = view["players"]
	var reserved: Array = players[0]["reserved"]
	reserved[1]["id"] = null
	_write_fixture("g3_spectator", G3_SEATS, -1, view, G3_LOG, {"mode": "spectate"})


func _build_g3_replay() -> void:
	var view: Dictionary = _g3_view(1)
	view["viewer_seat"] = -1
	# 第 37 步（3 人局）= 第 13 轮，和底部的步骤说明保持一致。
	view["turn_counts"] = [12, 12, 12]
	# 回放除非切到某个玩家视角，否则看不到任何人的盲抽。
	for item: Variant in (view["players"] as Array):
		for entry: Variant in ((item as Dictionary)["reserved"] as Array):
			if bool((entry as Dictionary).get("blind", false)):
				(entry as Dictionary)["id"] = null
	_write_fixture("g3_replay", G3_SEATS, -1, view, G3_LOG, {
		"mode": "replay",
		"pill_text": "回放 · 第 37 / 74 步",
		"replay_label": "第 37 步 · 第 13 轮 · 薄荷 盲抽预留了三级牌堆顶",
	})


func _build_g4_endgame() -> void:
	var view: Dictionary = _g4_view()
	_write_fixture("g4_endgame", G4_SEATS, 0, view, G4_LOG, {
		"strip": {
			"kind": "event",
			"seat": 0,
			"text": "小明 到 15 分了！终局轮：薄荷、紫晶、橘子各还有一回合，之后结算",
			"right": "终局轮",
		},
	})


func _g3_view(current_seat: int) -> Dictionary:
	var players: Array = []
	players.append(_player(0, G3_TOKENS[0], G3_PURCHASED[0], [
		{"id": "L2-K-04", "level": 2, "blind": false},
		{"id": "L3-U-02", "level": 3, "blind": true},
	], []))
	players.append(_player(1, G3_TOKENS[1], G3_PURCHASED[1], [
		{"id": null, "level": 3, "blind": true},
	], []))
	players.append(_player(2, G3_TOKENS[2], G3_PURCHASED[2], [
		{"id": "L2-W-03", "level": 2, "blind": false},
		{"id": null, "level": 1, "blind": true},
	], []))
	return _view(3, current_seat, [8, 8, 8], G3_BANK, G3_DECKS, G3_MARKET,
			G3_NOBLES, players, 0)


func _g4_view() -> Dictionary:
	var players: Array = []
	for seat: int in 4:
		players.append(_player(seat, G4_TOKENS[seat], G4_PURCHASED[seat],
				_g4_reserved(seat), G4_NOBLES_OWNED[seat]))
	return _view(4, 1, [24, 23, 23, 23], G4_BANK, G4_DECKS, G4_MARKET,
			G4_NOBLES, players, 0, true, 0)


func _g4_reserved(seat: int) -> Array:
	match seat:
		0:
			return [{"id": "L3-K-02", "level": 3, "blind": false}]
		1:
			return [{"id": null, "level": 3, "blind": true}]
		2:
			return [
				{"id": "L2-R-05", "level": 2, "blind": false},
				{"id": null, "level": 2, "blind": true},
			]
		3:
			return [{"id": "L3-G-04", "level": 3, "blind": false}]
	return []


# ---------------------------------------------------------------- 预设局面 / 种子跑局

func _build_scenario(fixture_name: String, path: String, seats: Array[Dictionary],
		log_entries: Array[Dictionary]) -> void:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		_fail("读不到预设局面 %s" % path)
		return
	var data: Dictionary = parsed
	var state_data: Dictionary = SaveFile.unwrap_snapshot(data)
	if state_data.is_empty():
		_fail("%s 不是快照" % path)
		return
	var errors: Array[String] = []
	var state: GameState = GameState.from_dict(state_data, _rules, _catalog, errors)
	if state == null:
		_fail("%s 重建失败：%s" % [path, " / ".join(errors)])
		return
	_write_fixture(fixture_name, seats, 0, state.to_dict(0), log_entries, {})


func _build_seed_run(fixture_name: String, player_count: int, seed_value: int,
		seats: Array[Dictionary]) -> void:
	var controller := GameController.new()
	controller.name = "FixtureGame"
	add_child(controller)

	var controllers: Array[PlayerController] = []
	for seat: int in player_count:
		var random := RandomController.new()
		random.rng.seed = seed_value * 31 + seat
		controllers.append(random)

	# 用容器承接 lambda 里的赋值：GDScript 的 lambda 按值捕获变量，但字典本身是共享引用。
	var captured: Dictionary = {"initial": {}, "mid": {}, "first": {}, "step": 0}
	controller.state_changed.connect(func(view: Dictionary) -> void:
		var viewer: int = int(view.get("viewer_seat", -1))
		var current: int = int(view.get("current_seat", -1))
		var phase: String = String(view.get("phase", ""))
		if viewer != 0 or current != 0 or phase != "playing":
			return
		var step: int = controller.action_count()
		if (captured["initial"] as Dictionary).is_empty():
			captured["initial"] = view.duplicate(true)
		if (captured["first"] as Dictionary).is_empty() and step > 0:
			captured["first"] = view.duplicate(true)
		if (captured["mid"] as Dictionary).is_empty() and step >= 12 and step <= 28:
			captured["mid"] = view.duplicate(true)
			captured["step"] = step
	)

	if not controller.start_with_controllers(player_count, seed_value, controllers):
		_fail("种子跑局 %d 人失败" % player_count)
		controller.queue_free()
		return
	var chosen: Dictionary = captured["mid"] as Dictionary
	if chosen.is_empty():
		chosen = captured["first"] as Dictionary
	if chosen.is_empty():
		chosen = captured["initial"] as Dictionary
	if chosen.is_empty():
		_fail("种子跑局没有拿到座位 0 的视图")
		controller.queue_free()
		return
	_write_fixture(fixture_name, seats, 0, chosen, [], {})
	print("  种子跑局 %s：%d 人，共 %d 步，取第 %d 步后的视图"
			% [fixture_name, player_count, controller.action_count(), int(captured["step"])])
	controller.queue_free()


# ---------------------------------------------------------------- 视图组装

func _view(player_count: int, current_seat: int, turn_counts: Array, bank: Dictionary,
		decks: Dictionary, market: Dictionary, nobles: Array, players: Array,
		viewer_seat: int, endgame_triggered: bool = false,
		trigger_seat: int = -1) -> Dictionary:
	var deck_entries: Dictionary = {}
	for level: String in decks:
		deck_entries[level] = {"count": int(decks[level])}
	var board_entries: Dictionary = {}
	for level: String in market:
		board_entries[level] = (market[level] as Array).duplicate()
	return {
		"schema_version": 1,
		"viewer_seat": viewer_seat,
		"player_count": player_count,
		"current_seat": current_seat,
		"phase": "playing",
		"turn_counts": turn_counts.duplicate(),
		"endgame_triggered": endgame_triggered,
		"trigger_seat": trigger_seat,
		"winners": [],
		"finished_reason": "",
		"bank": bank.duplicate(),
		"decks": deck_entries,
		"boards": board_entries,
		"nobles": nobles.duplicate(),
		"pending_nobles": [],
		"players": players,
	}


func _player(seat: int, tokens: Dictionary, purchased: Array, reserved: Array,
		nobles: Array) -> Dictionary:
	return {
		"seat": seat,
		"tokens": tokens.duplicate(),
		"purchased": purchased.duplicate(),
		"reserved": reserved.duplicate(true),
		"nobles": nobles.duplicate(),
	}


# ---------------------------------------------------------------- 写文件

func _write_fixture(fixture_name: String, seats: Array[Dictionary], me_seat: int,
		view: Dictionary, log_entries: Array[Dictionary], extra: Dictionary) -> void:
	var view_path := "%s/%s.json" % [VIEW_DIR, fixture_name]
	var fixture := {
		"schema_version": 1,
		"name": fixture_name,
		"seats": seats,
		"me_seat": me_seat,
		"log": log_entries,
		"steps": [{"at_ms": 0, "view": "views/%s.json" % fixture_name}],
	}
	for key: String in ["strip", "pill_text", "mode", "replay_label", "flash_cards",
			"log_limit", "llm_waiting"]:
		if extra.has(key):
			fixture[key] = extra[key]
	_write_json(view_path, view)
	_write_json("%s/%s.json" % [FIXTURE_DIR, fixture_name], fixture)
	print("  写入 %s.json（%d 人，me_seat=%d）" % [fixture_name,
			int(view.get("player_count", 0)), me_seat])


func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("写不了 %s" % path)
		return
	file.store_string(JSON.stringify(data, "  ") + "\n")
	file.close()


func _ensure_dirs() -> void:
	for path: String in [FIXTURE_DIR, VIEW_DIR]:
		var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
		if error != OK and error != ERR_ALREADY_EXISTS:
			_fail("建不了目录 %s（%s）" % [path, error_string(error)])


func _fail(message: String) -> void:
	_failed = true
	printerr("build_fixtures：" + message)
