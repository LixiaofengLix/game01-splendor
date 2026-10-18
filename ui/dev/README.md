# ui/dev/

开发辅助：

- `gallery.tscn` — 零件全状态陈列（U1）。运行 `godot --path . ui/dev/gallery.tscn`；
  `--full` 截图由下面的工具完成。
- `capture.tscn/.gd` — 带窗口截图（headless 没有渲染）：
  ```bash
  # 整页（SubViewport 放大，一次拍完）
  godot --path . ui/dev/capture.tscn --quit-after 400 -- --full --out /tmp/splendor_ui/gallery_full.png --width 1280 --wait 8
  # 窗口尺寸 + 缩放方案
  godot --path . ui/dev/capture.tscn --quit-after 300 -- --out /tmp/splendor_ui/g.png --width 1440 --height 900 --scale fractional --wait 8
  ```
  `--scale` 可取 `fractional` / `integer`；`--scroll` 指定窗口截图的滚动位置。
- `quick_start.tscn` — U3 的临时开局入口（尚未创建）。
- `fixtures/` — 假后端与渲染用的视图 JSON（U2 起）。
