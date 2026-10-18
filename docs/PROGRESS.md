# 进度

> 跨会话交接的唯一依据。每次会话结束更新：已完成 / 与计划的偏差 / 遗留问题 / 下一阶段需要知道的事。

## 当前状态

- **阶段 1（工程骨架与数据层）：已验收并提交（`37b708c`）**
- **阶段 2（核心规则引擎 + 文本调试台）：已验收并提交**（2026-10-17；规则解释经用户确认无异议）
- **阶段 3（对局流程、座位控制器与最小可视化界面）：已验收并提交**（2026-10-17；用户确认提交）。
- **阶段 4（程序 AI）：已验收并提交（2026-10-18；用户确认提交）**。
  三档电脑座位、人机对战、批量模拟和自动自检都已就位；完整 3/4 人局现在可以由 AI 补座位试玩。
- **阶段 5（大模型 AI）：已验收并提交（2026-10-18；用户确认提交）**。
  大模型座位、配置档、提示词、重试 / 兜底、调试界面和本地模拟服务器自检都已就位；
  真实服务 / 本地 Ollama 建议按 `docs/tests/phase_5.md` 各跑一次（需要你填 Key / 安装）。
- **正式 UI（并行线 U0–U9）：U0–U2 已提交；U3 已完成、自动验证通过（2026-10-18，人机试玩待验收）；进度、偏差与下一阶段事项见 `docs/ui/UI_PROGRESS.md`。**
- 人工验收的分工与结果：规则解释 ✓；阶段 3 界面已验收；阶段 4 用户 2026-10-18 确认提交；
  阶段 5 用户 2026-10-18 确认提交（真实服务 / Ollama 为后续可选验收）；
  卡表对照实体卡仍是可选待办。
- 上次更新：2026-10-18

---

## 阶段 5：大模型 AI

### 已完成

- `autoload/app_config.gd`（新 autoload）：读写 `user://config.json`，首次运行从
  `data/llm/llm_config.example.json` 复制；配置档的增删改查、激活配置档、逐条校验错误。
  API Key 只存在用户目录，不进仓库、存档和日志。
- `llm/`：
  - `llm_profile.gd` — 配置档类型化对象与校验（base_url / model / 温度 / max_tokens /
    超时 / 预算 / 重试 / 结构化输出 / 思考强度 / 兜底难度 / 性格）。
  - `llm_client.gd` — OpenAI 兼容 `/chat/completions`：超时、HTTP、网络、空回复归类，
    token 统计，`response_format` / `format` 不支持时自动退回纯文本，`test_connection()`。
  - `state_describer.gd` — 过滤视图转中文文本、合法动作编号（从 1 开始）、
    `privacy_problems()` 隐藏信息检查。
  - `prompt_library.gd` — 系统 / 回合 / 性格模板加载与占位符替换。
  - `llm_controller.gd` — 解析 `{"action": 编号, "reason": "..."}`，重试，程序 AI 兜底；
    信号 `waiting_started` / `reason_emitted` / `fallback_used`（IR-08）。
- `data/llm/`：示例配置（DeepSeek / Ollama 两个配置档）、系统提示、回合提示、四种性格模板、README。
- `game/game_controller.gd`：
  - 新座位类型 `llm`；
  - `start_new_game(player_count, seed, seat_types, seat_options := [])`，大模型座位用
    `{"llm_profile": "id"}` 指定配置档（用户确认的接口，阶段 6 远程座位复用同一数组）；
  - 转发 IR-08 三个信号；新增 `is_current_llm()`。
- `debug_ui/setup/`：大模型座位选项启用；每个座位可选配置档；「大模型设置…」面板。
- `debug_ui/llm_settings/`（新）：配置档增删改、连接参数、思考预算、重试、兜底、性格、
  测试连接；保存到 `user://config.json`。
- `debug_ui/board/`：大模型回合禁用动作按钮；顶栏显示“已等 N / 预算 秒”；日志显示
  每次请求、模型理由和兜底原因；和电脑一样遮蔽当前座位自己盲抽预留的牌。
- `tests/llm_selfcheck.gd/.tscn` + `tests/mock_llm_server.gd`：本地模拟 HTTP 服务器，
  覆盖正常回复、结构化输出回退、HTTP 401/500、断网、超时、乱回复、越界编号、取消、
  完整 LLM vs 程序 AI 对局、`start_new_game` 的 llm 座位、调试棋盘与配置面板。
- `tests/board_smoke.gd` 更新：大模型座位选项启用、配置档下拉框、seat_options 传递。
- 诊断日志（验收后补充）：`LlmController` 把每次请求的结果追加到 `user://llm_debug.log`
  （配置档 / 模型 / BASE URL / 尝试次数 / HTTP 状态 / 错误正文 / 耗时 / token /
  解析失败时的回复片段；不记录 API Key 和完整提示词），超过 2 MB 自动清空；
  用于排查真实服务失败。路径与常用 grep 命令见 `docs/tests/phase_5.md` T5-08。
