# llm/

大模型 AI（阶段 5）。座位控制器和程序 AI 一样继承 `PlayerController`，只拿过滤视图。

- `llm_profile.gd` — 一档配置（`user://config.json` 的 `llm.profiles.<id>`）的类型化对象与校验。
- `llm_client.gd` — OpenAI 兼容的 `/chat/completions` 客户端（HTTPRequest）：
  超时 / HTTP 错误 / 网络错误归类、token 统计、结构化输出（`response_format` / `format`）
  和思考强度（`reasoning_effort`）不支持时自动去掉参数重试、`test_connection()`。
- `state_describer.gd` — 过滤视图转中文文本、合法动作编号（从 1 开始）、隐藏信息检查
  `privacy_problems()`（种子 / 牌堆顺序 / 对手盲抽预留）。
- `prompt_library.gd` — 读取 `data/llm/prompts/` 的系统提示、回合提示与性格模板。
- `llm_controller.gd` — 请求 → 解析 `{"action": 编号, "reason": "..."}` → 重试 → 程序 AI 兜底。
  对外信号（由 `GameController` 转发，IR-08）：`waiting_started` / `reason_emitted` / `fallback_used`。

兜底原因取值：`parse_failed`（回复无法解析 / 编号越界）、`timeout`（单次请求或思考预算超时）、
`network`（断网 / HTTP 错误）。兜底动作用 `data/ai/<fallback_difficulty>.json` 的评估器当场计算，
不创建额外控制器；兜底步骤的随机种子由开局种子派生，和程序 AI 一样可复现。

## 诊断日志

`LlmController` 把每次请求的结果追加到 `user://llm_debug.log`（macOS：
`~/Library/Application Support/Godot/app_userdata/Splendor/llm_debug.log`），每行包含：

- 配置档显示名、模型名、BASE URL、请求超时；
- 尝试次数、HTTP 状态、错误类别（`http` / `timeout` / `network` / `bad_response` / `empty`）、
  错误正文、耗时、token 用量；
- 解析失败时的原始回复片段（截断到 300 字）；
- 成功时的动作编号与理由、是否触发结构化输出 / 思考强度回退；
- `CANCELLED`（换局 / 返回设置）、`FALLBACK`（兜底原因与次数）、`BUDGET_TIMEOUT`。

不记录 API Key，也不记录完整提示词。文件超过 2 MB 会自动清空重来。

`FAILED kind=empty` 表示 HTTP 成功但 `message.content` 为空。日志会带 `finish=...`、
`reasoning_chars=...` 和原始响应片段：如果是 `finish=length` 或 `reasoning_chars>0`，
通常是推理模型把 `max_tokens` 用在了思考过程上：把该配置档的 `thinking_effort` 设为
`none` / `low`，或把 `max_tokens` 调到 4096 以上（或换非推理模型）即可。

## 设置字段

大模型配置档的完整字段见 `data/llm/README.md`。正式设置页（`ui/screens/settings/llm_page.gd`）
暴露：显示名、BASE URL、API Key、模型名、温度、最大回复 token、单次请求超时、
思考预算、解析失败重试、思考强度、结构化输出、兜底难度、性格。
调试面板（`debug_ui/llm_settings/`）也提供同样字段，并多了 `max_tokens` / 超时的直接编辑。

`thinking_effort` 非 `default` 时作为 `reasoning_effort` 发送；DeepSeek 的取值是
`none` / `low` / `high` / `max`（`medium` 会被归到 `high`）。服务返回 400/422 且提到
`reasoning_effort` / `thinking` 不支持时，客户端会自动去掉它重试，结果里的
`thinking_fallback=true` 会写入诊断日志。

排查常用命令：

```bash
LOG="$HOME/Library/Application Support/Godot/app_userdata/Splendor/llm_debug.log"
tail -f "$LOG"
grep -E "FAILED|PARSE_FAILED|FALLBACK|BUDGET_TIMEOUT" "$LOG" | tail -30
```

配置与提示词说明见 `data/llm/README.md`；自检命令见根目录 `CLAUDE.md`。
