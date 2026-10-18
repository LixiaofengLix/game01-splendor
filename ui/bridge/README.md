# ui/bridge/

UI 与逻辑层之间的唯一接触面。屏幕和零件只认这一层；`ui/` 的其他目录不引用 `GameController` / `GameState`。

- `live_backend.gd` — `UiLiveBackend`（RefCounted）：包装 `GameController`，转发
  `state_changed` / `events_emitted` / `game_finished` / `action_rejected` 和 IR-08 的大模型信号。
  只调用 `docs/UI_INTEGRATION.md` 的公开接口。载入支持 `load_snapshot()` / `load_replay()`。
- `table_session.gd` — `UiTableSession`（Node，挂在牌桌宿主下）：
  - `start_local({count, seed, seats: [{name, type}], hotseat_cover})` / `resume(entry, errors)` /
    `resume_until(entry, step, errors)` / `load_snapshot(state, errors)` / `close()`。
  - 信号：`view_updated(view, me_seat)`、`events_arrived(Array[Dictionary])`、`game_ended(result)`、
    `action_failed(message)`、`seat_status_changed(seat, status)`。
  - 动作与查询：`legal_actions()` / `submit(action)` / `submit_sequence(actions)` / `is_my_turn()` /
    `me_seat()` / `names()` / `seat_types()` / `seat_info(seat)` / `rules()` / `catalog()` /
    `log_entries()` / `result()` / `elapsed_seconds()`。
  - 存档：`can_save()` / `build_save_data()` / `fingerprint()`；重开一局用 `rematch_setup()`。
  - 读档：`original_seat_types()` / `hotseat_cover()` / `resume_note()`。
  - 隐私：别人的盲抽 id 一律置空；viewer 不是“我”时，viewer 自己的盲抽也置空；
    “我”的盲抽用缓存补上（见下）。
  - 日志：把事件整理成 `{seat, text, time}`（从新到旧），连续的弃宝石合并成一条。
  - 结算：`game_ended` 的 `result` 字段见 `docs/ui/BRIDGE_AND_REQUESTS.md` 1.2；`tiebreak` 由分数和卡牌数推出。
- `save_entry.gd` — `UiSaveEntry`（RefCounted）：读档列表的一项。字段有 `kind`（replay / snapshot /
  unreadable）、`reason`、`ui_meta`、`display_name`、`player_count`、`action_count`、`saved_at`、
  `read_only`、以及选中时填写的 `verify_*`。屏幕只读它，不解析存档 JSON。
- `ui_settings.gd` — `UiSettings`（RefCounted，全部静态）：UI 自有设置的运行时状态。
  U5 只有 `anim_speed`（`slow` / `normal` / `fast`，倍率 1.5 / 1 / 0.5）、`animations_enabled`、
  `sfx_enabled`、`confirm_before_buy`；`reset_defaults()` 供测试用。
  持久化（`user://ui_settings.json`）按计划在 U7 做。
- `replay_source.gd` — `UiReplaySource`（Node）：14 回放屏的数据源。
  - `open(entry, errors)` / `open_data(data, ui_meta, player_count, errors)`；打开时载入最后一步并
    比对存档指纹，失败原因写进 errors。
  - 查询：`step_count()` / `view(step, viewer_seat)` / `public_view(step)` / `actor_at(step)` /
    `round_at(step)` / `action_at(step)` / `step_text(step)` / `events_at(step)` /
    `log_entries(step)` / `fingerprint()`。
  - `events_at(step)` 在 IR-03 前合成动效事件（拿 / 预留 / 购买 / 弃 / 选贵族 / 终局），
    购买支付和预留拿金从前后视图的筹码差算；回放屏把它交给 `UiTableAnim` 播飞行动效。
  - IR-03 落地前的临时实现：用截断存档 + 单独的 `GameController.load_replay` 按需载入每一步，
    **只有当前行动者视角**；指定其他座位时返回“全部公开”视图（所有盲抽 id 置空），不会泄露。
    视图和步骤说明按步缓存；时间轴颜色由回放屏在后台逐帧补齐。
- `save_store.gd` — `UiSaveStore`（Node）：管理 `user://saves/`。
  - `list()` / `autosave_entry()` / `autosave_summary()` / `validate(entry)` / `delete_entry(entry)`。
  - `save_autosave(data, meta)`（每回合结束）/ `save_quick(data, meta)`（暂停菜单）/ `transfer_finished(data, meta)`
    （对局结束写 `finished/<yyyyMMdd-HHmmss>.json` 并删掉自动存档）。
  - `ui_meta` 由 `make_meta()` / `make_summary()` 生成：名字、座位类型、同屏开关、用时、轮数 / 当前座位 /
    分数 / 胜者。读不了的存档也留在列表里，`reason` 取 `version_too_new` / `corrupt` / `unknown_kind`；
    选中时 `validate()` 用临时 `GameController` 重放，失败记为 `verify_failed` 并指出步数。
  - 测试可以设置静态变量 `root_override` 指向临时目录（`user://ui_smoke_saves`）。

## IR-04 前的读档行为

`GameController.load_replay` / `load_snapshot` 目前会把所有座位恢复为人类控制器。`UiTableSession.resume()`
因此把实际座位类型都记成 `human`，但保留 ui_meta 里的原类型：牌桌按实际类型显示（都是人类），
`resume_note()` 给出“电脑座位暂时以人类身份恢复”的提示；`rematch_setup()` 和存档 ui_meta 仍沿用原类型。
IR-04 落地后只需在 `_resume_payload()` 里把原类型传给控制器。

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
