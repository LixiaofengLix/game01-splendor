# ui/dev/

开发辅助。所有命令在仓库根目录运行（`$GODOT` 指 `/Applications/Godot.app/Contents/MacOS/Godot`）。

- `gallery.tscn` — 零件全状态陈列（U1）。`$GODOT --path . ui/dev/gallery.tscn`。
- `capture.tscn/.gd` — 带窗口截图（headless 没有渲染）：
  ```bash
  # 整页零件陈列（SubViewport 放大，一次拍完）
  $GODOT --path . ui/dev/capture.tscn --quit-after 400 -- --full --out /tmp/splendor_ui/gallery_full.png --width 1280 --wait 8
  # 窗口尺寸 + 缩放方案（零件陈列）
  $GODOT --path . ui/dev/capture.tscn --quit-after 300 -- --out /tmp/splendor_ui/g.png --width 1440 --height 900 --scale fractional --wait 8
  # 牌桌夹具（U2）
  $GODOT --path . ui/dev/capture.tscn --quit-after 400 -- --fixture g3_turn_mine --out /tmp/splendor_ui/g3_turn_mine.png --width 1280 --height 800 --wait 10
  ```
  `--scale` 可取 `fractional` / `integer`；`--scroll` 指定窗口截图的滚动位置。
- `table_preview.tscn/.gd` — 单张夹具的牌桌预览：
  `$GODOT --path . ui/dev/table_preview.tscn -- --fixture g3_turn_mine`（默认 `g3_turn_mine`）。
- `build_fixtures.tscn/.gd` — 生成 `fixtures/` 下的夹具。改完卡表、规则或样张局面后重跑：
  ```bash
  $GODOT --headless --path . ui/dev/build_fixtures.tscn
  ```
  1. G3 / G4 按 `docs/ui-mockup-v4.html` 的局面数据手写（卡牌 id 真实、宝石守恒）；
  2. `tests/scenarios/bank_edges.json` / `deck_empty.json` 转成过滤视图；
  3. 用 `GameController` + 随机合法动作控制器按种子跑两局，取中途“轮到我”的视图。
- `fixtures/` — 牌桌 / 假后端夹具。每个 `<name>.json` 的格式与 `BRIDGE_AND_REQUESTS.md` 第 2 节一致：
  ```json
  {
    "schema_version": 1,
    "name": "g3_turn_mine",
    "seats": [{"name": "小明", "type": "human"}, ...],
    "me_seat": 0,
    "log": [{"seat": 2, "text": "紫晶 拿了 {gem:white}{gem:green} 各 1 枚", "time": "刚刚"}],
    "steps": [{"at_ms": 0, "view": "views/g3_turn_mine.json"}]
  }
  ```
  `views/*.json` 就是 `GameState.to_dict(viewer_seat)` 的格式。日志文本支持
  `{card:L2-R-01}`（卡牌引用）与 `{gem:red}`（宝石图标）。`strip` / `pill_text` / `mode` /
  `replay_label` / `flash_cards` / `log_limit` 是可选的显示覆盖项。U3 的 `FakeBackend` 可以直接复用这些文件。
- `quick_start.tscn/.gd` — U3 的临时开局入口：选人数 / 电脑难度 / 种子，直接进入正式牌桌。
  `$GODOT --path . ui/dev/quick_start.tscn`。开局后 HUD 的“菜单”按钮直接回到开局设置（U4 的暂停菜单之前的临时行为）。
  这是开发入口，正式的主菜单与开局设置（02）在 U4 接入后删除。
