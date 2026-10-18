# ai/

程序 AI（阶段 4）。AI 只接收过滤视图（`GameState.to_dict(viewer_seat)`）和合法动作列表，
看不到牌堆顺序、种子和对手盲抽预留的牌；推演时用 `GameState.from_dict(view)` 重建局面，
未翻开的牌是未知牌。

- `bot_controller.gd` — 座位控制器（继承 `PlayerController`）。同步决定动作；正常回合可以配置
  思考延迟（界面观察用），弃宝石 / 选贵族立即处理。重置 / 换局时 `cancel_pending()` 会作废
  尚未发出的动作。
- `evaluator.gd` — 动作评分与三档策略：`greedy`（一步 + 随机扰动 / 偶尔犯错）、
  `one_step`（一步最优）、`two_ply`（我方一步 + 下一位对手最佳回应；确定性节点预算 + 超时安全网）。
- `ai_profile.gd` — 从 `data/ai/*.json` 解析的静态类型配置（策略、搜索预算、权重、思考延迟）。

权重与难度参数在 `data/ai/{easy,normal,hard}.json`，含义见 `data/README.md`。

改完 AI 后跑：

```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
$GODOT --headless --path . tests/ai_selfcheck.tscn
$GODOT --headless --path . tests/ai_sim.tscn -- --sim 100 easy normal
$GODOT --headless --path . tests/ai_sim.tscn -- --sim 100 normal hard
```
