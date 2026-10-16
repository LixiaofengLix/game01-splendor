# 璀璨宝石（Splendor）电子版 — 项目约定

**新会话开场流程：读本文件 → `docs/DEVELOPMENT_PLAN.md` → `docs/PROGRESS.md`，然后开始计划里的下一个阶段。**

文档只有一个来源：约定只写在本文件；各文件夹的 `README.md` 只写"这里放什么"；`docs/PROGRESS.md` 只写"做到哪了、与计划有什么偏差、下一阶段要知道什么"。

## 环境

- Godot **4.7** + GDScript（全部静态类型），基础版规则，2–4 人。
- 引擎路径：`/Applications/Godot.app/Contents/MacOS/Godot`。
- 无界面自检（先导入一次资源）：
  ```
  /Applications/Godot.app/Contents/MacOS/Godot --headless --import --path .
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . tests/data_report.tscn
  ```
  脚本以 `quit(0/1)` 返回结果，失败时退出码非 0。
- 版本管理：每阶段验收通过后提交一次。

## 架构原则（开发计划第 1 节，摘录）

1. **逻辑与表现分离**：`core/` 只有纯数据和纯函数，不引用 Node、场景树和单例；规则参数一律通过 `RulesConfig` 对象传入。这样 AI 能复制状态推演、能无界面批量模拟、联网时主机能直接校验动作、正式 UI 能替换掉调试界面。
2. **一切操作都是 Action**：拿宝石、预留、购买、弃宝石、选贵族都是同一种数据对象；人类、程序 AI、大模型、远程玩家都只是"产出 Action 的控制器"。
3. **状态可序列化**：`GameState.to_dict(viewer_seat)` / `from_dict()`，字典带 `schema_version` 并在读取时校验；`viewer_seat` 用于隐藏他人不可见的信息（牌堆顺序、他人盲抽预留的牌）。
4. **随机可复现**：带种子的 `RandomNumberGenerator`；存档 = 种子 + 动作序列，可完整重放。
5. **Action 只用稳定引用**：卡牌用 `card_id`、盲抽用等级、玩家用座位号；绝不用"场面第几张"这类索引。
6. **只有规则引擎看完整状态**：AI、大模型、客户端、界面拿到的都是 `to_dict(viewer_seat)` 过滤后的视图。
7. **数据驱动**：卡牌、贵族、规则参数、AI 权重、提示词全在 `data/`；代码里只保留枚举。

目录结构见 `docs/DEVELOPMENT_PLAN.md` 第 1 节。

## 编码约定（开发计划第 2 节）

- 全部使用静态类型；核心类使用 `class_name`；文件名 snake_case，类名 PascalCase。
- 每个脚本开头用 `##` 文档注释写 1–3 行说明用途；只在不显而易见的地方写注释。注释与文档用中文。
- `core/` 不引用 Node、场景和单例，规则参数通过 `RulesConfig` 对象传入。
- 不写魔法数字：规则数值都来自 `data/rules.json`。
- 信号用过去式命名（`state_changed`、`action_applied`）。
- 不做低价值的抽象：一个实现就不建接口，没有需求就不加配置项。
- AI、大模型、界面只能读 `to_dict(viewer_seat)` 视图，不能直接访问 GameState 内部字段（评审时用 grep 检查）。
- 改动 `core/` 后必须跑一次规则自检（阶段 2 起：`tests/rules_selfcheck.gd`）。
- 每个阶段结束必须完成：代码 + 文件夹 README + 更新 `docs/PROGRESS.md` + 输出 `docs/tests/phase_N.md` 测试用例 + 验收通过后 git 提交。

## 数据格式约定

- 数据文件是 `data/*.json`：**英文键 + 英文值**，UTF-8，缩进 2 空格，`"schema_version"` 放在顶层。
- 宝石颜色值：`white` / `blue` / `green` / `red` / `black` / `gold`。
  单字母简写（用于 id、日志、卡表）：`W` / `U` / `G` / `R` / `K` / `X`（U=蓝、K=黑，避免与 W/G/R 冲突）。枚举定义见 `core/enums.gd`。
- 卡牌 id：`L<等级>-<颜色字母>-<两位序号>`，如 `L1-U-03`、`L3-K-04`。
  贵族 id：`N-<两位序号>`，如 `N-01`。
  **id 是跨存档、联网协议、测试场景的稳定引用：改数值可以，改已有 id 不行。**
- 花费 / 要求只写非零项：`"cost": {"white": 1, "green": 2}` 表示白 1 绿 2，其余为 0。
- 枚举值的序列化一律用**字符串**（如 `"take_three"`、`"blue"`），不用枚举序号，这样以后插入枚举项不会破坏旧存档。
- `data/` 里的数值是唯一来源；代码中只允许出现校验用的结构常量（如"每级 40/30/20 张"）。

## 常用命令

```bash
# 导入资源 + 数据层自检（会重新生成 docs/CARD_LIST.md）
/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path .
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . tests/data_report.tscn
```
