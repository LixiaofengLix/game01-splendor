# autoload/

全局单例（在 `project.godot` 的 `[autoload]` 里注册）。

- `data_registry.gd` — 启动时加载 `data/` 下的 JSON，校验并转成 `core/` 的类型化对象；校验失败时逐条报出问题。
- `app_config.gd` — 用户设置读写（阶段 5）。
- `network_manager.gd` — 建主机 / 加入、连接事件（阶段 6）。
