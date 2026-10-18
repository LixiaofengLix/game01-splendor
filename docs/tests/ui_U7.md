# UI 阶段 U7 测试用例（设置 + 大模型界面）

> 命令都在仓库根目录运行。`$GODOT` = `/Applications/Godot.app/Contents/MacOS/Godot`。
> 自动检查：`$GODOT --headless --path . tests/ui_smoke.tscn`（U7 相关 **145 项**，总计 1505 项）。
> 需要看画面的用例在最后，截图必须带窗口（`--headless` 没有渲染）。

## 自动验证（不用人工看）

### U7-01 设置持久化

- **前置**：无（测试用 `user://ui_smoke_settings.json`，不碰真实设置）。
- **步骤**：运行 `ui_smoke`。
- **预期**：
  - 没有设置文件时全部用默认值（昵称“小明”、标准速度、动效 / 音效 / 购买前确认 / 同屏遮挡 / 自动存档开，
    全屏 / 显示 id 关）。
  - 改昵称 / 速度 / 各个开关后文件立即出现，带 `schema_version: 1`。
  - 重新 `load_from_disk()` 后值全部恢复。
  - JSON 损坏 → 回默认并记录原因；`schema_version` 不匹配 → 不采用文件内容；未知动画速度 → 回标准。

### U7-02 设置页（15 / 关于）

- **前置**：无。
- **步骤**：运行 `ui_smoke`（`_check_u7_settings_screen`）。
- **预期**：
  - 四个页签【通用】【大模型】【联网】【关于】，默认通用，联网页签禁用。
  - 通用页改昵称 / 动画速度 / 播放动效 / 购买前确认 / 同屏遮挡 / 音效 / 显示 id / 自动存档后，
    `UiSettings` 立即变化并写盘。
  - 存档目录写到页面（`user://saves/`）。
  - 关于页含 Fusion Pixel、Press Start 2P、OFL、`ui_settings.json`。
  - 返回按钮发 `back_requested`。

### U7-03 设置接到牌桌

- **前置**：无。
- **步骤**：运行 `ui_smoke`（`_check_u7_preferences_on_table`）。
- **预期**：
  - 打开“显示卡牌 id”后市场卡显示 id；`session_info.show_card_ids` 可以覆盖。
  - 关掉“购买前确认”后，点一张买得起的卡直接产生购买日志、不进入选中；
    打开后同样点击只选中卡。
  - “每回合自动存档”关掉后拿宝石不写自动存档；打开后下一回合恢复写盘。

### U7-04 大模型配置档页（16）

- **前置**：无（测试用本地 `MockLlmServer`，不访问外网）。
- **步骤**：运行 `ui_smoke`（`_check_u7_llm_page`）。
- **预期**：
  - 配置档列表、当前选中项、名称 / BASE URL / 模型名回填；API KEY 是密码框。
  - 思考预算 / 重试 / 兜底难度按配置档回显。
  - 最大回复 token / 单次请求超时按配置档回显；思考强度 / 结构化输出分段回显。
  - 保存修改后 `AppConfig` 里的名称、`max_tokens`、`thinking_effort`、`structured_output` 更新，
    状态“已保存”。
  - 【测试连接】发出与正式出招一致的请求（带 `response_format` / `reasoning_effort`）并显示
    “连接成功 · N 秒”，列表状态变“已连接”；服务不支持某个参数时成功信息会说明已自动关闭。
  - 【＋ 新建】增加一行并选中新配置档；【删除】需要点两次，删除后列表刷新。

### U7-05 大模型座位与牌桌显示（02 / 17）

- **前置**：无（测试用本地模拟服务器 + 两个配置档，激活的是“关闭的地址”，座位指定的是可用配置）。
- **步骤**：运行 `ui_smoke`（`_check_u7_local_setup_llm` / `_check_u7_table_llm_display` / `_check_u7_llm_live`）。
- **预期**：
  - 有配置档时“大模型”分段可选；没有配置档时禁用并给出提示。座位默认用激活配置档，可下拉切换。
  - 开局数据的 `seats[i].llm_profile` 与 `seat_options[i].llm_profile` 一致。
  - 默认昵称进入第一个人类座位；同屏遮挡默认值生效，“4 人同屏”组合仍打开遮挡。
  - 大模型回合：胶囊“已等 N 秒”、对手面板等待块（配置档 · 第 N 次请求 + 已等 / 预算 + 进度条）。
  - 模型回复后日志出现紫色竖线理由；等待状态清掉、等待块消失。
  - 乱回复 / 超时 / 网络错误触发兜底：顶条“X 的大模型回复 N 次都没看懂　这一步已由困难电脑代打”，
    日志那条带 orange“电脑代打”标签和原因。
  - 座位指定“mock”配置档时请求真的发到 mock 服务器（证明 `seat_options` 生效，而不是用激活的坏地址）。

