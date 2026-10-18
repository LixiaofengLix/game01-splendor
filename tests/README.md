# tests/

无界面的自检脚本与预设局面。不是单元测试框架，用 `godot --headless` 直接跑。

- `data_report.gd` / `data_report.tscn` — 阶段 1：加载并校验 `data/`，打印统计，生成 `docs/CARD_LIST.md`。失败时退出码非 0。
- `rules_selfcheck.gd` / `.tscn` — 阶段 2：随机合法动作跑 N 局（默认 2000），检查宝石 / 卡牌守恒、上限、往返序列化、视图隐藏信息、终局判定与重放一致性。失败时退出码非 0。
- `flow_selfcheck.gd` / `.tscn` — 阶段 3：用同步测试控制器跑 2/3/4 人局，检查 GameController 的信号、视图隔离、动作合法性、非法动作拒绝、重放与六个预设快照。失败时退出码非 0。
- `board_smoke.gd` / `.tscn` — 阶段 3：实例化设置界面和棋盘，按按钮走拿宝石 / 预留 / 弃宝石 / 选贵族 / 终局 / 存读档流程；阶段 4 增加人类 vs 电脑的回合切换检查。失败时退出码非 0。
- `ai_selfcheck.gd` / `.tscn` — 阶段 4：三档 AI 配置校验、全 AI 对局（2/3/4 人）、同种子可复现、预设局面的弃宝石 / 选贵族决策、困难 AI 思考耗时。失败时退出码非 0。
- `ai_sim.gd` / `.tscn` — 阶段 4：AI 批量模拟（难度互打），每个种子镜像交换座位，输出胜率 / 平均分 / 回合数 / 思考耗时。参数见文件头。
- `scenarios/` — 手工测试用的预设局面 JSON + 生成脚本，见该目录 README。

```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
$GODOT --headless --path . tests/data_report.tscn
$GODOT --headless --path . tests/rules_selfcheck.tscn -- 2000
$GODOT --headless --path . tests/flow_selfcheck.tscn
$GODOT --headless --path . tests/board_smoke.tscn
$GODOT --headless --path . tests/ai_selfcheck.tscn
$GODOT --headless --path . tests/ai_sim.tscn -- --sim 100 easy normal
$GODOT --headless --path . tests/ai_sim.tscn -- --sim 100 normal hard
```
