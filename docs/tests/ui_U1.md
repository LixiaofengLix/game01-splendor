# 阶段 U1 测试用例（零件库 + 陈列场景）

## 先用 30 秒看这里

- **机器能判断的已经全部跑完**：`ui_smoke` 234 项通过、陈列场景 headless 无报错、`data_report` 通过、
  正式 UI 入口 headless 退出码 0。
- 需要你参与两件事：
  1. **对照样张看截图**（U1-06）：像素清晰度、颜色 / 形状、字号、状态是否齐全。
  2. **拍板缩放方案**（U1-07）：我建议保持现在的分数缩放（方案 a），理由见下。
- 所有命令在仓库根目录执行：

```bash
cd /Users/lixiaofeng/workspace/GameProjects/GodotProjects/splendor
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
```

- 截图都写到 `/tmp/splendor_ui/`，不进仓库。截图工具**必须带窗口运行**，不能加 `--headless`。

---

## U1-01 资源导入

**前置条件**：仓库干净，Godot 4.7。

**步骤**

```bash
$GODOT --headless --import --path .; echo "退出码: $?"
```

**预期结果**：退出码 `0`；没有 `SCRIPT ERROR` / `Parse Error`。

---

## U1-02 零件冒烟测试

**前置条件**：U1-01 已通过。

**步骤**

```bash
$GODOT --headless --path . tests/ui_smoke.tscn; echo "退出码: $?"
```

**预期结果**：退出码 `0`；打印“ui_smoke：234 项全部通过。”

检查范围：

- 零件脚本全部使用 `Ui` 前缀类名，且不直接引用 `GameState` / 读 `_state`；
- 筹码 4 种尺寸、满币 / 空心贴图、+N / −N 角标、bare 形状；
- 折扣块 5 种尺寸、0 值配色；花费药丸普通 / 迷你；
- 发展卡市场 / 迷你尺寸、点数、花费、可买、缺口条、选中上移、盲抽标签、牌背、空位、对手头像；
- 牌堆尺寸 / 罗马数字 / 剩余张数 / 已空；贵族大号尺寸、分数来自 `CardCatalog`、要求只列非零项；
- 卡牌引用文案；标签 / 键帽 / 分段 / 开关 / 输入框 / 进度条 / 转圈 / 列表行 / 按钮 / 菜单按钮 / 弹窗 / toast / 提示卡；
- 陈列场景可以实例化，滚动容器存在，整页高度大于 1000。

---

## U1-03 陈列场景 headless 启动

**前置条件**：U1-01 已通过。

**步骤**

```bash
$GODOT --headless --path . ui/dev/gallery.tscn --quit-after 10; echo "退出码: $?"
```

**预期结果**：退出码 `0`；没有 `SCRIPT ERROR` / `ERROR`。

---

## U1-04 数据层未受影响

**前置条件**：U1-01 已通过。

**步骤**

```bash
$GODOT --headless --path . tests/data_report.tscn; echo "退出码: $?"
git status --short docs/CARD_LIST.md
```

**预期结果**：退出码 `0`；打印“OK - 数据校验通过”；`docs/CARD_LIST.md` 没有变化。

---

## U1-05 正式 UI 入口 headless 启动

**前置条件**：U1-01 已通过。

**步骤**

```bash
$GODOT --headless --path . ui/app/app.tscn --quit-after 10; echo "退出码: $?"
```

**预期结果**：退出码 `0`；打印“UI：数据层校验通过（90 张卡牌，10 位贵族）。”。

---

## U1-06 整页零件截图（人工观察）

**前置条件**：U1-01 已通过；在有图形界面的终端里运行。

**步骤**

```bash
$GODOT --path . ui/dev/capture.tscn --quit-after 400 -- \
  --full --out /tmp/splendor_ui/gallery_full.png --width 1280 --wait 8
echo "退出码: $?"
open /tmp/splendor_ui/gallery_full.png
```

**预期结果**：退出码 `0`；打印“capture：整页 1280×…，保存到 …”；图片一次包含全部零件。

**逐项观察点**

1. **宝石 · 颜色 + 形状**
   - 6 种颜色各有专属形状：白◇ 蓝● 绿▮ 红♥ 黑■ 金★；
   - 筹码 lg 48px、md 36px、sm 24px、xs 12px，直径看起来是整数倍放大，不糊；
   - 满币下面有 2px 硬投影；数量 0 使用空心描边；
   - 已选筹码有 3px ORANGE 外框 + 右上角 `+1`；待弃筹码有 `−2` 角标且没有外框；
   - bare 筹码中间是 12px 单色形状，没有数字。
2. **折扣块 · 花费药丸**
   - 折扣块是方块、筹码是圆形，两者一眼能区分；
   - 数量 0 的折扣块是 CARD 底 + 空心描边 + `INK_3` 字；
   - noble / opp / base / big / md 五种尺寸都存在；
   - 花费药丸按白蓝绿红黑排序，数字清楚，迷你版高度明显更小。