### U7-06 主菜单 / 暂停菜单的设置入口

- **前置**：无。
- **步骤**：运行 `ui_smoke`（`_check_u7_pause_and_app_settings`）。
- **预期**：
  - 主菜单【设置】可点，进入设置后【返回】回主菜单。
  - 牌桌暂停菜单【设置】可点：暂停菜单关闭，设置屏压在牌桌上、牌桌隐藏；【返回】回到同一局牌桌，
    状态不变。
  - 设置屏返回后 `UiTableFlow.refresh()` 重画（显示 id 等立即生效）。

## 人工看画面

### U7-07 设置页截图

```bash
$GODOT --path . ui/dev/capture.tscn --quit-after 400 -- --screen settings --out /tmp/splendor_ui/u7_settings.png --width 1280 --height 800 --wait 10
$GODOT --path . ui/dev/capture.tscn --quit-after 400 -- --screen settings_llm --out /tmp/splendor_ui/u7_settings_llm.png --width 1280 --height 800 --wait 10
$GODOT --path . ui/dev/capture.tscn --quit-after 400 -- --screen settings_about --out /tmp/splendor_ui/u7_settings_about.png --width 1280 --height 800 --wait 10
```

- **观察点**：
  1. 顶栏页签在右侧，联网页签是灰的；标题“设置”。
  2. 通用页左右两栏对齐，开关和分段没有溢出；字号清晰。
  3. 大模型页：左侧列表每行“名称 + 模型 · 座位数 + 状态”不重叠；右侧可滚动，
     从上到下能看到连接配置、出手（含最大 token / 单次超时 / 思考强度 / 结构化输出）、
     兜底与性格；按钮一行放得下。
  4. 关于页文字完整，不截断。

### U7-08 大模型牌桌截图（17）

```bash
$GODOT --path . ui/dev/capture.tscn --quit-after 400 -- --fixture g3_llm_waiting --out /tmp/splendor_ui/u7_llm_waiting.png --width 1280 --height 800 --wait 12
```

- **观察点**：
  1. 顶栏胶囊“紫晶 · 大模型 [转圈] 已等 12.4 秒”。
  2. 紫晶的对手面板底部有浅紫等待块：“DeepSeek · 第 1 次请求　12.4 / 30 秒”，进度条约 41%。
  3. 日志第二条下面有紫色竖线引出的模型理由。
  4. 日志里有一条 orange“电脑代打”标签 + “回复解析失败，由困难电脑代打”。

### U7-09 走一遍设置（人工）

```bash
$GODOT --path . ui/app/app.tscn
```

- 主菜单 →【设置】→ 通用：把默认昵称改成别的名字、动画速度改成“快”、关掉“显示卡牌 id”。
- 大模型页：确认至少有一个配置档；**不要**在这里填真实 Key 截图或发给别人。
- 返回主菜单 → 本地游戏：第一个座位名字应是新昵称。
- 开一局（1 人类 + 1 大模型，选有 Key 的配置档或本地 Ollama）：
  - 大模型回合看胶囊计时、等待块、日志理由；
  - 拔网线 / 填错 Key，看兜底顶条和日志“电脑代打”。
- 退出游戏重开：设置应保留（`user://ui_settings.json`）。
- 全屏开关：切换后窗口立即变化；再关掉回窗口模式。

### U7-10 设置在大屏 / 全屏下

- **前置**：U7-09 打开的窗口。
- **步骤**：打开全屏，进设置页各页签。
- **预期**：内容仍然居中 / 对齐，没有控件被裁掉（U9 前是分数缩放，允许像素轻微抖动）。
