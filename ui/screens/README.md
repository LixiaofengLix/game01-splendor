# ui/screens/

各屏幕的场景与脚本，由 `ui/app/app.gd` 路由。

- `main_menu/` — 01 主菜单（继续上一局、本地游戏、联网入口禁用、桌面静物）。
- `local_setup/` — 02 本地开局设置（座位 / 常用组合 / 人数 / 种子 / 规则摘要 / 同屏开关）。
- `save_browser/` — 03 读档列表 + 详情（`UiSaveRow` 是列表行）。
- `table/` — 04–13 牌桌、交互、回合内弹窗、暂停菜单与规则速查。
- `hotseat/` — 09 同屏换人遮挡。
- `modals/` — 通用二次确认弹窗。
- `errors/` — 21 数据加载失败、22 存档无法读取（含“读到第 N 步为止”）。
- `replay/` — 14 回放：复用牌桌 + 底部播放条（`UiReplayBar` / `UiReplayTimeline`）。
- `settings/`、`net/` — U7 / U8 的占位目录。

约定：屏幕只和 `ui/bridge/` 打交道，不直接调用 `GameController`；场景根节点自带主题和 Nearest 过滤。
