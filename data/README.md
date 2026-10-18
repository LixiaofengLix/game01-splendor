# data/

数据驱动层。代码里只有枚举，所有数值都从这里读。

- `cards.json` — 90 张发展卡（官方基础版）：`id`（`L<等级>-<颜色字母>-<序号>`）、`level`、`bonus`、`points`、`cost`（只写非零项）。
- `nobles.json` — 10 位贵族：`id`、`points`、`requirement`（按卡牌折扣数计，只写非零项）。
- `rules.json` — 规则参数与开关，见下表。
- `ai/*.json` — 三档程序 AI 的配置（阶段 4），见下文。
- `llm/llm_config.example.json` — 用户配置示例（阶段 5）：首次运行自动复制到 `user://config.json`，
  真实 API Key 只填在用户目录。
- `llm/prompts/` — 大模型提示词模板（系统 / 回合 / 性格）。字段与占位符见 `llm/README.md`。

## rules.json 各项

| 键 | 含义 |
|---|---|
| `players.<人数>.gems_per_color` | 该人数下银行每种颜色的宝石枚数（2 人 4 / 3 人 5 / 4 人 7） |
| `players.<人数>.nobles` | 该人数下参与对局的贵族张数（= 人数 + 1） |
| `gold_count` | 金币枚数 |
| `win_points` | 触发终局的分数 |
| `max_tokens` | 回合结束时允许持有的宝石上限（含金币） |
| `max_reserved` | 每人最多预留的卡牌数 |
| `board_slots_per_level` | 每级场面翻开的卡牌数 |
| `take_two_min_remaining` | 拿两枚同色时，该颜色在银行里至少要剩这么多枚 |
| `max_turns_safety` | 保险丝：任一玩家进行到这么多回合、且所有人回合数相同时以 `stalled` 结束。远高于正常对局（约 35 回合），只用来兜底“双方都买不起、反复拿 1 枚再弃 1 枚”的病态循环 |

## switches（规则细节开关）

| 开关 | 默认 | 含义 |
|---|---|---|
| `allow_take_fewer_when_colors_short` | `true` | 可取的不同颜色不足 3 种时能否少拿：`true` = 可以拿 1~2 种（官方规则说明："如果没办法一次拿足 3 种不同颜色的指示物，玩家也可以拿走 2 种，甚至 1 种"）；可取颜色 ≥ 3 种时仍必须拿满 3 种。`false` = 颜色不足 3 种时「拿三枚」不可用 |
| `reserve_takes_gold` | `true` | 预留时是否附带 1 枚金币（金币已用完时仍然可以预留，只是拿不到） |
| `noble_visit_at_turn_end` | `true` | 贵族只在回合末结算时来访（`false` = 买入卡牌后立即检查） |
| `max_one_noble_per_turn` | `true` | 一回合最多来一位贵族（同时满足多位时由玩家选择，没被选的留在场面） |

## data/ai/*.json（程序 AI）

三档 AI 的配置，英文键 + 英文值。`easy` / `normal` / `hard` 三个文件都必须存在，
`id` 必须与文件名一致；权重键必须恰好是代码约定的一组，拼错会由 `tests/data_report.tscn` 报出来。

| 键 | 含义 |
|---|---|
| `strategy` | `greedy`（一步 + 噪声 + 偶尔犯错）/ `one_step`（一步最优）/ `two_ply`（我方一步 + 下一位对手最佳回应） |
| `seed_salt` | 派生每个座位随机种子的盐；不同难度用不同的值 |
| `thinking_delay_ms` | 界面观察用的思考延迟；模拟 / 自检会覆盖为 0 |
| `random_noise` | 简单难度的评分扰动幅度（厘分，100 = 1 分） |
| `mistake_chance` | 简单难度随机选“非最高分动作”的概率（0~1） |
| `search.top_k` | two_ply 展开的我方候选动作数（8~12） |
| `search.opponent_top_m` | 每个候选最多完整模拟的对手回应数 |
| `search.max_nodes` | two_ply 的确定性 `Rules.apply` 预算；超出后回退到一步最优 |
| `search.timeout_ms` | 超时安全网；正常不应触发（自检会检查回退次数为 0） |
| `weights.*` | 整数评分权重（JSON 里只写非负幅度，扣分符号由代码应用） |

权重含义：`points` 分数、`card_bonus` 已购卡 / 折扣、`token` / `gold` 宝石、
`noble_gap` 离贵族的折扣缺口、`target_points` / `target_bonus` / `target_gap` 目标卡价值与购买缺口、
`affordable` 当前买得起的卡数、`opponent_threat` 对手最强目标的威胁、
`block_bonus` 预留 / 买走对手目标、`reserve_gap` 预留短期买不起的牌的惩罚、
`waste` 用不上的宝石、`win` 终局胜负。

格式约定见根目录 `CLAUDE.md`。改完数据后用 `tests/data_report.tscn` 自检。
