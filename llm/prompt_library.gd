## 提示词模板加载：系统提示、回合提示、性格模板都在 data/llm/prompts/。
## 模板只做占位符替换，不在这里拼规则细节，方便不改代码就调整提示词。
class_name PromptLibrary
extends RefCounted

const PROMPT_DIR: String = "res://data/llm/prompts"
const SYSTEM_PATH: String = PROMPT_DIR + "/system.txt"
const TURN_PATH: String = PROMPT_DIR + "/turn.txt"
const PERSONALITY_DIR: String = PROMPT_DIR + "/personalities"

static var _cache: Dictionary[String, String] = {}

static func system_prompt(personality: String, config: RulesConfig) -> String:
	var text: String = _load(SYSTEM_PATH)
	text = text.replace("{{win_points}}", str(config.win_points))
	text = text.replace("{{max_tokens}}", str(config.max_tokens))
	text = text.replace("{{max_reserved}}", str(config.max_reserved))
	text = text.replace("{{take_two_min_remaining}}", str(config.take_two_min_remaining))
	var personality_id: String = personality
	if not LlmProfile.PERSONALITIES.has(personality_id):
		push_error("PromptLibrary：未知性格模板 \"%s\"，改用 balanced" % personality_id)
		personality_id = "balanced"
	var personality_text: String = _load("%s/%s.txt" % [PERSONALITY_DIR, personality_id])
	if personality_text.is_empty():
		return text
	return text.strip_edges() + "\n\n" + personality_text.strip_edges()

static func turn_prompt(view: Dictionary, legal_actions: Array[Action],
		catalog: CardCatalog, config: RulesConfig, retry_note: String = "") -> String:
	var template: String = _load(TURN_PATH)
	var state_text: String = StateDescriber.describe(view, catalog, config)
	var actions_text: String = StateDescriber.describe_actions(view, legal_actions, catalog)
	var text: String = template.replace("{{state}}", state_text).replace("{{actions}}", actions_text)
	if not retry_note.is_empty():
		text += "\n\n注意：上一次回复不可用（%s）。请严格遵守格式，只输出 JSON 对象，action 必须是上面列出的编号。" % retry_note
	return text

## 组装成 OpenAI 兼容的 messages 数组。
static func build_messages(view: Dictionary, legal_actions: Array[Action],
		catalog: CardCatalog, config: RulesConfig, profile: LlmProfile,
		retry_note: String = "") -> Array[Dictionary]:
	var messages: Array[Dictionary] = [
		{"role": "system", "content": system_prompt(profile.personality, config)},
		{"role": "user", "content": turn_prompt(view, legal_actions, catalog, config, retry_note)},
	]
	return messages

## 测试用：模板文件改了以后清缓存。
static func clear_cache() -> void:
	_cache.clear()

static func _load(path: String) -> String:
	if _cache.has(path):
		return _cache[path]
	if not FileAccess.file_exists(path):
		push_error("PromptLibrary：找不到提示词模板 %s" % path)
		return ""
	var text: String = FileAccess.get_file_as_string(path)
	_cache[path] = text
	return text
