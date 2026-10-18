# 正式 UI 进度

> UI 线的交接文档。计划与并行开发约定见 `UI_DEV_PLAN.md`；逻辑线进度见 `docs/PROGRESS.md`。
> 每个 U 阶段结束后更新：已完成 / 与计划的偏差 / 遗留问题 / 下一阶段需要知道的事 / 新登记的 IR。

## 当前状态

- **U0（工程骨架与素材）：已完成，随 U1 一起提交（2026-10-18）。**
  `ui/` 目录树、字体、44 张像素贴图、调色板、初版 Theme、入口空壳与 `tests/ui_smoke.tscn` 已就位。
- **U1（零件库 + 陈列场景）：已完成并提交（2026-10-18）；视觉验收待看，缩放方案已定为 b。**
  21 个零件脚本、共享 `UiFrame`、陈列场景、整页截图工具和 U1 冒烟检查已就位。
  自动验证全部通过：`ui_smoke` **234 项**、陈列场景 headless 无报错、`data_report` 通过、
  正式入口 headless 退出码 0；整页截图 1280×4128 已人工检查。
- **U2（牌桌静态渲染）：已完成并提交（2026-10-18）。**
  `UiViewMath`、牌桌场景与 6 个面板零件、9 个夹具、`build_fixtures` / `table_preview` / 截图 `--fixture`
  已就位。自动验证全部通过：`ui_smoke` **877 项**、`data_report` 通过、入口 headless 退出码 0；
  04 / 07 / 08、2 人 / 4 人、牌堆空、银行见底、观战、回放占位、1600 宽 / 900 高截图已检查。
- 下一步：U3（牌桌交互 + 接真实对局）。
  **缩放方案已拍板选 b（整数缩放），在 U9 改 `project.godot`，U0–U8 不改项目设置。**
- 上次更新：2026-10-18

---

## U0：工程骨架与素材

### 已完成

- `ui/` 目录树与各文件夹 `README.md`（第 3 节列出的目录全部建好）。
- 字体放进 `ui/theme/fonts/`：
  - Fusion Pixel 12px Proportional 简中（2026.10.16 发布，6.9 MB）。
  - Press Start 2P（google/fonts）。
  - 两份字体各自的 `OFL_*.txt`。
  - 导入参数：`antialiasing=0`、`hinting=0`、`subpixel_positioning=0`、MSDF 关闭、mipmaps 关闭。
- `ui/tools/build_pixel_assets.gd/.tscn`：生成 44 张 PNG 到 `ui/assets/pixel/`，结束时自检张数与尺寸；
  连续两次运行的文件哈希完全一致。
  - 9 宫格：小框 5 色（透明中心）+ 5 张白色中心版；大框 2 色（羊皮纸内衬）。
  - 金币 6 色 × 满 / 空；宝石 6 色 × 彩色 / 单色；吉祥物 4 座位 + 眯眼。
  - 平铺底纹：`tile_paper`（4×4）、`tile_wood`（48×48）、`tile_card_back`（10×10）。
- `ui/theme/palette.gd`：`VISUAL_SPEC.md` 第 2 节全部颜色、标签配色、宝石四套配色（底色 / 字色 / 卡面浅底 / 空心描边）。
- `ui/theme/pixel_theme.tres` 初版：
  - 默认字体 Fusion Pixel、默认字号 12。
  - 文字变体 `UiSmall` 12 / `UiTitle` 24 / `UiHero` 48；数字变体 `UiNumSmall` 8 / `UiNum` 16 / `UiNumBig` 32（Press Start 2P）。
  - 默认 Button + 5 个按钮变体（`UiButtonAccent/Dark/Ghost/Quiet/Danger`）的 normal / hover / pressed / disabled / focus；
    focus 是 3px 橙色外框。
  - `PanelContainer` / `Panel` 大框；`UiPanelHot` 当前行动者面板；6 种 tag 及其文字变体；`LineEdit`。
- `ui/app/app.tscn` + `app.gd`：
  - 根节点 `texture_filter = NEAREST`、挂主题、羊皮纸棋盘格背景、U0 占位画面。
  - `ScreenRoot`、`ModalLayer/ModalRoot`、`ToastLayer/ToastRoot` 三层；`set_screen()` / `push_modal()` / `clear_modals()`。
  - 运行时注册 12 个 `spl_` 快捷键动作（1–5、Enter、Esc、R、L、← →、空格），不改 `project.godot`。
  - 启动时检查 `DataRegistry.is_valid()`，失败按 U0 约定先打印（21 屏在 U4 做）。
