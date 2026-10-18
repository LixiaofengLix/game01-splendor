# llm/

大模型 AI（阶段 5）。座位控制器和程序 AI 一样继承 `PlayerController`，只拿过滤视图。

- `llm_profile.gd` — 一档配置（`user://config.json` 的 `llm.profiles.<id>`）的类型化对象与校验。
- `llm_client.gd` — OpenAI 兼容的 `/chat/completions` 客户端（HTTPRequest）：
  超时 / HTTP 错误 / 网络错误归类、token 统计、结构化输出（`response_format` / `format`）
  不支持时自动退回纯文本、`test_connection()`。
- `state_describer.gd` — 过滤视图转中文文本、合法动作编号（从 1 开始）、隐藏信息检查
  `privacy_problems()`（种子 / 牌堆顺序 / 对手盲抽预留）。
- `prompt_library.gd` — 读取 `data/llm/prompts/` 的系统提示、回合提示与性格模板。
- `llm_controller.gd` — 请求 → 解析 `{"action": 编号, "reason": "..."}` → 重试 → 程序 AI 兜底。
  对外信号（由 `GameController` 转发，IR-08）：`waiting_started` / `reason_emitted` / `fallback_used`。

兜底原因取值：`parse_failed`（回复无法解析 / 编号越界）、`timeout`（单次请求或思考预算超时）、
`network`（断网 / HTTP 错误）。兜底动作用 `data/ai/<fallback_difficulty>.json` 的评估器当场计算，
不创建额外控制器；兜底步骤的随机种子由开局种子派生，和程序 AI 一样可复现。

配置与提示词说明见 `data/llm/README.md`；自检命令见根目录 `CLAUDE.md`。
