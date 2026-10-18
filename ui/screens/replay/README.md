# ui/screens/replay/

14 回放（`replay_screen.tscn` + `UiReplayScreen`）。用同一张牌桌：没有“我”，右栏列出全部玩家，
左栏底部（高 246）放播放条。

- `replay_screen.gd` — 屏幕入口：
  - `configure(entry, errors)`：由 `UiReplaySource` 打开回放，成功后停在第 0 步；
    失败原因写进 errors（应用入口转成 22）。
  - 播放：`seek(step)` / `advance_animated()` / `toggle_play()` / `set_speed(0.5|1|2)`；
    1x 每步 0.9 秒，速度按比例换算。
    快捷键：← / → 上一步 / 下一步，空格播放 / 暂停，Esc 退出回放。
  - 动效：【下一步】、→ 和自动播放走 `advance_animated()`，复用 `UiTableAnim` 播该步的飞行 / 补牌；
    时间轴、上一步、开头 / 结尾是 `seek()` 直接跳转。
  - 视角：`set_viewer_seat(-1 = 全部公开, 0..)`；切换后整桌按该视角重画。
  - 【从这里接着玩】：`request_continue()` 弹确认框，确认后发 `continue_requested(entry, step)`；
    截断和开新局由应用入口处理。
  - 时间轴颜色：每一步的行动者需要载入截断存档才能知道，首次打开只算当前步；
    其余颜色在后台每帧补 2 步，补上后自动换色（打开不会卡住）。
  - 信号：`exit_requested`、`continue_requested(entry, step)`。
- `replay_bar.gd` — `UiReplayBar`（UiFrame，246 高）：当前步说明、视角分段、
  时间轴图例（“每格 = 一步 · 颜色 = 行动者”+ 玩家色块）、时间轴、
  开头 / 上一步 / 播放 / 下一步 / 结尾、速度 0.5x / 1x / 2x。只发信号，不推进步数。
- `replay_timeline.gd` — `UiReplayTimeline`：每一步一格（最左是开局），按行动座位着色，
  颜色和四个吉祥物一致（深棕 / 薄荷 / 紫 / 橙）；已播放实色、未播放灰色、当前步加高 + 橙框；
  点击发 `seek_requested(step)`。

回放数据只来自 `ui/bridge/replay_source.gd`；屏幕不碰 `GameController`。
IR-03（逐步回放接口）落地前的临时实现只有当前行动者视角，其他座位返回“全部公开”视图。
