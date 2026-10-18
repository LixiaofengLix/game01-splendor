# ui/assets/sfx/

音效素材，U5 只留播放钩子，素材后期再放。`UiSfx`（`ui/common/sfx.gd`）按下列文件名查找，
文件不存在时静默跳过；开关是 `UiSettings.sfx_enabled()`。

| 文件 | 触发 |
|---|---|
| `gems_taken.wav` | 拿宝石 |
| `card_reserved.wav` | 预留 |
| `card_purchased.wav` | 购买 |
| `noble_visited.wav` | 贵族来访 |
| `endgame_triggered.wav` | 触发终局 |
| `game_finished.wav` | 对局结束 |
| `click.wav` | 按钮点击 |

素材加入后不需要改代码；直接放成同名文件即可。
