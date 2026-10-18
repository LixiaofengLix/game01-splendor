## 音效钩子：调用点固定，素材放在 ui/assets/sfx/，文件不存在时静默跳过。
## U5 只留调用点和开关（UiSettings.sfx_enabled）；素材与音量在后续阶段再加。
class_name UiSfx
extends RefCounted

const DIR := "res://ui/assets/sfx/"
const SOUNDS: Dictionary[String, String] = {
	"click": "click.wav",
	"take": "gems_taken.wav",
	"reserve": "card_reserved.wav",
	"purchase": "card_purchased.wav",
	"noble": "noble_visited.wav",
	"endgame": "endgame_triggered.wav",
	"finish": "game_finished.wav",
}
## 事件类型 → 音效 id；没有映射的事件不出声。
const EVENT_SOUNDS: Dictionary[String, String] = {
	"gems_taken": "take",
	"card_reserved": "reserve",
	"card_purchased": "purchase",
	"noble_visited": "noble",
	"endgame_triggered": "endgame",
	"game_finished": "finish",
}

## 测试钩子：记录播放过的音效 id（素材为空时也能验证调用点）。
## 只保留最近 128 条，正式运行也不会无限增长。
static var _calls: Array[String] = []
const MAX_CALLS := 128
## 素材存在性只查一次。
static var _missing: Dictionary[String, bool] = {}
static var _streams: Dictionary[String, AudioStream] = {}
static var _player: AudioStreamPlayer = null


## 播放一个音效；素材不存在就什么都不做。
static func play(id: String) -> void:
	if not UiSettings.sfx_enabled():
		return
	if _calls.size() < MAX_CALLS:
		_calls.append(id)
	var file_name: String = String(SOUNDS.get(id, ""))
	if file_name.is_empty():
		return
	var path: String = DIR + file_name
	if bool(_missing.get(path, false)):
		return
	if not ResourceLoader.exists(path):
		_missing[path] = true
		return
	var stream: AudioStream = _streams.get(path)
	if stream == null:
		stream = load(path) as AudioStream
		if stream == null:
			_missing[path] = true
			return
		_streams[path] = stream
	if _player == null or not is_instance_valid(_player):
		var loop: MainLoop = Engine.get_main_loop()
		if not loop is SceneTree:
			return
		var root: Window = (loop as SceneTree).root
		if root == null:
			return
		_player = AudioStreamPlayer.new()
		_player.name = "UiSfxPlayer"
		root.add_child(_player)
	_player.stream = stream
	_player.play()


## 按事件数组播放入场音效；同一批里同一种音效只播一次。
static func play_events(events: Array) -> void:
	var played: Dictionary[String, bool] = {}
	for item: Variant in events:
		if not item is Dictionary:
			continue
		var id: String = String(EVENT_SOUNDS.get(String((item as Dictionary).get("type", "")), ""))
		if id.is_empty() or played.has(id):
			continue
		played[id] = true
		play(id)


static func take_calls() -> Array[String]:
	var copy: Array[String] = []
	copy.assign(_calls)
	_calls.clear()
	return copy


static func clear_calls() -> void:
	_calls.clear()
