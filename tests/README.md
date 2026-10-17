# tests/

无界面的自检脚本与预设局面。不是单元测试框架，用 `godot --headless` 直接跑。

- `data_report.gd` / `data_report.tscn` — 阶段 1：加载并校验 `data/`，打印统计，生成 `docs/CARD_LIST.md`。失败时退出码非 0。
- `rules_selfcheck.gd` / `.tscn` — 阶段 2：随机合法动作跑 N 局（默认 2000），检查宝石 / 卡牌守恒、上限、往返序列化、视图隐藏信息、终局判定与重放一致性。失败时退出码非 0。
- `scenarios/` — 手工测试用的预设局面 JSON + 生成脚本，见该目录 README。

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . tests/data_report.tscn
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . tests/rules_selfcheck.tscn -- 2000
```
