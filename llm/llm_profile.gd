## 一档大模型配置（对应 user://config.json 的 llm.profiles.<id>）。
## 只负责解析与校验；API Key 只存在于用户目录，不会写进仓库、存档或日志。
## 字段含义见 data/llm/README.md。
class_name LlmProfile
extends RefCounted

const STRUCTURED_AUTO: String = "auto"
const STRUCTURED_JSON_OBJECT: String = "json_object"
const STRUCTURED_OLLAMA_FORMAT: String = "ollama_format"
const STRUCTURED_NONE: String = "none"
const STRUCTURED_OUTPUT_MODES: Array[String] = [
	STRUCTURED_AUTO, STRUCTURED_JSON_OBJECT, STRUCTURED_OLLAMA_FORMAT, STRUCTURED_NONE,
]

const PERSONALITIES: Array[String] = ["balanced", "aggressive", "conservative", "blocking"]
const FALLBACK_DIFFICULTIES: Array[String] = ["easy", "normal", "hard"]

## 配置档 id（JSON 里的键），用于座位引用。
var id: String = ""
## 界面显示名。
var display_name: String = ""
## OpenAI 兼容接口的根地址，例如 https://api.deepseek.com/v1。
var base_url: String = ""
var api_key: String = ""
var model: String = ""
var temperature: float = 0.7
var max_tokens: int = 300
## 单次 HTTP 请求的超时。
var request_timeout_ms: int = 20000
## 一次决策的总预算（含重试）；0 = 不限。
var think_budget_ms: int = 30000
## 解析失败 / 编号非法后的重试次数（不含第一次请求）。
var max_retries: int = 2
## 结构化输出方式：auto / json_object / ollama_format / none。
var structured_output: String = STRUCTURED_AUTO
## 失败时交给哪档程序 AI 兜底。
var fallback_difficulty: String = "hard"
## 性格模板 id，对应 data/llm/prompts/personalities/<id>.txt。
var personality: String = "balanced"

## 从 JSON 解析。expected_id 是配置档在 profiles 里的键；有任何问题都写进 errors 并返回 null。
static func from_dict(data: Dictionary, expected_id: String, errors: Array[String]) -> LlmProfile:
	var before: int = errors.size()
	var profile := LlmProfile.new()
	profile.id = expected_id.strip_edges()
	if profile.id.is_empty():
		errors.append("llm 配置档：id 不能为空")
	if not _is_valid_id(profile.id):
		errors.append("llm 配置档 \"%s\"：id 只能包含小写字母、数字、下划线和连字符" % profile.id)

	var where: String = "llm 配置档 \"%s\"" % profile.id
	profile.display_name = String(data.get("display_name", "")).strip_edges()
	if profile.display_name.is_empty():
		profile.display_name = profile.id

	profile.base_url = String(data.get("base_url", "")).strip_edges()
	if profile.base_url.ends_with("/"):
		profile.base_url = profile.base_url.substr(0, profile.base_url.length() - 1)
	if not (profile.base_url.begins_with("http://") or profile.base_url.begins_with("https://")):
		errors.append("%s：base_url 必须以 http:// 或 https:// 开头" % where)

	profile.api_key = String(data.get("api_key", "")).strip_edges()
	profile.model = String(data.get("model", "")).strip_edges()
	if profile.model.is_empty():
		errors.append("%s：model 不能为空" % where)

	profile.temperature = float(data.get("temperature", 0.7))
	if profile.temperature < 0.0 or profile.temperature > 2.0:
		errors.append("%s：temperature 必须在 0~2 之间，实际为 %s" % [where, profile.temperature])

	profile.max_tokens = int(data.get("max_tokens", 300))
	if profile.max_tokens < 1 or profile.max_tokens > 8192:
		errors.append("%s：max_tokens 必须在 1~8192 之间，实际为 %d" % [where, profile.max_tokens])

	profile.request_timeout_ms = int(data.get("request_timeout_ms", 20000))
	if profile.request_timeout_ms < 500 or profile.request_timeout_ms > 600000:
		errors.append("%s：request_timeout_ms 必须在 500~600000 之间，实际为 %d"
				% [where, profile.request_timeout_ms])

	profile.think_budget_ms = int(data.get("think_budget_ms", 30000))
	if profile.think_budget_ms != 0 and profile.think_budget_ms < 1000:
		errors.append("%s：think_budget_ms 必须是 0（不限）或至少 1000，实际为 %d"
				% [where, profile.think_budget_ms])

	profile.max_retries = int(data.get("max_retries", 2))
	if profile.max_retries < 0 or profile.max_retries > 5:
		errors.append("%s：max_retries 必须在 0~5 之间，实际为 %d" % [where, profile.max_retries])

	profile.structured_output = String(data.get("structured_output", STRUCTURED_AUTO))
	if not STRUCTURED_OUTPUT_MODES.has(profile.structured_output):
		errors.append("%s：structured_output 必须是 %s，实际为 \"%s\""
				% [where, str(STRUCTURED_OUTPUT_MODES), profile.structured_output])

	profile.fallback_difficulty = String(data.get("fallback_difficulty", "hard"))
	if not FALLBACK_DIFFICULTIES.has(profile.fallback_difficulty):
		errors.append("%s：fallback_difficulty 必须是 %s，实际为 \"%s\""
				% [where, str(FALLBACK_DIFFICULTIES), profile.fallback_difficulty])

	profile.personality = String(data.get("personality", "balanced"))
	if not PERSONALITIES.has(profile.personality):
		errors.append("%s：personality 必须是 %s，实际为 \"%s\""
				% [where, str(PERSONALITIES), profile.personality])

	if errors.size() > before:
		return null
	return profile

## 写回 JSON 使用；id 是 profiles 的键，不放在对象里。
func to_dict() -> Dictionary:
	return {
		"display_name": display_name,
		"base_url": base_url,
		"api_key": api_key,
		"model": model,
		"temperature": temperature,
		"max_tokens": max_tokens,
		"request_timeout_ms": request_timeout_ms,
		"think_budget_ms": think_budget_ms,
		"max_retries": max_retries,
		"structured_output": structured_output,
		"fallback_difficulty": fallback_difficulty,
		"personality": personality,
	}

## 复制一份，方便界面编辑时不影响已保存的对象。
func copy() -> LlmProfile:
	var duplicate := LlmProfile.new()
	for field: String in to_dict():
		duplicate.set(field, get(field))
	duplicate.id = id
	return duplicate

func endpoint_url() -> String:
	if base_url.ends_with("/chat/completions"):
		return base_url
	return base_url + "/chat/completions"

static func _is_valid_id(value: String) -> bool:
	if value.is_empty():
		return false
	for index: int in value.length():
		var code: int = value.unicode_at(index)
		var is_lower: bool = code >= 97 and code <= 122
		var is_digit: bool = code >= 48 and code <= 57
		var is_sep: bool = code == 95 or code == 45  # _ -
		if not (is_lower or is_digit or is_sep):
			return false
	return true
