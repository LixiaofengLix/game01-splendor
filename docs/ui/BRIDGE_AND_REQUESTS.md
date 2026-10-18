# 桥接层、假后端与接口需求

> UI 和逻辑层之间只有一个接触面：`ui/bridge/`。本文定义它对 UI 暴露什么、内部调用逻辑层的哪些公开接口，
> 以及 UI 需要逻辑侧补的接口（IR-xx）。逻辑层现有接口见 `docs/UI_INTEGRATION.md`。

## 1. 桥接层（`ui/bridge/`）

### 1.1 `UiTableSession`（Node，挂在 `app.tscn` 下）

屏幕只认这个对象。它内部持有一个后端（`LiveBackend` 或 `FakeBackend`），对外接口一致。

```gdscript
# 视图已经按隐私规则处理过（INTERACTION.md 第 5 节）：
#   别人的盲抽 id 为 null；viewer 不是“我”时，viewer 自己的盲抽也是 null；“我”的盲抽用 IR-01 / 缓存补上。
signal view_updated(view: Dictionary, me_seat: int)       # me_seat = -1 表示观战 / 回放
signal events_arrived(events: Array[Dictionary])           # GameEvent.to_dict() 的数组，先于对应的 view_updated
signal game_ended(result: Dictionary)                      # 见 1.2
signal action_failed(message: String)
signal seat_status_changed(seat: int, status: Dictionary)  # 见 1.3；大模型 / 联网用

func start_local(setup: Dictionary) -> bool        # {count, seed (-1 = 随机), seats: [{name, type}], hotseat_cover}
func resume(entry: UiSaveEntry, errors: Array[String]) -> bool   # 继续存档（回放存档 / 快照）
func resume_until(entry: UiSaveEntry, step: int, errors: Array[String]) -> bool  # 读到第 N 步为止
func close() -> void                                # 回主菜单前调用（内部 reset + cancel_pending）

func legal_actions() -> Array[Action]
func submit(action: Action) -> bool
func submit_sequence(actions: Array[Action]) -> bool   # 弃宝石用：逐个提交，任一失败就停
func is_my_turn() -> bool
func me_seat() -> int
func local_seats() -> Array[int]
func seat_info(seat: int) -> Dictionary             # {name, type, mascot}；type 是座位类型字符串
func rules() -> RulesConfig
func catalog() -> CardCatalog
func elapsed_seconds() -> int

func can_save() -> bool
func save_quick() -> bool                           # 写 user://saves/quick.json
func set_paused(paused: bool) -> void               # 暂停菜单；IR-12 前只冻结界面动效队列
```

### 1.2 `game_ended` 的 `result`

```
{
  "winners": [0],                      # 座位号
  "scores": {"0": 16, "1": 16, ...},   # 来自 GameController.game_finished
  "reason": "win_points" | "stalled",  # 视图 finished_reason
  "cards": {"0": 12, ...},             # 视图 purchased 数量
  "nobles": {"0": 2, ...},
  "tiebreak": "cards" | "tie" | "",    # 最高分并列时：按卡数分出胜负 / 卡数也相同 / 没有并列
  "round": 27,
  "elapsed_sec": 2280
}
```

### 1.3 `seat_status_changed` 的 `status`

| `kind` | 字段 | 来源 |
|---|---|---|
| `llm_waiting` | `profile`、`attempt`、`started_ms`、`limit_sec` | IR-08 |
| `llm_reason` | `text`（挂到该座位下一条日志） | IR-08 |
| `llm_fallback` | `reason`（`parse_failed` / `timeout` / `network`）、`bot`（`bot_hard` 等） | IR-08 |
| `offline` / `online` | `latency_ms`（在线时） | IR-09 |

“电脑思考中”不需要状态：当前座位是电脑就是在思考。

### 1.4 其他桥接对象

