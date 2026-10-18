# ui/screens/table/

正式牌桌：顶栏、贵族列、三级市场（牌堆 + 卡位）、银行、我的面板、对手面板、日志、卡牌浮层、
回合内弹窗、暂停菜单与规则速查。

- 场景：`table_screen.tscn`（根节点 `UiTableScreen`，自带主题与 Nearest 过滤）。
- 渲染入口：`render(view, me_seat, session_info)`。视图是唯一真相，每次调用按视图整桌重画；
  重复调用是幂等的，不累积节点。`me_seat = -1` 时是观战 / 回放布局。
- 交互入口：`table_flow.gd`（`UiTableFlow`，Node）。它把 `UiTableSession` 的视图 / 事件与牌桌的点击接起来：
  宝石选择状态机、选卡 / 浮层、弃宝石 / 选贵族 / 结算弹窗、快捷键、锁定和失败提示，
  以及 U4 的暂停菜单、规则速查、同屏换人遮挡和存读档。宿主按下面的顺序装配：

  ```gdscript
  var session := UiTableSession.new()
  add_child(session)
  var flow := UiTableFlow.new()
  add_child(flow)
  flow.setup(table, session, save_store, {"hotseat_cover": true})
  session.start_local({"count": 3, "seed": 123, "seats": [...]})
  ```

- 几何按 `docs/ui/SCREENS.md`：顶栏 44，左栏 906（市场 470 / 我的面板 246），右栏 330（最宽 420）。
- `session_info` 键：
  - 显示：`names`、`seat_types`、`log`、`strip`、`pill_text`、`mode`（`spectate` / `replay`）、
    `replay_label`、`flash_cards`（卡牌 id）、`flash_slots`（`Vector2i(level, slot)`，补牌卡位）、
    `log_limit`、`catalog`、`rules`。
  - 回放（U6）：`hud_mode = "replay"` 把顶栏右侧换成【从这里接着玩】【退出回放】；
    `bottom_custom = true` 隐藏观战占位框，回放屏通过 `bottom_holder()` 把播放条挂到同一块 246 高的区域。
  - 交互：`interactive`、`selection`（颜色 → 枚数）、`clickable_colors`、
    `selected_kind`（`market` / `deck` / `reserved`）、`selected_id`、`selected_level`、
    `popover`（`UiCardPopover` 的数据）、`take_confirm_enabled`。
  - U7：`llm_waiting`（`{seat, profile, attempt, elapsed_sec, limit_sec}`，当前大模型的等待块）、
    `show_card_ids`（覆盖 `UiSettings.show_card_ids()`，用于调试 / 截图）。
- 牌桌发出的信号：`gem_chip_clicked`、`confirm_pressed`、`cancel_pressed`、`card_clicked`、
  `blank_clicked`、`purchase_pressed`、`reserve_pressed`、`menu_requested`、`rules_requested`、
  `replay_continue_requested`、`replay_exit_requested`。
- 回放模式没有“我”：右栏列出全部玩家，市场卡上标出所有买得起的人（`affordable_by`）。
- 浮层：选中卡的右侧 14px、顶部 −12px，超出右边界翻到左侧（`UiCardPopover`）。
- 弹窗层：牌桌自带的 `ModalLayer`（遮罩 + 居中框），回合内用 `show_modal()` / `hide_modal()`。
  弃宝石 / 选贵族 / 结算的构建在 `table_modals.gd`（`UiTableModals`）。
- 上层叠放：`OverlayLayer`（z 150）用 `push_overlay()` / `pop_overlay()` 叠暂停菜单、规则速查和换人遮挡；
  所以弃宝石 / 选贵族弹窗打开时仍能开暂停。toast 用 `show_toast()`，出现在顶栏下 12px。
- 暂停与规则：`pause_menu.gd`（`UiPauseMenu`）+ `rules_panel.gd`（`UiRulesPanel`）。
  Esc 的行为：有选择先取消；弃宝石 / 选贵族 / 结算弹窗上叠开暂停；什么都没选时打开 / 关闭暂停。
- 动效：`table_anim.gd`（`UiTableAnim`，Node，`UiTableFlow` 的子节点）。
  - `events_arrived` 先到、`view_updated` 后到；`UiTableFlow` 把一对事件 + 目标视图作为一批交给它。
    队列播完（或跳过）后才调用 `UiTableFlow._apply_view()` 落到目标视图。
  - 视觉只画在牌桌的 `AnimationLayer`（z 90，不拦鼠标）：筹码飞行、卡牌滑走、贵族来访、
    补牌翻盖、分数 / 折扣两帧跳动、终局标签跳动。飞行位置每步取整到 2px。
  - 积压（当前 + 排队）超过 2 批时 `skip_all()` 直接落到最新视图，只保留最后一批的光晕；
    同一座位的连续弃宝石会合并成一批，避免一次弃 3 枚就触发快进。
  - 可跳过：动效播放时点击牌桌任意位置，或按 1–5 / Enter / R / Esc，都会先跳到最新视图；
    这一下点击本身不再执行原动作。
  - 回合内弹窗（弃宝石 / 选贵族）在动效播放期间关闭；确认提交后立刻关窗，让飞行可见，
    需要继续选时由 `_sync_modal()` 按落地后的视图重开。
  - 动画速度来自 `UiSettings.anim_speed`（slow ×1.5 / normal ×1 / fast ×0.5）；
    `UiSettings.animations_enabled = false` 时事件和视图同步落地，供测试与 U7 设置页使用。
  - 音效在事件播放时调用 `UiSfx.play_events()`；素材为空，只有调用点与开关。
  - `sync_view(view)`：调用方直接落视图（回放跳转 / 换视角）时同步动画起点，
    保证补牌翻面对比的是正确的前一帧。
- 同屏换人遮挡：`UiTableFlow` 按 `INTERACTION.md` 第 5 节判断，牌桌不渲染私密信息直到玩家点按钮。
  遮挡前会先把积压动效直接落完（盖屏期间不播）。
- 存读档：`UiTableFlow` 在视图落地后写自动存档（`turn_ended` 触发；设置 15 的“每回合自动存档”关掉后跳过），
  暂停菜单写快速存档，`game_ended` 后转存 `finished/`；结算弹窗的【保存回放】在自动转存失败时补存。
  存档摘要取会话最新视图，不取落后一拍的动效画面。
- U7 设置接到牌桌：动画速度 / 动效开关（`UiTableAnim` 读取）、购买前确认（关掉后点买得起的卡直接购买）、
  显示卡牌 id、自动存档。设置屏返回时应用入口调用 `refresh()` 重画当前画面。
- 大模型（17）：`UiTableFlow` 监听 `seat_status_changed`——
  - `llm_waiting`：胶囊右侧“已等 12.4 秒”、该对手面板的等待块；`_process` 每 0.1 秒只刷新这两处。
  - `llm_reason`：由 `UiTableSession` 挂到下一条动作日志，日志面板用紫色竖线显示。
  - `llm_fallback`：我的面板顶条（事件态）显示“X 的大模型…　这一步已由困难电脑代打”，日志那条带
    orange“电脑代打”标签；顶条停留 8 秒。等待与兜底状态在动作事件 / 换人视图到达时清掉。
- 本机“我”的判定、盲抽隐私和缓存的边界见 `ui/bridge/README.md`。
- 调试夹具与截图见 `ui/dev/`；自动检查在 `tests/ui_smoke.gd`。