- 设置与思考强度（验收后补充）：
  - `LlmProfile` 新增 `thinking_effort`（`default` / `none` / `low` / `medium` / `high` /
    `max`），非 default 时作为 `reasoning_effort` 发送；服务不支持时客户端自动去掉并重试，
    结果里的 `thinking_fallback` 写入诊断日志。
  - 正式 UI 16 屏与调试面板补齐：最大回复 token、单次请求超时、思考强度、结构化输出；
    正式 UI 右栏改为可滚动（新字段在 1280×800 下会超出）。
  - `max_tokens` 默认从 300 改为 1024（推理模型会用 completion tokens 思考）；
    已有配置档不会被强制改写，可在设置页调整。
  - `LlmClient.test_connection` 改为与正式请求一致（带 `response_format` / `reasoning_effort`，
    提示词含 JSON），并在成功信息里说明自动关闭了哪些参数。
  - `llm_selfcheck` 增至 136 项；`ui_smoke` 增至 1505 项，U7-04 覆盖新字段的回显与保存。
- 各目录 README、`docs/UI_INTEGRATION.md`、`docs/ui/BRIDGE_AND_REQUESTS.md`（IR-08 状态）、
  `CLAUDE.md` 常用命令已更新。

### 自动验证结果（2026-10-18）

- `tests/llm_selfcheck.tscn`：**136 项检查全部通过，约 5.9 秒**。
  - 配置解析、AppConfig 读写 / 增删改 / 坏 JSON、局面描述与隐藏信息断言、提示词与性格。
  - `LlmClient`：正常回复（120 tokens）、结构化输出不支持时自动回退（2 次请求）、
    思考强度发送 `reasoning_effort` / 不支持时自动去掉、空 content 的诊断字段、
    HTTP 401、断网（network）、超时（timeout）、测试连接。
  - `LlmController`：正常 JSON、代码块 + 前后解释、越界编号重试后 parse_failed 兜底、
    HTTP 500 重试后 network 兜底、HTTP 200 但 content 为空时归为 parse_failed、
    超时预算内 timeout 兜底、`cancel_pending()` 后不再发动作。
  - 完整对局（第 0 座大模型 + 第 1 座简单电脑，模拟服务器）：**34 次请求 / 4080 tokens /
    win_points 正常结束 / 0 次兜底 / 回合数相同**。
  - `start_new_game` 的 `llm` 座位实际推进；不存在的配置档被拒绝（测试里会打印一条预期的
    `GameController：座位 0 的类型 "llm" 在本阶段不可用`，不是失败）；
    两个大模型座位分别使用两个配置档时，请求里的 `model` 各不相同。
  - 调试棋盘日志出现“大模型”等待和“理由”；配置面板能加载配置档。
- `tests/board_smoke.tscn`：101 项检查通过，约 0.5 秒。
- `tests/flow_selfcheck.tscn`：8647 项检查通过，约 3.3 秒。
- `tests/ai_selfcheck.tscn`：149 项检查通过，约 5.7 秒。
- `tests/data_report.tscn`：通过。
- `tests/rules_selfcheck.tscn -- 2000`：523273 项检查通过，137.3 秒；
  2000 局 / 284679 步，最长 273 步（与阶段 4 基线一致，`core/` 未改动）。
  运行中的非法动作 ERROR 日志是“非法动作被拒绝”用例的预期输出。
- 主场景 headless 启动 120 帧：退出码 0。

### 与计划的偏差 / 本阶段定的约定

1. **座位配置接口**（用户确认）：保留 `seat_types`，新增可选 `seat_options: Array[Dictionary]`；
   大模型座位用 `{"llm_profile": "id"}`。阶段 6 的远程座位可以在同一数组里加其他字段。
2. **IR-08 一次落地**（用户确认）：`GameController` 转发 `waiting_started` / `reason_emitted` /
   `fallback_used`；`AppConfig` 提供配置档 CRUD；`LlmClient.test_connection(profile, timeout_ms)`
   发 `test_finished(ok, message, elapsed_ms)`。正式 UI 不用再等假后端。
3. **兜底用 `AIEvaluator` 当场算**，不创建 `BotController` 节点：少一层异步和延迟，
   兜底步骤的随机种子由开局种子派生（`LLM_SEED_SALT`），与程序 AI 一样可复现。
4. **重试语义**：`max_retries` 是“第一次请求失败后的重试次数”（总请求数最多
   `max_retries + 1`）；模型回复允许 markdown 代码块和前后解释，动作编号从 1 开始；
   编号越界按解析失败处理。
5. **思考预算**：`think_budget_ms` 覆盖整次决策（含重试），0 = 不限；
   单次请求超时取 `min(request_timeout_ms, 剩余预算)`。
6. **结构化输出**：`structured_output` 取值 `auto` / `json_object` / `ollama_format` / `none`；
   服务返回 400/422 且正文提到 `response_format` / `format` 不支持时，自动去掉结构化参数重试一次，
   不消耗上层重试次数。Ollama 示例用 `auto`，避免不同版本对 `format` 的兼容差异。
7. **配置档字段**：见 `data/llm/README.md`；界面可改显示的显示名、BASE URL、Key、模型、温度、
   `max_tokens`、单次超时、思考预算、重试、结构化输出、兜底难度、性格。配置档 id 由程序生成
   （`profile_N`），界面只改显示名。
8. **示例配置**：`deepseek`（api.deepseek.com/v1，deepseek-chat）和
   `ollama`（127.0.0.1:11434/v1，qwen2.5:7b）；Key 为空，需用户自己填。模型名是示例值。
