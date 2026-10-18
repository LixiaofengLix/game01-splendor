## 单张夹具的牌桌预览：godot --path . ui/dev/table_preview.tscn -- --fixture g3_turn_mine
## 不带参数时显示 g3_turn_mine。截图用 capture.tscn 的 --fixture 参数。
extends Control

const TABLE_SCENE := "res://ui/screens/table/table_screen.tscn"

var _table: UiTableScreen


func _ready() -> void:
	var fixture_name := "g3_turn_mine"
	var args := OS.get_cmdline_user_args()
	var index := args.find("--fixture")
	if index >= 0 and index + 1 < args.size():
		fixture_name = args[index + 1]
	var fixture := UiFixtureLoader.load_fixture(fixture_name)
	if fixture.is_empty():
		printerr("table_preview：夹具 %s 加载失败" % fixture_name)
		get_tree().quit(1)
		return
	_table = load(TABLE_SCENE).instantiate()
	_table.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_table)
	await get_tree().process_frame
	_table.render(fixture["view"], int(fixture["me_seat"]), fixture["session_info"])
	print("table_preview：已渲染 %s（%d 人，me_seat=%d）" % [
		fixture_name,
		int((fixture["view"] as Dictionary).get("player_count", 0)),
		int(fixture["me_seat"]),
	])
