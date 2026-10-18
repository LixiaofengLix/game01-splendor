# ui/screens/table/

牌桌场景（U2 静态渲染）：顶栏、贵族列、三级市场（牌堆 + 卡位）、银行、我的面板、对手面板与日志。

- 场景：`table_screen.tscn`（根节点 `UiTableScreen`，自带主题与 Nearest 过滤）。
- 唯一入口：`render(view, me_seat, session_info)`。视图是唯一真相，每次调用按视图整桌重画；
  重复调用是幂等的，不累积节点。`me_seat = -1` 时是观战 / 回放布局（右栏列出全部玩家，
  底部换成占位条）。
- 几何按 `docs/ui/SCREENS.md`：顶栏 44，左栏 906（市场 470 / 我的面板 246），右栏 330（最宽 420），
  窗口更宽时整组居中；更高的窗口把多出来的高度给日志。
- `session_info` 可选键：`names`、`seat_types`、`log`（从新到旧，支持 `{card:id}` / `{gem:color}` 标记）、
  `strip`（我的面板顶条覆盖）、`pill_text`、`mode`（`spectate` / `replay`）、`replay_label`、
  `flash_cards`、`log_limit`、`catalog`、`rules`。不传 `catalog` / `rules` 时用 `DataRegistry` 的静态数据。
- 视图到显示数据的换算全部走 `UiViewMath`（`ui/common/`），牌桌不读 `GameState` 内部字段。
- 调试夹具与截图见 `ui/dev/`；U2 的自动检查在 `tests/ui_smoke.gd`。
