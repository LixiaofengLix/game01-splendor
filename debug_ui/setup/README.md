# debug_ui/setup/

开局设置：人数（2/3/4）、种子、每个座位的类型与配置。

阶段 5 起座位可选“人类”“电脑（简单 / 普通 / 困难）”“大模型”；“远程”阶段 6 再启用。
默认座位 0 是人类，其余座位是“电脑（普通）”，打开就能人机对战。
选择大模型座位后会出现配置档下拉框；「大模型设置…」打开 `debug_ui/llm_settings/` 的配置面板。
座位选项通过 `start_requested(player_count, seed, seat_types, seat_options)` 交给
`debug_ui/main/`，大模型座位形如 `{"llm_profile": "deepseek"}`。
