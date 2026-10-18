# ui/screens/local_setup/

02 本地开局设置（`local_setup.tscn` + `UiLocalSetup`）。

- 座位行：序号 + 吉祥物 + 名字（最多 8 字）+ 类型分段【人类 / 电脑 / 大模型】+ 难度分段 + 移除。
  大模型类型在 U7 前禁用；座位数上下限和规则摘要全部来自 `RulesConfig`。
- 常用组合：单挑电脑 / 标准 3 人 / 4 人同屏 / 电脑对战；点击后填好座位，再改任意座位会取消选中样式。
- 对局面板：人数分段（和座位数同步）、种子（留空随机）、只读规则标签。
- 同屏面板：换人遮挡开关（≥ 2 位人类时才生效）。电脑思考延迟（IR-05 落地前隐藏）。
- “开始对局”发出 `start_requested(setup)`；setup 的键：
  `{count, seed, seats: [{name, type}], hotseat_cover}`，座位类型是引擎字符串
  （`human` / `bot_easy` / `bot_normal` / `bot_hard`）。全是电脑时按钮改“开始观战”。
- 开局失败时由应用入口调用 `report_start_failed(message)` 在按钮上方显示原因。