- `tests/ui_smoke.tscn/.gd` 第一版：主题与字号变体、按钮 / 面板 / tag 样式、14 张代表性贴图的尺寸、
  入口场景结构与 12 个快捷键动作、数据层校验。**95 项全部通过。**
- 文档：本文件、`docs/tests/ui_U0.md`；`CLAUDE.md` 追加 UI 启动 / 冒烟 / 贴图命令和 UI 线约定；
  `docs/PROGRESS.md` 当前状态加一行指向本文件。

### 与计划的偏差

1. **小框多生成了 5 张“白色中心”版本**（`frame_s_*_fill.png`，共 44 张而不是 39 张）。
   原因：Godot 的 `StyleBoxTexture` 只能画一张贴图、没有单独的填充色；白色中心的版本可以用 `modulate_color`
   染成按钮 / tag / 输入框的底色。样张里的透明中心版本仍保留（`frame_s_*.png`），给牌背、牌堆等需要
   露出底纹的场合使用（`draw_center = false`）。
2. **大框面板的顶部 2px 内高光和向下 4px 硬投影暂未做进 StyleBox**。`VISUAL_SPEC` 4.1 要求的两层效果
   无法用单个 StyleBox 叠出，留到 U1 的面板零件（额外 NinePatch / StyleBoxFlat 层）实现。
3. **按钮的悬停抬起 / 按下压扁暂未实现**：Theme 里只做了亮度变化；2px 位移是 U1 的运行时效果。
4. **按钮尺寸变体（sm / lg）暂未做**：当前所有按钮共用 7/14/9 的内容边距，U1 再按规格补。
5. `pixel_theme.tres` 是用一次性脚本构建后保存的，**现在它是源文件**；以后直接改 `.tres` / 在编辑器里改，
   不再重新生成（避免覆盖手工调整）。
6. 字体没有子集化（Fusion Pixel 6.9 MB）；U9 视导出包体积再处理。
7. `tests/ui_smoke.tscn` 比计划提前到 U0 建立，这样每个 UI 改动都有可复现的自动检查；U2 继续扩充，
   不改变“U2 起 UI 改动必跑”的约定。
8. `ui/app/app.tscn` 目前带一个占位画面（标题 + “U0 工程骨架”）；主菜单在 U4 接入，占位画面届时移除。

### 遗留问题 / 下一阶段需要知道的事

- **贴图命名**：`frame_s_<色>`（透明中心）/ `frame_s_<色>_fill`（白色中心）、`frame_l_<色>`、
  `coin_<字母>` / `coin_<字母>_empty`、`gem_<字母>` / `gem_<字母>_mono`、`mascot_1..4` / `mascot_sleepy`、
  `tile_paper` / `tile_wood` / `tile_card_back`。颜色字母用 W/U/G/R/K/X。
- **Theme 变体**：文字用 `UiSmall/UiTitle/UiHero`，数字用 `UiNumSmall/UiNum/UiNumBig`；
  按钮用 `UiButton*`；tag 用 `UiTag*` + 对应的 `UiTag*Text`；当前行动者面板用 `UiPanelHot`。
  零件里不要再散写字号和颜色。
- **颜色**：一律引用 `UiPalette`；宝石色用 `UiPalette.GEM_BASE[Enums.GemColor.X]` 等字典 / 静态函数。
- **入口**：屏幕通过 `app.set_screen(control)` 切换，`set_screen(null)` 会显示占位画面；
  弹窗加到 `push_modal()`。U1 的陈列场景和 U2 的牌桌都从 `app.tscn` 之外单独启动，不受占位画面影响。
- **自动检查**：改完 `ui/` 跑 `tests/ui_smoke.tscn`；U1 起每加一个零件就往里补检查。
- **视觉验收**：U1 才会做正式截图对照；U0 已用临时截图确认 12 / 24 / 48 号像素字清晰、没有模糊，
  窗口基准 1280×800 下背景平铺无接缝。
- 没有改动 `project.godot`（主场景仍是调试界面），符合 U0–U8 的约定。