9. **提示词语言为中文**；系统提示里的规则数值用 `{{win_points}}` / `{{max_tokens}}` /
   `{{max_reserved}}` / `{{take_two_min_remaining}}` 从 `rules.json` 替换，不在提示词里写死。
10. **隐藏信息断言**：`LlmController` 在调试构建里发送前调用
    `StateDescriber.privacy_problems(view, text)`；测试再用完整视图检查文本不含牌堆卡牌 id
    和对手盲抽预留 id。发布构建不做断言。
11. **大模型座位的界面细节**：顶栏显示的预算是 `think_budget_ms`；每次尝试都会在日志里写
    “第 N 次请求”；理由截断到 200 字；兜底原因映射为中文。界面不显示 token 用量，
    但 `LlmController.token_usage()` 可取。
12. **AppConfig 坏配置不阻塞游戏启动**：只在选择大模型座位时才会失败；没有配置档时
    设置界面的“大模型”选项自动置灰，并提示去「大模型设置」新建。
13. **测试使用本地 HTTP 服务器**（`tests/mock_llm_server.gd`），不依赖外网；HTTP 解析按字节处理，
    因为请求正文含中文（按字符比较长度会少读 UTF-8 字节）。
14. **本阶段没有做**：正式 UI 的设置页（并行 UI 线的第 16 屏）；联网时把 LLM 等待 / 理由
    同步给客户端（阶段 6）；真实服务自动化测试（需要 Key / Ollama）。

### 遗留问题 / 下一阶段需要知道的事

- **真实服务手工验收**：本机没有 OpenAI 兼容 Key，也没有安装 Ollama；真实连接、
  错误 Key、断网、超时的手工步骤见 `docs/tests/phase_5.md`（自动测试已用模拟服务器覆盖同样分支）。
- **阶段 6 联网**：
  - 大模型座位只在主机上运行；主机需要把 `waiting_started` / `reason_emitted` / `fallback_used`
    作为公开事件转发给客户端（理由是模型基于公开视图写的，可以下发）。
  - 客户端不能拿到主机的完整状态；LLM 座位的视图由主机用 `to_dict(seat)` 生成，和远程玩家一样。
  - `seat_options` 可以继续扩展（远程座位加 nickname / token 等），不要把 LLM 配置档 id
    和远程座位信息塞进 `seat_types` 字符串。
  - 掉线玩家的座位由程序 AI 接管时，如果原座位是 LLM，建议直接换 `BotController`（阶段 4 的兜底策略）。
- **重放 / 存档**：对局存档仍是“种子 + 动作序列”，大模型调用不进入存档；重放时只要有动作序列
  就能复现局面，不会重新请求模型。`load_snapshot` / `load_replay` 仍重建为人类控制器（IR-04 未做）。
- **模型输出不确定性**：同一局面两次请求可能给出不同动作；这不影响存档 / 重放（动作已记录），
  但同一局不能靠“重跑请求”复现。LLM 座位的对局不适合做严格的可复现性对比。
- **配置安全**：`user://config.json` 是明文；这是单机工具的正常做法。不要把真实 Key 写进
  `data/llm/llm_config.example.json` 或任何仓库文件。调试面板用密码框显示 Key。
- **Ollama 版本差异**：`ollama` 示例用 `structured_output: "auto"`；如果某个版本对
  `response_format` 报错，客户端会自动退回纯文本。模型名 `qwen2.5:7b` 只是示例，
  拉取哪个模型由你决定。
- **提示词长度**：局面文本含所有可见卡牌、贵族、玩家面板和合法动作，4 人局较长；
  当前 `max_tokens` 默认 300 只限制回复，不限制输入。如果某家服务有上下文上限，
  需要换成更大的模型或精简描述（未做）。
- **阶段 7 导出**：`data/llm/llm_config.example.json` 和 `data/llm/prompts/**` 是运行时读取的文件，
  导出时要确保被打进包里（和 `data/ai/*.json` 一样）；否则首次运行复制示例会失败，
  提示词也读不到。
- 卡表对照实体卡仍是阶段 1 的可选待办。

---

## 阶段 4：程序 AI

### 已完成

- `ai/`：
  - `ai_profile.gd` — 从 `data/ai/*.json` 解析的静态类型配置；权重用整数（厘分），
    校验 schema、id、策略、搜索预算、权重键集合（拼错会报错）。
  - `evaluator.gd` — 只从过滤视图重建局面并推演：一步评分 + 目标卡规划 + 贵族缺口 +
    对手威胁 / 阻挡 + 浪费惩罚；三档策略 `greedy` / `one_step` / `two_ply`。
  - `bot_controller.gd` — 继承 `PlayerController`；正常回合有可配置思考延迟，
    弃宝石 / 选贵族立即处理；子 `Timer` + 请求代数，取消 / 重开后旧动作不会注入新局。
- `data/ai/{easy,normal,hard}.json`：三档权重、搜索预算、思考延迟、随机种子盐。
- `autoload/data_registry.gd`：启动时加载并校验三档 AI 配置，`is_valid()` 包含它们；
  新增 `ai_profile(id)` / `ai_profile_ids()` / `ai_profiles()`。
- `game/`：
  - `GameController.start_new_game()` 支持 `bot_easy` / `bot_normal` / `bot_hard`；
  - 新增 `is_current_human()`；
  - `PlayerController.cancel_pending()`（人类清等待、AI 停计时器）；
    `_reset_controllers()` 在移除控制器前调用它。
