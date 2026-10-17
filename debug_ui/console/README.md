# debug_ui/console/

文本调试台：用文字命令完整打完一局，命令行列表见界面里的 `help`。

- `console.tscn` / `console.gd` — 界面用代码搭（只有 Label + LineEdit + RichTextLabel）。

```bash
# 交互模式（也可以直接 godot --path . ，主场景就是它）
/Applications/Godot.app/Contents/MacOS/Godot --path . debug_ui/console/console.tscn

# 批处理模式：按顺序执行命令文件，任一命令失败退出码 1
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . debug_ui/console/console.tscn -- --commands <命令文件>
```

存档写到 `user://saves/`；`load` 先找 `user://saves/`，再找 `tests/scenarios/`。