### 新登记的 IR

无。

---

## U1：零件库 + 陈列场景

### 已完成

- 共享底座 `ui/components/frame.gd`（`UiFrame`）：9 宫格框 + 底色 + 可选硬投影 / 顶部内高光 /
  重点色条，子节点放进 `content`。标签、toast、提示卡、弹窗、贵族、章节框都从它长出来。
- 贴图工具 `ui/common/ui_assets.gd`（`UiAssets`）：按 `Enums.GemColor` 取筹码 / 宝石 / 吉祥物贴图，
  生成固定像素尺寸的图标，提供 9 宫格与平铺贴图节点。
- 通用控件（11 个）：`UiButton`（5 变体 × sm/默认/lg，悬停抬起、按下压扁、硬投影、陈列预览状态）、
  `UiMenuButton`、`UiSegmented`、`UiSwitch`、`UiInput`、`UiTag`（6 配色）、`UiKbd`、
  `UiProgressBar`（含 8px 竖纹）、`UiSpinner`（四帧像素环）、`UiListRow`、
  `UiModalFrame`（大框 + 6px 硬投影 + 标题 tag + 按钮行）、`UiToast`、`UiNoticeCard`。
- 宝石类（3 个）：`UiGemChip`（lg/md/sm/xs × 正常/空心/已选 +N/待弃 −N/bare）、
  `UiBonusTile`（noble/opp/base/big/md 五种尺寸、0 值配色）、`UiCostPill`（普通/迷你）。
- 卡牌类（4 个）：`UiDevCard`（市场 128×150 / 迷你 92×120；普通、可买、差 N + 悬停缺口条、
  选中 + ▼、光晕、对手能买头像、空位、牌背、我的盲抽标签、显示 id）、
  `UiDeckPile`（有牌 / 已空 / 选中）、`UiNobleTile`（市场 / 200×170 大号 × 选中）、`UiCardRef`。
- `ui/dev/gallery.tscn`：按样张“设计零件”一节排版，所有状态并排；顶部有说明和截图命令。
- `ui/dev/capture.tscn/.gd`：带窗口截图。`--full` 用放大的 SubViewport 一次拍整页；
  默认模式按 `--width/--height/--scale fractional|integer/--scroll` 拍窗口。
  headless 下会直接报错退出（没有渲染）。
- 主题：新增 `UiNumMid`（Press Start 2P 12），给 md/sm 筹码、迷你花费药丸等中小数字用。
- `tests/ui_smoke.tscn` 扩充到 **234 项**：零件脚本命名与禁用依赖扫描、每个零件的尺寸 / 文本 / 状态、
  陈列场景结构与整页高度。
- 文档：`docs/tests/ui_U1.md`；本文件；`ui/components/`、`ui/dev/`、`ui/common/`、`ui/theme/` 的 README；
  `CLAUDE.md` 常用命令追加陈列 / 截图命令。

### 与计划的偏差

1. **零件是代码构建的，没有给每个零件单独做 `.tscn`**。这些零件的布局由尺寸 / mini / 状态决定，
   静态场景反而要写大量占位；`ui/dev/gallery.tscn` 就是它们的编辑器预览。对外的类名和接口与计划一致。
2. **新增共享底座 `UiFrame`**（计划零件表里没有）。9 宫格框、底色、投影、内高光在标签 / toast /
   提示卡 / 弹窗 / 贵族 / 章节框里重复出现，抽成一个底座比复制 6 份低价值代码更省事。
3. **新增主题变体 `UiNumMid`（Press Start 2P 12）**。`VISUAL_SPEC` 第 3 节说数字只用 8/16/32，
   但同一节又明确“中号 / 小号筹码里的数字用像素字体 12”；U0 没有这个变体，U1 补上。
4. **空位卡的文字色改用 `LINE`**，不用 `CREAM`。样张的 `.gc.empty` 实际用的是 `#cdb68c`；
   在羊皮纸面板上 `CREAM` 几乎看不见。虚线仍是 `CREAM` α .35，透明底不变。
5. **选中卡的上移做成内容层偏移**，没有移动零件根节点。这样在以后牌桌的固定卡位里，
   选中不会改变槽位布局；代价是调用方要在卡位上方留出约 28px 给 ▼ 光标（U2 排版时注意）。