- `debug_ui/setup/`：三档电脑选项启用；默认座位 0 人类、其余普通电脑（用户已确认）。
- `debug_ui/board/`：电脑回合禁用所有动作按钮、顶栏显示“电脑思考中…”、
  不显示电脑的弃宝石 / 选贵族弹窗；遮蔽当前电脑自己盲抽预留的牌。
- 新增 `tests/ai_selfcheck.gd/.tscn`、`tests/ai_sim.gd/.tscn`；
  `tests/board_smoke.gd` 增加人类 vs 电脑的回合切换检查。
- `data/rules.json` 新增 `max_turns_safety`（见“偏差”第 3 条）。
- 各目录 README、`docs/UI_INTEGRATION.md`、`CLAUDE.md` 常用命令已更新。

### 自动验证结果（2026-10-17）

- `tests/ai_selfcheck.tscn`：149 项检查通过，约 5.7 秒；
  困难 AI 思考 p50 18ms / p95 30ms / max 35ms（164 次决策），超时 / 节点预算回退 0 次。
- `tests/flow_selfcheck.tscn`：8647 项检查通过，约 3.3 秒。
- `tests/board_smoke.tscn`：93 项检查通过，约 0.5 秒（含人类 vs 普通电脑的回合切换）。
- `tests/rules_selfcheck.tscn -- 2000`：523273 项检查通过，136.0 秒（最长一局 273 步；
  与阶段 3 基线完全一致，说明 `max_turns_safety` 没有被正常随机对局触发）。
- `tests/data_report.tscn`：通过，AI 配置与 `max_turns_safety` 都参与校验。
- `tests/ai_sim.tscn`（100 局 = 50 个种子 × 2 局，镜像交换座位）：
  - easy vs normal：normal 63.5% / easy 36.5%（3 平）；stalled 1/100。
  - normal vs hard：hard 60.5% / normal 39.5%（1 平）；stalled 3/100。
  - easy vs hard：hard 67.0% / easy 33.0%（2 平）；stalled 0/100。
  - 3 人 easy/normal/hard（20 局）：easy 20% / normal 30% / hard 50%，stalled 0 局。
  - 4 人 easy/normal/hard/hard（20 局，hard 占 2 席）：easy 0% / normal 25% / hard 37.5%，
    stalled 0 局。
  - 困难 AI 思考 p50 约 18–19ms / p95 约 31–33ms / max 约 66ms（4 人局）；
    非法动作、AI 回退、超时回退均为 0。

### 与计划的偏差 / 本阶段定的约定

1. **多一个 `ai/ai_profile.gd`**：计划只写了 evaluator / bot_controller；把 JSON 解析成静态类型
   对象，避免热循环里到处查字典，也让“权重键拼错”能被数据校验抓到。
2. **批量模拟命令带场景路径**：按项目约定写成
   `tests/ai_sim.tscn -- --sim 100 easy normal`（计划原文少了 `.tscn`）；
   `--sim` 必须是偶数，每个种子跑两局并反转座位列表，抵消先手优势。
3. **`max_turns_safety` 保险丝（core 改动）**：批量模拟发现过病态对局——双方都满 10 枚宝石、
   银行只剩 1 种颜色、所有卡都买不起且预留已满，唯一合法动作是“拿 1 枚再弃 1 枚”，
   状态原地循环；现有 `stalled` 保险丝只处理“没有合法动作”，抓不到这种情况。
   现在 `rules.json` 增加 `max_turns_safety = 150`：任一玩家到 150 回合且所有人回合数相同时，
   以 `stalled` 结束并按分数结算。正常对局约 35 回合，随机自检最长约 136 回合/人，不会触发。
   该判定只依赖 `turn_counts`，重放可复现。
4. **AI 权重在模拟后调过**：初版权重会让 AI 在前几步预留 3 张三级牌并囤宝石，容易进入上述死锁。
   调整后：`target_gap` 提高（更偏向短期买得起的牌）、新增 `reserve_gap` 惩罚（预留短期买不起的牌）、
   `opponent_threat` / `block_bonus` 降低（减少为阻挡而阻挡）。最终三档胜率见上。
5. **困难搜索参数**：`top_k=8` / `opponent_top_m=12` / `max_nodes=300` / `timeout=700ms`。
   试过 12 / 16 / 500，胜率反而降到 57.5% 且平均回合从 39.6 涨到 61.8，已回退。
6. **思考延迟只用于正常回合**：弃宝石 / 选贵族不等待，否则一次弃 3 枚要等 1.5 秒。
7. **电脑回合界面完全不可操作**：`is_current_human()` 为 false 时所有动作按钮禁用；
   电脑的弃宝石 / 选贵族弹窗不显示；当前电脑的盲抽预留牌显示为 `?级（盲抽）`。
8. **异步取消**：`PlayerController.cancel_pending()` 是阶段 5 / 6 的通用接口；
   大模型 HTTP 和远程等待也要覆盖它。
9. **默认座位**：座位 0 人类、其余普通电脑（用户确认）；设置界面仍可逐座位改。
10. **AI 配置纳入 `DataRegistry.is_valid()`**：AI JSON 坏了会阻止所有开局（fail-fast），
    与卡表 / 规则数据的处理方式一致。

