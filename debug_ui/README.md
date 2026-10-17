# debug_ui/

最小可验证界面，全部用 Control + Button + Label，不做美术。将来被正式 UI 整体替换。

- `main/` — 调试入口：在设置界面与棋盘之间切换（`run/main_scene`）。
- `setup/` — 开局设置：人数、种子、座位类型（阶段 3 只有“人类”可选）。
- `board/` — 最小可视化桌面：银行、卡牌、贵族、玩家面板、弃宝石 / 选贵族弹窗、事件日志、
  存档 / 读档 / 重放、预设局面。
- `console/` — 文本调试台（阶段 2）：显式用 `godot --path . debug_ui/console/console.tscn` 打开。