6. **光晕动画由调用方控制时长**：`flash = true` 时零件自己两帧循环，U3 / U5 在 1.5 秒后设回 false。
   这样陈列场景可以一直看到光晕，不需要另做“冻结动画”模式。
7. **缺口条加了 `force_need`**（陈列场景专用），否则只有鼠标悬停才出现，整页截图里看不到。
8. **按钮的“悬停抬起 / 按下压扁”是运行时位移**；陈列场景的预览状态只展示配色 / 投影，
   不模拟位移（静态截图中看不出 2px 抬起，这是预期）。
9. **按钮投影用 `show_behind_parent` 的 NinePatchRect 画**，选中卡 / 牌堆的投影用 `_draw` 画；
   都没有改 `project.godot` 或加着色器。
10. **`UiCardPopover` 没做**。计划 U1 的 1–3 条没有列它，U3 第 3 条才做“选卡与浮层”；
    支付预览的数据结构建议等 U2 的 `ViewMath` 定下来再做，避免返工。
    银行 / 我的面板 / 对手面板 / 日志 / 顶栏等 6.6–6.10 的面板按计划留给 U2。
11. **缩放方案已拍板选 b（整数缩放）**：U9 在 `project.godot` 设
    `window/stretch/scale_mode = "integer"`；U0–U8 保持原样（分数缩放），U1 只提供两种模式的截图命令。

### 遗留问题 / 下一阶段需要知道的事

- **缩放方案（已拍板 2026-10-18）**：选 **b（整数缩放）**。U9 在 `project.godot` 设
  `window/stretch/scale_mode = "integer"`；届时非整数窗口会居中留边，逻辑画布保持 1280×800。
  U0–U8 不改项目设置；U2 起仍按 1280×800 逻辑尺寸排版，窗口更宽 / 更高的自适应分支保留作为兜底。
- **待你视觉验收**：`docs/tests/ui_U1.md` 的 U1-06。机器验证已全部通过；U1-07 已拍板。
- **零件接口约定**：
  - 只接收显示数据：`card_id` + `CardCatalog`、颜色、数字、状态布尔值；不认识视图字典。
  - 发展卡状态属性：`affordable`、`shortfall`、`missing`、`gold_can_pay`、`selected`、`flash`、
    `threat_seats`、`empty`、`card_back`、`back_level`、`blind_label`、`show_id`、`force_need`。
    U2 的牌桌从视图 + `ViewMath` 算出这些值再赋给零件即可。
  - `missing` 格式：`[{"color": Enums.GemColor, "amount": int}]`，由调用方按白蓝绿红黑顺序排好。
  - `UiFrame` 的 `content` 是 `MarginContainer`；外部往里面加内容后，最小尺寸会自动传播。
  - 按钮尺寸只改内边距，字号始终 12；新增按钮不要自己写 `add_theme_font_size_override`。
- **尺寸备忘**：市场卡 128×150、迷你卡 92×120、牌堆 96×150、贵族市场最小 100×86（高度由列平分）、
  大号贵族 200×170、筹码 48/36/24/12、折扣块 24×30 / 30×27 / 28×32 / 42×50 / 44×48。
- **主题**：数字用 `UiNumSmall(8) / UiNumMid(12) / UiNum(16) / UiNumBig(32)`；
  文字用 12（默认）/ `UiTitle(24)` / `UiHero(48)`。零件里不要再散写字号。
- **陈列与截图**：
  ```bash
  $GODOT --path . ui/dev/gallery.tscn
  $GODOT --path . ui/dev/capture.tscn --quit-after 400 -- --full --out /tmp/splendor_ui/gallery_full.png --width 1280 --wait 8
  ```
  截图必须带窗口；`--headless` 会直接退出。整页截图当前为 1280×4128。
- **已知小问题（不阻塞 U1）**：
  - U9 应用整数缩放后，1440×900 这类窗口会按 1× 居中留边，美术像素不再出现 2px / 3px 交替；
    代价是界面相对窗口变小。U9 截图时再确认。
  - `UiDevCard` 的缺口条目前是单行，4 种缺失颜色时可能挤；U3 的完整支付信息在卡牌浮层里，
    缺口条只做悬停提示，必要时再改成两行。
  - 陈列场景整页较长，截图工具用 SubViewport 一次拍完；U2 的牌桌截图仍按窗口尺寸拍。