### 遗留问题 / 下一阶段需要知道的事

- **两层的范围**：困难 AI 只模拟“我方一步 + 下一位对手最佳回应”，3/4 人局不是完整极小化极大；
  这是计划里的剪枝设计，不是 bug。
- **对手盲抽预留不可见**：AI 从过滤视图重建局面，把对手盲抽预留当未知牌，因此对手模型略偏保守；
  这是“AI 不能看隐藏信息”的必然结果。
- **`load_snapshot` / `load_replay` 仍重建人类控制器**：阶段 6 的远端座位 / 客户端镜像需要
  另一条控制器装配路径；`start_with_controllers()` 仍是正式注入点。
- **模拟样本量**：100 局配对约 ±10% 的 95% 置信区间；normal vs hard 的 60.5% 是真实但不算悬殊的
  梯度。阶段 5 若要拿困难 AI 做兜底，这个强度够用；想再拉开差距，先改评估特征，不要盲目加大搜索
  （试过，见偏差第 5 条）。
- **病态对局**：100 局里偶尔出现 0~3 局 `stalled`（easy vs normal 1/100、normal vs hard 3/100、
  easy vs hard 0/100）；这是双方都买不起的真实死锁，保险丝会正常结算。
  正常人类对局几乎不会遇到（人不会把自己和对手同时逼进这种状态）。
- **阶段 5 的大模型控制器**：必须实现 `cancel_pending()`；兜底可以直接创建
  `BotController` 或用 `GameController.start_with_controllers()` 注入。
- **阶段 7 导出**：`data/ai/*.json` 是运行时读取的 JSON，导出时要确保它们被打进包里
  （和 `data/*.json`、`tests/scenarios/*.json` 一样）。
- 卡表对照实体卡仍是阶段 1 的可选待办。

---

## 阶段 3：对局流程、座位控制器与最小可视化界面

### 已完成

- `game/`（Node 层，可以引用 autoload；规则仍在 `core/`）：
  - `player_controller.gd` — 控制器基类：`request_action(view, legal_actions)` + `action_decided(action)`。
  - `human_controller.gd` — 人类座位：`submit(action)`；另外提供 `action_requested` 信号，
    方便正式 UI 自己渲染操作面板。
  - `game_controller.gd` — 持有 GameState，按座位向控制器要动作、二次校验后执行；
    发出 `state_changed` / `events_emitted` / `game_finished` / `action_rejected`；
    提供 `start_new_game` / `start_with_controllers` / `load_snapshot` / `load_replay` /
    `submit_action` / `current_view` / `can_save_replay` / `build_replay_data` / `fingerprint` / `reset`。
- `debug_ui/main/` — 新的调试入口（`run/main_scene`）：设置界面 ↔ 棋盘切换。
- `debug_ui/setup/` — 人数、种子、每个座位的类型（阶段 3 只有“人类”可选，其余置灰）。
- `debug_ui/board/` — 最小可视化桌面：
  - 银行、三级场面卡（购买 / 预留）、牌堆剩余与盲抽预留、贵族、玩家面板（宝石 / 折扣 / 分数 / 预留）。
  - 底部的「拿宝石」按钮直接来自合法动作列表；卡牌 / 牌堆按钮按合法动作启用或禁用。
  - 弃宝石、选贵族用弹出选择框；对局结束有结算弹窗。
  - 顶部：存档 / 读档 / 重放（固定 `user://saves/board_quick.json`）、六个预设局面、返回设置。
  - 事件日志。4 人局时右侧玩家面板可滚动。
- `docs/UI_INTEGRATION.md` 草稿；`CLAUDE.md` 常用命令与各目录 README 已更新。
- 新增 `tests/flow_selfcheck.gd/.tscn`、`tests/board_smoke.gd/.tscn`。
- 窗口默认 1280×800（`project.godot`）。

### 自动验证结果（2026-10-17）

- `tests/flow_selfcheck.tscn`：2/3/4 人各 10 局（共 30 局），8647 项检查全部通过，约 3.2 秒。
- `tests/board_smoke.tscn`：84 项检查全部通过，约 0.2 秒。
- `tests/rules_selfcheck.tscn -- 2000`：2000 局 / 523273 项检查全部通过，131.4 秒（core/ 未改动，回归用）。
- `tests/data_report.tscn`：通过；文本调试台批处理回归通过；主场景 headless 启动通过。
- 逐页截图检查了 4 人棋盘、弃宝石 / 选贵族 / 结算弹窗、设置界面（临时预览脚本已删除，截图未进仓库）。

### 与计划的偏差 / 本阶段定的约定

1. **动作泵（计划没提）**：GameController 用循环而不是递归向控制器要动作。同步控制器（阶段 4 的 AI、
   测试）不会因为连续动作爆栈；异步控制器（人类点击、阶段 5 的大模型）保持等待，两边都不需要特殊处理。
2. **多一个 `action_rejected` 信号**：控制器交了非法 / 过期动作时发给界面写日志；对局状态不变。
   阶段 6 主机校验客户端动作时也能复用。
3. **控制器注入点 `start_with_controllers()`**：阶段 4 的 AI、阶段 6 的远程座位、测试都从这里接入；
   阶段 3 的 `start_new_game()` 只接受 `"human"`。
