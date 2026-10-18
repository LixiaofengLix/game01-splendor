# data/llm/

大模型 AI 的数据：示例配置与提示词模板。

- `llm_config.example.json` — 用户配置示例。首次运行时会自动复制到 `user://config.json`；
  **真实 API Key 只填在 `user://config.json`，不要写进这个文件，也不要提交进仓库。**
  支持多个配置档（`llm.profiles.<id>`），每个座位可以选择不同的配置档。
- `prompts/system.txt` — 系统提示（规则摘要 + 输出格式），占位符由 `RulesConfig` 替换：
  `{{win_points}}` / `{{max_tokens}}` / `{{max_reserved}}` / `{{take_two_min_remaining}}`。
- `prompts/turn.txt` — 回合提示，占位符 `{{state}}` / `{{actions}}`。
- `prompts/personalities/*.txt` — 性格模板，追加在系统提示后面；id 见 `LlmProfile.PERSONALITIES`。

## 配置档字段

| 键 | 含义 |
|---|---|
| `display_name` | 界面上显示的名字 |
| `base_url` | OpenAI 兼容接口根地址，代码会拼上 `/chat/completions`；以 `/chat/completions` 结尾时原样使用 |
| `api_key` | `Authorization: Bearer` 的 Key；本地 Ollama 可以留空 |
| `model` | 模型名 |
| `temperature` | 0~2 |
| `max_tokens` | 单次回复的最大 token 数。推理模型（如 `deepseek-flash` 默认开启思考）会先用 completion tokens 思考；建议把 `thinking_effort` 设为 `none` / `low`，或把这里调到 4096 以上，否则可能出现 `content` 为空、`finish_reason=length` |
| `request_timeout_ms` | 单次 HTTP 请求超时（毫秒） |
| `think_budget_ms` | 一次决策的总预算（含重试），0 = 不限 |
| `max_retries` | 解析失败 / 编号非法后的重试次数（不含第一次请求），0~5 |
| `structured_output` | `auto`（先试 `response_format`，服务不支持时退回文本解析）/ `json_object`（OpenAI `response_format`）/ `ollama_format`（`format: "json"`）/ `none` |
| `thinking_effort` | 思考强度，作为 `reasoning_effort` 发给服务：`default`（不发，沿用服务默认）/ `none`（关闭思考）/ `low` / `medium` / `high` / `max`。DeepSeek 会把 `medium` 归到 `high`；不支持该参数的服务会自动去掉它重试 |
| `fallback_difficulty` | 失败时由哪档程序 AI 兜底：`easy` / `normal` / `hard` |
| `personality` | 性格模板：`balanced` / `aggressive` / `conservative` / `blocking` |

改完配置后不需要重启：调试界面的「大模型设置」保存后会重新加载。格式约定见根目录 `CLAUDE.md`。
