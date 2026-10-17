# 进度

> 跨会话交接的唯一依据。每次会话结束更新：已完成 / 与计划的偏差 / 遗留问题 / 下一阶段需要知道的事。

## 当前状态

- **阶段 1（工程骨架与数据层）：已验收并提交（`37b708c`）**
- **阶段 2（核心规则引擎 + 文本调试台）：已验收并提交**（2026-10-17；规则解释经用户确认无异议）
- **阶段 3（对局流程、座位控制器与最小可视化界面）：已验收并提交**（2026-10-17；用户确认提交）。
  2 人局可以用鼠标试玩；完整 3/4 人局仍建议等阶段 4 有 AI 补座位后再做。
- 人工验收的分工与结果：规则解释 ✓；阶段 3 界面已验收（用户 2026-10-17 确认提交）；
  **完整 3/4 人局试玩留到阶段 4 的 AI 补座位之后**（用户明确不要一个人控制所有座位打完整局）；
  卡表对照实体卡仍是可选待办。
- 上次更新：2026-10-17

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

## 阶段 4 及以后

未开始。下一阶段是程序 AI（阶段 4），计划见 `docs/DEVELOPMENT_PLAN.md`。