4. **主场景换成 `debug_ui/main/main.tscn`**：`godot --path .` 现在进设置界面 / 棋盘；
   文本调试台仍然用显式场景路径打开（命令见 `CLAUDE.md`）。
5. **棋盘只读当前行动玩家的过滤视图**：不显示种子 / 指纹（这些在调试台里仍有）；
   其他玩家盲抽预留的牌显示为 `?级（盲抽）`，只有轮到本人时才看得到具体卡牌。
6. **存档 / 读档 / 重放固定用 `user://saves/board_quick.json`**，没有文件选择框；
   预设局面从 `res://tests/scenarios/` 读取。快照载入的局不能再存成重放文件（与调试台一致）。
7. **文本调试台没有改成调用 GameController**：阶段 2 的批处理逻辑保留，避免回归；
   `GameController` 的存读档是给界面用的。阶段 7 再考虑统一。
8. **座位类型字符串**：`human`（可用）；置灰项的元数据是 `bot_easy` / `bot_normal` / `bot_hard` /
   `llm` / `remote`，阶段 4 / 5 / 6 直接启用即可。
9. **新增两个自动测试**（计划没提）：`flow_selfcheck` 覆盖 GameController / 控制器 / 视图 / 重放；
   `board_smoke` 实例化界面按按钮走关键流程。它们让本阶段大部分验收可以机器完成。
10. **窗口默认 1280×800**：保证 4 人局一屏能看到主要区域；4 人玩家面板仍需滚动。

### 遗留问题 / 下一阶段需要知道的事

- **阶段 4 接入 AI**：在 `debug_ui/setup/` 取消对应禁用项；实现 `ai/bot_controller.gd` 继承
  `PlayerController`，用 `GameController.start_with_controllers()` 开局。动作泵对同步 AI 友好；
  批量模拟可以直接复用 GameController（也可以像阶段 2 自检那样直接用 Rules）。
- **`load_snapshot` / `load_replay` 目前总是重建为人类控制器**：阶段 6 的客户端镜像模式 / 远程座位
  需要另走一条装配路径（控制器注入），不要把这两个方法当成通用入口。
- **同屏视图**：棋盘显示当前行动玩家的视图。阶段 6 每个客户端应拿自己座位的 `to_dict(自己的座位)`。
- **玩家面板高度**：4 人局需要滚动；正式 UI 再排版。事件日志固定在下半区。
- **存读档**：只有快速存档；没有文件选择框、没有多存档槽。调试台仍是完整的 save/load/replay 工具。
- **UI 对接文档**：`docs/UI_INTEGRATION.md` 是草稿，阶段 7 定稿。
- **预设局面菜单依赖 `res://tests/scenarios/*.json`**：导出时要把这些 JSON 加进导出过滤，
  或者阶段 7 把调试用的「预设局面」菜单去掉。棋盘里的兜底名单只保证菜单项存在，文件没导出仍会加载失败。
- 卡表对照实体卡仍是阶段 1 的可选待办。

---

## 阶段 2：核心规则引擎 + 文本调试台

### 已完成

- `core/` 规则层（全部纯逻辑，不引用 Node / 场景 / 单例）：
  - `player_state.gd` — 宝石、已购卡牌、预留卡牌、贵族；折扣数与分数都是算出来的（不单独存）。
  - `reserved_card.gd` — 预留卡 + `blind` 标记（盲抽来的对别人不可见）。
  - `card_catalog.gd` — 卡牌 / 贵族查表 + **未知牌占位**（从过滤视图重建状态时用）。
  - `action.gd` — 动作数据对象，含 JSON 形态、`equals()`、中文描述；头部注释就是动作的协议定义。
  - `game_event.gd` — 事件对象（12 种类型），头部注释是事件字段的定义；只带公开信息
    （盲抽预留不带 `card_id`）。
  - `game_state.gd` — `to_dict(viewer_seat)` / `from_dict()` / `duplicate_state()` / `validate()` /
    `fingerprint()`；头部注释是状态字典的协议定义。
  - `rules.gd` — `setup()`（带种子的 Fisher–Yates 洗牌）、`get_legal_actions(view, catalog, config)`、
    `apply(state, action)`、`is_action_legal()`、`noble_met()`；`apply` 内部再校验一次合法性，
    执行后自动推进回合末流程。
  - `save_file.gd` — 存档（`kind: "replay"` = 种子 + 动作序列 + 指纹）与快照（`kind: "snapshot"`）两种格式。
- `debug_ui/console/` 文本调试台：命令 `new / state / legal / do / view / save / dump / load / replay / help / quit`；
  界面用代码搭（Label + LineEdit + RichTextLabel）。支持批处理模式
  （`-- --commands <文件>`，任一命令失败退出码 1）。阶段 2 时它是 `run/main_scene`；
  阶段 3 已把主场景换成 `debug_ui/main/main.tscn`，现在用显式场景路径打开。
- `tests/scenarios/` 六个预设局面（快照 JSON）+ 生成脚本 `build_scenarios.gd`：
  `token_limit`（持币 10）、`two_nobles`（同时满足两位贵族）、`endgame`（14 分 + 能买到分）、
  `bank_edges`（银行剩 4 / 3 / 0）、`colors_short`（只剩 2 种颜色可取）、`deck_empty`（1 级牌堆空）。
