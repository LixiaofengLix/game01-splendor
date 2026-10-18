# game/

对局流程与座位控制器（Node 层，可以引用 autoload；规则仍在 `core/`）。

- `game_controller.gd` — 持有 GameState，按座位向控制器要动作，校验后执行；发出
  `state_changed` / `events_emitted` / `game_finished` / `action_rejected`。界面只监听这些信号。
  `start_new_game()` 的座位类型支持 `human` / `bot_easy` / `bot_normal` / `bot_hard` / `llm`；
  大模型座位用 `seat_options` 里的 `{"llm_profile": "配置档 id"}` 指定配置档。
  `is_current_human()` / `is_current_llm()` 给界面判断当前能否点击、显示什么等待状态；
  重置 / 换局前对控制器调用 `cancel_pending()`。
- `game_controller.gd` 还转发大模型座位的 IR-08 信号：
  `waiting_started` / `reason_emitted` / `fallback_used`。
- `player_controller.gd` — 控制器基类：`request_action(view, legal_actions)` + `action_decided(action)`；
  异步控制器覆盖 `cancel_pending()`。
- `human_controller.gd` — 人类座位：界面点击后 `submit()`；动作可以同步给出，也可以异步等待。
- `ai/bot_controller.gd`、`llm/llm_controller.gd` 都继承 `PlayerController`；
  阶段 6 的 `remote_controller.gd` 也会继承它，通过 `GameController.start_with_controllers()`
  接入（或走座位类型）。