- **`UiSaveStore`**：管理 `user://saves/`。
  - 文件：`autosave.json`（进行中的自动存档，每回合结束覆盖）、`quick.json`（暂停菜单“保存”）、
    `finished/<yyyyMMdd-HHmmss>.json`（对局结束时把自动存档转存成一份记录）；
    其他 `*.json`（如调试界面的 `board_quick.json`）也列出来，只读。
  - 存档内容 = `GameController.build_replay_data()`，再加一个顶层键 `ui_meta`（IR-06）：
    ```
    "ui_meta": {
      "version": 1,
      "saved_at": 1760000000,
      "status": "in_progress" | "finished",
      "names": ["小明", "薄荷", "紫晶"],
      "seat_types": ["human", "bot_hard", "bot_normal"],
      "hotseat_cover": true,
      "elapsed_sec": 600,
      "summary": {"round": 9, "current_seat": 0, "scores": [3, 7, 1], "winners": []}
    }
    ```
  - `list() -> Array[UiSaveEntry]`：每项带 kind（replay / snapshot / unreadable）、原因、`ui_meta`（没有就为空）。
  - `autosave_summary()`：主菜单“继续上一局”用；没有进行中的自动存档时返回空。
  - 快照来源的局（预设局面）`can_save_replay()` 为 false，不自动存档，“保存”禁用并写原因（IR-10）。
- **`UiReplaySource`**：回放屏用，接口见 IR-03。
- **`UiSettings`**：UI 自有设置，存 `user://ui_settings.json`（带 `schema_version`）。
  键：`default_name`、`anim_speed`（slow / normal / fast）、`confirm_before_buy`、`hotseat_cover_default`、`sfx`、
  `fullscreen`、`show_card_ids`、`autosave`；IR-05 落地后加 `bot_delay_ms`。阶段 7 的 `AppConfig` 出来后迁移过去（IR-11）。
- **`UiViewMath`**（`ui/common/view_math.gd`，纯静态函数，输入都是视图 + `CardCatalog` + `RulesConfig`）：
  `score(view, seat)`、`bonuses(view, seat)`、`token_total(view, seat)`、`shortfall(view, seat, card_id)`、
  `missing_by_color(...)`、`payment_preview(...)`、`affordable_by(view, card_id) -> Array[int]`（哪些座位买得起）、
  `round_number(view)`、`endgame_remaining(view) -> Array[int]`。

### 1.5 `LiveBackend` 调用的逻辑层接口（全部是公开接口）

| 用途 | 接口 |
|---|---|
| 开局 | `GameController.start_new_game(count, seed, seat_types)` |
| 视图 / 事件 / 结束 / 被拒 | `state_changed`、`events_emitted`、`game_finished`、`action_rejected` |
| 合法动作 | `Rules.get_legal_actions(view, DataRegistry.card_catalog(), DataRegistry.rules())` |
| 提交 | `GameController.submit_action(action)` |
| 锁定 | `GameController.is_current_human()` |
| 存档 | `can_save_replay()`、`build_replay_data()`、`SaveFile.kind_of()` |
| 读档 | `load_replay(data, false, errors)`、`load_snapshot(SaveFile.unwrap_snapshot(data), errors)` |
| 读到第 N 步 | 把 `actions` 截到前 N 个、`fingerprint` 置空，再 `load_replay`（空指纹不比对，现有接口就支持） |
| 收尾 | `GameController.reset()` |
| 数据 | `DataRegistry.is_valid()`、`get_errors()`、`rules()`、`card_catalog()` |

## 2. 假后端（`FakeBackend`）

用途：阶段 5 / 6 还没做的界面（16–20、23）、难以在真实对局里稳定复现的局面（终局轮、掉线、兜底），以及截图。

