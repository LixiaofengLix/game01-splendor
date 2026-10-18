# ui/app/

正式 UI 的入口场景 `app.tscn`：屏幕路由、牌桌会话的生命周期、弹窗层、toast 层，以及运行时注册的
`spl_` 快捷键。

- `app.gd` — 持有 `UiSaveStore`、`UiTableSession`、`UiTableScreen`、`UiTableFlow`：
  - `show_main_menu()` / `show_local_setup()` / `show_save_browser(from_table)` /
    `start_game(setup)` / `continue_last_game()` / `back_to_main_menu()`。
  - 从牌桌打开读档时用屏幕栈把牌桌留在栈底（隐藏），返回时恢复；读档继续成功则整个换掉。
  - 启动时检查 `DataRegistry.is_valid()`：失败显示 21 数据错误弹窗，不进主菜单。
  - 读档失败把错误交给 `UiErrorModal`（22），关闭后可回到读档列表。
- `shortcuts.gd` — `UiShortcuts`：12 个 `spl_` 动作的唯一定义；牌桌交互和入口都会调用
  `UiShortcuts.register()`，重复调用是幂等的。

运行：`/Applications/Godot.app/Contents/MacOS/Godot --path . ui/app/app.tscn`。
U9 之前 `project.godot` 的主场景仍是调试界面。
