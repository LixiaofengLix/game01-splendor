# ui/common/

与界面无关的纯函数和显示数据工具：

- `ui_assets.gd` — `UiAssets`：按 `Enums.GemColor` 取筹码 / 宝石 / 吉祥物贴图，
  生成固定像素尺寸的 `TextureRect`，以及 9 宫格 / 平铺贴图节点。
- `view_math.gd` — `UiViewMath`：从过滤视图 + `CardCatalog` 算分数、折扣、持币总数、缺口、
  支付预览、买得起的座位、轮数、终局剩余人数。买得起 / 支付拆分与 `core/rules.gd` 同一算法
  （IR-02 的临时实现）；只读视图，不引用 `GameState`。
- `ui_markup.gd` — `UiMarkup`：日志 / 顶条文案的简写标记 → BBCode。
  `{card:L2-R-01}` 生成带浅色底的卡牌引用，`{gem:red}` 生成 11px 彩色宝石。
- `event_text.gd` — `UiEventText`：`GameEvent.to_dict()` → 中文日志 / 顶条文案。
  盲抽预留只写等级（事件里本来就没有卡牌 id），贵族按要求描述，不显示 id。
- `sfx.gd` — `UiSfx`：音效钩子。`play(id)` 检查 `UiSettings.sfx_enabled()`，按 `SOUNDS`
  找 `ui/assets/sfx/<文件>`；素材不存在时静默跳过。`play_events(events)` 按事件类型播放
  （拿宝石 / 预留 / 购买 / 贵族 / 终局 / 结束）。按钮点击在 `UiButton._ready` 里接 `click`。
  `take_calls()` / `clear_calls()` 是测试钩子（素材为空也能核对调用点）。