- `tests/rules_selfcheck.gd` + `.tscn`：随机合法动作跑 N 局（默认 2000），检查宝石守恒、卡牌守恒、
  上限、往返序列化、视图隐藏信息、深拷贝独立、同种子一致、重放一致、终局与胜者、非法动作被拒、支付顺序、
  没有合法动作时跳过 / 一圈都动不了时以 `stalled` 提前结束（后者用手工构造的病态局面固定验证）。
  **实测 2000 局 / 523273 项检查全部通过，用时约 133 秒**（`-- 2000` 可调局数）。
- `docs/tests/phase_2.md`：16 条验收用例，全部实际跑过（输出是真实结果）。
- 各文件夹 README 已更新；`CLAUDE.md` 补上"无界面脚本用 `.tscn` 跑"的约定与常用命令。

### 与计划的偏差 / 本阶段定的约定

1. **自检脚本用场景跑，不用 `-s`**：`godot -s script.gd` 下 autoload 不加载，脚本里访问不到 `DataRegistry`
   （会编译报错）。改用 `tests/xxx.tscn`，参数仍用 `-- 2000`。已写进 `CLAUDE.md`。
2. **`get_legal_actions(view, catalog, config)` 比计划多两个参数**：按你确认的方案，视图里只放 `card_id`，
   卡牌数值走 `CardCatalog`，规则参数走 `RulesConfig`（"数据只有一个来源"）。
3. **`Rules.setup(config, catalog, player_count, seed)` 多了 `catalog`**：同上，core 不读单例。
4. **`allow_take_fewer_when_colors_short` 默认改为 `true`**（按你给的规则说明）：颜色不足 3 种时
   可以拿 1~2 种（拿几种由玩家选）；可取颜色 ≥ 3 种时仍必须拿满 3 种。`data/README.md` 已写明。
5. **"未知牌"概念（你确认现在就打通）**：过滤视图里牌堆只留张数、他人盲抽预留只留等级、
   场面空位是 `null`；`from_dict` 能从这种视图重建出可推演的状态，看不到的牌用未知牌占位
   （id 为空、等级已知，不能被购买 / 预留）。阶段 4 的 AI 和阶段 6 的客户端直接复用这条路。
6. **分数不单独存**：永远由"卡牌分 + 贵族分"算出（没有第二处数据可变形）。因此计划里
   "分数 = 卡牌分 + 贵族分"这条不变量改成两条更实的检查：`GameState.validate()` 会核对
   "已发出去的贵族，玩家的折扣确实够"。
7. **弃宝石、选贵族都是普通动作**（不是自动的）：弃宝石一次弃 1 枚，直到 ≤ 上限；选贵族一回合最多一位，
   没被选的留在场面（已实测：选走 N-06 后 N-01 还在，下一回合自动来访）。
8. **终局判定用"所有人回合数相同"**（等价于"这一轮打完"）：触发者不会再打一回合，
   2 人局里"座位 0 触发 + 座位 1 走一步"就结束。
9. **保险丝 `finished_reason: "stalled"`**：一整圈都没有人有合法动作时提前结束（官方规则没有这条；
   2000 局自检里从未触发）。正常结束都是 `"win_points"`。
10. **新增 `dump <文件>` 命令**（计划里没有）：导出完整状态快照，预设局面就是这种文件；
    `save` 只对 `new` 开出来的一局有效（快照载入的局没有种子+动作可存）。
11. **存档带 `fingerprint`**：`replay` / `load` 时自动比对，不一致就报错——验收"重放后状态一致"更直观。
12. **事件里的盲抽预留不带 `card_id`**（只有等级）：事件要能原样发给所有人，阶段 6 不会因此泄露。
13. **主场景设为 `debug_ui/console/console.tscn`**：方便直接 `godot --path .` 打开调试台；阶段 3 会换成正式入口。
14. **`tests/scenarios/` 带生成脚本**（计划没提）：局面里嵌了卡牌 id，改完 `cards.json` 重跑一次即可。

### 遗留问题 / 下一阶段需要知道的事

- **状态与动作的格式**：`core/game_state.gd` / `core/action.gd` / `core/game_event.gd` 三个文件头部注释
  就是完整协议（存档、快照、将来的联网同步、喂给大模型都用这一套）。阶段 3 的界面、阶段 6 的网络都按它写。
- **合法动作列表顺序固定**（拿三枚 → 拿两枚 → 预留 → 购买；预留和购买按等级、场面位置排），
  所以调试台的编号是稳定的。阶段 3 的界面直接按这个列表渲染按钮即可。
- **`Rules.apply` 每次都重算一次合法动作列表**（O(场面 + 预留)，量级很小）。阶段 4 的困难 AI 要做两层搜索，
  如果 profile 出来觉得慢，先加缓存再谈，别提前优化。
- **`noble_visit_at_turn_end = false`**（贵族买入后立即来访）这个非默认分支没有专门用例覆盖，
  只在代码里保留（改开关 → 跑一次自检就能验证）；阶段 3 如果要用到这个变体再说。
- **`stalled` 保险丝**只在自检构造的病态局面里被触发过，正常对局（2000 局）里一次都没出现——
  这是符合预期的：真要对局卡死需要"银行被搬空 + 全员预留满 + 谁都买不起"同时成立。
