# ui/components/

可复用的界面零件。零件只接收“显示数据”（颜色、数字、`card_id` + `CardCatalog`、状态布尔值），
不认识视图字典；视图到零件的转换在 `screens/` 里做。

- `frame.gd` — `UiFrame`：9 宫格框 + 底色 + 可选硬投影 / 顶部内高光 / 重点色条，内容放进 `content`。
- `button.gd` — `UiButton`：5 种配色（accent / dark / ghost / quiet / danger）× sm / 默认 / lg；
  悬停抬起、按下压扁；`preview_state` 只给陈列场景用。
- `menu_button.gd` — `UiMenuButton`：主菜单大按钮（24 号主文字 + 12 号副文字 + `›`）。
- `segmented.gd` — `UiSegmented`：分段选择，`selected_changed(index)`。
- `switch.gd` — `UiSwitch`：40×24 像素开关；代码里切换用 `set_on()`。
- `input_field.gd` — `UiInput`：像素输入框。
- `tag.gd` — `UiTag`：默认 / dark / mint / orange / purple / red 6 种配色。
- `kbd.gd` — `UiKbd`：键帽。
- `progress_bar.gd` — `UiProgressBar`：高 6，带 8px 周期竖纹。
- `spinner.gd` — `UiSpinner`：12×12 四帧像素转圈。
- `list_row.gd` — `UiListRow`：列表行（普通 / 选中）。
- `modal_frame.gd` — `UiModalFrame`：大框弹窗，`body()` 加内容、`add_action()` 加按钮。
- `toast.gd` — `UiToast`：2.5 秒自动消失的成功提示。
- `notice_card.gd` — `UiNoticeCard`：右栏持续状态提示卡。
- `gem_chip.gd` — `UiGemChip`：圆形筹码，lg / md / sm / xs，满币 / 空心 / 已选 / 待弃 / bare。
- `bonus_tile.gd` — `UiBonusTile`：方形折扣块，noble / opp / base / big / md。
- `cost_pill.gd` — `UiCostPill`：花费药丸，普通 / 迷你。
- `dev_card.gd` — `UiDevCard`：市场 / 迷你发展卡，含可买、差 N、选中、光晕、对手头像、空位、牌背、盲抽标签。
- `deck_pile.gd` — `UiDeckPile`：牌堆（有牌 / 已空 / 选中）。
- `noble_tile.gd` — `UiNobleTile`：贵族牌（市场 / 大号 / 选中）。
- `card_ref.gd` — `UiCardRef`：日志里的卡牌引用小块。

所有类名统一 `Ui` 前缀。陈列与截图见 `ui/dev/`。
