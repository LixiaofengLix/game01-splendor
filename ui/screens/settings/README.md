# ui/screens/settings/

设置屏（15 / 16 / 关于）：`settings_screen.tscn` + `UiSettingsScreen`，顶栏页签【通用】【大模型】【联网】【关于】。
屏幕只通过 `UiSettings` / `UiLlmBridge` 读写，不直接调用 `AppConfig` / `LlmClient`。

- `general_page.gd`（`UiSettingsGeneralPage`）：对局偏好（默认昵称、动画速度、播放动效、购买前确认、
  同屏遮挡默认值）、声音与显示（音效、全屏、显示卡牌 id）、存档（每回合自动存档、打开存档目录）。
  改动立即生效并写 `user://ui_settings.json`。
- `llm_page.gd`（`UiSettingsLlmPage`）：左侧配置档列表（名称、模型 · 几个座位在用、已连接 / 未测试 /
  连接失败），【＋ 新建】；右侧连接配置（名称 / BASE URL / API KEY 密码框 / 模型名、【测试连接】【保存】【删除】）、
  出手（思考上限 / 重试次数 / 温度 / 最大回复 token / 单次请求超时 / 思考强度 / 结构化输出）、
  兜底与性格；右栏可滚动。测试连接用 `UiLlmBridge.test_connection()`。
  `set_usage({profile_id: 座位数})` 由应用入口传入。
- `about_page.gd`（`UiSettingsAboutPage`）：版本、字体许可证（Fusion Pixel / Press Start 2P / OFL）、
  卡表来源、设置文件与存档目录。
- 联网页签在 U8 前禁用；程序里 `open_tab("net")` 仍可显示占位提示。
- 入口：主菜单的【设置】和暂停菜单的【设置】。从牌桌打开时应用入口把设置屏压在牌桌之上（隐藏牌桌），
  返回后调用 `UiTableFlow.refresh()`，让“显示卡牌 id”等设置立即反映到当前画面。