3. **发展卡**
   - 色带 + 形状表示加成颜色；点数只在非 0 时显示，使用 Press Start 2P 16；
   - 花费在左下竖排，只列非零项；
   - “可买”卡边框是绿色（ok），右下有绿底“可买”；
   - “差 1”卡悬停时底部出现深色缺口条，列出还差的颜色与“金币可抵”；
   - “选中”卡有 3px ORANGE 外框、整体上移 4px，正上方有 ▼ 光标；
   - “刚被拿走”卡在 ORANGE / GOLD_TEXT 之间闪烁（截图只截到其中一帧）；
   - “对手能买”卡右上角有两个 16px 对手头像；
   - 迷你卡 92×120，市场卡 128×150；牌背有罗马数字、◆×等级、“盲抽”；
   - 空位卡是透明底 + 虚线框，中间写“空位”/“空”；我的盲抽显示正面 + dark 标签“盲抽”；
   - 打开“显示卡牌 id”时，卡面右下能看到 `L2-U-03`。
4. **牌堆 · 贵族**
   - 牌堆 96×150，斜纹深色底、金色罗马数字、下方两层硬投影；
   - 已空牌堆是虚线空位 + “已空”；选中牌堆有 3px ORANGE 外框；
   - 贵族是金边奶油色方牌，左上金色徽章写 `CardCatalog` 里的分数（不是写死的 3）；
   - 贵族要求用 24×30（大号 42×50）的折扣块，只列非零项；
   - 选中贵族换成 ink 小框 + 3px ORANGE 外框 + 浅橙底；
   - 大号贵族 200×170。
5. **通用控件**
   - 按钮：5 种配色 × sm / 默认 / lg × 正常 / 悬停 / 按下 / 禁用，共 60 个，状态色可区分；
   - 菜单大按钮：24 号主文字 + 12 号副文字 + 右侧 `›`；
   - 分段：选中项 HUD 底 + 金字；禁用项透明度约 .35；
   - 开关：关是 BG_SOFT 底、黑滑块在左；开是 ORANGE 底、白滑块在右；
   - 输入框、6 种标签、键帽、进度条（含竖纹）、转圈、列表行（普通 / 选中）。
6. **弹窗 · toast · 提示卡**
   - 弃宝石弹窗宽 560、异常弹窗宽 420，大框 + 向下 6px 硬投影；
   - toast 是 EVENT_BG + hot 小框，最宽约 320；提示卡是持续状态样式；
   - 所有 12px 文字边缘是硬的，没有抗锯齿灰边。
7. **整体**
   - 1280×800 基准下没有横向裁切；页面可以上下滚动看完整；
   - 颜色和形状同时传达信息：把截图转成灰度后，宝石仍能靠形状区分。

---

## U1-07 缩放方案对比（需要你拍板）

**背景**：`project.godot` 现在是 `canvas_items` + `expand`。

- **方案 a（当前，分数缩放）**：窗口是 1440×900 时放大 1.125 倍，1920×1200 时放大 1.5 倍；
  画面始终铺满窗口，但 1.125 不是整数，美术像素会出现 2px / 3px 交替。
- **方案 b（整数缩放）**：在 1440×900 / 1920×1200 都只能选 1×（2× 需要 2560×1600）；
  逻辑画布保持 1280×800，窗口会留边，界面相对窗口显得更小。
  像素完全不会抖动，但需要改 `project.godot` 的 `window/stretch/scale_mode`，只能在 U9 落地。

**步骤**（逐条运行；每条都会自己退出）

```bash
$GODOT --path . ui/dev/capture.tscn --quit-after 300 -- --out /tmp/splendor_ui/scale_1280_fractional.png --width 1280 --height 800 --scale fractional --wait 8
$GODOT --path . ui/dev/capture.tscn --quit-after 300 -- --out /tmp/splendor_ui/scale_1440_fractional.png --width 1440 --height 900 --scale fractional --wait 8
$GODOT --path . ui/dev/capture.tscn --quit-after 300 -- --out /tmp/splendor_ui/scale_1920_fractional.png --width 1920 --height 1200 --scale fractional --wait 8
$GODOT --path . ui/dev/capture.tscn --quit-after 300 -- --out /tmp/splendor_ui/scale_1440_integer.png --width 1440 --height 900 --scale integer --wait 8
$GODOT --path . ui/dev/capture.tscn --quit-after 300 -- --out /tmp/splendor_ui/scale_1920_integer.png --width 1920 --height 1200 --scale integer --wait 8
open /tmp/splendor_ui/scale_1440_fractional.png /tmp/splendor_ui/scale_1440_integer.png
```

**预期结果**

- 分数缩放：1280 图 1280×800、1440 图 1440×900、1920 图 1920×1200；
  1440 下文字和 1px 描边会有一点不均匀，但整体仍清晰。
- 整数缩放：截图是 1280×800 的逻辑画布；窗口四周留边，界面在 1440 / 1920 窗口里显得更小。

**开发侧建议**：选 **方案 a（保持现状）**。理由：1440×900 下 1.125 的抖动在实际窗口里不明显，
而方案 b 会让 UI 在常见窗口尺寸下明显偏小并留黑边；像素完美不值得这个代价。
如果你更看重像素绝对整齐、能接受留边，就在回复里选方案 b，我会在 U9 改项目设置。

---

## U1-08 交互式陈列（可选）

**前置条件**：U1-06 已通过。

**步骤**

```bash
$GODOT --path . ui/dev/gallery.tscn
```

**观察点**：

- 鼠标滚轮可以一直滚到底；
- 悬停“差 1”发展卡时，底部缺口条出现；移开后消失；
- 按钮悬停上移 2px、按下下移 2px 且投影消失；
- 开关可以点击切换；分段可以点击切换选中项；
- 转圈在动，选中卡上方的 ▼ 在跳动，光晕卡在闪烁；
- 关掉窗口即可，不需要开始对局。
