# tests/scenarios/

预设局面（边界情况），调试台里 `load <文件名>` 直接进入，例如 `load token_limit`。

- `*.json` — 完整状态快照（`SaveFile` 的 snapshot 格式，人可读、可手改）。
- `build_scenarios.gd` / `.tscn` — 生成上面这些局面的脚本（改完卡表或规则后重跑）：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . tests/scenarios/build_scenarios.tscn
```

局面一览：`token_limit`（持币到 10）、`two_nobles`（同时满足两位贵族）、`endgame`（14 分 + 能买到分）、
`bank_edges`（银行剩 4 / 3 / 0）、`colors_short`（只剩 2 种颜色可取）、`deck_empty`（1 级牌堆已空）。
