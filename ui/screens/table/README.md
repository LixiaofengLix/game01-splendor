# ui/screens/table/

正式牌桌：顶栏、贵族列、三级市场（牌堆 + 卡位）、银行、我的面板、对手面板、日志、卡牌浮层与回合内弹窗。

- 场景：`table_screen.tscn`（根节点 `UiTableScreen`，自带主题与 Nearest 过滤）。
- 渲染入口：`render(view, me_seat, session_info)`。视图是唯一真相，每次调用按视图整桌重画；
  重复调用是幂等的，不累积节点。`me_seat = -1` 时是观战 / 回放布局。
- 交互入口：`table_flow.gd`（`UiTableFlow`，Node）。它把 `UiTableSession` 的视图 / 事件与牌桌的点击接起来：
  宝石选择状态机、选卡 / 浮层、弃宝石 / 选贵族 / 结算弹窗、快捷键、锁定和失败提示。
  宿主按下面的顺序装配：

  ```gdscript
  var session := UiTableSession.new()
  add_child(session)
  var flow := UiTableFlow.new()
  add_child(flow)
  flow.setup(table, session)
  session.start_local({"count": 3, "seed": 123, "seats": [...]})
  ```

- 几何按 `docs/ui/SCREENS.md`：顶栏 44，左栏 906（市场 470 / 我的面板 246），右栏 330（最宽 420）。
- `session_info` 键：
  - 显示：`names`、`seat_types`、`log`、`strip`、`pill_text`、`mode`（`spectate` / `replay`）、
    `replay_label`、`flash_cards`、`log_limit`、`catalog`、`rules`。
  - 交互（U3）：`interactive`、`selection`（颜色 → 枚数）、`clickable_colors`、
    `selected_kind`（`market` / `deck` / `reserved`）、`selected_id`、`selected_level`、
    `popover`（`UiCardPopover` 的数据）、`take_confirm_enabled`。
- 牌桌发出的信号：`gem_chip_clicked`、`confirm_pressed`、`cancel_pressed`、`card_clicked`、
  `blank_clicked`、`purchase_pressed`、`reserve_pressed`、`menu_requested`。
- 浮层：选中卡的右侧 14px、顶部 −12px，超出右边界翻到左侧（`UiCardPopover`）。
- 弹窗层：牌桌自带的 `ModalLayer`（遮罩 + 居中框），回合内用 `show_modal()` / `hide_modal()`。
  弃宝石 / 选贵族 / 结算的构建在 `table_modals.gd`（`UiTableModals`）。
- 本机“我”的判定、盲抽隐私和缓存的边界见 `ui/bridge/README.md`；换人遮挡是 U4。
- 调试夹具与截图见 `ui/dev/`；自动检查在 `tests/ui_smoke.gd`。
