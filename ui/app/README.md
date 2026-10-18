# ui/app/

正式 UI 的入口场景 `app.tscn`：屏幕路由、弹窗层、toast 层，以及运行时注册的 `spl_` 快捷键。

- `shortcuts.gd` — `UiShortcuts`：12 个 `spl_` 动作的唯一定义；`app.tscn` 与
  `ui/dev/quick_start.tscn`（以及牌桌交互）都调用 `UiShortcuts.register()`，重复调用是幂等的。
- U3 的临时入口 `ui/dev/quick_start.tscn` 不经过 `app.tscn`，直接装配牌桌；U4 的正式主菜单会接进这里。
