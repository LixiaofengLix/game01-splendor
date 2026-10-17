# game/

对局流程与座位控制器（Node 层，可以引用 autoload；规则仍在 `core/`）。

- `game_controller.gd` — 持有 GameState，按座位向控制器要动作，校验后执行；发出
  `state_changed` / `events_emitted` / `game_finished` / `action_rejected`。界面只监听这些信号。
- `player_controller.gd` — 控制器基类：`request_action(view, legal_actions)` + `action_decided(action)`。
- `human_controller.gd` — 人类座位：界面点击后 `submit()`；动作可以同步给出，也可以异步等待。
- 阶段 4 的 `ai/bot_controller.gd`、阶段 5 的 `llm/llm_controller.gd`、阶段 6 的 `remote_controller.gd`
  都继承 `PlayerController`，通过 `GameController.start_with_controllers()` 接入。
