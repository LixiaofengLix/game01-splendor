# tests/

无界面的自检脚本与预设局面。不是单元测试框架，用 `godot --headless` 直接跑。

- `data_report.gd` / `data_report.tscn` — 阶段 1：加载并校验 `data/`，打印统计，生成 `docs/CARD_LIST.md`。失败时退出码非 0。
- `rules_selfcheck.gd` — 阶段 2：用随机合法动作跑 N 局，检查不变量。
- `scenarios/` — 手工测试用的预设局面 JSON（阶段 2）。