### 新登记的 IR

无。

---

## U2：牌桌静态渲染

### 已完成

- `ui/common/view_math.gd`（`UiViewMath`）：分数、折扣、持币总数、缺口明细、金币可抵、支付预览、
  买得起的座位、轮数、终局剩余人数、座位类型文案。买得起 / 支付拆分与 `core/rules.gd`
  的 `_can_afford` / `_payment` 同一算法（IR-02 的临时实现）。
- `ui/common/ui_markup.gd`（`UiMarkup`）：日志 / 顶条文案的 `{card:id}` / `{gem:color}` 简写 → BBCode。
- 6 个牌桌零件：
  - `UiHud`（顶栏：标题、人数轮数、终局标签、回合胶囊、规则 / 菜单按钮）
  - `UiTurnPill`（轮到我 / 等别人 + 转圈 / 纯文字）
  - `UiBankColumn`（银行列：6 枚 lg 筹码 + 操作提示）
  - `UiMyPanel`（状态条 + 身份 / 资源 / 预留三列；事件态顶条）
  - `UiOpponentPanel`（分数进度条 + 6 列折扣 / 宝石网格 + 预留标记 + 思考中）
  - `UiLogPanel`（最新一条高亮、卡牌引用 / 宝石内联、全部记录 L）
- `ui/screens/table/table_screen.tscn/.gd`（`UiTableScreen`）：`render(view, me_seat, session_info)`
  唯一入口；按 `SCREENS.md` 的几何搭牌桌；没有“我”时右栏列全部玩家、底部换成观战 / 回放占位；
  窗口更宽时右栏扩展到 420 后整组居中，更高时多出的高度给日志。
- 夹具与工具：
  - `ui/dev/build_fixtures.tscn/.gd`：生成 9 个夹具（G3 轮到我 / 电脑回合 / 观战 / 回放、G4 终局、
    2 人银行见底、4 人牌堆已空、3 人 / 4 人种子跑局）。
  - `ui/dev/fixture_loader.gd`、`ui/dev/table_preview.tscn`。
  - `ui/dev/capture.tscn` 新增 `--fixture <name>` 牌桌截图。
- `tests/ui_smoke.tscn` 扩充到 **877 项**：ViewMath 数值、逐个夹具渲染、卡牌 id / 银行 / 玩家数字 /
  分数与视图一致、三级顺序、4 人右栏不溢出、重复 render 节点数不变、盲抽隐私、宝石守恒、
  观战 / 回放底部布局。
- 文档：`docs/tests/ui_U2.md`；本文件；`ui/common/`、`ui/components/`、`ui/screens/table/`、
  `ui/dev/`、`ui/theme/` 的 README；`CLAUDE.md` 常用命令补 U2 的生成 / 预览 / 截图命令。

### 与计划的偏差

1. **市场卡位数改为运行时从 `RulesConfig.board_slots_per_level` 读**。三行市场在第一次 `render`
   时按规则搭好；规则里的卡位数变化会重建。我的面板预留位也按 `max_reserved` 生成，不再写死 3。
2. **G3 / G4 是“脚本里的手写常量”**：牌面、宝石、日志照样张录入 `build_fixtures.gd`，
   由工具写成 JSON 并提交。这样改样张时只改一处，也能保证重复生成一致。
3. **预设局面夹具（银行见底 / 牌堆已空）的日志为空**。快照本身没有动作历史，手写日志会和
   局面数字矛盾（例如日志说拿了绿宝石但银行 / 手牌里没有），所以只显示“还没有记录”。
4. **牌桌直接读 `DataRegistry` 的静态数据作为兜底**：`session_info` 可以注入 `catalog` / `rules`，
   不注入时用 `DataRegistry`。这不涉及 `GameController`；U3 的桥接层会统一提供视图、动作与数据。
5. **观战 / 回放底部先用占位框**：观战写“全部 N 位玩家在右栏”，回放写步骤说明 +
   “回放播放条将在 U6 实现”。回放夹具里当前行动者仍显示橙框，但不显示“思考中”。
6. **日志用 RichTextLabel + BBCode**（卡牌引用 = 浅色底 + 宝石图标），没有把 `UiCardRef`
   塞进日志行。`UiCardRef` 仍保留给后续需要独立零件的地方。
