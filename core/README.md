# core/

纯逻辑层：只有纯数据和纯函数，**不引用 Node、场景和单例**，规则参数通过 `RulesConfig` 传入。
AI 复制状态推演、无界面批量模拟、联网时主机校验动作，都依赖这一层没有副作用。

- `enums.gd` — 宝石颜色、动作类型、对局阶段的枚举，以及枚举与字符串的互转。
- `card_data.gd` / `noble_data.gd` / `rules_config.gd` — 类型化数据对象（由 `DataRegistry` 构造）。
- `player_state.gd` / `game_state.gd` / `action.gd` / `rules.gd` — 阶段 2。
