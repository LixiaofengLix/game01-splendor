# ui/screens/main_menu/

01 主菜单（`main_menu.tscn` + `UiMainMenu`）。

- 左半区：眉标、48 号标题、玩法说明（胜利分取自 `RulesConfig`）、菜单按钮列。
- “继续上一局”只在存在进行中的自动存档时显示，副标题来自 `UiSaveStore.autosave_summary()`。
- 联网入口禁用（阶段 6 / U8 打开）；【设置】在 U7 开放。
- 只发信号（`continue_pressed` / `local_pressed` / `saves_pressed` / `settings_pressed` / `quit_pressed`），
  路由在 `ui/app/`。
- 右半区：用零件拼的桌面静物（三张扇形发展卡、牌堆、贵族、筹码、座位 1 吉祥物），不另画插图。
