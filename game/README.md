# game/

对局流程与座位控制器（阶段 3）。

- `game_controller.gd` — 持有 GameState，向当前玩家的控制器要动作，校验后执行，发出 `state_changed` / `events_emitted` / `game_finished`。
- `player_controller.gd` — 控制器基类。
- `human_controller.gd` / `remote_controller.gd` — 人类与远程座位。
