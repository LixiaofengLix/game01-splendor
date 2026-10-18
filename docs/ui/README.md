# docs/ui/

正式 UI 的开发文档。依据是 `docs/ui-mockup-v4.html`（V4 像素风，23 屏），和逻辑阶段 5–7 并行开发。

阅读顺序：

1. `UI_DEV_PLAN.md` — 目标、并行开发约定（目录归属、共享文件、接口冻结）、`ui/` 目录结构、阶段 U0–U9 与验收。
2. `VISUAL_SPEC.md` — 视觉规范：颜色、字体、像素贴图、9 宫格边框、各零件的尺寸与状态。
3. `SCREENS.md` — 23 屏逐屏说明：布局、数据来源、交互、边界情况、依赖。
4. `INTERACTION.md` — 牌桌交互状态机、弹窗流程、锁定 / 隐私 / 换人遮挡、事件动效、快捷键、文案规则。
5. `BRIDGE_AND_REQUESTS.md` — UI 与逻辑层之间的桥接层（真实后端 / 假后端）、测试夹具、
   需要逻辑侧补的接口清单（IR-xx）。

UI 线的进度写在 `UI_PROGRESS.md`（U0 时创建），验收用例写在 `docs/tests/ui_UN.md`。