- 读取 `ui/dev/fixtures/<name>.json` 脚本，按时间发出和真实后端同形态的信号：
  ```
  {
    "schema_version": 1,
    "seats": [{"name": "小明", "type": "human"}, {"name": "薄荷", "type": "bot_hard"}, ...],
    "me_seat": 0,
    "steps": [
      {"at_ms": 0,    "view": "views/g3_turn_mine.json"},
      {"at_ms": 800,  "events": [{"type": "card_reserved", "seat": 1, "card_id": "L2-R-01", "level": 2, "blind": false, "gold": 1}],
                      "view": "views/g3_after_reserve.json"},
      {"at_ms": 1200, "seat_status": {"seat": 3, "kind": "llm_waiting", "profile": "DeepSeek", "attempt": 1, "limit_sec": 30}}
    ]
  }
  ```
- 视图文件就是 `to_dict(viewer_seat)` 的格式（`core/game_state.gd` 头部注释），**不另造格式**；
  这样同一个夹具既能喂假后端，也能用 `Rules.get_legal_actions()` 算出合法动作，让假后端里的牌桌也能点。
- `submit()` 在假后端里：在合法列表里就接受，按脚本里的 `on_submit` 分支跳转（没有分支就只回显）。
- 视图夹具的来源：
  1. `ui/dev/build_fixtures.tscn`：用 `GameController` 按种子跑局，在指定步数把 `current_view()` 存成 JSON（只用公开接口）；
  2. `tests/scenarios/*.json` 的快照经 `GameState.from_dict` → `to_dict(seat)` 转出来（同样走公开接口）；
  3. 照样张手写（样张的 3 人局 G3、4 人局 G4，卡牌 id 都是真实的）——手写的不要求局面可达，只用于渲染和截图。
- 夹具清单（U2 起逐步补齐）：`g3_turn_mine`（04/05/06）、`g3_bot_turn`（07）、`g4_endgame`（08）、`g3_discard`（10）、
  `g3_two_nobles`（11）、`g4_finished_tie`（12）、`g4_llm`（17）、`g4_offline`（20），以及 2 人 / 4 人的空场面（牌堆已空、银行见底）。

## 3. 屏幕的开发顺序和后端

| 屏幕 | 先用 | 换成真实 |
|---|---|---|
| 04–13、21 | 夹具（U2 静态）→ `LiveBackend`（U3） | U3 |
| 01–03、22 | `LiveBackend` + `UiSaveStore` | U4 |
| 14 | `UiReplaySource` 临时实现 | IR-03 落地时 |
| 15 | `UiSettings` | U7（`AppConfig` 出来后迁移，IR-11） |
| 16、17 | `FakeBackend` | 阶段 5 + IR-08 |
| 18–20、23 | `FakeBackend` | 阶段 6 + IR-09 |

## 4. 接口需求清单（IR）

逻辑线按优先级排期；每条都写了 UI 侧的临时方案，所以**没有一条会阻塞 UI 开发**。
落地后由逻辑线更新 `docs/UI_INTEGRATION.md`，并在这里把状态改成“已落地（提交号）”。