- **`tests/scenarios/*.json` 与卡表绑定**：改 `cards.json` 的**数值**后重跑 `build_scenarios.tscn`；
  只改数值不改 id 的话，存档（种子 + 动作序列）和快照都还能用。
- 阶段 1 的 `tests/data_report.tscn` 仍然通过（`rules.json` 改了开关值，不影响数据层校验）。
- 阶段 3 需要的东西都已经就位：`GameState`（主机侧完整状态）、`Rules.get_legal_actions`（界面启用按钮）、
  `Rules.noble_met`（显示谁能拿哪位贵族）、事件流（日志面板）、`SaveFile` + 调试台里的存档 / 读档 / 重放逻辑
  （建议挪进 `GameController`，调试台改为调用它）。

---

## 阶段 1：工程骨架与数据层

### 已完成

- git 初始化；`.gitignore` 补上 `exports/` 与 `.DS_Store`。
- `CLAUDE.md`：架构原则、编码约定、数据格式约定（含卡牌 / 贵族 id 方案）、常用命令。
- 目录结构与各目录 `README.md`：`autoload/ core/ game/ ai/ llm/ net/ debug_ui/ data/ tests/ docs/`。
- `core/`：`enums.gd`（宝石颜色 / 动作类型 / 对局阶段 + 字符串互转）、`card_data.gd`、`noble_data.gd`、`rules_config.gd`。
- `data/`：`cards.json`（90 张，id `L<等级>-<颜色字母>-<序号>`）、`nobles.json`（10 位，id `N-01`…）、`rules.json`（含 4 个规则开关）。
- `autoload/data_registry.gd`：启动加载 + 全量校验（分布、id 唯一、字段、单色花费上限、锚点卡、贵族形状），逐条报错。
- `tests/data_report.gd` + `.tscn`：打印统计、生成 `docs/CARD_LIST.md`；数据有问题时退出码 1。
- `docs/CARD_LIST.md`：按「等级 → 颜色 → 分数 → 花费」排序的卡表，供对照实体卡核对。
- `docs/tests/phase_1.md`：14 条测试用例，均已实际跑过一遍。

### 卡表数据来源与交叉比对

卡表不是"凭印象"录入的，而是取自开源实现 `inclement/lapidary-ai`（`lapidary/game.py` 的 `tier_1/2/3` 与 `nobles` 列表），
再用多个**互相独立**的开源实现做交叉比对（一次性脚本，放在 `/tmp/splendor_analysis/`，未进入仓库）。

| 来源 | 类型 | 卡牌（90） | 贵族（10） |
|---|---|---|---|
| `inclement/lapidary-ai` | Python AI | 基准 | 基准 |
| `thaiv28/SplendorRL` | 强化学习 | **90/90 完全一致** | **10/10 完全一致** |
| `dsmiller95/SplendorSimulator` | Java 模拟器 | **90/90 完全一致** | **10/10 完全一致** |
| `xaelleone/spondue` | — | 8 张有差异（转录错误） | 4 位有差异（含一位重复、一位少写一种颜色） |
| `daniman/splendor-server` | JS 服务端 | 2 张有差异 | 未比对 |

另有 `tcstewar` 的一份卡表（由模板旋转生成），其非白色列与上述所有来源都不一致（例如它让"黑加成 6 费"的
二级 3 分卡变成常见形态，而其余来源一致认为二级 3 分卡花费的是**本颜色 6 枚**），判定为错误的旋转规则，未采用。

结论：三份互相独立的实现逐张一致，且与开发计划里写明的锚点卡（三级 4 分红加成 花费 7 绿）吻合，
录入数据可信度高。**仍需你对照实体卡抽查**（见 `docs/tests/phase_1.md` T1-04 的重点卡）。

### 与计划的偏差（阶段 1）

1. **autoload 脚本不能写 `class_name`**：Godot 4.7 会报 `Class "X" hides an autoload singleton`。已改为不写
   `class_name`，用单例名 `DataRegistry` 直接访问（GDScript 能解析其成员）。此约定已写进 `CLAUDE.md`。
2. **`rules.json` 的开关集合是新增的**：计划只举例"颜色不够时能否少拿"，实际定义了 4 个开关
   （`allow_take_fewer_when_colors_short` / `reserve_takes_gold` / `noble_visit_at_turn_end` /
   `max_one_noble_per_turn`），含义见 `data/README.md`。
3. **多了一个 `docs/CARD_LIST.md`**：计划里没有这个文件，是按你的要求由验证脚本生成的卡表，方便人工核对。

### 遗留问题（阶段 1，仍然有效）

- **贵族没有名字**：官方贵族有名字（如 "Anne of Brittany, Queen of France"），当前 `nobles.json` 只存
  `id/points/requirement`。将来 UI 或大模型描述需要名字时再补。
- **id 与数据的绑定**：`cards.json` 里同一（等级, 颜色）下的序号是按「分数 → 总花费 → 颜色序」生成的。
  以后**改数值不要重排 id**（`CLAUDE.md` 已写明）；新增数据要走校验，看锚点报错就知道有没有错位。
- `core/` 的类型化字典用了 `Dictionary[int, int]`（Godot 4.4+ 语法），已确认 4.7 可用。

---

## 阶段 5 及以后

未开始。下一阶段是大模型 AI（阶段 5），计划见 `docs/DEVELOPMENT_PLAN.md`。
