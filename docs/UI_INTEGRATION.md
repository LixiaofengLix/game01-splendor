# 正式 UI 对接说明（阶段 3 草稿，阶段 7 定稿）

正式 UI 只需要替换 `debug_ui/`。规则、对局流程、存档格式都不变。唯一的对接面是：

1. **`GameController` 的信号与方法**；
2. **`GameState.to_dict(viewer_seat)` 的视图字典**（结构见 `core/game_state.gd` 头部注释）；
3. **`Rules.get_legal_actions(view, catalog, config)`** 返回的 `Array[Action]`。

**不要直接访问 `GameState` 的内部字段。** 调试界面严格按这份约定写，可以直接当成示例。

## GameController

```gdscript
signal state_changed(view: Dictionary)                 # 当前玩家自己的过滤视图
signal events_emitted(events: Array[GameEvent])        # 本次动作产生的全部事件
signal game_finished(winners: Array[int], scores: Dictionary)
signal action_rejected(message: String)                # 控制器交了非法 / 过期动作

# IR-08（阶段 5）：大模型座位的界面信号
signal waiting_started(seat: int, profile: String, attempt: int, limit_sec: float)
signal reason_emitted(seat: int, text: String)
signal fallback_used(seat: int, reason: String, bot_type: String)
```

`waiting_started` 每次请求尝试发一次（`attempt` 从 1 开始，`limit_sec` 是思考预算，0 = 不限）；
`reason_emitted` 是模型给的简短理由；`fallback_used` 的 `reason` 取值
`parse_failed` / `timeout` / `network`，`bot_type` 形如 `bot_hard`。

```gdscript
start_new_game(player_count, seed, seat_types, seat_options := []) -> bool
# seat_types: "human" / "bot_easy" / "bot_normal" / "bot_hard" / "llm"
# seat_options: 与座位一一对应，可为空；大模型座位 {"llm_profile": "配置档 id"}
start_with_controllers(player_count, seed, controllers) -> bool  # AI / 远程 / 测试 / 自定义控制器
submit_action(action) -> bool                           # 界面提交人类动作
is_current_human() -> bool                             # 当前座位是否人类（界面据此启用按钮）
is_current_llm() -> bool                               # 当前座位是否大模型（显示等待时间）
current_view() -> Dictionary                           # 最近一次 state_changed 的视图
load_snapshot(state_data, errors) -> bool
load_replay(data, verbose, errors) -> Array[String]     # 返回日志行；成功后再发信号
can_save_replay() -> bool
build_replay_data() -> Dictionary                       # SaveFile 的 replay 格式
fingerprint() -> String
reset()
```

`state_changed` 发出的视图总是**当前行动玩家**的视图（`viewer_seat == current_seat`）：
牌堆只有张数、别人盲抽预留的牌 `id` 为 `null`、没有种子 / 随机数状态。
同屏轮流时这就是玩家看到的信息；联网镜像模式（阶段 6）会改成各自座位的视图。

## 合法动作与控制器

`Rules.get_legal_actions(view, DataRegistry.card_catalog(), DataRegistry.rules())`：
顺序固定（拿三枚 → 拿两枚 → 预留 → 购买；预留 / 购买按等级、场面位置），同一局面每次一致。
界面按它启用 / 禁用按钮；不要自己发明"看起来合法"的操作。

座位控制器继承 `PlayerController`：

```gdscript
func request_action(view: Dictionary, legal_actions: Array[Action]) -> void
func cancel_pending() -> void
signal action_decided(action: Action)
```

人类控制器是异步的（等点击），AI 可以同步决定（`GameController` 内部有动作泵，不会递归爆栈）。
大模型可以异步返回；超时由控制器自己兜底。异步控制器必须实现 `cancel_pending()`：
`GameController` 在换局 / 载入 / 返回设置前调用它，避免旧计时器或旧 HTTP 响应把动作注入新局。

### 电脑座位（阶段 4）

- 座位类型 `bot_easy` / `bot_normal` / `bot_hard`；AI 配置在 `data/ai/*.json`。
- 电脑座位由 `GameController` 创建，界面**不要**替它调用 `submit_action()`。
  电脑回合 `is_current_human()` 返回 false，动作按钮应全部禁用。
- 电脑有思考延迟时，`state_changed` 在它决定后立即发出，界面只需按信号刷新；
  顶栏可以显示“电脑思考中…”。
- 同屏旁观时注意隐藏电脑的私密信息：`state_changed` 发出的是当前行动者的视图，
  轮到电脑 / 大模型时会包含它自己盲抽预留的牌；调试棋盘会把这一项显示为 `?级（盲抽）`，
  正式 UI 也应这样做。
- 预设局面 / 读档 / 重放目前会把所有座位重建为人类控制器（阶段 6 再改装配路径）。

### 大模型座位（阶段 5，IR-08）

- 座位类型 `llm`；配置档在 `user://config.json` 的 `llm.profiles.<id>`，由 `AppConfig` 读写。
  **API Key 只存在用户目录，不进存档、不发给联网对手、不写日志。**
- `AppConfig`（autoload）：
  `llm_profile_ids()` / `llm_profile(id)` / `active_llm_profile()` /
  `save_llm_profile(profile)` / `delete_llm_profile(id)` / `set_active_llm_profile(id)` / `save()`。
- 测试连接：`LlmClient.test_connection(profile) -> signal test_finished(ok, message, elapsed_ms)`。
  `LlmClient` 是 Node，需要挂到场景树里；一个实例同一时间只能有一个请求。
- 失败兜底：`LlmController` 先按配置里的 `max_retries` 重试；仍失败时用
  `data/ai/<fallback_difficulty>.json` 的程序 AI 当场算一个合法动作，并发出 `fallback_used`。
  模型回复只接受 `{"action": <1 起的编号>, "reason": "..."}`；编号必须来自本次请求的合法动作列表。
- 发给模型的内容来自 `StateDescriber`：只包含当前座位的过滤视图（牌堆只有张数、对手盲抽为 null）。
  调试构建会在发送前断言文本不含种子 / 牌堆顺序 / 对手盲抽卡牌 id。
- 调试棋盘顶栏在大模型回合显示“已等 N 秒 / 预算”，日志里显示模型理由和兜底原因。

## 事件与存档

- 事件类型与 payload 见 `core/game_event.gd` 头部注释；事件只带公开信息（盲抽预留不带 `card_id`）。
- 存档格式见 `core/save_file.gd`：`replay` = 种子 + 动作序列 + 指纹；`snapshot` = 完整状态。
- 牌 / 贵族数据通过 `CardCatalog` 查（`DataRegistry.card_catalog()`）；数值不在视图里重复存。
