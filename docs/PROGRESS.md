# 进度

> 跨会话交接的唯一依据。每次会话结束更新：已完成 / 与计划的偏差 / 遗留问题 / 下一阶段需要知道的事。

## 当前状态

- **阶段 1（工程骨架与数据层）：代码完成，等待人工验收**
- 上次更新：2026-10-16

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

### 与计划的偏差

1. **autoload 脚本不能写 `class_name`**：Godot 4.7 会报 `Class "X" hides an autoload singleton`。已改为不写
   `class_name`，用单例名 `DataRegistry` 直接访问（GDScript 能解析其成员）。此约定已写进 `CLAUDE.md`。
2. **`rules.json` 的开关集合是新增的**：计划只举例"颜色不够时能否少拿"，实际定义了 4 个开关
   （`allow_take_fewer_when_colors_short` / `reserve_takes_gold` / `noble_visit_at_turn_end` /
   `max_one_noble_per_turn`），含义见 `data/README.md`。默认值按官方规则设定，阶段 2 用规则自检再确认。
3. **多了一个 `docs/CARD_LIST.md`**：计划里没有这个文件，是按你的要求由验证脚本生成的卡表，方便人工核对。

### 遗留问题 / 下一阶段需要知道的事

- **贵族没有名字**：官方贵族有名字（如 "Anne of Brittany, Queen of France"），当前 `nobles.json` 只存
  `id/points/requirement`（按计划）。将来 UI 或大模型描述需要名字时再补。
- **阶段 2 的自检脚本**计划用 `godot --headless -s tests/rules_selfcheck.gd` 运行；`-s` 模式下 autoload 是否
  会加载需要在阶段 2 开头确认。若不会加载，改成跑场景（和 `tests/data_report.tscn` 一样）即可。
- **id 与数据的绑定**：`cards.json` 里同一（等级, 颜色）下的序号是按「分数 → 总花费 → 颜色序」生成的。
  以后**改数值不要重排 id**（`CLAUDE.md` 已写明）；新增数据要走校验，看锚点报错就知道有没有错位。
- **`allow_take_fewer_when_colors_short` 的默认值**（false = 可取颜色不足 3 种时不能执行"拿三枚"）是从官方
  规则文本推出来的，阶段 2 写规则时请再确认一次（这条会直接影响边界局面）。
- `core/` 的类型化字典用了 `Dictionary[int, int]`（Godot 4.4+ 语法），已确认 4.7 可用。

## 阶段 2 及以后

未开始。计划见 `docs/DEVELOPMENT_PLAN.md`。
