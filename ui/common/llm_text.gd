## 大模型相关文案：等待计时、失败原因、兜底说明。只做字符串拼接，不读视图。
class_name UiLlmText
extends RefCounted


## 胶囊里的短计时：“已等 12.4 秒”。
static func waiting_short(elapsed_sec: float) -> String:
	return "已等 %.1f 秒" % maxf(elapsed_sec, 0.0)


## 对手面板等待块里的计时：“12.4 / 30 秒”；预算为 0 时只写已等时间。
static func waiting_progress(elapsed_sec: float, limit_sec: float) -> String:
	if limit_sec <= 0.0:
		return "%.1f 秒" % maxf(elapsed_sec, 0.0)
	return "%.1f / %d 秒" % [maxf(elapsed_sec, 0.0), int(roundf(limit_sec))]


static func fallback_reason_title(reason: String) -> String:
	match reason:
		"parse_failed":
			return "回复解析失败"
		"timeout":
			return "思考超时"
		"network":
			return "网络错误"
	return "调用失败"


static func bot_label(bot_type: String) -> String:
	match bot_type:
		"bot_easy":
			return "简单电脑"
		"bot_normal":
			return "普通电脑"
		"bot_hard":
			return "困难电脑"
	return "电脑"


## 我的面板顶条的兜底说明：一眼看懂“谁的大模型怎么了、谁代打”。
static func fallback_strip(seat_name: String, reason: String, bot_type: String,
		attempts: int) -> String:
	var what: String = fallback_reason_title(reason)
	if reason == "parse_failed" and attempts >= 2:
		what = "回复 %d 次都没看懂" % attempts
	elif attempts >= 2:
		what = "%s（第 %d 次请求）" % [what, attempts]
	return "%s 的大模型%s　这一步已由%s代打" % [seat_name, what, bot_label(bot_type)]


## 日志里那条兜底记录的附加说明。
static func fallback_detail(reason: String, bot_type: String) -> String:
	return "%s，由%s代打" % [fallback_reason_title(reason), bot_label(bot_type)]