| 编号 | 需求 | 建议接口 | UI 用在 | UI 临时方案 | 优先级 | 状态 |
|---|---|---|---|---|---|---|
| IR-01 | 按座位取视图（电脑回合时我的面板要显示我自己的盲抽） | `GameController.view_for(seat: int) -> Dictionary`（= `to_dict(seat)`） | 04、07、08 | 桥接层缓存本机座位预留卡 id（预留卡只在自己回合变化） | 中 | 待排期 |
| IR-02 | 支付预览 / 买得起判断的公开版本 | `Rules.payment_for(view, seat, card_id, catalog) -> Dictionary`、`Rules.can_afford(view, seat, card_id, catalog) -> bool` | 04、06 | `UiViewMath` 按同一算法实现；`ui_smoke` 用 `card_purchased.paid` 交叉校验 | 低 | 待排期 |
| IR-03 | 逐步回放：任意步跳转、指定视角、每步事件 | `game/replay_player.gd`：`open(data, errors) -> bool`、`step_count()`、`seek(step)`、`view(viewer_seat)`、`public_view()`（所有预留可见、牌堆顺序隐藏）、`events_at(step) -> Array[Dictionary]`、`action_at(step)`、`seat_at(step)` | 14、03、22 | 已落地临时实现 `ui/bridge/replay_source.gd`（U6）：单独一个 `GameController`，对截断后的存档反复 `load_replay`；只有“当前行动者视角”，其他座位返回全部公开视图；步骤说明由动作 + 卡表拼；`events_at()` 由动作 + 前后视图合成，供回放动效 | 中（U6 前） | 待排期；UI 已用临时实现跑通 |
| IR-04 | 读档恢复座位类型（继续和电脑的对局） | `load_replay(data, verbose, errors, seat_types: Array[String] = [])`、`load_snapshot(state, errors, seat_types = [])`；空数组 = 现在的行为 | 01、03、13、14 | 恢复成全人类座位，并提示“电脑座位暂时以人类身份恢复” | **高** | 待排期 |
| IR-05 | 电脑思考延迟可由界面设置 | `start_new_game(..., options: Dictionary = {})`，`options.bot_delay_ms` 覆盖配置里的延迟 | 02、15、观战 | 不显示这一项 | 低 | 待排期 |
| IR-06 | 存档里的 `ui_meta` 顶层键：`SaveFile.parse_replay` / `kind_of` 忽略它，调试台读写不丢、不报错 | 不需要新接口，只需要约定 + `flow_selfcheck` 里加一条检查 | 01、03 | 现有代码已经忽略未知键，先直接用 | 确认即可 | 待确认 |
| IR-07 | 贵族名字 | `nobles.json` 加可选 `name` | 11、日志 | 用位置或要求指代 | 可选 | — |
| IR-08 | 大模型座位的界面信号与配置档接口 | 控制器信号 `waiting_started(seat, profile, attempt, limit_sec)`、`reason_emitted(seat, text)`、`fallback_used(seat, reason, bot_type)`；`AppConfig` 的配置档增删改查 + `LlmClient.test_connection(profile) -> 结果信号`；座位类型 `llm` + 配置档 id | 02、16、17 | 假后端 | 阶段 5 | **已落地（阶段 5）**：信号在 `GameController`；`start_new_game(..., seat_options)` 的 `{"llm_profile": id}`；`LlmClient.test_connection(profile, timeout_ms)` 发 `test_finished(ok, message, elapsed_ms)`；`AppConfig` 见 `autoload/app_config.gd` |
| IR-09 | 联网大厅与在线状态 | `NetworkManager`：建房 / 加入 / 离开、本机地址列表、座位表（名字、类型、准备、延迟）变化信号、请出、设置空座位类型、开始；掉线 / 重连信号；客户端镜像模式的 `view_updated` | 18、19、20、23 | 假后端 | 阶段 6 | 待阶段 6 |
| IR-10 | 导出当前局的快照（预设局面开出来的局也能存） | `GameController.build_snapshot_data() -> Dictionary`（`SaveFile.wrap_snapshot`） | 13 | 快照来源的局不能保存，按钮写原因 | 低 | 待排期 |
| IR-11 | 设置的归属：哪些键由 `AppConfig` 管 | 阶段 7 定：昵称、电脑延迟、大模型配置归 `AppConfig`；纯显示类留在 `UiSettings` | 15 | 全部先放 `UiSettings` | 阶段 7 | 待阶段 7 |
| IR-12 | 暂停时冻结电脑思考计时 | `GameController.set_paused(paused: bool)`（转发给控制器） | 13 | 只冻结界面动效队列；电脑在后台照常行动，关菜单后补播 | 低 | 待排期 |

### 提交 IR 的格式

新需求追加到表尾，编号顺延，不复用。写清：为什么需要（对应哪一屏）、建议签名（逻辑线可以改）、
UI 现在怎么绕过去。逻辑线拒绝或改签名时，把结论写在“状态”列。
