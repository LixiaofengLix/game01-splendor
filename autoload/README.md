# autoload/

全局单例（在 `project.godot` 的 `[autoload]` 里注册）。

- `data_registry.gd` — 启动时加载 `data/` 下的 JSON（卡牌、贵族、规则、三档 AI 配置），
  校验并转成 `core/` / `ai/` 的类型化对象；校验失败时逐条报出问题。
  AI 配置用 `ai_profile(id)` / `ai_profiles()` 读取。
- `app_config.gd` — 用户设置（阶段 5 目前只有大模型配置档）。读写 `user://config.json`；
  首次运行从 `data/llm/llm_config.example.json` 复制。API Key 只存在用户目录，不进仓库、不进存档。
  接口：`llm_profile_ids()` / `llm_profile(id)` / `active_llm_profile()` /
  `save_llm_profile()` / `delete_llm_profile()` / `set_active_llm_profile()` / `save()`。
- `network_manager.gd` — 建主机 / 加入、连接事件（阶段 6）。
