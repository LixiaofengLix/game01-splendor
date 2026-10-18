# ui/screens/save_browser/

03 读档（`save_browser.tscn` + `UiSaveBrowser`，列表行 `save_row.gd` / `UiSaveRow`）。

- 左列：`UiSaveStore.list()` 的全部文件。自动存档 / 快速存档 / 结束记录 / 预设局面 / 坏文件都列出；
  坏文件用红色“无法读取”标签写明原因，不静默消失。
- 右列详情：保存时间、玩家（名字 / 类型 / 分数）、种子、动作步数与轮数、完整性、继续 / 删除。
  - 完整性在选中时调用 `UiSaveStore.validate()`：回放会真的重放并比对指纹，快照会尝试载入。
  - “从头看回放”按钮保留但隐藏，U6 打开。
  - 删除需要二次确认（`UiConfirmModal`）；其他工具写的只读 json 不能删。
- 继续只发 `continue_requested(entry)`；载入和失败弹窗由应用入口处理，读档列表不会因为失败消失。
- `configure(store, back_label)`：从主菜单进入时返回主菜单，从牌桌暂停菜单进入时返回牌桌。
