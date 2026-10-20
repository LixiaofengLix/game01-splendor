# 璀璨宝石（Splendor）电子版

用 **Godot 4.7 + GDScript** 实现的基础版《璀璨宝石》非官方电子版。支持 2–4 人本地同屏、
三档程序 AI、OpenAI 兼容的大模型玩家，以及一套完整的像素风正式界面（主菜单、牌桌、回放、设置）。

![Godot](https://img.shields.io/badge/Godot-4.7-478CBF)
![GDScript](https://img.shields.io/badge/GDScript-statically%20typed-355570)
![Status](https://img.shields.io/badge/status-in%20development-orange)

> 本项目为个人开发项目，与《Splendor》的出版方无关。Splendor 由 Marc André 设计，
> 相关商标与美术版权归其权利人所有；本仓库不包含官方美术素材。

## 功能

- **完整基础版规则**：90 张发展卡、10 位贵族、2–4 人；拿宝石、预留、购买、弃宝石、选贵族、
  终局与破同分全部按官方规则实现。
- **多种对局方式**：本地同屏多人、人机对战、全电脑观战，也可以让任意座位交给大模型。
- **三档程序 AI**：简单（贪心 + 扰动）、普通（一步评估 + 目标规划）、困难（两层搜索），
  每档的权重和搜索预算都在 `data/ai/*.json`。
- **大模型玩家**：兼容 OpenAI 的 `/chat/completions` 接口（DeepSeek、通义、Kimi、Ollama 等）。
  支持配置档、结构化输出、超时预算、重试与程序 AI 兜底；模型的决策理由会显示在牌桌日志里。
- **可复现对局**：同一个种子开局完全一致；存档 = 种子 + 动作序列，可完整重放。
- **像素风正式 UI**：主菜单、开局设置、牌桌、事件动效、回放、读档、设置、大模型配置、
  同屏换人遮挡、数据错误与存档错误提示。窗口基准 1280×800。
- **数据驱动**：卡牌、贵族、规则参数、AI 权重、提示词全部在 `data/`，代码里只保留枚举。

## 当前状态

开发进行中。逻辑层与正式 UI 并行推进：

| 部分 | 已完成 | 未完成 |
|---|---|---|
| 逻辑层 | 阶段 1–5：数据层、规则引擎、对局流程、程序 AI、大模型 AI | 阶段 6 联网对战、阶段 7 整合与导出 |
| 正式 UI | U0–U7：零件库、牌桌、交互、流程、动效、回放、设置与大模型界面 | U8 联网界面、U9 替换调试界面与导出 |

当前 `project.godot` 的主场景仍是调试界面。正式 UI 需要显式打开（见“快速开始”）。

## 快速开始

### 环境

- [Godot 4.7](https://godotengine.org/)（标准版即可，无需 .NET）
- macOS / Windows / Linux

### 运行

```bash
git clone https://github.com/LixiaofengLix/game01-splendor.git
cd game01-splendor

# 先导入一次资源
godot --headless --import --path .

# 正式 UI（当前不是默认主场景）
godot --path . ui/app/app.tscn

# 调试界面 / 最小可视化牌桌（当前默认主场景）
godot --path .
```

macOS 上 Godot 的默认路径是 `/Applications/Godot.app/Contents/MacOS/Godot`，
可以自行设为 `GODOT` 变量：

```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT" --path . ui/app/app.tscn
```

### 操作

- **鼠标**：点击银行筹码拿宝石，点击市场卡或自己的预留卡购买 / 预留。
- **键盘**：`1`–`5` 选择宝石颜色，`Enter` 确认，`R` 预留，`Esc` 取消选择 / 打开暂停菜单；
  回放中 `←` `→` 切换步骤，`空格` 播放 / 暂停。

### 大模型座位

在 **设置 → 大模型** 中新建配置档（BASE URL、API Key、模型名），测试连接后即可在本地开局
设置里把任意座位设为“大模型”。也可以直接编辑 `user://config.json`
（示例见 `data/llm/llm_config.example.json`）。

- API Key 只保存在本机用户目录，不进入仓库、存档或日志。
- 模型回复无法解析、超时或网络失败时，会自动交给指定难度的程序 AI 代打。
- 诊断日志写入 `user://llm_debug.log`。

## 项目结构

```
splendor/
├── autoload/     # DataRegistry（数据加载与校验）、AppConfig（大模型配置档）
├── core/         # 纯逻辑：枚举、数据模型、GameState、Action、Rules、存档格式
├── game/         # GameController 与座位控制器（人类 / 本地）
├── ai/           # 程序 AI：评估器、三档配置、BotController
├── llm/          # 大模型客户端、局面描述、提示词、LLM 控制器与兜底
├── net/          # 联网对战（阶段 6，尚未实现）
├── data/         # 卡牌、贵族、规则参数、AI 权重、大模型提示词（JSON）
├── ui/           # 正式 UI：主题、零件、屏幕、桥接层、像素素材、开发工具
├── debug_ui/     # 调试用文本控制台与最小可视化界面
├── tests/        # 无界面自检脚本与预设局面
└── docs/         # 开发计划、进度、测试用例、UI 规范与对接文档
```

## 架构要点

- **逻辑与表现分离**：`core/` 只有纯数据和纯函数，不依赖 Node、场景树和单例；
  规则参数通过 `RulesConfig` 传入。
- **一切操作都是 Action**：拿宝石、预留、购买、弃宝石、选贵族都是同一种数据对象；
  人类、程序 AI、大模型、远程玩家都只是“产出 Action 的控制器”。
- **状态可序列化**：`GameState.to_dict(viewer_seat)` / `from_dict()`，`viewer_seat`
  用于隐藏他人不可见的信息（牌堆顺序、他人盲抽预留的牌）。
- **随机可复现**：带种子的 `RandomNumberGenerator`，存档 = 种子 + 动作序列。
- **稳定引用**：Action 只用 `card_id`、等级、座位号，不用场面位置索引。
- **只有规则引擎看完整状态**：AI、大模型、客户端和界面都只读过滤后的视图。
- **数据驱动**：数值来自 `data/*.json`，代码中只保留枚举和校验用的结构常量。

逻辑层接口与正式 UI 的接触面见 [`docs/UI_INTEGRATION.md`](docs/UI_INTEGRATION.md)。

## 测试

项目不依赖第三方测试框架，自检脚本以无界面方式运行，失败时退出码非 0。

```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot   # 按需替换

# 数据层：校验卡表 / 贵族 / 规则 / AI 配置，并重新生成 docs/CARD_LIST.md
"$GODOT" --headless --path . tests/data_report.tscn

# 规则自检：随机合法动作跑 2000 局并检查不变量
"$GODOT" --headless --path . tests/rules_selfcheck.tscn -- 2000

# 对局流程 / 控制器 / 视图 / 重放
"$GODOT" --headless --path . tests/flow_selfcheck.tscn

# 程序 AI
"$GODOT" --headless --path . tests/ai_selfcheck.tscn

# 大模型（使用本地模拟 HTTP 服务器，不依赖外网）
"$GODOT" --headless --path . tests/llm_selfcheck.tscn

# 正式 UI 冒烟测试
"$GODOT" --headless --path . tests/ui_smoke.tscn

# 调试界面冒烟测试
"$GODOT" --headless --path . tests/board_smoke.tscn
```

AI 批量模拟（每个种子镜像交换座位，`--sim` 必须为偶数）：

```bash
"$GODOT" --headless --path . tests/ai_sim.tscn -- --sim 100 normal hard
```

## 文档

- [开发计划](docs/DEVELOPMENT_PLAN.md) — 阶段划分、规则细节与验收标准
- [进度](docs/PROGRESS.md) — 已完成内容、与计划的偏差、遗留问题
- [正式 UI 进度](docs/ui/UI_PROGRESS.md) — UI 线各阶段状态
- [视觉规范](docs/ui/VISUAL_SPEC.md) / [界面说明](docs/ui/SCREENS.md) / [交互规则](docs/ui/INTERACTION.md)
- [UI 对接说明](docs/UI_INTEGRATION.md) — `GameController`、视图、事件与存档格式
- [卡表](docs/CARD_LIST.md) — 按等级 / 颜色 / 分数排序，可对照实体卡核对
- [界面样张](docs/ui-mockup-v4.html) — 浏览器直接打开，查看全部 23 屏像素风设计

## 路线图

- [ ] **阶段 6：联网对战** — ENet 主机权威同步、大厅、断线 AI 接管与重连
- [ ] **U8：联网界面** — 建房 / 加入、大厅、掉线接管、重连弹窗
- [ ] **阶段 7 / U9：收尾与导出** — 主场景切换、整数缩放、导出预设、导出包冒烟
- [ ] 读档恢复电脑座位（IR-04）、按座位取视图（IR-01）、真正的逐步回放（IR-03）
- [ ] 暂停时冻结电脑思考（IR-12）、完整日志浮层（`L` 键）
- [ ] 可选：贵族名字、正式音效素材

## 数据与素材来源

- 卡牌与贵族数据取自开源实现，并与多份独立实现逐张交叉比对；结果见
  [`docs/PROGRESS.md`](docs/PROGRESS.md) 的“卡表数据来源与交叉比对”。
- 字体：[Fusion Pixel 12px Proportional 简中](https://github.com/TakWolf/fusion-pixel-font)、
  [Press Start 2P](https://fonts.google.com/specimen/Press+Start+2P)，
  均按 SIL Open Font License 使用，许可证见 `ui/theme/fonts/`。
- 像素贴图由 `ui/tools/build_pixel_assets.tscn` 从代码中的点阵定义生成；
  可重复执行且结果一致。

## 许可证

本仓库尚未添加开源许可证（`LICENSE` 文件）。在补充许可证之前，默认保留所有权利。
