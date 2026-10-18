# ui/theme/

界面主题：`palette.gd`（颜色常量）、`pixel_theme.tres`（字体、字号变体与 StyleBox）、`fonts/`（像素字体与 OFL 许可证）。

- 文字变体：`UiSmall(12)` / `UiTitle(24)` / `UiHero(48)`。
- 数字变体（Press Start 2P）：`UiNumSmall(8)` / `UiNumMid(12)` / `UiNum(16)` / `UiNumBig(32)`。
- 按钮变体：`UiButtonAccent` / `UiButtonDark` / `UiButtonGhost` / `UiButtonQuiet` / `UiButtonDanger`。
- 面板：`Panel` / `PanelContainer` 大框、`UiPanelHot`（当前行动者）。
- 标签：`UiTag*` 与对应的 `UiTag*Text`。

零件里不要散写字号和颜色；颜色一律引用 `UiPalette`，字号用上面的变体。
