# data/

数据驱动层。代码里只有枚举，所有数值都从这里读。

- `cards.json` — 90 张发展卡（官方基础版）：`id`（`L<等级>-<颜色字母>-<序号>`）、`level`、`bonus`、`points`、`cost`（只写非零项）。
- `nobles.json` — 10 位贵族：`id`、`points`、`requirement`（按卡牌折扣数计，只写非零项）。
- `rules.json` — 规则参数与开关，见下表。
- `ai/*.json` — 各难度 AI 权重（阶段 4）。
- `llm/prompts/` — 大模型提示词模板（阶段 5）。

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

## switches（规则细节开关）

| 开关 | 默认 | 含义 |
|---|---|---|
| `allow_take_fewer_when_colors_short` | `false` | 可取的不同颜色不足 3 种时，是否允许少拿（`false` = 该动作不可用） |
| `reserve_takes_gold` | `true` | 预留时是否附带 1 枚金币（金币已用完时仍然可以预留，只是拿不到） |
| `noble_visit_at_turn_end` | `true` | 贵族只在回合末结算时来访 |
| `max_one_noble_per_turn` | `true` | 一回合最多来一位贵族（同时满足多位时由玩家选择） |

格式约定见根目录 `CLAUDE.md`。改完数据后用 `tests/data_report.tscn` 自检。