7. **小型零件扩展**：`UiFrame.side_bar`（我的面板 / 当前行动者左侧橙条）、
   `UiDevCard.show_status`（不是我的回合时仍可悬停看缺口，但不显示“差 N”）、
   `UiTag.in_hud`（顶栏深底标签配色）、`UiButton` 新增 `hud` 变体、
   `UiPalette.PROGRESS_FILL`（对手进度条的灰色填充）。
8. **`build_fixtures` 的种子跑局用随机合法动作控制器**（不是程序 AI），只用于取“真实对局中途视图”；
   两只夹具分别在第 12 步截取，避免等 AI 思考延迟。G3 / G4 仍覆盖主要视觉状态。
9. **HUD 的“规则 / 菜单”按钮在 U2 只有外观**，点击行为分别留到 U3 / U4。
10. **截图工具的 `--fixture` 与陈列的 `--full` 互斥**；牌桌截图固定用窗口模式（headless 没有渲染）。
11. **`tests/ui_smoke` 的检查数从 234 增加到 877**；U2 起每次 UI 改动都要跑它。

### 遗留问题 / 下一阶段需要知道的事

- **缩放方案（U1 遗留，已拍板）**：选 **b（整数缩放）**，U9 落地。
  U2 仍按 1280×800 逻辑尺寸排版；窗口更宽 / 更高时的布局已实测（1600×800、1280×900），
  但 U9 应用整数缩放后，非整数窗口会居中留边、逻辑画布保持 1280×800，这两条自适应分支主要作为兜底保留。
- **视觉验收**：截图与逐项观察点见 `docs/tests/ui_U2.md` 的 U2-05 至 U2-11
  （04 / 07 / 08、2 人、牌堆空、观战、回放）；已确认提交。后续如发现视觉问题，优先在 U3 前修。
- **牌桌入口契约**：`render(view, me_seat, session_info)`；`me_seat = -1` 表示观战 / 回放。
  `session_info` 键见 `ui/screens/table/README.md`（`names` / `seat_types` / `log` / `strip` /
  `pill_text` / `mode` / `replay_label` / `flash_cards` / `log_limit` / `catalog` / `rules`）。
- **U3 要接的东西**：`UiTableSession` + `LiveBackend`；点击状态机、卡牌浮层、弃宝石 / 选贵族弹窗、
  动效、`action_failed`。牌桌已经只认视图，桥接层把这些数据喂进来即可。
- **U3 隐私注意**：全电脑观战时，`GameController.state_changed` 发出的是当前电脑的视图，
  里面可能有它自己的盲抽 id。桥接层在生成观战视图时应把所有盲抽 id 置空（U2 的 `g3_spectator`
  夹具就是这么做的）。UI 现在只画对手面板的罗马数字标记，不会显示卡面，但桥接层仍应做这层过滤。
- **同一块牌桌连续切换 `me_seat`**（例如观战 ↔ 玩家）时，隐藏的我的面板会保留上一次的预留卡节点。
  它们不可见、不影响布局；U3 接真实会话时在 `me_seat` 变化时清空一次即可。
- **日志条数**：3 个对手时 4 条，否则 7 条；`session_info.log_limit` 可覆盖。
- **回放 / 观战夹具**：`g3_replay` 的 `turn_counts` 设为 `[12,12,12]`（第 37 步 = 第 13 轮），
  与底部说明一致；`g3_spectator` 把三家的盲抽 id 都置空。
- **截图与预览**：
  ```bash
  $GODOT --headless --path . ui/dev/build_fixtures.tscn
  $GODOT --path . ui/dev/table_preview.tscn -- --fixture g3_turn_mine
  $GODOT --path . ui/dev/capture.tscn --quit-after 400 -- --fixture g3_turn_mine --out /tmp/splendor_ui/g3_turn_mine.png --width 1280 --height 800 --wait 10
  ```
- **已知非问题**：`g3_turn_mine` 有一条日志在 330 宽右栏折成两行；截图退出时的 RID / ObjectDB
  `leaked` 警告来自 `--quit-after` 强制退出，不影响结果。

### 新登记的 IR

无（`UiViewMath` 是 IR-02 的临时实现；U3 的桥接层会处理观战视图的盲抽过滤，不需要逻辑层新接口）。
