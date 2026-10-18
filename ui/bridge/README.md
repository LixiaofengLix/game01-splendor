# ui/bridge/

UI 与逻辑层之间的唯一接触面。屏幕和零件只认这一层；`ui/` 的其他目录不引用 `GameController` / `GameState`。

- `live_backend.gd` — `UiLiveBackend`（RefCounted）：包装 `GameController`，转发
  `state_changed` / `events_emitted` / `game_finished` / `action_rejected` 和 IR-08 的大模型信号。
  只调用 `docs/UI_INTEGRATION.md` 的公开接口。
- `table_session.gd` — `UiTableSession`（Node，挂在牌桌宿主下）：
  - `start_local({count, seed, seats: [{name, type}], hotseat_cover})` / `load_snapshot(state, errors)` / `close()`。
  - 信号：`view_updated(view, me_seat)`、`events_arrived(Array[Dictionary])`、`game_ended(result)`、
    `action_failed(message)`、`seat_status_changed(seat, status)`。
  - `legal_actions()` / `submit(action)` / `submit_sequence(actions)` / `is_my_turn()` / `me_seat()` /
    `names()` / `seat_types()` / `seat_info(seat)` / `rules()` / `catalog()` / `log_entries()` / `result()`。
  - 隐私：别人的盲抽 id 一律置空；viewer 不是“我”时，viewer 自己的盲抽也置空；
    “我”的盲抽用缓存补上（见下）。
  - 日志：把事件整理成 `{seat, text, time}`（从新到旧），连续的弃宝石合并成一条。
  - 结算：`game_ended` 的 `result` 字段见 `docs/ui/BRIDGE_AND_REQUESTS.md` 1.2；`tiebreak` 由分数和卡牌数推出。

## 盲抽缓存的边界（IR-01 落地前）

`_blind_cache` 记录“本机座位预留区的卡 id 列表”。第一次看到自己的视图时整体刷新；
之后用公开事件维护位置：预留追加（盲抽补一个未知空位）、从预留区购买时移除对应项。
刚盲抽预留的那张牌在事件里没有 id，下一次视图又属于下一位玩家，所以**这张新牌要到本机玩家的
下一个回合才会翻正面**；在别人的回合里先画牌背。IR-01（按座位取视图）落地后可以去掉缓存，
直接取 `to_dict(座位)`。

## 约定

- 屏幕不直接调用 `GameController`；需要新能力先登记 IR（`docs/ui/BRIDGE_AND_REQUESTS.md`）。
- 视图是唯一真相：每次 `view_updated` 都按整桌重画；本地选择状态由 `UiTableFlow` 用新的合法动作重新校验。
- `UiTableSession` 不读 `GameState` 内部字段，也不认识具体屏幕。
