# 阶段 U0 测试用例（工程骨架与素材）

## 先用 30 秒看这里

- **U0 的验收全部可以机器判断**，不需要你操作游戏；下面 U0-01 ~ U0-08 已由开发侧执行并通过。
  U0-09 是可选的视觉观察，不构成验收阻塞。
- 所有命令在仓库根目录执行，`$GODOT` 指 `/Applications/Godot.app/Contents/MacOS/Godot`。

```bash
cd /Users/lixiaofeng/workspace/GameProjects/GodotProjects/splendor
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
```

- 结果汇总：贴图 44 张、重复生成哈希一致；`ui_smoke` 95 项通过；入口 headless 退出码 0；
  `data_report` 通过；字体导入参数为关闭抗锯齿 / hinting / 子像素定位。
- 注：U1 起 `ui_smoke` 已扩充到 234 项（U0 的历史检查全部包含在内）；下文的 95 项是 U0 当时的数字。

---

## U0-01 资源导入

**前置条件**：仓库干净，Godot 4.7。

**步骤**

```bash
$GODOT --headless --import --path .; echo "退出码: $?"
```

**预期结果**：退出码 `0`；输出里没有 `ERROR` / `WARNING`；字体被识别为像素字体并关闭 hinting / 子像素定位。

---

## U0-02 贴图生成工具

**前置条件**：U0-01 已通过。

**步骤**

```bash
$GODOT --headless --path . ui/tools/build_pixel_assets.tscn; echo "退出码: $?"
```

**预期结果**：退出码 `0`；打印“像素贴图：生成 44 张，尺寸自检通过。”
工具会检查每张 PNG 重新读取后的尺寸、目录里没有多余 / 缺失的 PNG，以及总张数。

---

## U0-03 重复生成一致性

**前置条件**：U0-02 已通过。

**步骤**

```bash
shasum -a 256 ui/assets/pixel/*.png > /tmp/splendor_ui_a.txt
$GODOT --headless --path . ui/tools/build_pixel_assets.tscn > /dev/null
shasum -a 256 ui/assets/pixel/*.png > /tmp/splendor_ui_b.txt
diff /tmp/splendor_ui_a.txt /tmp/splendor_ui_b.txt; echo "退出码: $?"
```

**预期结果**：`diff` 没有输出，退出码 `0`（两次生成的文件完全一致）。

---

## U0-04 字体导入参数

**前置条件**：U0-01 已通过。

**步骤**

```bash
grep -E "^(antialiasing|hinting|subpixel_positioning|multichannel_signed_distance_field)=" \
  ui/theme/fonts/*.ttf.import
```

**预期结果**：两个字体各四行，都是 `antialiasing=0`、`hinting=0`、`subpixel_positioning=0`、
`multichannel_signed_distance_field=false`。

---

## U0-05 正式 UI 冒烟测试

**前置条件**：U0-01 已通过。

**步骤**

```bash
$GODOT --headless --path . tests/ui_smoke.tscn; echo "退出码: $?"
```

**预期结果**：退出码 `0`；打印“ui_smoke：234 项全部通过。”（U0 当时为 95 项，U1 起扩充）。
检查内容：主题与默认字体、7 个字号变体、按钮 / 面板 / tag 样式、14 张代表性贴图的尺寸、
全部零件、陈列场景、入口场景结构、12 个快捷键动作、数据层校验。

---

## U0-06 入口场景 headless 启动

**前置条件**：U0-01 已通过。

**步骤**

```bash
$GODOT --headless --path . ui/app/app.tscn --quit-after 10; echo "退出码: $?"
```

**预期结果**：退出码 `0`；打印“UI：数据层校验通过（90 张卡牌，10 位贵族）。”

---

## U0-07 数据层未受影响

**前置条件**：U0-01 已通过。

**步骤**

```bash
$GODOT --headless --path . tests/data_report.tscn; echo "退出码: $?"
git status --short docs/CARD_LIST.md
```

**预期结果**：退出码 `0`；打印“OK - 数据校验通过，卡表已写入 …”；`docs/CARD_LIST.md` 没有变化。

---

## U0-08 目录与文档完整性

**前置条件**：仓库干净。

**步骤**

```bash
for d in app theme theme/fonts assets assets/pixel assets/sfx tools bridge common components \
         screens screens/table screens/modals screens/settings screens/net screens/errors \
         screens/replay dev dev/fixtures; do
  test -f "ui/$d/README.md" || echo "缺少 README：ui/$d"
done
find ui/assets/pixel -name "*.png" | wc -l
```

**预期结果**：没有“缺少 README”的输出；PNG 数量为 `44`。

---

## U0-09 可选人工观察

**前置条件**：无。只在想看效果时运行，不阻塞验收。

**步骤**

```bash
$GODOT --path . ui/app/app.tscn
```

**预期结果（观察点）**：

- 背景是 `#e9d8b4` / `#e3d0a8` 的细棋盘格，平铺没有接缝；
- 标题“璀璨宝石”是 48px 像素字，边缘是硬的，没有灰边或模糊；
- 副标题 24px、提示行 12px，同样清晰；
- 窗口可正常关闭；Esc / Enter 在 U0 还没有行为，不应报错。

关掉窗口即可，不需要操作游戏。
