# core/

纯逻辑层：只有纯数据和纯函数，**不引用 Node、场景和单例**。
规则参数通过 `RulesConfig`、卡牌数据通过 `CardCatalog` 注入，视图（`to_dict`）是唯一的信息入口。
AI 复制状态推演、无界面批量模拟、联网时主机校验动作，都依赖这一层没有副作用。

- `enums.gd` — 宝石颜色、动作类型、对局阶段、事件类型的枚举，以及枚举与字符串的互转。
- `card_data.gd` / `noble_data.gd` / `rules_config.gd` — 类型化数据对象（由 `DataRegistry` 构造）。
- `card_catalog.gd` — 卡牌 / 贵族查表 + 未知牌占位（从过滤视图重建状态时用）。
- `player_state.gd` — 一名玩家的宝石、已购卡牌、预留卡牌、贵族。
- `action.gd` — 动作数据对象（拿宝石 / 预留 / 购买 / 弃宝石 / 选贵族），含 JSON 形态与中文描述。
- `game_event.gd` — `Rules.apply` 返回的事件（日志、界面、联网同步用）。
- `game_state.gd` — 完整对局状态：`to_dict(viewer_seat)` / `from_dict()` / `duplicate_state()` / `validate()`。
- `rules.gd` — 规则引擎：`setup()`、`get_legal_actions(view)`、`apply(state, action)`。
- `save_file.gd` — 存档（种子 + 动作序列）与快照（完整状态）文件的格式。
